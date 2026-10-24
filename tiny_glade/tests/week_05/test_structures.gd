extends GutTest


func pond() -> Dictionary:
	return PondShape.draw(WorldDocument.new().snapshot(), [[-2, -2], [2, -2], [2, 2], [-2, 2]])


func bridge(world: Dictionary) -> Dictionary:
	return GardenStructures.allocate(world, "bridge", Vector2(0, -2.5), Vector2(0, 2.5))


func test_bridge_valid_two_banks_and_geometry_above_water() -> void:
	var world: Dictionary = pond()
	var item: Dictionary = bridge(world)
	assert_eq(GardenStructures.status(world, item), "")
	assert_eq(WorldDocument.validate(world), "")
	var result: Dictionary = GardenStructures.build(world)
	assert_true(result["issues"].is_empty())
	assert_gt(result["bridge"][0][Mesh.ARRAY_VERTEX].size(), 0)
	var deck_found: bool = false
	for p: Vector3 in result["bridge"][0][Mesh.ARRAY_VERTEX]:
		deck_found = deck_found or p.y > world["pool"]["water_y"] + 0.1
	assert_true(deck_found)


func test_bridge_range_limits() -> void:
	var world: Dictionary = pond()
	for length: float in [1.49, 6.01]:
		var item: Dictionary = GardenStructures.allocate(
			world, "bridge", Vector2(0, -length / 2), Vector2(0, length / 2)
		)
		assert_eq(GardenStructures.status(world, item), "bridge_length_1_5_to_6")


func test_bridge_head_inside_water_and_missing_crossing_rejected() -> void:
	var world: Dictionary = pond()
	var item: Dictionary = GardenStructures.allocate(world, "bridge", Vector2.ZERO, Vector2(0, 2.5))
	assert_false(GardenStructures.status(world, item).is_empty())
	item = GardenStructures.allocate(world, "bridge", Vector2(8, -2), Vector2(8, 2))
	assert_eq(GardenStructures.status(world, item), "bridge_adjust_heads")


func test_new_invalid_bridge_rejected_at_transaction_boundary() -> void:
	var doc: WorldDocument = WorldDocument.new()
	doc.state = pond()
	var edit: EditSession = EditSession.new(doc)
	var draft: Dictionary = doc.snapshot()
	GardenStructures.allocate(draft, "bridge", Vector2.ZERO, Vector2.ONE)
	assert_false(edit.commit_snapshot(draft, "bad")["ok"])
	assert_false(edit.reserve_commit(draft, "bad")["ok"])
	assert_true(doc.state["bridges"].is_empty())
	edit.dispose()


func test_shore_invalidates_bridge_retains_id_and_undo_restores_together() -> void:
	var doc: WorldDocument = WorldDocument.new()
	doc.state = pond()
	var item: Dictionary = bridge(doc.state)
	var id_value: String = item["id"]
	var edit: EditSession = EditSession.new(doc)
	var old: Dictionary = doc.snapshot()
	var changed: Dictionary = PondShape.draw(old, [[-3, -3], [3, -3], [3, 3], [-3, 3]])
	assert_true(edit.commit_snapshot(changed, "shore")["ok"])
	assert_eq(doc.state["bridges"][0]["id"], id_value)
	assert_eq(GardenStructures.build(doc.state)["issues"][0]["error"], "bridge_adjust_heads")
	assert_gt(GardenStructures.build(doc.state)["bridge"][0][Mesh.ARRAY_VERTEX].size(), 0)
	assert_true(edit.request_undo()["ok"])
	assert_eq_deep(doc.state["pool"], old["pool"])
	assert_eq(GardenStructures.status(doc.state, doc.state["bridges"][0]), "")
	assert_true(edit.request_redo()["ok"])
	assert_eq(GardenStructures.build(doc.state)["issues"].size(), 1)
	edit.dispose()


func test_delete_pond_keeps_invalid_bridge_visible() -> void:
	var world: Dictionary = pond()
	bridge(world)
	world["pool"] = {}
	assert_eq(WorldDocument.validate(world), "")
	assert_eq(GardenStructures.build(world)["issues"][0]["error"], "bridge_missing_pond")
	assert_gt(GardenStructures.build(world)["bridge"][0][Mesh.ARRAY_VERTEX].size(), 0)


func test_bridge_excessive_height_difference_rejected() -> void:
	var world: Dictionary = pond()
	var item: Dictionary = GardenStructures.allocate(world, "bridge", Vector2(0, -3), Vector2(0, 3))
	world["terrain"]["height_deltas"] = [[64, 70, 0.7]]
	assert_eq(GardenStructures.status(world, item), "bridge_height_0_5")


func test_stair_height_limits_and_continuous_treads() -> void:
	var world: Dictionary = WorldDocument.new().snapshot()
	world = TerrainEdits.stroke(world, Vector2(2, 0), "raise", 1.1, 0.6)
	var item: Dictionary = GardenStructures.allocate(world, "stair", Vector2.ZERO, Vector2(2, 0))
	assert_eq(GardenStructures.status(world, item), "")
	var arrays: Array = GardenStructures.build(world)["stair"][0]
	assert_eq(arrays[Mesh.ARRAY_VERTEX].size(), 4 * 36)
	item["width"] = 2.1
	assert_eq(WorldDocument.validate(world), "structure_width")


