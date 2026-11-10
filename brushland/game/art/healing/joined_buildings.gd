extends RefCounted
## Each plot owns its half of every wing. Heights at the boundary depend on
## both plots, so replacing either building does not leave a gap in the ridge.
const HALF := 0.80
const WOOD := Color("#785139")
const TRIM := Color("#957052")
const PLASTER := Color("#e6cdab")
const STONE := Color("#aa9b86")
const BRICK := Color("#986b58")
const DIRECTIONS := [Vector3.BACK, Vector3.RIGHT, Vector3.FORWARD, Vector3.LEFT]
const Village = preload("res://game/art/healing/village_models.gd")
const PAN_TILES = preload("res://game/art/healing/pantiles.gdshader")
static var tiles_material: ShaderMaterial

class Geometry:
	var walls := SurfaceTool.new()
	var roof := SurfaceTool.new()
	var windows := SurfaceTool.new()
	var roof_color: Color
	var face_count := [0, 0, 0]

	func _init(tint: Color) -> void:
		roof_color = tint
		for tool in [walls, roof, windows]:
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	func face(a: Vector3, b: Vector3, c: Vector3, outside: Vector3, pigment: Color, slot: int = 0) -> void:
		var normal := (b-a).cross(c-a)
		if normal.length_squared() < 0.00000001:
			return
		normal = normal.normalized()
		var points := [a,c,b]
		if normal.dot(outside) < 0:
			normal = -normal
			points = [a,b,c]
		var tool: SurfaceTool = [walls,roof,windows][slot]
		var along := Vector2(-normal.z,normal.x).normalized()
		for p: Vector3 in points:
			tool.set_normal(normal)
			tool.set_color(pigment.srgb_to_linear())
			tool.set_uv(Vector2(Vector2(p.x,p.z).dot(along),p.y))
			tool.add_vertex(p)
		face_count[slot] += 1

	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3, pigment: Color, slot: int = 0) -> void:
		face(a,b,c,outward,pigment,slot)
		face(a,c,d,outward,pigment,slot)

	func tile(a: Vector3, b: Vector3, c: Vector3) -> void:
		face(a,b,c,Vector3.UP,roof_color,1)

	func panel(side: Vector3, s0: float, s1: float, d: float, bottom: float, top: float, color: Color, slot: int = 0) -> void:
		var axis := Vector3(side.z,0,-side.x)
		var a := axis*s0 + side*d + Vector3.UP*bottom
		var b := axis*s1 + side*d + Vector3.UP*bottom
		quad(a,b,b+Vector3.UP*(top-bottom),a+Vector3.UP*(top-bottom),side,color,slot)

	func beam(a: Vector3, b: Vector3, width: float, col: Color) -> void:
		var forward := (b-a).normalized()
		if forward.is_zero_approx():
			return
		var across := forward.cross(Vector3.UP)
		if across.length_squared() < 0.01:
			across = forward.cross(Vector3.RIGHT)
		across = across.normalized() * width * 0.5
		var up := forward.cross(across).normalized() * width * 0.5
		var ring := [across+up,-across+up,-across-up,across-up]
		for i in range(4):
			var left: Vector3 = ring[i]
			var right: Vector3 = ring[(i+1)%4]
			quad(a+left,a+right,b+right,b+left,left+right,col)
		quad(a+ring[0],a+ring[1],a+ring[2],a+ring[3],-forward,col)
		quad(b+ring[0],b+ring[1],b+ring[2],b+ring[3],forward,col)

	func finish(root: Node3D, tile_mat: Material, window_mat: Material) -> void:
		for slot in range(3):
			if face_count[slot] == 0:
				continue
			var piece := MeshInstance3D.new()
			piece.name = ["HalfTimber","JoinedRoof","Casements"][slot]
			var tool: SurfaceTool = [walls,roof,windows][slot]
			piece.mesh = tool.commit()
			piece.material_override = [Village.paint(Color.WHITE),tile_mat,window_mat][slot]
			root.add_child(piece)

