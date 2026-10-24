extends "res://tests/garden_presentation/playground_test_base.gd"


func test_rejected_pool_action_is_readable_with_context_open_at_150_percent() -> void:
	playground._preference_changed("ui_scale", 1.5)
	playground.hud.open_group("water")
	playground.hud.set_status("bridge_missing_pond")
	for i: int in range(10):
		await get_tree().process_frame
	var bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(viewport.size))
	assert_true(bounds.encloses(playground.hud.context.get_global_rect()))
	var feedback: Label = playground.hud.context_status
	assert_true(feedback.is_visible_in_tree())
	assert_true("请先画池塘" in feedback.text)
	assert_true(playground.hud.context.get_global_rect().encloses(feedback.get_global_rect()))
	assert_true(
		playground.hud.context.get_global_rect().encloses(
			playground.hud.cancel_stroke.get_global_rect()
		)
	)
	assert_false(playground.hud._dock.get_global_rect().intersects(feedback.get_global_rect()))


func test_feedback_survives_close_reopen_and_photography_without_source_edits() -> void:
	var before: Dictionary = playground.document.snapshot()
	playground.hud.open_group("build")
	playground.hud.set_status("不能提交：尺寸冲突")
	playground.hud.close_context()
	assert_true(playground.hud.breadcrumbs.is_visible_in_tree())
	assert_eq(playground.hud.breadcrumbs.text, "不能提交：尺寸冲突")
	playground.hud.open_group("build", false)
	assert_eq(playground.hud.context_status.text, "不能提交：尺寸冲突")
	assert_true(playground.enter_photo())
	assert_false(playground.hud.context_status.is_visible_in_tree())
	playground.exit_photo()
	assert_true(playground.hud.context_status.is_visible_in_tree())
	assert_eq_deep(playground.document.state, before)
	assert_eq(playground.session.history_count(), 0)


func test_mouse_cancel_drops_pending_commit_and_ignores_late_worker_result() -> void:
	var before: Dictionary = playground.document.snapshot()
	playground.hud.open_group("terrain")
	var draft: Dictionary = TerrainField.brush(before, Vector2(18, 18), 0.02)
	playground._submit_async(draft, "mouse cancel")
	assert_eq(playground.session.phase, EditSession.Phase.PENDING_COMMIT)
	playground.hud.cancel_stroke.pressed.emit()
	await _settle()
	assert_eq(playground.session.phase, EditSession.Phase.IDLE)
	assert_eq_deep(playground.document.state, before)
	assert_eq(playground.session.history_count(), 0)
	assert_true("已取消" in playground.hud.context_status.text)


func test_mouse_cancel_discards_preview_and_can_start_next_stroke() -> void:
	var before: Dictionary = playground.document.snapshot()
	playground.hud.open_group("build")
	assert_true(playground.session.begin_gesture())
	playground.session.update_gesture(TerrainField.brush(before, Vector2(18, 18), 0.02))
	playground.hud.cancel_stroke.pressed.emit()
	assert_eq(playground.session.phase, EditSession.Phase.IDLE)
	assert_eq_deep(playground.document.state, before)
	var draft: Dictionary = TerrainField.brush(before, Vector2(18, 18), 0.02)
	playground._submit_async(draft, "after cancellation")
	await _settle()
	assert_eq(playground.session.history_count(), 1)
	assert_ne(playground.document.state["terrain"], before["terrain"])


func test_bank_reuses_live_resources_for_distant_terrain_but_rebuilds_for_seed() -> void:
	var bank: Node3D = playground._pond_bank
	var draft: Dictionary = TerrainField.brush(
		playground.document.snapshot(), Vector2(18, 18), 0.02
	)
	playground._submit_async(draft, "distant terrain")
	await _settle()
	assert_true(is_instance_valid(bank))
	assert_same(playground._pond_bank, bank)
	draft = playground.document.snapshot()
	draft["world_seed"] = "w11-new-bank"
	assert_true(playground.session.replace_document(draft, playground._prepare_views)["ok"])
	await _settle()
	assert_false(is_instance_valid(bank))
	assert_true(is_instance_valid(playground._pond_bank))


func test_near_bank_terrain_change_and_undo_refresh_grounding() -> void:
	var source: Dictionary = TerrainField.pond(
		WorldDocument.new("w11-grounding").snapshot(), Vector2.ZERO, 3
	)
	assert_true(playground.session.replace_document(source, playground._prepare_views)["ok"])
	await _settle()
	var bank: Node3D = playground._pond_bank
	var before: Dictionary = playground.document.snapshot()
	var draft: Dictionary = TerrainField.brush(before, Vector2(4, 0), 0.02, 0.8)
	playground._submit_async(draft, "bank grounding")
	await _settle()
	assert_false(is_instance_valid(bank))
	assert_ne(playground.document.state["terrain"], before["terrain"])
	var changed_bank: Node3D = playground._pond_bank
	playground._on_action(&"undo")
	await _settle()
	assert_false(is_instance_valid(changed_bank))
	assert_true(_same(playground.document.state, before))


func test_feedback_and_cancel_remain_pinned_when_properties_scroll() -> void:
	playground._preference_changed("ui_scale", 1.5)
	playground.hud.open_group("plants")
	playground.hud.set_status("bridge_missing_pond")
	for i: int in range(3):
		await get_tree().process_frame
	var feedback_rect: Rect2 = playground.hud.context_status.get_global_rect()
	var cancel_rect: Rect2 = playground.hud.cancel_stroke.get_global_rect()
	var scroll: ScrollContainer = playground.hud.context.find_child(
		"ToolOptionsScroll", true, false
	)
	playground.hud.context_body.custom_minimum_size.y = 1200
	for i: int in range(3):
		await get_tree().process_frame
	scroll.scroll_vertical = 10000
	for i: int in range(3):
		await get_tree().process_frame
	assert_gt(scroll.scroll_vertical, 0)
	assert_eq(playground.hud.context_status.get_global_rect(), feedback_rect)
	assert_eq(playground.hud.cancel_stroke.get_global_rect(), cancel_rect)
	assert_true(playground.hud.context_status.is_visible_in_tree())
