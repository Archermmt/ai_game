extends GutTest


func test_three_trees_have_smaller_lod_and_same_atlas_region() -> void:
	for id_value: String in VegetationCatalog.NAMES:
		var high: Node3D = VegetationCatalog.instantiate_asset(id_value, "stable", 0)
		var low: Node3D = VegetationCatalog.instantiate_asset(id_value, "stable", 1)
		assert_not_null(high.find_child("socket_ground", true, false))
		assert_gt(_triangles(high), _triangles(low))
		assert_lte(_triangles(high), 4000)
		for root: Node3D in [high, low]:
			var valid: bool = true
			for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
				assert_eq(
					mesh.material_override.get_shader_parameter("atlas"), VegetationCatalog.ATLAS
				)
				for uv: Vector2 in mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]:
					valid = valid and uv.x >= 0 and uv.x <= 1 and uv.y >= 0 and uv.y <= 1
			assert_true(valid)
		high.free()
		low.free()


func test_tree_trunks_are_fixed_and_fruit_weights_follow_crown() -> void:
	var root: Node3D = VegetationCatalog.instantiate_asset("NAT-03", "fruit")
	var fruit_seen: bool = false
	var valid: bool = true
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		for color: Color in mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]:
			if mesh.name.begins_with("tree_trunk"):
				valid = valid and is_zero_approx(color.r)
			if mesh.name.begins_with("fruit"):
				fruit_seen = true
				valid = valid and color.r > 0.1 and color.b > 0.9
	assert_true(valid)
	assert_true(fruit_seen)
	root.free()


func test_atlas_has_transparent_leaf_edge_with_extended_color_and_opaque_bark() -> void:
	var img: Image = VegetationCatalog.ATLAS.get_image()
	if img.is_compressed():
		assert_eq(img.decompress(), OK)
	assert_eq(img.get_size(), Vector2i(2048, 2048))
	# Godot image rows are top-down; leaf tile occupies top-left.
	assert_lt(img.get_pixel(20, 20).a, 0.1)
	assert_gt(img.get_pixel(20, 20).g, 0.1)
	assert_gt(img.get_pixel(512, 512).a, 0.9)
	assert_gt(img.get_pixel(1536, 512).a, 0.9)


func test_lod_material_seed_phase_matches_for_both_levels() -> void:
	var high: Node3D = VegetationCatalog.instantiate_asset("NAT-01", "object-001", 0)
	var low: Node3D = VegetationCatalog.instantiate_asset("NAT-01", "object-001", 1)
	var a: MeshInstance3D = high.find_children("*", "MeshInstance3D", true, false)[0]
	var b: MeshInstance3D = low.find_children("*", "MeshInstance3D", true, false)[0]
	assert_eq(
		a.material_override.get_shader_parameter("phase"),
		b.material_override.get_shader_parameter("phase")
	)
	high.free()
	low.free()


func test_tree_copy_keeps_asset_kind_and_unrelated_seed() -> void:
	var world: Dictionary = WorldDocument.new().snapshot()
	var item: Dictionary = InstanceEdits.allocate(world, Vector3(-9, 0, 8))
	item["asset_id"] = "NAT-02"
	var original: Dictionary = item.duplicate(true)
	InstanceEdits.duplicate_selection(world, [item["id"]])
	assert_eq(world["instances"][1]["asset_id"], "NAT-02")
	assert_eq_deep(world["instances"][0], original)
	assert_eq(WorldDocument.validate(world), "")


func _triangles(root: Node) -> int:
	var total: int = 0
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		for surface: int in range(mesh.mesh.get_surface_count()):
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			total += (
				(
					arrays[Mesh.ARRAY_INDEX].size()
					if arrays[Mesh.ARRAY_INDEX] != null
					else arrays[Mesh.ARRAY_VERTEX].size()
				)
				/ 3
			)
	return total