static func local_ports(o: Dictionary, seams: Array) -> Dictionary:
	var ports := {}
	var center := Vector2(o.x+0.5,o.z+0.5)
	var turn := Basis(Vector3.UP,int(o.rotation)*PI*0.5)
	for seam in seams:
		var delta: Vector2 = seam.center-center
		var local: Vector3 = turn * Vector3(delta.x,0,delta.y)
		var direction: Vector2i = seam.direction
		var side: Vector3 = (turn * Vector3(direction.x,0,direction.y)).round()
		var axis := Vector3(side.z,0,-side.x)
		var mid := local.dot(axis)
		var span: float = HALF if seam.width == 2 else seam.width * 0.42
		var port := {"a":mid-span, "b":mid+span, "other_form":int(seam.other_form), "full":seam.width == 2.0}
		if not ports.has(side):
			ports[side] = []
		ports[side].append(port)
	for side in ports:
		ports[side].sort_custom(func(a,b): return a.a < b.a)
	return ports

static func eave(form: int) -> float:
	return [1.30,1.94,1.49][form]

static func join_wing(g: Geometry, side: Vector3, port: Dictionary, form: int, radius: float, hall: bool) -> void:
	var tangent := Vector3(side.z,0,-side.x)
	var span := float(port.b-port.a)
	var side_height: float = (eave(form)+eave(port.other_form))*0.5
	var inner_y := eave(form)
	var inside := side*radius
	var inset := 1.0 if port.full and hall else radius
	var a := inside + tangent*float(port.a)*inset
	var b := inside + tangent*float(port.b)*inset
	var end_a := side + tangent*float(port.a)
	var end_b := side + tangent*float(port.b)
	var left := a + Vector3.UP*inner_y
	var right := b + Vector3.UP*inner_y
	var rise := 0.67 if port.full else span*0.38
	var peak := (a+b)*0.5 + Vector3.UP*(inner_y+rise)
	var far_peak := (end_a+end_b)*0.5 + Vector3.UP*(side_height+rise)
	var far_left := end_a + Vector3.UP*side_height
	var far_right := end_b + Vector3.UP*side_height
	if hall:
		var apex := Vector3.UP*(inner_y+0.67)
		g.tile(apex,left,peak)
		g.tile(apex,peak,right)
	g.tile(left,far_left,far_peak)
	g.tile(left,far_peak,peak)
	g.tile(peak,far_peak,far_right)
	g.tile(peak,far_right,right)
	g.quad(a,end_a,far_left,left,-tangent,PLASTER)
	g.quad(b,end_b,far_right,right,tangent,PLASTER)
	g.beam(left,far_left,0.055,WOOD)
	g.beam(right,far_right,0.055,WOOD)
	# No partitions across the boundary. The paired wings are one structure.
	for pair in [[a,end_a],[b,end_b]]:
		g.beam(pair[0]+Vector3.UP*0.13,pair[1]+Vector3.UP*0.13,0.08,STONE)

static func casement(g: Geometry, side: Vector3, mid: float, y: float, width: float, d: float) -> void:
	g.panel(side,mid-width/2,mid+width/2,d,y,y+0.41,WOOD)
	g.panel(side,mid-width/2+0.035,mid+width/2-0.035,d+0.008,y+0.045,y+0.365,Color.WHITE,2)
	g.panel(side,mid-0.016,mid+0.016,d+0.018,y+0.035,y+0.38,TRIM)
	g.panel(side,mid-width/2,mid+width/2,d+0.02,y+0.18,y+0.205,TRIM)
	var tangent := Vector3(side.z,0,-side.x)
	g.beam(side*d+tangent*(mid-width/2-0.028)+Vector3.UP*y,side*d+tangent*(mid+width/2+0.028)+Vector3.UP*y,0.06,TRIM)

