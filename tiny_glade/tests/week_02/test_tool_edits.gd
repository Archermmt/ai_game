extends GutTest

var doc: WorldDocument
var session: EditSession
var tools: WorldTools


func before_each() -> void:
	doc = WorldDocument.new()
	session = EditSession.new(doc)
	tools = WorldTools.new(session)


func after_each() -> void:
	session.dispose()


func test_preview_cancel_does_not_consume_id_or_write_source() -> void:
	var before: Dictionary = doc.snapshot()
	tools.mode = "prop"
	assert_true(tools.begin(Vector3(4, 0, 4)))
	tools.update(Vector3(6, 0, 4))
	assert_eq(session.preview["instances"].size(), 1)
	assert_eq_deep(doc.snapshot(), before)
	session.cancel_gesture()
	assert_eq_deep(doc.snapshot(), before)


func test_brush_many_stamps_is_one_transaction_with_stable_seed_and_unique_cells() -> void:
	tools.mode = "brush"
	assert_true(tools.begin(Vector3.ZERO))
	tools.update(Vector3(1, 0, 0))
	tools.update(Vector3(2, 0, 0))
	var count: int = session.preview["instances"].size()
	assert_gt(count, 9)
	assert_true(session.release_gesture("brush")["ok"])
	assert_eq(session.history_count(), 1)
	var first: Dictionary = doc.snapshot()
	session.request_undo()
	assert_true(doc.state["instances"].is_empty())
	session.request_redo()
	assert_eq_deep(doc.state["instances"], first["instances"])
	var other: Dictionary = WorldDocument.new().snapshot()
	InstanceEdits.brush(other, Vector2.ZERO, {})
	assert_eq_deep(other["instances"][0], first["instances"][0])


func test_erasing_brush_protects_hand_placed_and_manually_adjusted_instances() -> void:
	var draft: Dictionary = doc.snapshot()
	var manual: Dictionary = InstanceEdits.allocate(draft, Vector3.ZERO)
	var brush: Dictionary = InstanceEdits.allocate(draft, Vector3(1, 0, 0), false)
	var edited_id: String = brush["id"]
	InstanceEdits.transform_selection(draft, [edited_id], Vector3.ZERO, 0.2)
	InstanceEdits.allocate(draft, Vector3(0, 0, 1), false)
	InstanceEdits.brush(draft, Vector2.ZERO, {}, true)
	assert_eq(draft["instances"].size(), 2)
	assert_eq(draft["instances"][0]["id"], manual["id"])
	assert_eq(draft["instances"][1]["id"], edited_id)


func test_multi_selection_move_rotate_scale_copy_delete_and_undo() -> void:
	var draft: Dictionary = doc.snapshot()
	InstanceEdits.allocate(draft, Vector3.ZERO)
	InstanceEdits.allocate(draft, Vector3(3, 0, 0))
	session.replace_document(draft)
	tools.mode = "select"
	tools.begin(Vector3.ZERO)
	tools.begin(Vector3(3, 0, 0), true)
	assert_eq(tools.selected.size(), 2)
	tools.mode = "move"
	assert_true(tools.begin(Vector3.ZERO))
	tools.update(Vector3(0, 0, 3))
	assert_true(session.release_gesture("move")["ok"])
	assert_eq(doc.state["instances"][0]["position"][2], 3.0)
	assert_true(session.commit_snapshot(tools.selection_action("rotate"), "rotate")["ok"])
	assert_almost_eq(doc.state["instances"][0]["yaw"], PI / 12, 0.001)
	for index: int in range(12):
		session.commit_snapshot(tools.selection_action("scale_up"), "scale")
	assert_eq(doc.state["instances"][0]["scale"], 2.0)
	var before: Dictionary = doc.snapshot()
	assert_true(session.commit_snapshot(tools.selection_action("copy"), "copy")["ok"])
	assert_eq(doc.state["instances"].size(), 4)
	assert_ne(doc.state["instances"][0]["seed"], doc.state["instances"][2]["seed"])
	session.request_undo()
	assert_eq_deep(doc.state["instances"], before["instances"])
	tools.selected = [doc.state["instances"][0]["id"]]
	assert_true(session.commit_snapshot(tools.selection_action("delete"), "delete")["ok"])
	assert_eq(doc.state["instances"].size(), 1)
	session.request_undo()
	assert_eq_deep(doc.state["instances"], before["instances"])


func test_rejected_batch_move_leaves_all_items_and_history_unchanged() -> void:
	var draft: Dictionary = doc.snapshot()
	var item: Dictionary = InstanceEdits.allocate(draft, Vector3(22, 0, 0))
	session.replace_document(draft)
	tools.selected = [item["id"]]
	tools.mode = "move"
	tools.begin(Vector3(22, 0, 0))
	tools.update(Vector3(30, 0, 0))
	var before: Dictionary = doc.snapshot()
	assert_false(session.release_gesture("move")["ok"])
	assert_eq_deep(doc.snapshot(), before)
	assert_eq(session.history_count(), 0)


func test_pending_commit_blocks_new_gesture_and_failure_keeps_source_and_history() -> void:
	var draft: Dictionary = doc.snapshot()
	InstanceEdits.allocate(draft, Vector3.ZERO)
	assert_true(session.reserve_commit(draft, "release")["ok"])
	assert_false(session.begin_gesture())
	assert_false(session.request_undo()["ok"])
	assert_false(tools.begin(Vector3.ZERO))
	assert_false(session.finish_reserved({"ok": false, "error": "injected_prepare_failure"})["ok"])
	assert_true(doc.state["instances"].is_empty())
	assert_eq(session.history_count(), 0)
	assert_eq(session.phase, EditSession.Phase.IDLE)


