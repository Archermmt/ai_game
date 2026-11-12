extends Node3D
## Deterministic orchard, verge grass and vegetable patch for the street diorama.

const PLANT_SHADER = preload("res://street/vegetation/foliage.gdshader")
const PETAL_EDGE = preload("res://street/vegetation/petal_edge.gdshader")

# x and z are ground coordinates. The third axis of each lobe is depth.
# Higher rear lobes and wider foreground lobes give the crowns their domed outline.
const CROWN: Array[Vector4] = [
	Vector4(-1.57, 3.70, -0.52, 0.81), Vector4(-0.91, 4.50, -0.85, 0.77),
	Vector4(-0.16, 4.88, -0.83, 0.78), Vector4(0.65, 4.52, -0.97, 0.92),
	Vector4(1.52, 4.11, -0.62, 0.85), Vector4(1.98, 3.57, -0.22, 0.53),
	Vector4(-1.72, 3.43, 0.19, 0.69), Vector4(-1.21, 4.11, 0.04, 0.69),
	Vector4(-0.66, 4.22, 0.37, 0.84), Vector4(0.22, 4.42, 0.12, 0.67),
	Vector4(1.04, 4.04, 0.10, 0.85), Vector4(1.55, 3.34, 0.40, 0.82),
	Vector4(-1.17, 3.26, 0.91, 0.67), Vector4(-0.47, 3.62, 1.03, 0.74),
	Vector4(0.43, 3.71, 0.88, 0.90), Vector4(1.12, 3.03, 1.08, 0.88),
	Vector4(-0.82, 2.81, 0.55, 0.65), Vector4(0.02, 2.71, 0.78, 0.90),
	Vector4(0.80, 2.72, 0.35, 0.74)
]
# Visible flower centers were traced in the reference camera and back-projected
# onto staggered depth planes. The rear/interior lobes close the canopy on orbit.
const HERO_CROWN = [
	[-2.268,4.202,-0.530,0.531,1.18,"#edabd2"], [-1.710,5.077,-0.540,0.560,1.06,"#ffdef4"],
	[-1.217,4.312,-0.680,0.496,1.04,"#fbdaef"], [-0.666,4.831,-0.730,0.492,1.02,"#f7b9d9"],
	[-0.208,4.541,-0.850,0.565,0.96,"#ffdef1"], [0.415,5.076,-0.720,0.559,1.00,"#f7b7d6"],
	[0.968,5.380,-0.580,0.451,1.10,"#eea0c8"], [1.367,5.306,-0.280,0.484,1.06,"#ffacd2"],
	[1.791,4.335,-0.550,0.386,1.06,"#f7c7df"], [1.498,4.323,-0.050,0.593,1.15,"#ffe0f2"],
	[-1.594,4.041,0.180,0.456,1.13,"#eaa7ca"], [-1.117,4.810,0.160,0.416,1.02,"#ffdaee"],
	[-0.496,4.723,0.520,0.586,1.09,"#eeb5d4"], [-0.166,3.283,0.180,0.883,1.05,"#e5b5d5"],
	[0.509,4.204,0.240,0.662,1.25,"#ffebf8"], [1.337,3.954,0.550,0.799,1.14,"#f3b6d5"],
	[-1.471,4.193,0.760,0.416,1.22,"#f7c3e0"], [-0.721,3.081,0.700,0.774,1.32,"#f1b9d6"],
	[0.735,3.435,1.180,0.797,1.07,"#fff1fa"], [0.232,3.213,0.270,0.670,1.10,"#ffe1f6"]
]
const PETAL_COLORS = ["#efa9d0", "#ffe2f4", "#e897c4", "#f9d3f0", "#efbad8", "#ffecff", "#e78dbc"]
const BUSH_COLORS = ["#7ab04b", "#75ad45", "#8bb94c", "#7bb43f", "#80ba49"]
const GRASS_COLORS = ["#a7e654", "#a8ed4e", "#d5fa83", "#c3f46b", "#e1ff99", "#a0dc50"]
const BARK_COLORS = ["#875340", "#81513d", "#945c44"]
const ROAD_LEFT = 4.125
const ROAD_RIGHT = 8.375
const SEED_VALUE = 77251