static func wall(g: Geometry, side: Vector3, start: float, finish: float, form: int, door_at: float) -> void:
	if finish-start < 0.002:
		return
	var top := eave(form)
	var axis := Vector3(side.z,0,-side.x)
	var left := side*HALF + axis*start
	var right := side*HALF + axis*finish
	g.panel(side,start,finish,HALF,0,top,PLASTER)
	g.panel(side,start,finish,HALF+0.008,0,0.18,STONE)
	g.tile(Vector3.UP*(top+0.67),left+Vector3.UP*top,right+Vector3.UP*top)
	for y in [0.22,1.16,top]:
		g.beam(left+Vector3.UP*y,right+Vector3.UP*y,0.067,WOOD)
	for point in [left,right]:
		g.beam(point+Vector3.UP*0.16,point+Vector3.UP*top,0.073,WOOD)
	if finish-start > 0.55:
		var has_door := door_at >= start+0.13 and door_at <= finish-0.13
		if has_door:
			g.panel(side,door_at-0.245,door_at+0.245,HALF+0.02,0.04,1.02,WOOD)
			g.panel(side,door_at-0.18,door_at+0.18,HALF+0.036,0.06,0.96,Color("#8d7460"))
			g.panel(side,door_at-0.12,door_at+0.12,HALF+0.045,0.60,0.88,Color.WHITE,2)
		for offset in [-0.40,0.40]:
			if offset-0.18 > start and offset+0.18 < finish and (not has_door or absf(offset-door_at)>0.35):
				casement(g,side,offset,0.48,0.33,HALF+0.03)
		if form == 1:
			casement(g,side,start+(finish-start)*0.28,1.28,minf(0.48,(finish-start)*0.35),HALF+0.03)
		var base := (left+right)*0.5
		g.beam(base+Vector3.UP*0.23,base+Vector3.UP*top,0.064,WOOD)
		if form == 1:
			g.beam(left+Vector3.UP*1.19,base+Vector3.UP*(top-0.04),0.045,TRIM)
			g.beam(right+Vector3.UP*1.19,base+Vector3.UP*(top-0.04),0.045,TRIM)

# The village study uses projecting front gables. Keep the little rake boards,
# half-timbered triangle and casement in the player's view as the main roof grows.
static func front_gable(g: Geometry, x: float, y: float, half: float, rise: float, front: float, rear: float, window: bool) -> void:
	var a := Vector3(x-half,y,front)
	var b := Vector3(x+half,y,front)
	var peak := Vector3(x,y+rise,front)
	g.face(a,b,peak,Vector3.BACK,PLASTER)
	if window:
		g.panel(Vector3.BACK,x-half,x+half,front,y-0.19,y,PLASTER)
		g.panel(Vector3.BACK,x-half*0.47,x+half*0.47,front+0.01,y-0.145,y+rise*0.51,WOOD)
		g.panel(Vector3.BACK,x-half*0.34,x+half*0.34,front+0.02,y-0.12,y+rise*0.39,Color.WHITE,2)
		g.panel(Vector3.BACK,x-0.012,x+0.012,front+0.027,y-0.13,y+rise*0.43,TRIM)
		g.panel(Vector3.BACK,x-half*0.42,x+half*0.42,front+0.03,y-0.024,y+0.002,TRIM)
	else:
		g.beam((a+b)*0.5,peak,0.045,WOOD)
		g.beam(a.lerp(peak,0.33),b.lerp(peak,0.33),0.043,WOOD)
		g.beam(a.lerp(b,0.28),a.lerp(peak,0.52),0.034,TRIM)
		g.beam(b.lerp(a,0.28),b.lerp(peak,0.52),0.034,TRIM)
	for p in [a,b]:
		var outer: Vector3 = p+Vector3(signf(p.x-x)*0.047,-0.023,0.044)
		var tip := peak+Vector3(0,0.031,0.044)
		var far: Vector3 = Vector3(outer.x,outer.y,rear)
		var far_peak := Vector3(tip.x,tip.y,rear)
		g.tile(tip,outer,far)
		g.tile(tip,far,far_peak)
		g.beam(outer,tip,0.044,WOOD)
		g.beam(outer,far,0.041,TRIM)
	g.beam(peak,Vector3(x,peak.y,rear),0.047,BRICK)