func test_cancelled_pending_candidate_cannot_publish_late_result() -> void:
	var draft: Dictionary = doc.snapshot()
	InstanceEdits.allocate(draft, Vector3.ZERO)
	session.reserve_commit(draft, "release")
	session.cancel_gesture()
	assert_false(session.finish_reserved({"ok": true})["ok"])
	assert_true(doc.state["instances"].is_empty())
	assert_eq(session.history_count(), 0)


func test_reserving_preview_does_not_clear_queued_source_snapshot() -> void:
	tools.mode = "prop"
	tools.begin(Vector3.ZERO)
	var candidate: Dictionary = session.preview
	assert_true(session.reserve_commit(candidate, "release")["ok"])
	assert_eq(WorldDocument.validate(candidate), "")
	assert_eq(candidate["instances"].size(), 1)
	assert_true(session.finish_reserved({"ok": true})["ok"])
	assert_eq(doc.state["instances"].size(), 1)


func test_simplified_x_handle_constrains_drag_to_x_axis() -> void:
	var draft: Dictionary = doc.snapshot()
	var item: Dictionary = InstanceEdits.allocate(draft, Vector3.ZERO)
	session.replace_document(draft)
	tools.selected = [item["id"]]
	tools.mode = "move"
	assert_true(tools.begin(Vector3(1, 0, 0)))
	tools.update(Vector3(3, 0, 5))
	assert_true(session.release_gesture("x axis")["ok"])
	assert_eq(doc.state["instances"][0]["position"], [2.0, 0.0, 0.0])


func test_road_door_probe_is_one_prepared_transaction_and_rejects_manual_conflict() -> void:
	var draft: Dictionary = doc.snapshot()
	var house: Dictionary = WorldDocument.allocate_building(draft, Vector3.ZERO, Vector3(4, 3, 4))
	session.replace_document(draft)
	var candidate: Dictionary = RiskEdits.road_to_door(
		doc.snapshot(), house["id"], Vector3(0, 0, 7), Vector3(0, 0, 2)
	)
	assert_true(candidate["ok"])
	assert_true(
		session.commit_snapshot(candidate["snapshot"], "road and door", WorldRebuild.evaluate)["ok"]
	)
	assert_eq(doc.state["paths"].size(), 1)
	assert_eq(doc.state["buildings"][0]["openings"].size(), 1)
	assert_eq(session.history_count(), 1)
	session.request_undo()
	assert_eq(doc.state["paths"].size(), 0)
	assert_eq(doc.state["buildings"][0]["openings"].size(), 0)
	draft = doc.snapshot()
	draft["buildings"][0]["openings"] = [
		{"kind": "rect", "center": 0.5, "width": 0.9, "height": 0.9, "sill": 1.0}
	]
	session.replace_document(draft)
	var before: Dictionary = doc.snapshot()
	assert_false(
		RiskEdits.road_to_door(before, house["id"], Vector3(0, 0, 7), Vector3(0, 0, 2))["ok"]
	)
	assert_eq_deep(doc.snapshot(), before)
	assert_eq(session.history_count(), 0)


func test_fifty_mixed_edits_undo_redo_restore_all_source_layers_and_ids() -> void:
	var draft: Dictionary = TerrainField.pond(doc.snapshot(), Vector2(10, 7), 2.0)
	WorldDocument.allocate_building(draft, Vector3.ZERO, Vector3(4, 3, 4))
	assert_true(session.replace_document(draft)["ok"])
	var initial: Dictionary = doc.snapshot()
	for index: int in range(50):
		draft = doc.snapshot()
		match index % 5:
			0:
				draft = TerrainField.brush(draft, Vector2(12, 0), 0.01)
			1:
				draft["environment"]["dusk"] = not draft["environment"]["dusk"]
			2:
				InstanceEdits.allocate(draft, Vector3(-12 + float(index) * 0.12, 0, -8))
			3:
				draft["pool"]["radius"] += 0.025
			4:
				draft["buildings"][0]["size"][1] += 0.02
		assert_true(session.commit_snapshot(draft, "mixed edit")["ok"])
	var completed: Dictionary = doc.snapshot()
	assert_eq(session.history_count(), 50)
	for index: int in range(50):
		assert_true(session.request_undo()["ok"])
	var restored: Dictionary = doc.snapshot()
	restored.erase("revision")
	initial.erase("revision")
	assert_eq_deep(restored, initial)
	for index: int in range(50):
		assert_true(session.request_redo()["ok"])
	restored = doc.snapshot()
	restored.erase("revision")
	completed.erase("revision")
	assert_eq_deep(restored, completed)


func test_bad_path_shape_and_dangling_door_reference_are_rejected_by_codec() -> void:
	var draft: Dictionary = doc.snapshot()
	draft["paths"] = [{"id": "bad", "points": 12, "width": 1.2}]
	assert_eq(WorldDocument.validate(draft), "invalid_path_points")
	assert_true(SaveCodec.encode(draft).is_empty())
	draft = doc.snapshot()
	var house: Dictionary = WorldDocument.allocate_building(draft, Vector3.ZERO, Vector3(4, 3, 4))
	house["openings"] = [
		{"kind": "arch", "center": 0.5, "width": 1.1, "height": 2.05, "source_path": "missing"}
	]
	assert_eq(WorldDocument.validate(draft), "invalid_opening_path_reference")
	assert_true(SaveCodec.encode(draft).is_empty())
