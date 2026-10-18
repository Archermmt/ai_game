extends GutTest


func test_window_sources_import_uv_color_and_complete_frames_with_sockets() -> void:
	for name: String in ["window_rect", "window_round"]:
		var packed: PackedScene = load("res://assets/buildings/" + name + ".glb")
		var scene: Node3D = packed.instantiate() as Node3D
		assert_not_null(scene.find_child("socket_wall_mount", true, false))
		var meshes: Array[Node] = scene.find_children("*", "MeshInstance3D", true, false)
		assert_gt(meshes.size(), 3)
		var found_light: bool = false
		for mesh: MeshInstance3D in meshes:
			var arrays: Array = mesh.mesh.surface_get_arrays(0)
			assert_gt(arrays[Mesh.ARRAY_TEX_UV].size(), 0)
			assert_gt(arrays[Mesh.ARRAY_COLOR].size(), 0)
			found_light = found_light or mesh.name.begins_with("window_light")
		assert_true(found_light)
		scene.free()


func test_painted_texture_resolutions_and_emission_mask_dark_edge() -> void:
	for name: String in [
		"plaster", "wood", "terracotta", "stone", "window_emission", "grass", "soil", "wet_bank"
	]:
		var texture: Texture2D = load("res://assets/materials/textures/" + name + ".png")
		var expected: int = 2048 if name in ["grass", "soil", "wet_bank"] else 1024
		assert_eq(texture.get_width(), expected)
		assert_eq(texture.get_height(), expected)
	var mask_texture: Texture2D = load("res://assets/materials/textures/window_emission.png")
	var mask: Image = mask_texture.get_image()
	if mask.is_compressed():
		assert_eq(mask.decompress(), OK)
	assert_lt(mask.get_pixel(0, 0).r, 0.01)
	assert_gt(mask.get_pixel(512, 512).r, 0.9)


func test_three_tree_blockouts_have_distinct_shapes_and_zero_weight_roots() -> void:
	var counts: Array[int] = []
	for name: String in ["tree_broadleaf", "tree_conifer", "tree_fruit"]:
		var packed: PackedScene = load("res://assets/nature/" + name + ".glb")
		var scene: Node3D = packed.instantiate() as Node3D
		assert_not_null(scene.find_child("socket_ground", true, false))
		var meshes: Array[Node] = scene.find_children("*", "MeshInstance3D", true, false)
		var triangles: int = 0
		for mesh: MeshInstance3D in meshes:
			triangles += mesh.mesh.surface_get_array_len(0)
			if mesh.name.begins_with("tree_trunk"):
				var colors: PackedColorArray = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
				for color: Color in colors:
					assert_almost_eq(color.r, 0.0, 0.001)
		counts.append(triangles)
		scene.free()
	assert_ne(counts[0], counts[1])
	assert_ne(counts[0], counts[2])
