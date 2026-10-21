extends GutTest


func test_round_resize_keeps_diameter_linked_and_source_immutable() -> void:
	var source: Dictionary = WorldDocument.new("ux-data").snapshot()
	var home: Dictionary = WorldDocument.allocate_building(
		source, Vector3.ZERO, Vector3(4, 3, 4), "round"
	)
	var before: Dictionary = source.duplicate(true)
	var changed: Dictionary = DirectEditData.transform(
		source, home["id"], true, "width", Vector3(2, 0, 0)
	)
	assert_eq(changed["buildings"][0]["size"], [6.0, 3.0, 6.0])
	assert_eq_deep(source, before)
	assert_eq(WorldDocument.validate(changed), "")


func test_dimension_limits_and_object_seed_are_preserved() -> void:
	var source: Dictionary = WorldDocument.new("ux-data").snapshot()
	var home: Dictionary = WorldDocument.allocate_building(source, Vector3.ZERO, Vector3(4, 3, 4))
	var changed: Dictionary = DirectEditData.transform(
		source, home["id"], true, "height", Vector3(100, 0, 0)
	)
	assert_almost_eq(changed["buildings"][0]["size"][1], 7.2, 0.00001)
	var item: Dictionary = InstanceEdits.allocate(source, Vector3(12, 0, 12))
	item["asset_id"] = "PROP-02"
	changed = DirectEditData.transform(source, item["id"], false, "rotate", Vector3(0.7, 0, 0))
	assert_eq(changed["instances"][0]["seed"], item["seed"])
	assert_almost_eq(changed["instances"][0]["yaw"], 0.7, 0.00001)


func test_copy_uses_fresh_ids_seeds_and_removes_attachment_identity_collisions() -> void:
	var source: Dictionary = WorldDocument.new("ux-data").snapshot()
	var home: Dictionary = WorldDocument.allocate_building(source, Vector3.ZERO, Vector3(4, 3, 4))
	home["openings"] = [
		{
			"kind": "rect",
			"center": 0.5,
			"width": 1.0,
			"height": 1.0,
			"sill": 0.8,
			"source": "manual",
			"attachment_id": "manual-opening"
		}
	]
	var result: Dictionary = DirectEditData.clone(source, home["id"], true)
	assert_ne(result["id"], home["id"])
	assert_ne(result["source"]["buildings"][1]["seed"], home["seed"])
	assert_false(result["source"]["buildings"][1]["openings"][0].has("attachment_id"))
	var changed: Dictionary = DirectEditData.transform(
		result["source"], result["id"], true, "move", Vector3(10, 0, 10)
	)
	assert_eq(WorldDocument.validate(changed), "")
	assert_eq(source["buildings"].size(), 1)


func test_moving_support_rejects_instead_of_discarding_attached_content() -> void:
	var source: Dictionary = WorldDocument.new("ux-support").snapshot()
	var support: Dictionary = InstanceEdits.allocate(source, Vector3.ZERO)
	support["asset_id"] = "PROP-01"
	var child: Dictionary = InstanceEdits.allocate(source, Vector3.ZERO)
	child["asset_id"] = "PROP-07"
	child["support_id"] = support["id"]
	var changed: Dictionary = DirectEditData.transform(
		source, support["id"], false, "move", Vector3(4, 0, 0)
	)
	assert_false(WorldDocument.validate(changed).is_empty())
	assert_eq(changed["instances"].size(), 2)
	assert_eq(child["support_id"], support["id"])


func test_round_wall_target_uses_the_cylinder_instead_of_empty_box_corners() -> void:
	var source: Dictionary = WorldDocument.new().snapshot()
	var home: Dictionary = WorldDocument.allocate_building(
		source, Vector3.ZERO, Vector3(4, 3, 4), "round"
	)
	var point: Variant = DirectEditData.wall_hit(home, Vector3(1.8, 1, 10), Vector3.FORWARD)
	assert_true(point is Vector3)
	assert_almost_eq(Vector2(point.x, point.z).length(), 2.0, 0.00001)
	assert_lt(point.z, 1.0)
	assert_null(DirectEditData.wall_hit(home, Vector3(2.1, 1, 10), Vector3.FORWARD))