static func enrich_front(g: Geometry, root: Node3D, door: float, form: int, garden: bool, ports: Array, hall: bool) -> void:
	var open_door := true
	var open_window := true
	var window_x := -signf(door)*0.40
	for port in ports:
		if door >= port.a-0.08 and door <= port.b+0.08:
			open_door = false
		if window_x >= port.a-0.14 and window_x <= port.b+0.14:
			open_window = false
	var top := eave(form)
	if open_door:
		var x := signf(door)*0.36
		if not hall:
			front_gable(g,x,top-0.02,0.31,0.47,0.847,0.16,false)
		front_gable(g,door,0.98,0.253,0.16,0.99,0.76,false)
		for edge in [-1,1]:
			var pier := Vector3(door+edge*0.205,0.04,0.951)
			g.beam(pier,pier+Vector3.UP*0.93,0.047,WOOD)
		g.panel(Vector3.BACK,door+0.104,door+0.134,0.868,0.44,0.50,Color("#c1975a"))
	if open_window:
		if not hall:
			front_gable(g,window_x,top+0.21,0.16,0.18,0.56,0.20,true)
		var base := Vector3(window_x,0.46,HALF+0.08)
		g.beam(base-Vector3.RIGHT*0.19,base+Vector3.RIGHT*0.19,0.103,TRIM)
		g.beam(Vector3(window_x+0.18,0.23,HALF+0.02),Vector3(window_x+0.31,0.47,HALF+0.02),0.038,WOOD)
		for i in range(2):
			var pot := Node3D.new()
			pot.scale = Vector3.ONE * (0.57 if garden else 0.37)
			pot.position = base+Vector3((i-0.5)*0.18,0.02,0.015)
			root.add_child(pot)
			Village.flowers(pot,Vector3.ZERO,i)
		if form == 1:
			var y := 1.91
			g.beam(Vector3(window_x-0.25,1.20,HALF+0.02),Vector3(window_x+0.25,y,HALF+0.02),0.046,WOOD)
			g.beam(Vector3(window_x-0.25,y,HALF+0.02),Vector3(window_x+0.25,1.20,HALF+0.02),0.046,WOOD)

static func lantern(g: Geometry, center: Vector3, radius: float, height: float, roof_height: float, glazed: bool) -> void:
	var tip := center + Vector3.UP*(height+roof_height)
	var ring := []
	for i in range(8):
		var angle := TAU*(i+0.5)/8.0
		ring.append(Vector3(cos(angle),0,sin(angle)))
	for i in range(8):
		var a: Vector3 = center+radius*ring[i]
		var b: Vector3 = center+radius*ring[(i+1)%8]
		var side: Vector3 = (ring[i]+ring[(i+1)%8]).normalized()
		var up := Vector3.UP*height
		g.quad(a,b,b+up,a+up,side,PLASTER)
		g.beam(a,a+up,0.058,WOOD)
		g.beam(a+up,b+up,0.060,WOOD)
		if glazed:
			var left := a.lerp(b,0.16)+side*0.012
			var right := a.lerp(b,0.84)+side*0.012
			g.quad(left+up*0.29,right+up*0.29,right+up*0.82,left+up*0.82,side,Color.WHITE,2)
		var rim_a: Vector3 = center+ring[i]*(radius+0.10)+up
		var rim_b: Vector3 = center+ring[(i+1)%8]*(radius+0.10)+up
		g.tile(rim_a,rim_b,tip)
	g.beam(tip,tip+Vector3.UP*0.14,0.035,TRIM)

