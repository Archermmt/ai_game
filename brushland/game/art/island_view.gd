class_name IslandView
extends Node3D
var kit=ArtKit.new()
const MODELS={
	"house_basic":preload("res://game/art/models/house_basic.glb"),"house_coast":preload("res://game/art/models/house_coast.glb"),"house_garden":preload("res://game/art/models/house_garden.glb"),
	"tea":preload("res://game/art/models/tea.glb"),"greenhouse":preload("res://game/art/models/greenhouse.glb"),"lighthouse":preload("res://game/art/models/lighthouse.glb"),
	"bench":preload("res://game/art/models/bench.glb"),"pot":preload("res://game/art/models/pot.glb"),"tree":preload("res://game/art/models/tree.glb")}
const RESIDENTS=[preload("res://game/art/models/resident_0.glb"),preload("res://game/art/models/resident_1.glb"),preload("res://game/art/models/resident_2.glb"),preload("res://game/art/models/resident_3.glb")]
var ground=Node3D.new()
var props=Node3D.new()
var inhabitants=Node3D.new()
var actor_nodes:Dictionary={}
var sea:MeshInstance3D
var foam:Node3D
var day:bool=true
var batch_stats:Dictionary={}
var data:IslandData
func setup(d:IslandData) -> void:
	data=d;add_child(ground);add_child(props);add_child(inhabitants)
	ground.name="Ground";props.name="Buildings";inhabitants.name="Inhabitants"
	var plane=PlaneMesh.new();plane.size=Vector2(180,180)
	sea=MeshInstance3D.new();sea.mesh=plane;sea.position=Vector3(32,-0.04,32)
	var shader=Shader.new();shader.code="""shader_type spatial;
render_mode unshaded;
uniform vec4 shallow : source_color = vec4(0.47,0.71,0.70,1.0);
uniform float motion = 1.0;
varying vec3 world_pos;
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){float wave=sin(world_pos.x*1.8+world_pos.z*0.7+TIME*0.7*motion)*sin(world_pos.z*2.7-TIME*0.35*motion);float streak=smoothstep(0.93,1.0,wave)*0.11;float fade=clamp(length(world_pos.xz-vec2(32.0))/65.0,0.0,1.0);ALBEDO=shallow.rgb+vec3(streak)-vec3(fade*0.035);}
"""
	kit.material(Color("c5dfcf")).shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	var mat=ShaderMaterial.new();mat.shader=shader;sea.material_override=mat;add_child(sea)
