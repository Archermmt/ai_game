extends GutTest

const HeightIndex = preload("res://core/rebuild/height_delta_index.gd")
const RESULT_FIELDS: Array[String] = [
	"snapshot",
	"versions",
	"building_arrays",
	"supports",
	"terrain_arrays",
	"path_arrays",
	"fence_arrays",
	"water_arrays",
	"structures",
	"poses"
]


func _shuffled_source(spacing: float = 0.5) -> Dictionary:
	var source: Dictionary = WorldDocument.new("perf02-height-index").snapshot()
	source["terrain"]["spacing"] = spacing
	source["terrain"]["height_deltas"] = [
		[128, 128, 0.123456789012345],
		[64, 64, -0.98765432109876],
		[0, 0, 0.000000123456789],
		[48, 64, 0.42],
		[64, 48, -0.37],
		[16, 16, 0.27],
		[63, 63, 0.19],
		[65, 65, 0.81],
		[80, 64, -0.61]
	]
	return source


func _reference_entries(source: Dictionary, region: Rect2) -> Array:
	var entries: Array = []
	for entry: Array in source["terrain"]["height_deltas"]:
		var p: Vector2 = (
			Vector2(entry[0], entry[1]) * float(source["terrain"].get("spacing", 0.5))
			- Vector2.ONE * 32
		)
		if (
			p.x >= region.position.x
			and p.y >= region.position.y
			and p.x <= region.end.x
			and p.y <= region.end.y
		):
			entries.append(entry)
	return entries


func _assert_keys(source: Dictionary, region: Rect2, origin: Vector2) -> void:
	var before: Dictionary = source.duplicate(true)
	var index: HeightIndex = HeightIndex.new(source)
	assert_eq(DirtyGraph.field_key(source, region, index), DirtyGraph.field_key(source, region))
	assert_eq(
		TerrainChunks.signature(source, origin, index), TerrainChunks.signature(source, origin)
	)
	assert_eq_deep(source, before)


func _reference_versions(source: Dictionary) -> Dictionary:
	var values: Dictionary = {}
	for home: Dictionary in source["buildings"]:
		var region: Rect2 = DirtyGraph.bounds(home)
		values["building:" + home["id"]] = DirtyGraph.key(
			[home, DirtyGraph.nearby(source["buildings"], region)]
		)
		values["support:" + home["id"]] = DirtyGraph.key(
			[home, DirtyGraph.field_key(source, region)]
		)
	for z: int in range(-32, 32, 8):
		for x: int in range(-32, 32, 8):
			values["terrain:%d" % (values.size() - source["buildings"].size() * 2)] = (
				TerrainChunks.signature(source, Vector2(x, z))
			)
	var paths: Array = source["paths"]
	var fences: Array = source.get("fences", [])
	values["path"] = DirtyGraph.key(
		[
			paths,
			DirtyGraph.nearby(source["buildings"], DirtyGraph.union(paths)),
			DirtyGraph.field_key(source, DirtyGraph.union(paths))
		]
	)
	values["fence"] = DirtyGraph.key(
		[
			fences,
			DirtyGraph.nearby(paths, DirtyGraph.union(fences)),
			DirtyGraph.field_key(source, DirtyGraph.union(fences))
		]
	)
	values["water"] = DirtyGraph.key(source["pool"])
	for collection: String in ["bridges", "stairs"]:
		for item: Dictionary in source.get(collection, []):
			var region: Rect2 = DirtyGraph.bounds(item)
			values["structure:" + item["id"]] = DirtyGraph.key(
				[
					item,
					DirtyGraph.nearby(source["buildings"], region),
					source["pool"],
					DirtyGraph.field_key(source, region)
				]
			)
	for item: Dictionary in source["instances"]:
		values["instance:" + item["id"]] = DirtyGraph.key(
			[
				item,
				LocalRebuild._support_chain(source, item),
				DirtyGraph.field_key(source, DirtyGraph.bounds(item))
			]
		)
	return values