static func great_hall(g: Geometry, ports: Dictionary) -> void:
	# Orient the cross-gable across a row so it interrupts the long ridge.
	# It is set back from the plot edges; the existing eaves still meet their
	# neighbours at the original height on all four sides.
	var east_west: int = ports.get(Vector3.RIGHT,[]).size()+ports.get(Vector3.LEFT,[]).size()
	var north_south: int = ports.get(Vector3.BACK,[]).size()+ports.get(Vector3.FORWARD,[]).size()
	var front := Vector3.BACK if east_west>=north_south else Vector3.RIGHT
	var crosswise := Vector3(front.z,0,-front.x)
	var sill := 1.22
	var eaves := 2.06
	var ridge := 2.92
	for point in [front,-front]:
		var side: Vector3 = point
		var at := side*0.87
		var a := at-crosswise*0.65+Vector3.UP*eaves
		var b := at+crosswise*0.65+Vector3.UP*eaves
		var peak := at+Vector3.UP*ridge
		g.quad(a,b,b-Vector3.UP*(eaves-sill),a-Vector3.UP*(eaves-sill),side,PLASTER)
		g.face(a,b,peak,side,PLASTER)
		for y in [sill,eaves]:
			g.beam(at-crosswise*0.65+Vector3.UP*y,at+crosswise*0.65+Vector3.UP*y,0.07,WOOD)
		g.beam(a,peak,0.07,WOOD)
		g.beam(b,peak,0.07,WOOD)
		g.beam(at+Vector3.UP*(eaves+0.05),peak,0.047,TRIM)
		# A three-light oriel and outward-slanting timber struts mark the shared
		# room. Its upper windows light up with the rest of the inhabited island.
		for x in [-0.25,0.0,0.25]:
			var h := 0.11 if x==0.0 else 0.0
			var left: Vector3 = at+side*0.036+crosswise*(x-0.104)+Vector3.UP*1.45
			var right := left+crosswise*0.208
			g.quad(left,right,right+Vector3.UP*(0.44+h),left+Vector3.UP*(0.44+h),side,Color.WHITE,2)
			g.beam(left,right,0.041,TRIM)
			g.beam(left,left+Vector3.UP*(0.44+h),0.033,TRIM)
			g.beam(right,right+Vector3.UP*(0.44+h),0.033,TRIM)
			g.beam(left+Vector3.UP*0.29,right+Vector3.UP*0.29,0.027,TRIM)
		for sign_value in [-1,1]:
			var rim: Vector3 = at+crosswise*(0.60*sign_value)
			g.beam(rim+Vector3.UP*sill,rim+Vector3.UP*eaves,0.07,WOOD)
			g.beam(rim+Vector3.UP*1.33,at+crosswise*(0.39*sign_value)+Vector3.UP*1.93,0.048,WOOD)
	for sign_value in [-1,1]:
		var normal := crosswise*float(sign_value)
		var side_wall := normal*0.65
		var front_wall := side_wall+front*0.87
		var rear_wall := side_wall-front*0.87
		g.quad(front_wall+Vector3.UP*sill,rear_wall+Vector3.UP*sill,
			rear_wall+Vector3.UP*eaves,front_wall+Vector3.UP*eaves,normal,PLASTER)
		g.beam(front_wall+Vector3.UP*eaves,rear_wall+Vector3.UP*eaves,0.085,WOOD)
		for depth in [-0.65,0.0,0.65]:
			g.beam(side_wall+front*depth+Vector3.UP*sill,side_wall+front*depth+Vector3.UP*eaves,0.065,WOOD)
		var lip := normal*0.73+Vector3.UP*(eaves-0.047)
		var left := lip+front*0.93
		var right := lip-front*0.93
		var high_front := front*0.93+Vector3.UP*(ridge+0.035)
		var high_back := -front*0.93+Vector3.UP*(ridge+0.035)
		g.tile(left,right,high_back)
		g.tile(left,high_back,high_front)
		g.beam(left,high_front,0.047,TRIM)
		g.beam(right,high_back,0.047,TRIM)
	g.beam(front*0.93+Vector3.UP*(ridge+0.035),-front*0.93+Vector3.UP*(ridge+0.035),0.060,BRICK)

# A central lantern crowns the glass roof; the front sash faces the route.
static func glass_pavilion(g: Geometry, kit: ArtKit, root: Node3D, tint: Color) -> void:
	var glazing := SurfaceTool.new()
	glazing.begin(Mesh.PRIMITIVE_TRIANGLES)
	var shoulder := Vector3.UP * 1.65
	var crown := Vector3.UP * 2.26
	for i in range(8):
		var angle := (i+0.5)*TAU/8
		var next := (i+1.5)*TAU/8
		var a := Vector3(cos(angle),0,sin(angle))*0.91
		var b := Vector3(cos(next),0,sin(next))*0.91
		var outside := (a+b).normalized()
		g.quad(a,b,b+Vector3.UP*0.22,a+Vector3.UP*0.22,outside,STONE)
		g.beam(a,a+shoulder,0.066,TRIM)
		g.beam(a+shoulder,b+shoulder,0.064,tint)
		g.beam(a+Vector3.UP*0.23,b+Vector3.UP*0.23,0.06,tint)
		var inner_a := crown+a*0.30
		var inner_b := crown+b*0.30
		g.beam(a+shoulder,inner_a,0.05,TRIM)
		kit.glass_quad(glazing,a+shoulder,b+shoulder,inner_b,inner_a)
		kit.glass_quad(glazing,a+Vector3.UP*0.23,b+Vector3.UP*0.23,b+shoulder,a+shoulder)
		if outside.z > 0.95:
			g.beam(a+Vector3.UP*1.32,b+Vector3.UP*1.32,0.048,WOOD)
			g.beam((a+b)*0.5+Vector3.UP*0.23,(a+b)*0.5+Vector3.UP*1.32,0.053,WOOD)
			g.beam((a+b)*0.5+Vector3.UP*0.73+outside*0.033,a.lerp(b,0.73)+Vector3.UP*0.73+outside*0.033,0.028,WOOD)
		else:
			g.beam(a+Vector3.UP*0.79,b+Vector3.UP*0.79,0.050,tint)
	var green_glass := StandardMaterial3D.new()
	green_glass.albedo_color=Color(0.65,0.83,0.77,0.38)
	green_glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	green_glass.roughness=0.35
	green_glass.cull_mode=BaseMaterial3D.CULL_DISABLED
	var pane := MeshInstance3D.new()
	pane.mesh=glazing.commit()
	pane.material_override=green_glass
	pane.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(pane)
	for x in [-0.43,0.43]:
		kit.box(root,Vector3(x,0.49,0),Vector3(0.37,0.08,0.93),TRIM)
		for z in [-0.30,0.30]:
			kit.pot(root,Vector3(x,0.53,z))
	lantern(g,crown,0.30,0.34,0.38,true)