class PlantBatch:
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()

	func vertex(position: Vector3, normal: Vector3, color: Color) -> void:
		points.append(position)
		normals.append(normal)
		colors.append(color)

	func triangle(a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3, ca: Color, cb: Color, cc: Color) -> void:
		vertex(a, na, ca)
		if (b - a).cross(c - a).dot(na + nb + nc) > 0.0:
			vertex(c, nc, cc)
			vertex(b, nb, cb)
		else:
			vertex(b, nb, cb)
			vertex(c, nc, cc)

	func mesh() -> ArrayMesh:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = points
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		var result := ArrayMesh.new()
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return result

var rng := RandomNumberGenerator.new()
var petals := PlantBatch.new()
var stems := PlantBatch.new()
var shrubs := PlantBatch.new()
var meadow := PlantBatch.new()
var vegetables := PlantBatch.new()
var vegetable_soil := PlantBatch.new()
var ground_profile: Script
var ico_faces := PackedVector3Array()


func _ready() -> void:
	rng.seed = SEED_VALUE
	ground_profile = load("res://street/layout/ground_profile.gd")
	ico_faces = subdivided_icosahedron()
	make_trees()
	make_bushes()
	make_garden()
	make_meadow()
	var blossom := mesh_instance("BlossomCrowns", petals, plant_material(Vector3(0.73, 0.67, 0.76), 0.78, 0.49))
	var stems_material := plant_material(Vector3(0.65, 0.69, 0.77), 0.30, 0.02)
	mesh_instance("Branches", stems, stems_material)
	mesh_instance("RoundShrubs", shrubs, plant_material(Vector3(0.75, 0.77, 0.66), 0.30, 0.03))
	mesh_instance("GrassBlades", meadow, plant_material(Vector3(0.86, 0.87, 0.78), 0.75, 0.03), false)
	mesh_instance("GardenPlants", vegetables, plant_material(Vector3(0.73, 0.81, 0.70), 0.60, 0.06))
	mesh_instance("TilledSoil", vegetable_soil, plant_material(Vector3(0.80, 0.76, 0.74), 0.80, 0.0))
	var edge := MeshInstance3D.new()
	edge.name = "FinePetalEdges"
	edge.mesh = blossom.mesh
	var edge_material := ShaderMaterial.new()
	edge_material.shader = PETAL_EDGE
	edge.material_override = edge_material
	edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(edge)


