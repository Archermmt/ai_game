extends RefCounted
## Temporary unbatched nodes settle into the same authoritative final geometry.
const TERRAIN = preload("res://game/art/healing/terrain_growth.gdshader")
var entries: Array[Dictionary] = []
var elapsed := 0.0
const DURATION := 0.42

func terrain(node: MeshInstance3D, arrays: Array, old_surface: IslandSurface, surface: IslandSurface, final_material: Material) -> void:
	var uv2 := PackedVector2Array()
	var changed := false
	for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
		var xy := Vector2(vertex.x, vertex.z)
		var difference := old_surface.height_at(xy) - surface.height_at(xy)
		uv2.append(Vector2(difference, 0))
		changed = changed or absf(difference) > 0.005
	if not changed:
		return
	var animated := arrays.duplicate()
	animated[Mesh.ARRAY_TEX_UV2] = uv2
	node.mesh = ArrayMesh.new()
	node.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, animated)
	var material := ShaderMaterial.new()
	material.shader = TERRAIN
	material.set_shader_parameter("progress", 0.0)
	node.material_override = material
	node.set_meta("batch_exclude", true)
	entries.append({"node": node, "material": final_material, "arrays": arrays})

func building(node: Node3D) -> void:
	node.set_meta("batch_exclude", true)
	node.scale = Vector3(0.88, 0.025, 0.88)
	entries.append({"node": node})

func advance(delta: float) -> bool:
	if entries.is_empty():
		return false
	elapsed += delta
	var t := clampf(elapsed / DURATION, 0, 1)
	for entry in entries:
		var node: Node3D = entry.node
		if not is_instance_valid(node):
			continue
		if entry.has("arrays"):
			node.material_override.set_shader_parameter("progress", t)
		else:
			# A restrained overshoot adds weight without bouncing below the soil.
			var rise := 1.0 + 2.2 * pow(t - 1.0, 3) + 1.2 * pow(t - 1.0, 2)
			node.scale = Vector3(lerpf(0.88, 1.0, t), maxf(0.025, rise), lerpf(0.88, 1.0, t))
	if t < 1.0:
		return false
	finish()
	return true

func finish() -> void:
	for entry in entries:
		var node: Node3D = entry.node
		if not is_instance_valid(node):
			continue
		if entry.has("arrays"):
			node.mesh = ArrayMesh.new()
			node.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, entry.arrays)
			node.material_override = entry.material
		else:
			node.scale = Vector3.ONE
		node.remove_meta("batch_exclude")
	entries.clear()
	elapsed = 0.0