func rebuild() -> void:
	for n in ground.get_children():n.free()
	for n in props.get_children():n.free()
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for key in data.tiles:
		var parts=key.split(",");var p=Vector2i(int(parts[0]),int(parts[1]));var c=data.cell(p)
		if c.h==0:continue
		var y=float(c.h)*0.5
		var color=Color("a4b98a") if c.surface=="grass" else Color("e4d3af") if c.surface=="sand" else Color("b8baa9")
		color=color.lightened(float(posmod(p.x*17+p.y*11,7))*0.004)
		var ring:Array=[]
		# Clip only exposed corners. Interior cells join without a bevel grid.
		for corner in [Vector2i(-1,-1),Vector2i(-1,1),Vector2i(1,1),Vector2i(1,-1)]:
			var cut=data.cell(p+Vector2i(corner.x,0)).h==0 and data.cell(p+Vector2i(0,corner.y)).h==0
			var v=Vector3(p.x+corner.x*0.5,y,p.y+corner.y*0.5)
			if cut:
				if corner.x==corner.y:ring.append(v-Vector3(corner.x*0.18,0,0));ring.append(v-Vector3(0,0,corner.y*0.18))
				else:ring.append(v-Vector3(0,0,corner.y*0.18));ring.append(v-Vector3(corner.x*0.18,0,0))
			else:ring.append(v)
		for i in range(ring.size()):
			tri(st,Vector3(p.x,y,p.y),ring[i],ring[(i+1)%ring.size()],color)
			var a:Vector3=ring[i];var b:Vector3=ring[(i+1)%ring.size()]
			tri(st,a,Vector3(a.x,-0.13,a.z),b,color.darkened(0.09))
			tri(st,b,Vector3(a.x,-0.13,a.z),Vector3(b.x,-0.13,b.z),color.darkened(0.09))
		if c.road:draw_road(p,y)
		if c.flower:
			for i in range(4):kit.flower(props,Vector3(p.x+sin(i*2.4)*0.25,y,p.y+cos(i*2.4)*0.25),p.x+i)
		if not c.road and not c.flower and not BuildingRules.occupied(data,p):
			var noise=posmod(p.x*31+p.y*19,83)
			if noise==0 and c.surface=="grass":kit.tree(props,Vector3(p.x,y,p.y),p.x+p.y)
			elif noise<4:
				kit.sphere(props,Vector3(p.x,y+0.13,p.y),Vector3(0.5,0.4,0.45),Color("8b9f7c") if c.surface=="grass" else Color("b9b8a8"))
		if c.h==1:
			for dir in BuildingRules.DIRS:
				if data.cell(p+dir).h==0:
					var n=kit.sphere(props,Vector3(p.x+dir.x*0.58,0.015,p.y+dir.y*0.58),Vector3(0.7,0.025,0.7),Color("c5dfcf"))
					n.scale.x=0.6 if dir.x!=0 else 1.4;n.scale.z=1.4 if dir.x!=0 else 0.6
	var geo=st.commit();var mesh=MeshInstance3D.new();mesh.mesh=geo
	var mat=StandardMaterial3D.new();mat.vertex_color_use_as_albedo=true;mat.vertex_color_is_srgb=true;mat.roughness=1;mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	mesh.material_override=mat;ground.add_child(mesh)
	for o in data.objects:draw_object(o)
	compact_props()
func tri(st:SurfaceTool,a:Vector3,b:Vector3,c:Vector3,color:Color) -> void:
	st.set_normal((b-a).cross(c-a).normalized());st.set_color(color);st.add_vertex(a);st.add_vertex(b);st.add_vertex(c)
func draw_road(p:Vector2i,y:float) -> void:
	kit.cylinder(props,Vector3(p.x,y+0.015,p.y),0.36,0.035,Color("d9c7a5"))
	for dir in BuildingRules.DIRS:
		var next=data.cell(p+dir)
		if next.road and absi(int(next.h)-int(data.cell(p).h))<=1:
			var a=Vector3(p.x,y+0.025,p.y);var b=Vector3(p.x+dir.x,float(next.h)*0.5+0.025,p.y+dir.y)
			var piece=kit.box(props,(a+b)/2,Vector3(0.57,0.04,a.distance_to(b)),Color("d9c7a5"))
			piece.look_at_from_position((a+b)/2,b,Vector3.UP)
func draw_object(o:Dictionary) -> void:
	var p=Vector2i(o.x,o.z);var y=float(data.cell(p).h)*0.5
	if o.kind in ["bridge","dock"]:
		var dir:Vector2i=BuildingRules.DIRS[int(o.rotation)%4];var side=Vector2i(-dir.y,dir.x)
		var count=int(o.length)+2 if o.kind=="bridge" else int(o.length)+1
		for i in range(count):
			var pos=Vector3(p.x+dir.x*i,y+0.06,p.y+dir.y*i)
			for plank in range(4):
				var v=pos+Vector3(dir.x*(plank-1.5)*0.23,0,dir.y*(plank-1.5)*0.23)
				kit.box(props,v,Vector3(0.21 if dir.x!=0 else 0.9,0.1,0.21 if dir.y!=0 else 0.9),ArtKit.WOOD.lightened((plank%2)*0.04))
			for sign_value in [-1,1]:
				var v=pos+Vector3(side.x*0.47*sign_value,0,side.y*0.47*sign_value)
				kit.cylinder(props,v+Vector3(0,-0.1,0),0.06,1.25,ArtKit.WOOD.darkened(0.12))
				if o.kind=="bridge" and i<count-1:
					kit.beam(props,v+Vector3(0,0.45,0),v+Vector3(dir.x,0.45,dir.y),0.055,ArtKit.WOOD)
		if o.kind=="dock":draw_boat(o,y)
		return
	var kind=String(o.kind)
	var model_id="house_"+BuildingRules.variant(data,o) if kind=="house" else kind
	var node=MODELS[model_id].instantiate() if int(o.get("color",0))==0 else kit.building(kind,BuildingRules.variant(data,o) if kind=="house" else "basic",int(o.get("color",0)))
	node.position=Vector3(p.x+0.5 if kind in ["house","tea","greenhouse","lighthouse"] else p.x,y,p.y+0.5 if kind in ["house","tea","greenhouse","lighthouse"] else p.y)
	node.rotation.y=-float(o.rotation)*PI/2;props.add_child(node)
	if kind=="lighthouse":
		var lamp=OmniLight3D.new();lamp.position=Vector3(0,4,0);lamp.light_color=Color("ffd08a");lamp.light_energy=0.6;lamp.omni_range=6;lamp.visible=not day;node.add_child(lamp);lamp.add_to_group("island_lanterns")
