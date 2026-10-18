extends GutTest


func test_formal_base_profile_is_finite_and_delta_restore_keeps_base() -> void:
	var world: Dictionary = WorldDocument.new().snapshot()
	world["terrain"]["base_profile"] = "forest_slope_v1"
	var before: TerrainField = TerrainField.new(world)
	assert_lt(before.height_at(Vector2.ZERO), 0.0)
	world = TerrainEdits.stroke(world, Vector2(8, 8), "raise")
	assert_gt(TerrainField.new(world).height_at(Vector2(8, 8)), before.height_at(Vector2(8, 8)))
	world = TerrainEdits.stroke(world, Vector2(8, 8), "restore")
	assert_almost_eq(
		TerrainField.new(world).height_at(Vector2(8, 8)), before.height_at(Vector2(8, 8)), 0.0001
	)
	assert_eq(WorldDocument.validate(world), "")


func test_smoothing_reduces_peak_without_changing_far_data() -> void:
	var world: Dictionary = WorldDocument.new().snapshot()
	world["terrain"]["height_deltas"] = [[80, 80, 1.0], [100, 100, 0.5]]
	world = TerrainEdits.stroke(world, Vector2(8, 8), "smooth")
	var field: TerrainField = TerrainField.new(world)
	assert_lt(field.height_at(Vector2(8, 8)), 1.0)
	assert_almost_eq(field.height_at(Vector2(18, 18)), 0.5, 0.0001)


func test_pool_and_core_boundary_are_protected_for_all_new_brush_modes() -> void:
	var world: Dictionary = TerrainField.pond(WorldDocument.new().snapshot(), Vector2(8, 8), 2)
	for mode: String in ["raise", "lower", "smooth", "restore"]:
		var candidate: Dictionary = TerrainEdits.stroke(world, Vector2(8, 8), mode, 2.5)
		assert_eq_deep(candidate["terrain"], world["terrain"])
		candidate = TerrainEdits.stroke(world, Vector2(24, 0), mode)
		for entry: Array in candidate["terrain"]["height_deltas"]:
			assert_lt(entry[0], 112)


func test_entrance_clearance_is_not_eroded_by_brush() -> void:
	var world: Dictionary = WorldDocument.new().snapshot()
	var home: Dictionary = WorldDocument.allocate_building(world, Vector3.ZERO, Vector3(5, 3, 5))
	home["openings"] = [{"kind": "arch", "center": 0.5, "width": 1.1, "height": 2.05}]
	world = TerrainEdits.stroke(world, Vector2(0, 3), "lower")
	assert_almost_eq(TerrainField.new(world).height_at(Vector2(0, 3)), 0.0, 0.0001)


func test_chunk_cache_rebuilds_only_local_halo_and_matches_full_generation() -> void:
	var world: Dictionary = WorldDocument.new().snapshot()
	var cache: Dictionary = {}
	var first: Dictionary = WorldRebuild.evaluate(world, cache)
	assert_eq(first["terrain_rebuilt"], 64)
	assert_eq(WorldRebuild.evaluate(world, cache)["terrain_rebuilt"], 0)
	world = TerrainEdits.stroke(world, Vector2(12, 8), "raise")
	var local: Dictionary = WorldRebuild.evaluate(world, cache)
	assert_gt(local["terrain_rebuilt"], 0)
	assert_lt(local["terrain_rebuilt"], 8)
	assert_eq(local["terrain_arrays"], WorldRebuild.evaluate(world)["terrain_arrays"])


func test_pool_deletion_invalidates_affected_chunks_and_restores_player_data() -> void:
	var world: Dictionary = WorldDocument.new().snapshot()
	var cache: Dictionary = {}
	WorldRebuild.evaluate(world, cache)
	world = TerrainField.pond(world, Vector2(8, 8), 2)
	var added: Dictionary = WorldRebuild.evaluate(world, cache)
	assert_gt(added["terrain_rebuilt"], 0)
	assert_lt(added["terrain_rebuilt"], 64)
	world["pool"] = {}
	var removed: Dictionary = WorldRebuild.evaluate(world, cache)
	assert_eq(removed["terrain_rebuilt"], added["terrain_rebuilt"])
	assert_true(world["terrain"]["height_deltas"].is_empty())


func test_base_profile_change_invalidates_all_chunks() -> void:
	var world: Dictionary = WorldDocument.new().snapshot()
	var cache: Dictionary = {}
	WorldRebuild.evaluate(world, cache)
	world["terrain"]["base_profile"] = "forest_slope_v1"
	assert_eq(WorldRebuild.evaluate(world, cache)["terrain_rebuilt"], 64)


func test_foundation_timbers_leave_entrance_clear_and_stone_follows_ground() -> void:
	var world: Dictionary = WorldDocument.new().snapshot()
	var home: Dictionary = WorldDocument.allocate_building(
		world, Vector3(0, 0.6, 0), Vector3(5, 3, 5)
	)
	home["openings"] = [{"kind": "arch", "center": 0.5, "width": 1.1, "height": 2.05}]
	var result: Dictionary = FoundationGeometry.build(home, TerrainField.new(world))
	assert_gt(result["stone_arrays"][Mesh.ARRAY_VERTEX].size(), 0)
	var blocked: bool = false
	for p: Vector3 in result["wood_arrays"][Mesh.ARRAY_VERTEX]:
		blocked = blocked or (absf(p.x) < 0.8 and p.z > 2.4)
	assert_false(blocked)


func test_three_metre_support_boundary_still_rejects_whole_source() -> void:
	var world: Dictionary = WorldDocument.new().snapshot()
	WorldDocument.allocate_building(world, Vector3(0, 3, 0), Vector3(5, 3, 5))
	assert_eq(WorldDocument.validate(world), "")
	world = TerrainEdits.stroke(world, Vector2.ZERO, "lower", 1)
	assert_eq(WorldDocument.validate(world), "foundation_exceeds_3m")


func test_unchanged_path_mesh_is_reused_when_terrain_is_far_away() -> void:
	var world: Dictionary = WorldDocument.new().snapshot()
	PathGeometry.allocate(world, [[0, 0, 0], [0, 0, 4]])
	var before: Dictionary = WorldRebuild.materialize(WorldRebuild.evaluate(world))
	world = TerrainEdits.stroke(world, Vector2(15, 15), "raise")
	var after: Dictionary = WorldRebuild.materialize(WorldRebuild.evaluate(world), before)
	assert_eq(before["path_mesh"], after["path_mesh"])