func plant_material(tint: Vector3, softness: float, shine: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = PLANT_SHADER
	material.set_shader_parameter("shadow_tint", tint)
	material.set_shader_parameter("soft_facets", softness)
	material.set_shader_parameter("highlight", shine)
	return material


func mesh_instance(label: String, batch: PlantBatch, material: Material, casts: bool = true) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = batch.mesh()
	instance.material_override = material
	if not casts:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance


func surface_y(x: float, z: float) -> float:
	if ground_profile != null:
		return float(ground_profile.call("height_at", x, z))
	return 0.0


func subdivided_icosahedron() -> PackedVector3Array:
	var phi := (1.0 + sqrt(5.0)) * 0.5
	var verts := [Vector3(-1,phi,0),Vector3(1,phi,0),Vector3(-1,-phi,0),Vector3(1,-phi,0),Vector3(0,-1,phi),Vector3(0,1,phi),Vector3(0,-1,-phi),Vector3(0,1,-phi),Vector3(phi,0,-1),Vector3(phi,0,1),Vector3(-phi,0,-1),Vector3(-phi,0,1)]
	var triples := [0,11,5, 0,5,1, 0,1,7, 0,7,10, 0,10,11, 1,5,9, 5,11,4, 11,10,2, 10,7,6, 7,1,8, 3,9,4, 3,4,2, 3,2,6, 3,6,8, 3,8,9, 4,9,5, 2,4,11, 6,2,10, 8,6,7, 9,8,1]
	var result := PackedVector3Array()
	for i in range(0, triples.size(), 3):
		var a: Vector3 = verts[triples[i]].normalized()
		var b: Vector3 = verts[triples[i+1]].normalized()
		var c: Vector3 = verts[triples[i+2]].normalized()
		var ab := (a+b).normalized()
		var bc := (b+c).normalized()
		var ac := (a+c).normalized()
		result.append_array(PackedVector3Array([a,ab,ac, b,bc,ab, c,ac,bc, ab,bc,ac]))
	return result


func lobe(batch: PlantBatch, center: Vector3, radii: Vector3, color: Color, softness: float, distortion: float) -> void:
	var phi := rng.randf_range(0.0, TAU)
	var rotation := Basis(Vector3.UP, phi) * Basis(Vector3.RIGHT, phi * 0.3)
	for i in range(0, ico_faces.size(), 3):
		var xyz := PackedVector3Array()
		var normal := PackedVector3Array()
		for j in range(3):
			var v := rotation * ico_faces[i+j]
			var wave := sin(v.dot(Vector3(4.1, 2.7, 5.6)) + phi) * cos(v.dot(Vector3(-3.5, 3.2, 2.8)))
			xyz.append(center + v * radii * (1.0 + wave * distortion))
			normal.append((v / radii).normalized())
		var face := (xyz[1]-xyz[0]).cross(xyz[2]-xyz[0]).normalized()
		if face.dot(normal[0]+normal[1]+normal[2]) < 0.0:
			face = -face
		for j in range(3):
			normal[j] = face.lerp(normal[j], softness).normalized()
		batch.triangle(xyz[0], xyz[1], xyz[2], normal[0], normal[1], normal[2], color, color, color)


func taper(batch: PlantBatch, a: Vector3, b: Vector3, r0: float, r1: float, sides: int, color: Color) -> void:
	var axis := (b-a).normalized()
	var basis_x := axis.cross(Vector3.FORWARD).normalized()
	if basis_x.length_squared() < 0.25:
		basis_x = axis.cross(Vector3.RIGHT).normalized()
	var basis_z := axis.cross(basis_x)
	for i in range(sides):
		var angle0 := TAU * i / sides
		var angle1 := TAU * (i+1) / sides
		var v0 := cos(angle0) * basis_x + sin(angle0) * basis_z
		var v1 := cos(angle1) * basis_x + sin(angle1) * basis_z
		var n := (v0+v1).normalized()
		batch.triangle(a+v0*r0, b+v0*r1, b+v1*r1, n,n,n,color,color,color)
		batch.triangle(a+v0*r0, b+v1*r1, a+v1*r0, n,n,n,color,color,color)
		batch.triangle(b, b+v1*r1, b+v0*r1, axis,axis,axis,color,color,color)


func make_trees() -> void:
	# All locations correspond to the visible foot of each trunk at the target camera.
	cherry(-9.46, 6.65, 0.70, -0.12, "front_left")
	cherry(-4.45, 4.30, 0.80, 0.26, "middle_left")
	cherry(-0.37, 7.43, 0.52, 0.04, "front_small")
	cherry(2.36, 4.38, 1.02, -0.07, "main")
	cherry(-6.45, -6.32, 0.56, 0.85, "back")
	cherry(3.72, -5.51, 0.88, 0.25, "back")
	cherry(9.00, -5.22, 0.59, 0.85, "back")


func cherry(x: float, z: float, size: float, rotation_y: float, profile: String) -> void:
	var root := Vector3(x, surface_y(x,z), z)
	var pose := Transform3D(Basis(Vector3.UP, rotation_y).scaled(Vector3.ONE*size), root)
	var bend0 := pose * Vector3(0.10, 0.83, 0.01)
	var bend1 := pose * Vector3(-0.10, 1.86, 0.00)
	var bark := Color(BARK_COLORS[rng.randi_range(0,BARK_COLORS.size()-1)])
	var trunk_scale := 0.73 if profile == "front_left" or profile == "front_small" else 1.0
	taper(stems,root,bend0,0.46*size*trunk_scale,0.30*size*trunk_scale,7,bark)
	taper(stems,bend0,bend1,0.30*size*trunk_scale,0.28*size*trunk_scale,7,bark)
	for end in [Vector3(-1.40,3.76,-0.30), Vector3(1.02,3.47,0.30), Vector3(0.17,4.67,-0.80), Vector3(-0.16,3.63,0.90)]:
		taper(stems,bend1,pose*end,0.22*size,0.07*size,6,bark)
	if profile == "main":
		for flower in HERO_CROWN:
			var center := root + Vector3(flower[0],flower[1],flower[2])
			var r: float = flower[3]
			var radii := Vector3(r, r*float(flower[4]), r*rng.randf_range(0.88,1.10))
			lobe(petals,center,radii,Color(flower[5]),0.64,0.10)
		lobe(petals,root+Vector3(-0.32,3.91,-0.88),Vector3(1.00,0.94,0.89),Color("#e6afd3"),0.48,0.10)
		lobe(petals,root+Vector3(0.73,3.83,-0.75),Vector3(0.89,0.77,0.91),Color("#edaecf"),0.54,0.12)
		return
	for index in range(CROWN.size()):
		var v := CROWN[index]
		var local := Vector3(v.x, v.y, v.z)
		var radius_factor := 0.90
		match profile:
			"front_left":
				local.x += 0.27
				local.y = 3.80 + (local.y-3.80)*0.78 - local.x*0.42
				local.z *= 0.86
				radius_factor = 0.86
			"middle_left":
				local.y = 3.68 + (local.y-3.68)*0.85 - 0.10
				local.z *= 0.83
				radius_factor = 0.89
			"front_small":
				local.x -= 0.29
				local.x += (local.y-3.6)*0.37
				local.y += 0.32 + local.x*0.32
				local.z *= 0.82
				radius_factor = 0.86
			"back":
				local.y = 3.50 + (local.y-3.8)*0.77
				local.z *= 0.84
		local += Vector3(rng.randf_range(-0.16,0.16),rng.randf_range(-0.16,0.16),rng.randf_range(-0.13,0.13))
		var tint := Color(PETAL_COLORS[rng.randi_range(0,PETAL_COLORS.size()-1)])
		if index == 15 or index == 10 or index == 5:
			tint = Color("#ffe5f5")
		elif index == 17 or index == 4:
			tint = Color("#f4bbd6")
		var radius := radius_factor * v.w * size * rng.randf_range(0.88,1.13)
		var radii := Vector3(radius*rng.randf_range(0.90,1.09),radius*rng.randf_range(0.92,1.13),radius*rng.randf_range(0.88,1.08))
		lobe(petals, pose*local, radii, tint, 0.56, 0.115)


	# The small tree has a blossom sprig sticking up on its right-hand side.
	if profile == "front_small":
		var sprig := Vector3(0.84,6.02,-0.32)
		taper(stems,pose*Vector3(0.25,4.12,0.0),pose*sprig,0.10*size,0.045*size,5,bark)
		lobe(petals,pose*sprig,Vector3(0.30,0.41,0.32),Color("#f3b4d4"),0.60,0.12)


func bush(x: float, z: float, size: float, y_offset: float = 0.0) -> void:
	var tint := Color(BUSH_COLORS[rng.randi_range(0,BUSH_COLORS.size()-1)])
	if x < -5.0 and z > 6.8:
		tint = Color("#609844").lerp(tint,0.16)
	var radii := Vector3(size, size*rng.randf_range(0.83,1.08), size*0.91)
	lobe(shrubs,Vector3(x,surface_y(x,z)+size*0.18+y_offset,z),radii,tint,0.18,0.13)


func make_bushes() -> void:
	# Clipped hedge along the front-left house and the three road-edge hummocks.
	for i in range(6):
		bush(-8.75+i*0.54,7.25+0.08*sin(i),0.49+rng.randf()*0.09)
	bush(5.91,5.72,0.41)
	bush(6.35,5.32,0.45)
	bush(7.16,7.02,0.45)
	bush(-0.65,2.48,0.35)
	bush(-0.21,2.30,0.41)
	for side in [-1,1]:
		for i in range(6):
			var z := -7.55 + i*1.29 + rng.randf_range(-0.27,0.24)
			var outer: float = lerpf(10.50,11.42,smoothstep(0.5,7.5,absf(z)))
			var x: float = side * rng.randf_range(outer-0.34,outer)
			bush(x,z,rng.randf_range(0.25,0.48))


func blade(batch: PlantBatch, root: Vector3, direction: float, height: float, width: float, sway: float, tint: Color) -> void:
	var across := Vector3(cos(direction),0,sin(direction))*width
	var tilted := Vector3(-sin(direction),0,cos(direction))
	var middle := root + Vector3.UP*height*0.52 + tilted*sway*0.26
	var tip := root + Vector3.UP*height + tilted*sway
	var normal := (Vector3.UP*0.7-tilted).normalized()
	var dark := tint.darkened(0.12)
	batch.triangle(root-across, root+across, middle+across*0.53, normal,normal,normal,dark,dark,tint)
	batch.triangle(root-across, middle+across*0.53, middle-across*0.53, normal,normal,normal,dark,tint,tint)
	batch.triangle(middle-across*0.53, middle+across*0.53, tip, normal,normal,normal,tint,tint,tint.lightened(0.12))


func make_meadow() -> void:
	var patches := [
		Rect2(-11.6,5.3,1.3,1.8), Rect2(-11.7,0.3,1.0,3.7),
		Rect2(-3.0,0.10,7.0,4.1), Rect2(2.07,3.8,1.90,3.62),
		Rect2(-1.7,6.6,1.0,1.0), Rect2(8.6,1.8,3.12,5.9),
		Rect2(-10.4,-6.4,2.0,2.0)
	]
	var counts := [27,12,156,78,13,108,11]
	for i in range(patches.size()):
		var patch: Rect2 = patches[i]
		for j in range(counts[i]):
			var x := rng.randf_range(patch.position.x,patch.end.x)
			var z := rng.randf_range(patch.position.y,patch.end.y)
			if x > 8.70 and x < 11.57 and z > 2.88 and z < 6.09:
				continue
			if x > ROAD_LEFT-0.1 and x < ROAD_RIGHT+0.1:
				continue
			if x < -11.8 + 1.18*(1.0-smoothstep(0.0,7.8,absf(z+0.1))) or x > 11.8-.60*(1.0-smoothstep(0.0,5.8,absf(z-2.2))):
				continue
			var root := Vector3(x,surface_y(x,z)+0.02,z)
			var tint := Color(GRASS_COLORS[rng.randi_range(0,GRASS_COLORS.size()-1)])
			for k in range(rng.randi_range(3,6)):
				var angle := rng.randf()*TAU
				var origin := root+Vector3(cos(angle),0,sin(angle))*rng.randf_range(0.005,0.11)
				var surge := 0.78 + 0.32*sin(x*3.32 + z*2.63)
				blade(meadow,origin,angle,rng.randf_range(0.16,0.57)*surge,rng.randf_range(0.018,0.055),rng.randf_range(-0.06,0.23),tint)


func make_garden() -> void:
	# A raised patch of earth broken into narrow runs, with seedlings at regular intervals.
	var left := 8.85
	var right := 11.41
	var near := 5.97
	var far := 3.02
	var n := Vector3.UP
	var base := Color("#95643c")
	var a := Vector3(left,0.033,far)
	var b := Vector3(left,0.033,near)
	var c := Vector3(right,0.033,near)
	var d := Vector3(right,0.033,far)
	vegetable_soil.triangle(a,b,c,n,n,n,base,base,base)
	vegetable_soil.triangle(a,c,d,n,n,n,base,base,base)
	for row in range(5):
		var x := left+0.17+0.55*row
		taper(vegetable_soil,Vector3(x,0.055,far+0.04),Vector3(x,0.055,near-0.04),0.17,0.17,6,Color("#a87546"))
		for col in range(6):
			var z := far+0.24+0.46*col + rng.randf_range(-0.05,0.05)
			var y := rng.randf_range(0.13,0.19)
			var p := Vector3(x+rng.randf_range(-0.06,0.06),0.18,z)
			var tint := Color(["#94c54b","#80b84d","#9ad359","#96ca4f","#82c04a"][rng.randi_range(0,4)])
			lobe(vegetables,p+Vector3.UP*y*0.6,Vector3(0.12,y,0.12),tint,0.4,0.13)
			for i in range(4):
				var angle := TAU*i/4.0 + rng.randf()*0.48
				blade(vegetables,p,angle,y*rng.randf_range(1.10,2.15),rng.randf_range(0.045,0.079),rng.randf_range(0.11,0.26),tint)
			if (row+col)%4==0:
				# Outer leaves curve away from the core of the larger cabbages.
				for i in range(3):
					var angle := TAU*i/3.0+rng.randf_range(-0.40,0.40)
					var offset := Vector3(cos(angle)*0.10,0.09,sin(angle)*0.10)
					lobe(vegetables,p+offset,Vector3(0.12,0.12,0.11),tint.darkened(0.10),0.35,0.18)
	lobe(vegetables,Vector3(right-0.40,0.32,near-0.60),Vector3(0.35,0.33,0.33),Color("#93c859"),0.28,0.15)
	lobe(vegetables,Vector3(right-0.58,0.27,near-0.58),Vector3(0.27,0.27,0.26),Color("#9ed366"),0.25,0.11)
	for i in range(4):
		var p := Vector3(left+fmod(i,2)*(right-left),0.04,far+floori(i/2)*(near-far))
		taper(vegetable_soil,p,p+Vector3.UP*0.64,0.045,0.027,4,Color("#846247"))
