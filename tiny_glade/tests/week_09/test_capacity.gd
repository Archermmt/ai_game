extends GutTest


func test_full_capacity_exact_counts_and_valid_source() -> void:
	var source: Dictionary = StressLayout.create()
	assert_eq(source["buildings"].size(), 24)
	assert_eq(source["instances"].size(), 1000)
	assert_eq(VegetationBrush.capacity_count(source, "trees"), 80)
	assert_eq(VegetationBrush.capacity_count(source, "plants"), 800)
	assert_eq(source["bridges"].size(), 2)
	assert_false(source["pool"].is_empty())
	for bridge: Dictionary in source["bridges"]:
		assert_eq(GardenStructures.status(source, bridge), "")
	assert_eq(WorldDocument.validate(source), "")
	assert_eq_deep(VegetationBrush.reconcile(source), source)


func test_fixture_is_deterministic_and_reduced_density_keeps_buildings_pond_bridges() -> void:
	assert_eq_deep(StressLayout.create(), StressLayout.create())
	var reduced: Dictionary = StressLayout.create(0.5)
	assert_eq(WorldDocument.validate(reduced), "")
	assert_eq(reduced["buildings"].size(), 24)
	assert_eq(reduced["instances"].size(), 500)
	assert_eq(reduced["bridges"].size(), 2)


func test_full_capacity_roundtrip_and_history_source_budget() -> void:
	var source: Dictionary = StressLayout.create()
	assert_lt(JSON.stringify(source).to_utf8_buffer().size(), EditSession.MAX_SOURCE_BYTES)
	var decoded: Dictionary = SnapshotDto.unpack(SnapshotDto.pack(source, "满容量"))
	assert_true(decoded["ok"])
	assert_eq_deep(decoded["snapshot"], source)


func test_capacity_rejects_1001st_without_source_or_history_change() -> void:
	var document: WorldDocument = WorldDocument.new()
	document.state = StressLayout.create()
	var session: EditSession = EditSession.new(document)
	var before: Dictionary = document.snapshot()
	var draft: Dictionary = document.snapshot()
	InstanceEdits.allocate(draft, Vector3(22, 0, 22))
	assert_false(session.commit_snapshot(draft, "overflow")["ok"])
	assert_eq_deep(document.snapshot(), before)
	assert_eq(session.history_count(), 0)
	session.dispose()


func test_vegetation_budget_excludes_manual_props_and_trees() -> void:
	var source: Dictionary = StressLayout.create(0.5)
	assert_eq(VegetationBrush.capacity_count(source, "trees"), 40)
	assert_eq(VegetationBrush.capacity_count(source, "plants"), 400)
	var visited: Dictionary = {}
	VegetationBrush.paint(source, Vector2(20, 17), "plants", 5, 1, visited)
	assert_gt(source["instances"].size(), 500)
	assert_lte(VegetationBrush.capacity_count(source, "plants"), 800)
	assert_eq(VegetationBrush.capacity_count(source, "trees"), 40)