func test_queries_preserve_unsorted_source_order_and_height_precision() -> void:
	var source: Dictionary = _shuffled_source()
	var index: HeightIndex = HeightIndex.new(source)
	var region: Rect2 = Rect2(Vector2(-32, -32), Vector2(64, 64))
	assert_eq_deep(index.entries_within(region), source["terrain"]["height_deltas"])
	assert_eq(
		JSON.stringify(index.entries_within(region), "", true, true),
		JSON.stringify(source["terrain"]["height_deltas"], "", true, true)
	)
	_assert_keys(source, region, Vector2(-8, -8))


func test_queries_match_closed_edges_zero_area_negative_and_bucket_boundaries() -> void:
	var source: Dictionary = _shuffled_source()
	var index: HeightIndex = HeightIndex.new(source)
	for region: Rect2 in [
		Rect2(Vector2(-8, -8), Vector2(16, 16)),
		Rect2(Vector2(-32, -32), Vector2.ZERO),
		Rect2(Vector2(-8, 0), Vector2.ZERO),
		Rect2(Vector2(0, -8), Vector2.ZERO),
		Rect2(Vector2(-0.5, -0.5), Vector2.ONE),
		Rect2(Vector2(8, 0), Vector2(-8, 8)),
		Rect2(Vector2(-32.001, -32.001), Vector2(0.0001, 0.0001))
	]:
		assert_eq_deep(index.entries_within(region), _reference_entries(source, region))


func test_empty_huge_and_distant_queries_do_not_iterate_unbounded_empty_space() -> void:
	var source: Dictionary = WorldDocument.new().snapshot()
	var huge: Rect2 = Rect2(Vector2.ONE * -1e12, Vector2.ONE * 2e12)
	assert_eq_deep(HeightIndex.new(source).entries_within(huge), [])
	source = _shuffled_source()
	var index: HeightIndex = HeightIndex.new(source)
	assert_eq_deep(index.entries_within(huge), source["terrain"]["height_deltas"])
	assert_eq_deep(index.entries_within(Rect2(Vector2.ONE * 1e12, Vector2.ONE * 1e12)), [])
	_assert_keys(source, huge, Vector2.ONE * 1e12)


func test_signatures_match_for_both_spacings_halos_and_seed_profile_changes() -> void:
	for spacing: float in [0.25, 0.5]:
		var source: Dictionary = _shuffled_source(spacing)
		for profile: String in ["flat", "forest_slope_v1"]:
			source["terrain"]["base_profile"] = profile
			source["world_seed"] += ":next"
			for origin: Vector2 in [
				Vector2(-32, -32), Vector2(-16, -16), Vector2(-8, -8), Vector2.ZERO, Vector2(24, 24)
			]:
				_assert_keys(source, Rect2(origin, Vector2(0.5, 0.25)), origin)
		# Exactly on the outer halo edge contributes, one cell beyond does not.
		source["terrain"]["height_deltas"] = [
			[int(32 / spacing), int(32 / spacing), 0.1234567890123]
		]
		var edge: Rect2 = Rect2(Vector2.ONE * spacing * 2, Vector2.ZERO)
		var index: HeightIndex = HeightIndex.new(source)
		assert_eq(DirtyGraph.field_key(source, edge, index), DirtyGraph.field_key(source, edge))
		assert_true(DirtyGraph.field_key(source, edge, index).contains("0.1234567890123"))
		var outside: Rect2 = Rect2(Vector2.ONE * spacing * 3, Vector2.ZERO)
		assert_false(DirtyGraph.field_key(source, outside, index).contains("0.1234567890123"))


func test_circle_and_outline_pond_signatures_keep_exact_influence_boundary() -> void:
	for outline: bool in [false, true]:
		var source: Dictionary = _shuffled_source()
		source["pool"] = {"center": [-8.0, -8.0], "radius": 3.0, "water_y": -0.15}
		if outline:
			source["pool"]["outline"] = [[-10, -10], [-6, -10], [-6, -6], [-10, -6]]
		for offset: float in [0.0, 3.75, 4.75, 4.7501, 16.0]:
			var point: Vector2 = Vector2(-8 + offset, -8)
			_assert_keys(source, Rect2(point, Vector2.ZERO), point)