func test_flat_or_tall_stairs_rejected_preserving_existing() -> void:
	var world: Dictionary = WorldDocument.new().snapshot()
	var item: Dictionary = GardenStructures.allocate(world, "stair", Vector2.ZERO, Vector2(2, 0))
	assert_eq(GardenStructures.status(world, item), "stair_height_0_15_to_0_9")
	world = TerrainEdits.stroke(world, Vector2(2, 0), "raise", 1.1, 1.1)
	assert_eq(GardenStructures.status(world, item), "stair_height_0_15_to_0_9")


func test_fifty_mixed_transactions_undo_redo_reproduce_all_sources() -> void:
	var doc: WorldDocument = WorldDocument.new("mixed-w05")
	var home: Dictionary = WorldDocument.allocate_building(
		doc.state, Vector3(-12, 0, -12), Vector3(5, 3, 5)
	)
	home["openings"] = [
		{
			"kind": "rect",
			"center": 0.5,
			"width": 0.8,
			"height": 1.0,
			"sill": 1.0,
			"source": "manual",
			"locked": true
		}
	]
	var edit: EditSession = EditSession.new(doc)
	for i: int in range(50):
		var draft: Dictionary = doc.snapshot()
		match i % 5:
			0:
				var item: Dictionary = InstanceEdits.allocate(draft, Vector3(10 + i % 3, 0, 10))
				item["asset_id"] = "PROP-06"
			1:
				draft["environment"]["dusk"] = not draft["environment"]["dusk"]
			2:
				FenceGeometry.allocate(draft, [[-12, 0, i * 0.1], [-8, 0, i * 0.1]])
			3:
				draft = TerrainEdits.stroke(draft, Vector2(16, -16), "raise", 1.5, 0.05)
			4:
				draft = PondShape.draw(draft, [[-3, -2], [3 + i * 0.01, -2], [3, 2], [-3, 2]])
		if i == 5:
			InstanceEdits.brush(draft, Vector2(14, 14), {})
		if i == 11:
			GardenStructures.allocate(draft, "bridge", Vector2(0, -2.6), Vector2(0, 2.6))
		if i == 40:
			draft["pool"] = {}
		if i == 25:
			BuildingEdits.remove(draft, [home["id"]])
			assert_eq(draft["attachments"].size(), 1)
		if i == 30:
			var restored: Dictionary = WorldDocument.allocate_building(
				draft, Vector3(-12, 0, -12), Vector3(5, 3, 5)
			)
			assert_true(
				BuildingEdits.reattach(draft, draft["attachments"][0]["id"], restored["id"])
			)
		assert_true(edit.commit_snapshot(draft, "mixed")["ok"])
	var final: Dictionary = doc.snapshot()
	assert_eq(edit.history_count(), 50)
	for i: int in range(50):
		assert_true(edit.request_undo()["ok"])
	assert_true(doc.state["instances"].is_empty())
	for i: int in range(50):
		assert_true(edit.request_redo()["ok"])
	final["revision"] = doc.state["revision"]
	assert_eq_deep(doc.state, final)
	edit.dispose()


func test_stairs_snap_to_manual_door_floor_and_keep_body_outside_house() -> void:
	var world: Dictionary = WorldDocument.new().snapshot()
	var home: Dictionary = WorldDocument.allocate_building(
		world, Vector3(0, 0.6, 0), Vector3(5, 3, 5)
	)
	home["openings"] = [
		{"kind": "arch", "center": 0.5, "height": 2.05, "width": 1.1, "source": "manual"}
	]
	var item: Dictionary = GardenStructures.allocate(
		world, "stair", Vector2(0, 4.5), Vector2(0, 2.6)
	)
	assert_eq(GardenStructures.status(world, item), "")
	assert_almost_eq(item["heights"][1], 0.6, 0.00001)
	assert_eq(WorldDocument.validate(world), "")


func test_bridge_deck_ramps_join_uneven_heads() -> void:
	assert_almost_eq(GardenStructures.deck_height(0, 0.4, 0.4, 5, 0) + 0.06, 0.03, 0.00001)
	assert_almost_eq(GardenStructures.deck_height(0, 0.4, 0.4, 5, 1) + 0.06, 0.43, 0.00001)
	assert_gt(GardenStructures.deck_height(0, 0.4, 0.4, 5, 0.5), 0.3)


func test_serialized_pool_bounds_and_collapsed_closed_fence_fail_safely() -> void:
	var world: Dictionary = pond()
	world["pool"]["radius"] = 1e25
	assert_eq(WorldDocument.validate(world), "invalid_pool")
	world = pond()
	world["pool"]["radius"] = 1.0
	assert_eq(WorldDocument.validate(world), "invalid_pool_bounds")
	world = WorldDocument.new().snapshot()
	FenceGeometry.allocate(world, [[0, 0, 0], [3, 0, 0], [0, 0, 0]])
	world["fences"][0]["closed"] = true
	assert_eq(WorldDocument.validate(world), "invalid_fence_points")
