extends GutTest


func test_new_document_has_all_required_source_collections() -> void:
	var doc: WorldDocument = WorldDocument.new()
	assert_eq(WorldDocument.validate(doc.snapshot()), "")
	for collection: String in WorldDocument.COLLECTIONS:
		assert_true(doc.state[collection] is Array)


func test_snapshot_is_detached_from_live_source() -> void:
	var doc: WorldDocument = WorldDocument.new()
	var copy: Dictionary = doc.snapshot()
	copy["terrain"]["height_deltas"].append([1, 2, 0.5])
	assert_eq(doc.state["terrain"]["height_deltas"].size(), 0)


func test_identity_is_reproducible_without_consuming_cancelled_sequence() -> void:
	var doc: WorldDocument = WorldDocument.new("seed-18446744073709551615")
	var a: Dictionary = doc.snapshot()
	var b: Dictionary = doc.snapshot()
	var one: Dictionary = WorldDocument.allocate_building(a, Vector3.ZERO, Vector3(4, 3, 4))
	var two: Dictionary = WorldDocument.allocate_building(b, Vector3.ZERO, Vector3(4, 3, 4))
	assert_eq(one["id"], two["id"])
	assert_eq(one["seed"], two["seed"])
	assert_eq(doc.state["next_id"], 1)


func test_duplicate_ids_and_out_of_plot_are_rejected() -> void:
	var draft: Dictionary = WorldDocument.new().snapshot()
	var record: Dictionary = WorldDocument.allocate_building(draft, Vector3.ZERO, Vector3(4, 3, 4))
	draft["buildings"].append(record.duplicate(true))
	assert_eq(WorldDocument.validate(draft), "duplicate_id")
	draft["buildings"].pop_back()
	draft["buildings"][0]["position"][0] = 24.0
	assert_eq(WorldDocument.validate(draft), "outside_plot")


func test_corrupt_state_never_accepts_objects_or_nonfinite_numbers() -> void:
	var draft: Dictionary = WorldDocument.new().snapshot()
	draft["instances"].append(RefCounted.new())
	assert_eq(WorldDocument.validate(draft), "non_serializable_state")
	draft["instances"] = [NAN]
	assert_eq(WorldDocument.validate(draft), "non_serializable_state")


func test_bad_schema_seed_environment_and_dimensions_are_rejected() -> void:
	var doc: WorldDocument = WorldDocument.new()
	var draft: Dictionary = doc.snapshot()
	draft["schema_version"] = 999
	assert_eq(WorldDocument.validate(draft), "unsupported_schema")
	draft = doc.snapshot()
	draft["environment"] = {}
	assert_eq(WorldDocument.validate(draft), "invalid_environment")
	draft = doc.snapshot()
	WorldDocument.allocate_building(draft, Vector3.ZERO, Vector3(0.1, 3, 4))
	assert_eq(WorldDocument.validate(draft), "invalid_width")


func test_axis_aligned_side_contact_is_legal_but_intersection_is_not() -> void:
	var draft: Dictionary = WorldDocument.new().snapshot()
	WorldDocument.allocate_building(draft, Vector3.ZERO, Vector3(4, 3, 4))
	WorldDocument.allocate_building(draft, Vector3(4, 0, 0), Vector3(4, 3, 4))
	assert_eq(WorldDocument.validate(draft), "")
	draft["buildings"][1]["position"][0] = 3.0
	assert_eq(WorldDocument.validate(draft), "building_overlap")


func test_circle_tangency_and_circle_rectangle_overlap() -> void:
	var draft: Dictionary = WorldDocument.new().snapshot()
	WorldDocument.allocate_building(draft, Vector3.ZERO, Vector3(4, 3, 4), "round")
	WorldDocument.allocate_building(draft, Vector3(4, 0, 0), Vector3(4, 3, 4), "round")
	assert_eq(WorldDocument.validate(draft), "")
	draft["buildings"][1]["position"][0] = 3.5
	assert_eq(WorldDocument.validate(draft), "building_overlap")
	draft["buildings"][1]["shape"] = "rect"
	assert_eq(WorldDocument.validate(draft), "building_overlap")


func test_malformed_openings_are_rejected_before_mesh_preparation() -> void:
	var draft: Dictionary = WorldDocument.new().snapshot()
	var building: Dictionary = WorldDocument.allocate_building(
		draft, Vector3.ZERO, Vector3(4, 3, 4)
	)
	for malformed: Variant in [null, [3], [{"kind": "arch", "width": "bad"}]]:
		building["openings"] = malformed
		assert_eq(WorldDocument.validate(draft), "invalid_openings")
	building["openings"] = [{"kind": "rect", "center": 0.5, "width": 1, "height": 4}]
	assert_eq(WorldDocument.validate(draft), "invalid_openings")
	assert_true(SaveCodec.encode(draft).is_empty())


func test_malformed_revision_wind_and_height_deltas_are_rejected() -> void:
	var draft: Dictionary = WorldDocument.new().snapshot()
	draft["revision"] = "broken"
	assert_eq(WorldDocument.validate(draft), "invalid_revision")
	draft["revision"] = 0
	draft["environment"]["wind_strength"] = "broken"
	assert_eq(WorldDocument.validate(draft), "invalid_environment")
	draft["environment"]["wind_strength"] = 0.5
	draft["terrain"]["height_deltas"] = [[0, "broken", 0.5]]
	assert_eq(WorldDocument.validate(draft), "invalid_heights")
