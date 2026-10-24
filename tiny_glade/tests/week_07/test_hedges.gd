extends GutTest


func _world() -> Dictionary:
	return WorldDocument.new("w07-hedge").snapshot()


func test_short_and_turning_paths_have_closed_end_volumes() -> void:
	var world: Dictionary = _world()
	var item: Dictionary = HedgeRules.allocate(world, [[-3, -3], [-2.4, -3]])
	assert_eq(WorldDocument.validate(world), "")
	assert_eq(HedgeRules.samples(item).front(), Vector2.ZERO)
	assert_almost_eq(HedgeRules.samples(item).back(), Vector2(0.6, 0), Vector2.ONE * 0.00001)
	item["hedge"]["points"] = [[0, 0], [3, 0], [3, 3]]
	var points: Array[Vector2] = HedgeRules.samples(item)
	assert_eq(points.count(Vector2(3, 0)), 1)
	for i: int in range(points.size() - 1):
		assert_lte(points[i].distance_to(points[i + 1]), 0.451)


func test_invalid_hedge_shapes_are_rejected_without_crashing() -> void:
	for shape: Variant in [
		null,
		{},
		{"points": [], "width": 1},
		{"points": [[0, 0], [INF, 1]], "width": 1},
		{"points": [[0, 0], [0.1, 0]], "width": 1},
		{"points": [[0, 0], [17, 0]], "width": 1},
		{"points": [[0, 0], [2, 0]], "width": 5}
	]:
		var world: Dictionary = _world()
		var item: Dictionary = HedgeRules.allocate(world, [[0, 0], [2, 0]])
		item["hedge"] = shape
		assert_ne(WorldDocument.validate(world), "")


func test_transform_rotates_scales_all_segments_and_full_bounds() -> void:
	var world: Dictionary = _world()
	var item: Dictionary = HedgeRules.allocate(world, [[1, 2], [4, 2], [4, 5]])
	item["yaw"] = PI / 2
	item["scale"] = 2.0
	assert_almost_eq(
		HedgeRules.world_point(item, Vector2(3, 0)), Vector2(1, -4), Vector2.ONE * 0.001
	)
	assert_lt(HedgeRules.distance(item, Vector2(1, -3)), 0.001)
	assert_true(DirtyGraph.bounds(item).has_point(Vector2(1, -4)))


func test_hedge_far_end_cannot_cross_a_building_or_boundary() -> void:
	var world: Dictionary = _world()
	var item: Dictionary = HedgeRules.allocate(world, [[0, 0], [6, 0]])
	WorldDocument.allocate_building(world, Vector3(6, 0, 0), Vector3(3, 3, 3))
	assert_eq(WorldDocument.validate(world), "hedge_clearance")
	world["buildings"].clear()
	item["position"] = [21, 0, 0]
	assert_eq(WorldDocument.validate(world), "hedge_clearance")


func test_hedges_avoid_path_and_pool_at_every_sample() -> void:
	var world: Dictionary = _world()
	HedgeRules.allocate(world, [[-4, 0], [4, 0]])
	PathGeometry.allocate(world, [[3, 0, -3], [3, 0, 3]])
	assert_eq(WorldDocument.validate(world), "hedge_clearance")
	world["paths"].clear()
	world = TerrainField.pond(world, Vector2(3, 0), 2)
	assert_eq(WorldDocument.validate(world), "hedge_clearance")


func test_category_erase_near_far_end_removes_whole_automatic_hedge() -> void:
	var world: Dictionary = _world()
	HedgeRules.allocate(world, [[-4, 0], [4, 0]])
	assert_eq(VegetationBrush.paint(world, Vector2(4, 0), "plants", 0.5, 1, {}, true), 1)
	assert_true(world["instances"].is_empty())


func test_manual_adjustment_and_unrelated_categories_protect_hedges() -> void:
	var world: Dictionary = _world()
	var item: Dictionary = HedgeRules.allocate(world, [[-4, 0], [4, 0]])
	assert_eq(VegetationBrush.paint(world, Vector2(4, 0), "trees", 1, 1, {}, true), 0)
	InstanceEdits.transform_selection(world, [item["id"]], Vector3.ZERO, 0.1)
	assert_eq(VegetationBrush.paint(world, Vector2(4, 0), "plants", 2, 1, {}, true), 0)


func test_hedge_is_not_accidentally_batched_as_compact_shrub() -> void:
	var world: Dictionary = _world()
	HedgeRules.allocate(world, [[0, 0], [3, 0]])
	assert_true(FoliageBatches.groups(world).is_empty())


func test_duplicate_keeps_shape_but_has_independent_source_and_id() -> void:
	var world: Dictionary = _world()
	var item: Dictionary = HedgeRules.allocate(world, [[0, 0], [3, 0]])
	var copies: Array[String] = InstanceEdits.duplicate_selection(world, [item["id"]])
	var copy: Dictionary = world["instances"].back()
	assert_ne(copies[0], item["id"])
	assert_eq(copy["hedge"], item["hedge"])
	copy["hedge"]["width"] = 1.2
	assert_eq(item["hedge"]["width"], 0.8)


func test_slope_change_at_far_end_invalidates_hedge_region_only() -> void:
	var world: Dictionary = _world()
	var item: Dictionary = HedgeRules.allocate(world, [[-8, 0], [0, 0]])
	var cache: Dictionary = {}
	LocalRebuild.evaluate(world, cache)
	var changed: Dictionary = TerrainField.brush(world, Vector2.ZERO, 0.3)
	var result: Dictionary = LocalRebuild.evaluate(changed, cache)
	assert_has(result["generated"], "instance:" + item["id"])
	assert_lt(result["terrain_rebuilt"], 12)


func test_generated_shrub_mesh_uv_is_reused_at_ends_and_turns() -> void:
	var world: Dictionary = _world()
	var item: Dictionary = HedgeRules.allocate(world, [[0, 0], [2, 0], [2, 2]])
	var view: Node3D = HedgeView.create(item, world, null, null)
	var prototype: Node3D = WeekFourCatalog.create("NAT-06", "test", null, null)
	var source_meshes: Array = prototype.find_children("*", "MeshInstance3D", true, false)
	assert_eq(view.get_child_count(), source_meshes.size())
	for i: int in range(view.get_child_count()):
		var part: MultiMeshInstance3D = view.get_child(i)
		assert_same(part.multimesh.mesh, source_meshes[i].mesh)
		assert_eq(part.multimesh.instance_count, HedgeRules.samples(item).size())
	prototype.free()
	view.free()


func test_surface_follow_and_height_lock_do_not_tilt_whole_hedge() -> void:
	var world: Dictionary = _world()
	var item: Dictionary = HedgeRules.allocate(world, [[0, 0], [3, 0]])
	world = TerrainField.brush(world, Vector2(3, 0), 0.4)
	var layout: Dictionary = HedgeView.plan(item, world)
	var first: Transform3D = layout["poses"][layout["items"].front()["id"]]
	var last: Transform3D = layout["poses"][layout["items"].back()["id"]]
	assert_gt(last.origin.y - first.origin.y, 0.3)
	assert_eq(LocalRebuild.pose(world, item, TerrainField.new(world)).basis.y, Vector3.UP)
