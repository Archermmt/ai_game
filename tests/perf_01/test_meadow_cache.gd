extends GutTest


func test_cached_generation_matches_full_generation() -> void:
	var source: Dictionary = ArtLayout.create()
	var cache: Dictionary = {}
	var actual: Dictionary = MeadowData.generate_cached(source, cache)
	var expected: Dictionary = MeadowData.generate(source)
	assert_eq(actual["count"], expected["count"])
	assert_eq_deep(actual["chunks"], expected["chunks"])
	assert_gt(actual["updated_chunks"], 0)


func test_local_terrain_updates_preserve_distribution_and_previous_result() -> void:
	var source: Dictionary = ArtLayout.create()
	var cache: Dictionary = {}
	var previous: Dictionary = MeadowData.generate_cached(source, cache)
	var frozen: Dictionary = previous["chunks"].duplicate(true)
	var changed: Dictionary = TerrainField.brush(source, Vector2(12, 8), 0.1)
	var actual: Dictionary = MeadowData.generate_cached(changed, cache)
	assert_eq_deep(actual["chunks"], MeadowData.generate(changed)["chunks"])
	assert_eq_deep(previous["chunks"], frozen)
	assert_gt(actual["updated_chunks"], 0)
	assert_lt(actual["updated_chunks"], cache["chunks"].size())
	assert_eq(actual["count"], previous["count"])


func test_undo_and_spacing_profile_changes_match_fresh_generation() -> void:
	var source: Dictionary = ArtLayout.create()
	var cache: Dictionary = {}
	MeadowData.generate_cached(source, cache)
	MeadowData.generate_cached(TerrainField.brush(source, Vector2(12, 8), 0.1), cache)
	assert_eq_deep(
		MeadowData.generate_cached(source, cache)["chunks"], MeadowData.generate(source)["chunks"]
	)
	var changed: Dictionary = source.duplicate(true)
	changed["terrain"]["spacing"] = 0.25
	changed["terrain"]["base_profile"] = "flat"
	assert_eq_deep(
		MeadowData.generate_cached(changed, cache)["chunks"], MeadowData.generate(changed)["chunks"]
	)


func test_obstacle_and_seed_changes_invalidate_cached_distribution() -> void:
	var source: Dictionary = ArtLayout.create()
	var cache: Dictionary = {}
	MeadowData.generate_cached(source, cache)
	for key: String in ["buildings", "paths", "instances", "bridges"]:
		var changed: Dictionary = source.duplicate(true)
		changed[key] = []
		assert_eq_deep(
			MeadowData.generate_cached(changed, cache)["chunks"],
			MeadowData.generate(changed)["chunks"]
		)
	var changed: Dictionary = source.duplicate(true)
	changed["world_seed"] = "cache-new-seed"
	changed["pool"] = {}
	assert_eq_deep(
		MeadowData.generate_cached(changed, cache)["chunks"], MeadowData.generate(changed)["chunks"]
	)


func test_unchanged_source_reuses_all_chunks_without_mutating_source() -> void:
	var source: Dictionary = ArtLayout.create()
	var before: Dictionary = source.duplicate(true)
	var cache: Dictionary = {}
	var first: Dictionary = MeadowData.generate_cached(source, cache)
	var again: Dictionary = MeadowData.generate_cached(source, cache)
	assert_eq(again["updated_chunks"], 0)
	assert_eq_deep(again["chunks"], first["chunks"])
	assert_eq_deep(source, before)


func test_cached_pond_broad_phase_matches_exact_for_near_far_and_edges() -> void:
	var source: Dictionary = ArtLayout.create()
	source["pool"] = {
		"center": [0, 0],
		"radius": 10,
		"water_y": 0,
		"outline": [[-4, -4], [4, -4], [4, 4], [-4, 4]]
	}
	var field: TerrainField = TerrainField.new(source)
	for shape: String in ["rect", "round"]:
		for x: float in [-15.0, -6.25002, -6.25, -6.24998, -4.0, 0.0, 4.0, 6.25, 15.0]:
			for z: float in [-15.0, -4.0, 0.0, 4.0, 15.0]:
				var item: Dictionary = {"position": [x, 0, z], "size": [2, 2, 2], "shape": shape}
				assert_eq(
					field._pool_conflicts(1.25, item),
					PondShape.conflicts(source["pool"], 1.25, item)
				)


func test_pond_circle_fallback_preserves_exact_conflicts() -> void:
	var source: Dictionary = ArtLayout.create()
	source["pool"] = {"center": [0, 0], "radius": 4, "water_y": 0}
	var field: TerrainField = TerrainField.new(source)
	for x: float in [0.0, 4.0, 6.0, 20.0]:
		var item: Dictionary = {"position": [x, 0, 0], "size": [2, 2, 2], "shape": "rect"}
		assert_eq(
			field._pool_conflicts(1.25, item), PondShape.conflicts(source["pool"], 1.25, item)
		)


func test_building_index_matches_exhaustive_queries_across_cell_boundaries() -> void:
	var source: Dictionary = StressLayout.create()
	var buildings: BuildingIndex = BuildingIndex.new(source["buildings"])
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 90127
	for index: int in range(600):
		var p: Vector2 = Vector2(rng.randf_range(-32, 32), rng.randf_range(-32, 32))
		var radius: float = rng.randf_range(0, 4)
		var expected: bool = false
		for home: Dictionary in source["buildings"]:
			expected = expected or TerrainField.conflicts(p, radius, home)
		assert_eq(buildings.conflicts(p, radius), expected)
	for p: Vector2 in [Vector2(-8, -8), Vector2.ZERO, Vector2(8, 8)]:
		assert_eq(buildings.conflicts(p, 40), true)


func test_indexed_vegetation_clearance_and_reconcile_match_exhaustive_source() -> void:
	var source: Dictionary = ArtLayout.create()
	var buildings: BuildingIndex = BuildingIndex.new(source["buildings"])
	for z: int in range(-24, 25, 2):
		for x: int in range(-24, 25, 2):
			var p: Vector2 = Vector2(x, z)
			assert_eq(
				VegetationBrush.geometry_clear(source, p, buildings),
				VegetationBrush.geometry_clear(source, p)
			)
	var expected: Dictionary = source.duplicate(true)
	for i: int in range(expected["instances"].size() - 1, -1, -1):
		var item: Dictionary = expected["instances"][i]
		if item["source"] != "brush" or item["locked"] or not item.has("category"):
			continue
		var point: Vector2 = Vector2(item["position"][0], item["position"][2])
		if not VegetationBrush.geometry_clear(expected, point):
			expected["instances"].remove_at(i)
	assert_eq_deep(VegetationBrush.reconcile(source), expected)
	var invalid: Dictionary = source.duplicate(true)
	var item: Dictionary = invalid["instances"][0]
	item["position"] = invalid["buildings"][0]["position"].duplicate()
	assert_eq(WorldDocument.validate(invalid), "instance_building_collision")
