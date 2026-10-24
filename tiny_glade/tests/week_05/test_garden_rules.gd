extends GutTest


func _pond() -> Dictionary:
	return PondShape.draw(WorldDocument.new("w05").snapshot(), [[-3, -2], [3, -2], [3, 2], [-3, 2]])


func test_polygon_signed_distance_agrees_with_edges_and_inside() -> void:
	var pool: Dictionary = _pond()["pool"]
	assert_almost_eq(PondShape.distance(pool, Vector2.ZERO), -2.0, 0.0001)
	assert_almost_eq(PondShape.distance(pool, Vector2(4, 0)), 1.0, 0.0001)
	assert_almost_eq(PondShape.distance(pool, Vector2(3, 0)), 0.0, 0.0001)
	assert_eq(WorldDocument.validate(_pond()), "")


func test_legacy_circle_keeps_exact_distance() -> void:
	var world: Dictionary = TerrainField.pond(WorldDocument.new().snapshot(), Vector2(5, 5), 2)
	assert_almost_eq(PondShape.distance(world["pool"], Vector2(5, 5)), -2.0, 0.00001)
	assert_eq(WorldDocument.validate(world), "")


func test_water_level_fixed_after_redrawing_existing_pond() -> void:
	var world: Dictionary = _pond()
	var water: float = world["pool"]["water_y"]
	world = PondShape.draw(world, [[-4, -3], [4, -3], [4, 3], [-4, 3]])
	assert_eq(world["pool"]["water_y"], water)
	assert_eq(WorldDocument.validate(world), "")


func test_crossed_polygon_rejected_without_mutating_source() -> void:
	var world: Dictionary = _pond()
	var before: Dictionary = world.duplicate(true)
	var bad: Dictionary = PondShape.draw(world, [[-3, -2], [3, 2], [3, -2], [-3, 2]])
	assert_ne(WorldDocument.validate(bad), "")
	assert_eq_deep(world, before)


func test_polygon_minimum_width_two_metres() -> void:
	var world: Dictionary = PondShape.draw(_pond(), [[-3, -0.9], [3, -0.9], [3, 0.9], [-3, 0.9]])
	assert_eq(WorldDocument.validate(world), "pool_minimum_width")
	world = PondShape.draw(_pond(), [[-3, -1], [3, -1], [3, 1], [-3, 1]])
	assert_eq(WorldDocument.validate(world), "")


func test_degenerate_and_malformed_outlines_fail_safely() -> void:
	for outline: Array in [
		[[0, 0], [0, 0], [2, 2]], [[0, 0], [2, 0], [4, 0]], [[0, 0], [2, "x"], [4, 0]]
	]:
		var world: Dictionary = _pond()
		world["pool"]["outline"] = outline
		assert_ne(WorldDocument.validate(world), "")


func test_polygon_boundary_two_metres() -> void:
	var world: Dictionary = PondShape.draw(_pond(), [[19, -2], [22.1, -2], [22.1, 2], [19, 2]])
	assert_eq(WorldDocument.validate(world), "pool_boundary_2m")


func test_all_terrain_brushes_preserve_polygon_and_bank() -> void:
	var world: Dictionary = _pond()
	var before: float = TerrainField.new(world).height_at(Vector2(3.4, 0))
	for mode: String in ["raise", "lower", "smooth", "restore"]:
		var after: Dictionary = TerrainEdits.stroke(world, Vector2(2.5, 0), mode, 2)
		assert_eq(TerrainField.new(after).height_at(Vector2(3.4, 0)), before)
		assert_eq_deep(after["pool"], world["pool"])


func test_delete_pond_restores_player_heights() -> void:
	var world: Dictionary = TerrainEdits.stroke(
		WorldDocument.new().snapshot(), Vector2.ZERO, "raise", 3, 0.1
	)
	var original: Dictionary = world.duplicate(true)
	world = PondShape.draw(world, [[-3, -2], [3, -2], [3, 2], [-3, 2]])
	assert_lt(TerrainField.new(world).height_at(Vector2.ZERO), 0)
	world["pool"] = {}
	assert_eq_deep(world["terrain"], original["terrain"])
	assert_eq(
		TerrainField.new(world).height_at(Vector2.ZERO),
		TerrainField.new(original).height_at(Vector2.ZERO)
	)


func test_polygon_rejects_excessive_original_slope() -> void:
	var world: Dictionary = _pond()
	world["terrain"]["height_deltas"] = [[64, 64, 0.8]]
	assert_eq(WorldDocument.validate(world), "pool_slope_exceeds_0_6m")


func test_building_and_shore_use_same_safety_boundary_both_directions() -> void:
	var world: Dictionary = _pond()
	WorldDocument.allocate_building(world, Vector3(5.6, 0, 0), Vector3(3, 3, 3))
	assert_eq(WorldDocument.validate(world), "pool_building_safety")
	world["buildings"][0]["position"][0] = 5.76
	assert_eq(WorldDocument.validate(world), "")
	var enlarged: Dictionary = PondShape.draw(world, [[-3, -2], [3.2, -2], [3.2, 2], [-3, 2]])
	assert_eq(WorldDocument.validate(enlarged), "pool_building_safety")