func test_seeded_random_regions_match_exhaustive_entries_and_signatures() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 728905
	for spacing: float in [0.25, 0.5]:
		var source: Dictionary = WorldDocument.new("perf02-random-height").snapshot()
		source["terrain"]["spacing"] = spacing
		for n: int in range(180):
			source["terrain"]["height_deltas"].append(
				[
					rng.randi_range(0, int(64 / spacing)),
					rng.randi_range(0, int(64 / spacing)),
					rng.randf_range(-0.8, 0.8)
				]
			)
		var before: Dictionary = source.duplicate(true)
		var index: HeightIndex = HeightIndex.new(source)
		for n: int in range(100):
			var origin: Vector2 = Vector2(rng.randf_range(-40, 40), rng.randf_range(-40, 40))
			var region: Rect2 = Rect2(
				origin, Vector2(rng.randf_range(0, 20), rng.randf_range(0, 20))
			)
			assert_eq_deep(index.entries_within(region), _reference_entries(source, region))
			assert_eq(
				DirtyGraph.field_key(source, region, index), DirtyGraph.field_key(source, region)
			)
			assert_eq(
				TerrainChunks.signature(source, origin, index),
				TerrainChunks.signature(source, origin)
			)
		assert_eq_deep(source, before)


func test_support_chain_recursion_uses_identical_parent_height_signatures() -> void:
	var source: Dictionary = WorldDocument.new("perf02-support-height").snapshot()
	var parent: Dictionary = InstanceEdits.allocate(source, Vector3(-8, 0, -8))
	parent["asset_id"] = "PROP-05"
	var child: Dictionary = InstanceEdits.allocate(source, Vector3(-8, 0, -8))
	child["asset_id"] = "PROP-05"
	child["support_id"] = parent["id"]
	var lamp: Dictionary = InstanceEdits.allocate(source, Vector3(-8, 0, -8))
	lamp["asset_id"] = "PROP-08"
	lamp["support_id"] = child["id"]
	source = TerrainField.brush(source, Vector2(-8, -8), 0.03)
	assert_eq(WorldDocument.validate(source), "")
	var index: HeightIndex = HeightIndex.new(source)
	assert_eq_deep(
		LocalRebuild._support_chain(source, lamp, 0, index),
		LocalRebuild._support_chain(source, lamp)
	)
	var result: Dictionary = LocalRebuild.evaluate(source, {})
	assert_true(result["ok"])
	assert_eq_deep(result["versions"], _reference_versions(source))


func test_full_capacity_large_brush_then_undo_matches_all_fresh_geometry_and_reference_keys(
) -> void:
	var initial: Dictionary = StressLayout.create()
	var cache: Dictionary = {}
	assert_true(LocalRebuild.evaluate(initial, cache)["ok"])
	var changed: Dictionary = TerrainField.brush(initial, Vector2(12, 8), 0.02, 9.0)
	for source: Dictionary in [changed, initial]:
		var before: Dictionary = source.duplicate(true)
		assert_eq(WorldDocument.validate(source), "")
		var cached: Dictionary = LocalRebuild.evaluate(source, cache)
		var fresh: Dictionary = LocalRebuild.evaluate(source, {})
		assert_true(cached["ok"])
		assert_eq_deep(cached["versions"], _reference_versions(source))
		for key: String in RESULT_FIELDS:
			assert_eq_deep(cached[key], fresh[key])
		assert_eq_deep(source, before)


func test_indexed_rebuild_still_rejects_malformed_and_duplicate_height_entries() -> void:
	var source: Dictionary = WorldDocument.new().snapshot()
	source["terrain"]["height_deltas"] = [[64, 64, 0.1], [64, 64, 0.2]]
	assert_eq(LocalRebuild.evaluate(source, {})["error"], "invalid_height_index")
	source["terrain"]["height_deltas"] = [[64, 64]]
	assert_eq(LocalRebuild.evaluate(source, {})["error"], "invalid_heights")
