extends GutTest


func _source(shape: String = "rect") -> Dictionary:
	var source: Dictionary = WorldDocument.new("ux03-data").snapshot()
	WorldDocument.allocate_building(source, Vector3.ZERO, Vector3(6, 3.5, 6), shape)
	return source


func _opening(source: Dictionary) -> Dictionary:
	DoorRules.manual_opening(source, source["buildings"][0]["id"], Vector2(0, 3), 3)
	return {
		"family": "opening",
		"parent": source["buildings"][0]["id"],
		"attachment_id": source["buildings"][0]["openings"][0]["attachment_id"]
	}


func test_legacy_roof_defaults_and_flat_to_pitched_geometry() -> void:
	for shape: String in ["rect", "round"]:
		var source: Dictionary = _source(shape)
		var home: Dictionary = source["buildings"][0]
		assert_almost_eq(RoofProfile.rise(home), 6 * (0.48 if shape == "round" else 0.38), 0.0001)
		var before: Dictionary = source.duplicate(true)
		var target: Dictionary = {"family": "house", "id": home["id"]}
		var flat: Dictionary = SurfaceEditData.transform(source, target, "roof", Vector3(-10, 0, 0))
		assert_eq(RoofProfile.rise(flat["buildings"][0]), 0.0)
		var pitched: Dictionary = SurfaceEditData.transform(flat, target, "roof", Vector3(2, 0, 0))
		assert_eq(RoofProfile.rise(pitched["buildings"][0]), 2.0)
		assert_gt(
			BuildingGeometry.build(pitched["buildings"][0]).get_aabb().size.y,
			BuildingGeometry.build(flat["buildings"][0]).get_aabb().size.y + 1
		)
		assert_eq_deep(source, before)


func test_roof_validation_rejects_out_of_range_and_non_number() -> void:
	var source: Dictionary = _source()
	for value: Variant in [-1, 6.1, "bad"]:
		source["buildings"][0]["roof_rise"] = value
		assert_eq(WorldDocument.validate(source), "invalid_roof_rise")


func test_roof_survives_save_and_house_copy() -> void:
	var source: Dictionary = _source()
	var home: Dictionary = source["buildings"][0]
	home["roof_rise"] = 0.0
	var loaded: Dictionary = SceneSave.decode(SceneSave.encode(source))
	assert_true(loaded["ok"])
	assert_eq(RoofProfile.rise(loaded["snapshot"]["buildings"][0]), 0.0)
	var copy: Dictionary = DirectEditData.clone(source, home["id"], true)
	assert_eq(copy["source"]["buildings"][1]["roof_rise"], 0.0)


func test_window_move_and_resize_preserve_identity_and_wall_holes() -> void:
	var source: Dictionary = _source()
	var target: Dictionary = _opening(source)
	var before: Dictionary = source.duplicate(true)
	var moved: Dictionary = SurfaceEditData.transform(source, target, "move", Vector3(0.4, 0.2, 0))
	var changed: Dictionary = SurfaceEditData.resolve(moved, target)
	assert_almost_eq(changed["sill"], 1.2, 0.0001)
	assert_eq(changed["attachment_id"], target["attachment_id"])
	assert_ne(changed["center"], source["buildings"][0]["openings"][0]["center"])
	var widened: Dictionary = SurfaceEditData.transform(moved, target, "width", Vector3(0.3, 0, 0))
	assert_eq(SurfaceEditData.issue(source, widened), "")
	assert_almost_eq(SurfaceEditData.resolve(widened, target)["width"], 1.2, 0.0001)
	assert_eq_deep(source, before)


func test_door_stays_grounded_and_round_wall_window_moves_on_arc() -> void:
	var source: Dictionary = _source("round")
	DoorRules.manual_opening(source, source["buildings"][0]["id"], Vector2(3, 0), 0)
	var target: Dictionary = {
		"family": "opening", "parent": source["buildings"][0]["id"], "index": 0
	}
	var moved: Dictionary = SurfaceEditData.transform(source, target, "move", Vector3(0, 0.8, 0.5))
	assert_eq(SurfaceEditData.resolve(moved, target)["sill"], 0.0)
	assert_ne(
		SurfaceEditData.resolve(moved, target)["center"],
		source["buildings"][0]["openings"][0]["center"]
	)
	assert_eq(WorldDocument.validate(moved), "")