func test_manual_objects_not_swallowed_by_shore() -> void:
	var world: Dictionary = _pond()
	var item: Dictionary = InstanceEdits.allocate(world, Vector3(5, 0, 0))
	item["asset_id"] = "PROP-05"
	assert_eq(WorldDocument.validate(world), "")
	world = PondShape.draw(world, [[-3, -2], [4, -2], [4, 2], [-3, 2]])
	assert_eq(WorldDocument.validate(world), "pool_manual_instance_safety")
	assert_eq(world["instances"][0]["position"], [5.0, 0.0, 0.0])


func test_polygon_water_is_triangulated_at_fixed_height() -> void:
	var world: Dictionary = _pond()
	var arrays: Array = PondShape.water_arrays(world["pool"])
	assert_eq(arrays[Mesh.ARRAY_VERTEX].size(), 6)
	for p: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
		assert_almost_eq(p.y, world["pool"]["water_y"], 0.00001)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	assert_lt((v[1] - v[0]).cross(v[2] - v[0]).y, 0.0)


func test_chunk_cache_changes_with_outline_and_matches_fresh() -> void:
	var world: Dictionary = _pond()
	var cache: Dictionary = {}
	WorldRebuild.evaluate(world, cache)
	world = PondShape.draw(world, [[-4, -2], [3, -2], [3, 2], [-4, 2]])
	var result: Dictionary = WorldRebuild.evaluate(world, cache)
	assert_gt(result["terrain_rebuilt"], 0)
	assert_lt(result["terrain_rebuilt"], 64)
	assert_eq(result["terrain_arrays"], WorldRebuild.evaluate(world)["terrain_arrays"])


func test_failed_pond_transaction_preserves_history_and_view_payload() -> void:
	var doc: WorldDocument = WorldDocument.new()
	doc.state = _pond()
	var session: EditSession = EditSession.new(doc)
	var before: Dictionary = doc.snapshot()
	var bad: Dictionary = PondShape.draw(before, [[-3, -0.5], [3, -0.5], [3, 0.5], [-3, 0.5]])
	assert_false(session.commit_snapshot(bad, "bad")["ok"])
	assert_eq_deep(doc.snapshot(), before)
	assert_eq(session.history_count(), 0)
	session.dispose()


func test_concave_simple_wide_outline_supported() -> void:
	var world: Dictionary = PondShape.draw(
		WorldDocument.new().snapshot(), [[-5, -4], [5, -4], [5, 4], [1, 4], [1, 0], [-5, 0]]
	)
	assert_eq(WorldDocument.validate(world), "")
	assert_gt(PondShape.distance(world["pool"], Vector2(-3, 2)), 0)
	assert_lt(PondShape.distance(world["pool"], Vector2(3, 2)), 0)


func test_crate_support_height_and_cycle_guard() -> void:
	var world: Dictionary = WorldDocument.new().snapshot()
	var parent: Dictionary = InstanceEdits.allocate(world, Vector3(8, 0, 8))
	parent["asset_id"] = "PROP-05"
	var child: Dictionary = InstanceEdits.allocate(world, Vector3(8, 0, 8))
	child["asset_id"] = "PROP-05"
	child["support_id"] = parent["id"]
	assert_eq(WorldDocument.validate(world), "")
	assert_almost_eq(InstanceEdits.support_height(world, child), 0.8, 0.0001)
	parent["support_id"] = child["id"]
	assert_eq(WorldDocument.validate(world), "invalid_support")


func test_missing_support_rejects_delete_without_losing_child() -> void:
	var world: Dictionary = WorldDocument.new().snapshot()
	var item: Dictionary = InstanceEdits.allocate(world, Vector3(8, 0, 8))
	item["support_id"] = "missing"
	assert_eq(WorldDocument.validate(world), "missing_support")


func test_bad_fence_points_fail_without_engine_error() -> void:
	var world: Dictionary = WorldDocument.new().snapshot()
	FenceGeometry.allocate(world, [[0, 0, 0], [3, 0, 0]])
	world["fences"][0]["points"][0] = "bad"
	assert_eq(WorldDocument.validate(world), "invalid_fence_points")


func test_closed_fence_has_capped_rails_and_shared_corner_posts() -> void:
	var world: Dictionary = WorldDocument.new().snapshot()
	FenceGeometry.allocate(world, [[-2, 0, -2], [2, 0, -2], [2, 0, 2], [-2, 0, 2]])
	world["fences"][0]["closed"] = true
	assert_eq(WorldDocument.validate(world), "")
	var arrays: Array = FenceGeometry.build(world)
	# Four sides with 5 rail intervals each, 20 unique posts; each sealed box 36 vertices.
	assert_eq(arrays[Mesh.ARRAY_VERTEX].size(), (20 + 40) * 36)
	PathGeometry.allocate(world, [[0, 0, -5], [0, 0, 5]])
	assert_lt(
		FenceGeometry.build(world)[Mesh.ARRAY_VERTEX].size(), arrays[Mesh.ARRAY_VERTEX].size()
	)