static func make(kit: ArtKit, o: Dictionary, variant: String, seams: Array, windows: Material, is_hall: bool = false) -> Node3D:
	var form := int(o.get("form",0))
	var color_index := int(o.get("color",0))
	var hall: bool = o.kind in ["house","tea"]
	var tint: Color = Village.COAST_ROOF if variant=="coast" and color_index==0 else Village.ROOF_TINTS[color_index%3]
	var g := Geometry.new(tint)
	var root := Node3D.new()
	var ports := local_ports(o,seams)
	if hall:
		var entry := RouteGraph.entrance(o)
		var axis := Basis(Vector3.UP,int(o.rotation)*PI/2)
		var door := axis * Vector3(entry.x-o.x-0.5,0,entry.y-o.z-0.5)
		for side: Vector3 in DIRECTIONS:
			var door_at: float = clampf(door.x,-0.50,0.50) if side==Vector3.BACK else INF
			var start := -HALF
			for port in ports.get(side,[]):
				var inset := 1.0 if port.full else HALF
				wall(g,side,start,float(port.a)*inset,form,door_at)
				join_wing(g,side,port,form,HALF,true)
				start = float(port.b)*inset
			wall(g,side,start,HALF,form,door_at)
		enrich_front(g,root,clampf(door.x,-0.50,0.50),form,variant=="garden",ports.get(Vector3.BACK,[]),is_hall)
		if is_hall:
			great_hall(g,ports)
		elif form==2:
			lantern(g,Vector3(0.06,1.69,-0.06),0.47,0.93,0.70,true)
		var mouth := Vector3(-0.38,2.85 if is_hall else eave(form)+0.95,-0.35)
		g.beam(mouth-Vector3.UP*0.88,mouth,0.16,BRICK)
		g.beam(mouth-Vector3.UP*0.068,mouth+Vector3.UP*0.025,0.22,BRICK.darkened(0.19))
		root.set_meta("smoke_mouth",mouth)
		if not ports.has(Vector3.BACK):
			if o.kind=="tea":
				Village.canvas(kit,root,0.05,1.10,0.76,Color("#c2a374"))
				kit.table(root,Vector3(0.17,0,0.77))
			elif variant=="garden" or variant=="coast":
				Village.canvas(kit,root,-door.x*0.7,1.06,0.85,Color("#c88e93") if variant=="garden" else Color("#9fb7af"))
	else:
		var shell: Node3D = kit.building(o.kind,variant,color_index) if color_index != 0 else load("res://game/art/models/%s.glb" % o.kind).instantiate()
		root.add_child(shell)
		for side: Vector3 in DIRECTIONS:
			for port in ports.get(side,[]):
				join_wing(g,side,port,form,0.38,false)
		if o.kind=="greenhouse":
			if form==1:
				lantern(g,Vector3(0,1.78,-0.04),0.52,0.94,0.47,true)
			elif form==2:
				shell.free()
				glass_pavilion(g,kit,root,tint)
		elif form==1:
			lantern(g,Vector3(0,2.38,0),0.80,0.57,0.64,true)
		elif form==2:
			lantern(g,Vector3(0.50,0.12,0.43),0.42,1.68,0.60,true)
			lantern(g,Vector3(-0.52,0.12,-0.48),0.38,2.18,0.62,true)
	if tiles_material==null:
		tiles_material = ShaderMaterial.new()
		tiles_material.shader = PAN_TILES
		tiles_material.set_meta("static_batch_safe",true)
	g.finish(root,tiles_material,windows)
	return root