func test_automatic_door_converts_only_after_actual_drag() -> void:
	var source: Dictionary = _source()
	var target: Dictionary = _opening(source)
	var item: Dictionary = SurfaceEditData.resolve(source, target)
	item.erase("attachment_id")
	item["source"] = "auto_path"
	item["source_paths"] = ["old-path"]
	target.erase("attachment_id")
	target["index"] = 0
	# No-op stays byte-identical; reconcile must not remove a synthetic automatic door.
	assert_eq_deep(SurfaceEditData.transform(source, target, "move", Vector3.ZERO), source)
	var changed: Dictionary = SurfaceEditData.transform(source, target, "width", Vector3(0.1, 0, 0))
	item = changed["buildings"][0]["openings"][0]
	assert_eq(item["source"], "manual")
	assert_true(item.has("attachment_id"))
	assert_false(item.has("source_paths"))


func test_opening_conflict_is_rejected_without_mutating_source() -> void:
	var source: Dictionary = _source()
	var target: Dictionary = _opening(source)
	var before: Dictionary = source.duplicate(true)
	var invalid: Dictionary = SurfaceEditData.transform(source, target, "move", Vector3(3, 0, 0))
	assert_ne(SurfaceEditData.issue(source, invalid), "")
	assert_eq_deep(source, before)


func test_bridge_endpoint_changes_keep_other_head_and_reject_illegal_span() -> void:
	var source: Dictionary = PondShape.draw(
		WorldDocument.new("ux03-bridge").snapshot(), [[-2, -2], [2, -2], [2, 2], [-2, 2]]
	)
	var item: Dictionary = GardenStructures.allocate(
		source, "bridge", Vector2(-2.5, 0), Vector2(2.5, 0)
	)
	var target: Dictionary = {"family": "bridge", "id": item["id"]}
	var changed: Dictionary = SurfaceEditData.transform(
		source, target, "end_a", Vector3(-0.2, 0, 0)
	)
	assert_eq(changed["bridges"][0]["b"], item["b"])
	assert_eq(SurfaceEditData.issue(source, changed), "")
	var invalid: Dictionary = SurfaceEditData.transform(source, target, "end_a", Vector3(-4, 0, 0))
	assert_eq(SurfaceEditData.issue(source, invalid), "bridge_length_1_5_to_6")


func test_picker_prioritizes_opening_over_parent_and_roof_over_wall() -> void:
	var source: Dictionary = _source()
	_opening(source)
	var hit: Dictionary = SurfacePicker.pick(source, Vector3(0, 1.4, 12), Vector3.FORWARD)
	assert_eq(hit["family"], "opening")
	hit = SurfacePicker.pick(source, Vector3(0, 10, 0), Vector3.DOWN)
	assert_eq(hit["family"], "house")
	assert_eq(hit["zone"], "roof")


func test_picker_does_not_select_hidden_window_or_round_box_corner() -> void:
	var source: Dictionary = _source("round")
	_opening(source)
	var hit: Dictionary = SurfacePicker.pick(source, Vector3(2.9, 1, 12), Vector3.FORWARD)
	assert_eq(hit["family"], "house")
	assert_ne(hit.get("zone", ""), "roof")
	assert_true(SurfacePicker.pick(source, Vector3(4, 1, 12), Vector3.FORWARD).is_empty())


func test_automatic_opening_identity_survives_reconcile_reordering() -> void:
	var source: Dictionary = _source()
	var home: Dictionary = source["buildings"][0]
	for center: float in [0.2, 0.5, 0.8]:
		home["openings"].append(
			{
				"kind": "rect",
				"width": 0.7,
				"height": 0.9,
				"sill": 1.0,
				"center": center,
				"facade": 0,
				"source": "manual" if center == 0.5 else "auto_path"
			}
		)
	var target: Dictionary = {"family": "opening", "parent": home["id"], "index": 2}
	var draft: Dictionary = SurfaceEditData.transform(source, target, "width", Vector3(0.1, 0, 0))
	var identity: Dictionary = SurfaceEditData.identity_target(source, target)
	var changed: Dictionary = SurfaceEditData.resolve(draft, identity)
	assert_false(changed.is_empty())
	assert_almost_eq(changed["width"], 0.8, 0.0001)
	assert_eq(changed["center"], 0.8)
	assert_eq(draft["buildings"][0]["openings"].size(), 2)
	assert_eq(WorldDocument.validate(draft), "")