func draw_boat(o:Dictionary,_y:float) -> void:
	var dir:Vector2i=BuildingRules.DIRS[int(o.rotation)%4];var side=Vector2i(-dir.y,dir.x)
	var node=Node3D.new();props.add_child(node);node.name="Boat"
	node.position=Vector3(o.x+dir.x*2+side.x,0.1,o.z+dir.y*2+side.y)
	node.rotation.y=PI/2 if dir.x!=0 else 0
	kit.sphere(node,Vector3.ZERO,Vector3(0.87,0.42,2.8),ArtKit.BLUE)
	kit.sphere(node,Vector3(0,0.12,0),Vector3(0.7,0.2,2.55),ArtKit.CREAM)
	for z in [-0.65,0,0.65]:kit.box(node,Vector3(0,0.25,z),Vector3(0.65,0.06,0.18),ArtKit.WOOD)
	kit.beam(node,Vector3(-0.5,0.25,-0.1),Vector3(0.55,0.25,-0.1),0.04,ArtKit.WOOD)
func update_actors(sim:ResidentSim,time:float) -> void:
	var active:Dictionary={}
	for person in sim.people:
		var id=int(person.id);active[id]=true
		if not actor_nodes.has(id):
			var n=RESIDENTS[(id-1)%4].instantiate();inhabitants.add_child(n);actor_nodes[id]=n
		var n:Node3D=actor_nodes[id];n.visible=person.state!="resting"
		var p=Vector2i(roundi(person.x),roundi(person.z));var y=float(data.cell(p).h)*0.5
		for o in data.objects:
			if o.kind=="bridge" and p in BuildingRules.footprint(o):y=float(data.cell(Vector2i(o.x,o.z)).h)*0.5+0.08
		var moving=not person.route.is_empty()
		n.position=Vector3(person.x,y+(absf(sin(time*8+id))*0.045 if moving else 0),person.z)
		if moving:
			var target:Vector2i=person.route[0];var facing=Vector3(target.x,0,target.y)-Vector3(person.x,0,person.z)
			if facing.length()>0.02:n.rotation.y=atan2(facing.x,facing.z)
		if person.state=="tea":
			var target=sim.object_by_id(data,int(person.target))
			if not target.is_empty():
				var seat=0
				for other in sim.people:
					if other.target==person.target and int(other.id)<id:seat+=1
				var offset=Basis(Vector3.UP,-float(target.rotation)*PI/2)*Vector3(-0.65 if seat%2==0 else 0.65,0,0)
				n.position=Vector3(target.x+0.5,y+0.16,target.z+0.5)+offset
				n.rotation.y=PI/2 if seat%2==0 else -PI/2
				n.rotation.z=sin(time*0.7+id)*0.025
	for id in actor_nodes.keys():
		if not active.has(id):actor_nodes[id].free();actor_nodes.erase(id)
func compact_props() -> void:
	# Keep custom/transparent/animated surfaces intact; batch only proven static inputs.
	batch_stats=StaticBatcher.compact(props,8.0)
	if batch_stats.has("error"):push_error(String(batch_stats.error))
