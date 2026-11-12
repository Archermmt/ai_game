extends Node3D

const Profile := preload("res://street/layout/ground_profile.gd")
const HALF := Vector2(12.0, 8.0)
const CORNER := 0.48
const GREEN := Color("#c3fa83")
const SHADE_GREEN := Color("#70a144")

func _ready() -> void:
	_ground()
	_road()

func _rounded(x: float, z: float) -> Vector2:
	var p := Vector2(x, z)
	var centre := p.clamp(-HALF + Vector2.ONE * CORNER, HALF - Vector2.ONE * CORNER)
	var rounded := centre + (p - centre).limit_length(CORNER)
	var lip := smoothstep(0.,1.25,x) * (1.-smoothstep(3.6,4.1,x))
	var inset := 0.0
	if x < 0.:
		inset = 1.18 * (1.-smoothstep(.0,7.8,absf(z+.10)))
	else:
		inset = -.60 * (1.-smoothstep(.0,5.8,absf(z-2.2)))
	rounded.x += inset * smoothstep(8.5,11.8,absf(x))
	rounded.y += .34 * lip * smoothstep(6.,8.,z)
	return rounded

func _surface_color(x: float, z: float) -> Color:
	var edges := smoothstep(7.0, 12.0, absf(x))
	var near_left := smoothstep(0.0, 7.0, z) * (1.0 - smoothstep(-3.6, 1.1, x))
	var meadow := GREEN.lerp(SHADE_GREEN, maxf(0.84 * edges, 0.94 * near_left))
	var patch := sin(x*1.1+z*.43)*cos(z*1.2-x*.36)
	return meadow.lightened(maxf(0.0, patch * 0.026)).srgb_to_linear()

func _ground() -> void:
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	const NX := 84
	const NZ := 56
	for row in range(NZ + 1):
		for col in range(NX + 1):
			var q := _rounded(lerpf(-HALF.x, HALF.x, float(col)/NX), lerpf(-HALF.y, HALF.y, float(row)/NZ))
			var h := Profile.height_at(q.x, q.y)
			vertices.append(Vector3(q.x, h, q.y))
			var dx := Profile.height_at(q.x-.02, q.y)-Profile.height_at(q.x+.02, q.y)
			var dz := Profile.height_at(q.x, q.y-.02)-Profile.height_at(q.x, q.y+.02)
			normals.append(Vector3(dx, .04, dz).normalized())
			colors.append(_surface_color(q.x, q.y))
			if col < NX and row < NZ:
				var i := row * (NX+1) + col
				indices.append_array([i, i+1, i+NX+1, i+1, i+NX+2, i+NX+1])
	var top_mat := StandardMaterial3D.new()
	top_mat.vertex_color_use_as_albedo = true
	top_mat.roughness = 1.0
	top_mat.metallic_specular = 0.0
	_surface("Meadow", vertices, normals, colors, indices, top_mat)

	var edges: Array[Vector2] = []
	for i in NX:
		edges.append(_rounded(lerpf(-12.,12.,float(i)/NX),-8.))
	for i in NZ:
		edges.append(_rounded(12.,lerpf(-8.,8.,float(i)/NZ)))
	for i in NX:
		edges.append(_rounded(lerpf(12.,-12.,float(i)/NX),8.))
	for i in NZ:
		edges.append(_rounded(-12.,lerpf(8.,-8.,float(i)/NZ)))
	var bands := [
		[0.00, 1.000, Color("#91c458")],
		[-0.10, 1.000, Color("#91bc59")],
		[-0.17, 0.998, Color("#659346")],
		[-0.25, 0.994, Color("#85a852")],
		[-0.32, 0.987, Color("#546c38")],
		[-0.38, 0.984, Color("#827151")],
		[-0.73, 0.983, Color("#a17c67")],
		[-0.82, 0.981, Color("#825f50")],
		[-0.91, 0.976, Color("#664a42")],
		[-1.00, 0.972, Color("#916e59")],
		[-1.12, 0.962, Color("#644a44")]
	]
	for j in range(bands.size()-1):
		var mat := StandardMaterial3D.new()
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.vertex_color_use_as_albedo = true
		mat.roughness = 1.
		mat.metallic_specular = 0.
		var verts := PackedVector3Array()
		var norms := PackedVector3Array()
		var cols := PackedColorArray()
		var ids := PackedInt32Array()
		for i in edges.size():
			var a := edges[i]
			var b := edges[(i+1)%edges.size()]
			var n := Vector3(b.y-a.y,0.,a.x-b.x).normalized()
			for k in range(4):
				var e := a if k == 0 or k == 3 else b
				var level: Array = bands[j + (1 if k >= 2 else 0)]
				var h := Profile.height_at(e.x,e.y)
				var v := Vector3(e.x*level[1], h+level[0]*1.70, e.y*level[1])
				verts.append(v)
				norms.append(n)
				var color: Color
				if j <= 3:
					color = _surface_color(e.x,e.y) * [0.89,0.74,0.96,0.83][j]
				else:
					color = Color(["#799449","#8d6e5e","#8f6e5d","#704e40","#644736","#8b6a58"][j-4]).srgb_to_linear()
				cols.append(color)
			var start := i*4
			ids.append_array([start,start+2,start+1,start,start+3,start+2])
		_surface("CutLayer%d" % j, verts,norms,cols,ids,mat)

func _surface(label: String, verts: PackedVector3Array, norms: PackedVector3Array, cols: PackedColorArray, ids: PackedInt32Array, mat: Material) -> void:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = ids
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.material_override = mat
	add_child(node)

func _box(label: String, pos: Vector3, size: Vector3, color: String) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color)
	mat.roughness = 1.0
	mat.metallic_specular = 0.0
	var box := BoxMesh.new()
	box.size = size
	box.material = mat
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = box
	node.position = pos
	add_child(node)
	return node

func _road() -> void:
	const X := 6.25
	# The station occupies the far side of the crossing. The road meets its apron.
	var back := -2.12
	var front := 7.98
	_box("Asphalt", Vector3(X,.025,(back+front)*.5), Vector3(4.42,.05,front-back), "#73737d")
	var marking := "#f7f3ee"
	for side in [-1,1]:
		_box("EdgeStripe",Vector3(X+2.09*side,.059,(front+back)*.5), Vector3(.066,.008,front-back-.10),marking)
	for z in [2.28,3.72,5.16,6.6,7.75]:
		_box("CenterDash",Vector3(X,.062,z), Vector3(.076,.009,.61),marking)
	_box("StopStripe",Vector3(X-1.07,.069,1.82),Vector3(2.04,.009,.14),marking)
	_box("StopStripeEnd",Vector3(X-.09,.068,1.98),Vector3(.09,.009,.43),marking)
