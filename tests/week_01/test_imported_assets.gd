extends GutTest


func test_three_doors_have_meshes_correct_scale_and_mount_sockets() -> void:
	for name: String in ["door_plank", "door_arch", "door_glass"]:
		var packed: PackedScene = load("res://assets/buildings/%s.glb" % name) as PackedScene
		assert_not_null(packed)
		var instance: Node3D = autofree(packed.instantiate()) as Node3D
		assert_gt(_meshes(instance).size(), 3)
		assert_not_null(instance.find_child("socket_wall_mount", true, false))
		var maximum_height: float = 0.0
		for mesh: MeshInstance3D in _meshes(instance):
			maximum_height = maxf(maximum_height, mesh.position.y + mesh.mesh.get_aabb().end.y)
		assert_between(maximum_height, 1.9, 2.3)


func test_wind_weights_survive_actual_godot_gltf_import() -> void:
	for name: String in ["tree_sample", "cloth_sample"]:
		var packed: PackedScene = load("res://assets/samples/%s.glb" % name) as PackedScene
		var instance: Node3D = autofree(packed.instantiate()) as Node3D
		var min_weight: float = 1.0
		var max_weight: float = 0.0
		var count: int = 0
		for mesh: MeshInstance3D in _meshes(instance):
			for surface: int in range(mesh.mesh.get_surface_count()):
				var arrays: Array = mesh.mesh.surface_get_arrays(surface)
				var colors: Variant = arrays[Mesh.ARRAY_COLOR]
				assert_not_null(colors, "%s must contain COLOR_0" % mesh.name)
				if colors is PackedColorArray:
					for color: Color in colors:
						min_weight = minf(min_weight, color.r)
						max_weight = maxf(max_weight, color.r)
						count += 1
		assert_gt(count, 100)
		assert_almost_eq(min_weight, 0.0, 0.01)
		assert_gt(max_weight, 0.8)


func test_bench_source_export_has_surface_socket() -> void:
	var packed: PackedScene = load("res://assets/samples/bench_sample.glb") as PackedScene
	var instance: Node3D = autofree(packed.instantiate()) as Node3D
	assert_not_null(instance.find_child("socket_tea_surface", true, false))
	assert_gt(_meshes(instance).size(), 5)


func _meshes(root: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if root is MeshInstance3D:
		result.append(root as MeshInstance3D)
	for child: Node in root.get_children():
		result.append_array(_meshes(child))
	return result
