extends "res://tests/week_08/playground_test_base.gd"


func test_scene_exposes_library_settings_and_two_recommended_views() -> void:
	for action: String in ["library", "preferences", "view_day", "view_garden"]:
		assert_has(playground.hud.buttons, action)
	assert_eq(playground.hud.slots.item_count, 5)
	assert_eq(playground.document.state["buildings"].size(), 2)


func test_manual_save_updates_dirty_baseline_only_after_io_success() -> void:
	assert_true(playground.is_dirty())
	playground._start_save(2, "我的第三园")
	assert_true(playground.saves.is_busy())
	assert_true(playground.is_dirty())
	await _settle()
	assert_false(playground.is_dirty())
	assert_eq(playground.active_slot, 2)
	assert_eq(playground.active_title, "我的第三园")


func test_edits_during_save_remain_dirty_and_pause_pending_navigation() -> void:
	playground._intent = "load"
	playground._intent_index = 4
	playground._start_save(0, "快照")
	playground.camera_rig.yaw += 0.1
	playground.camera_rig.refresh()
	await _settle()
	assert_true(playground.is_dirty())
	assert_eq(playground._intent, "load")
	assert_true(playground.hud.decision.visible)
	playground._decision_made("cancel")
	playground.hud.decision.hide()
	var loaded: Dictionary = SlotStore.read_slot(playground.saves.directory, 0)
	assert_ne(loaded["metadata"]["presentation"]["camera"]["yaw"], playground.camera_rig.yaw)


func test_load_restores_source_camera_title_and_clears_history_atomically() -> void:
	playground._start_save(1, "待恢复")
	await _settle()
	var before: Dictionary = playground.document.snapshot()
	var camera_yaw: float = playground.camera_rig.yaw
	playground._choose_palette("wood", "wood_walnut")
	await _settle()
	playground.camera_rig.yaw += 0.3
	playground._start_load(1)
	assert_ne(
		playground.document.state["environment"]["palette"]["wood"],
		before["environment"]["palette"]["wood"]
	)
	await _settle()
	assert_eq_deep(playground.document.state["environment"], before["environment"])
	assert_eq(playground.camera_rig.yaw, camera_yaw)
	assert_eq(playground.active_title, "待恢复")
	assert_eq(playground.session.history_count(), 0)
	assert_false(playground.is_dirty())


func test_failed_load_preserves_entire_world_and_history() -> void:
	var before: Dictionary = playground.document.snapshot()
	playground._start_load(4)
	await _settle()
	assert_eq_deep(playground.document.snapshot(), before)
	assert_true("原作品保留" in playground.hud.status_label.text)


func test_save_rejects_preview_without_losing_it() -> void:
	playground.session.begin_gesture()
	playground._start_save(0, "preview")
	assert_false(playground.saves.is_busy())
	assert_eq(playground.session.phase, EditSession.Phase.PREVIEW)
	playground._cancel_edit()


func test_autosave_requires_sixty_idle_seconds_and_writes_active_slot() -> void:
	playground.active_slot = 3
	playground.idle_seconds = 59.0
	playground.autosave_seconds = 61.0
	playground._process(0.0)
	assert_false(playground.saves.is_busy())
	playground.idle_seconds = 60.0
	playground._process(0.01)
	assert_true(playground.saves.is_busy())
	await _settle()
	assert_true(SlotStore.read_slot(playground.saves.directory, 3)["ok"])
	assert_false(FileAccess.file_exists(SlotStore.path_for(playground.saves.directory, 0)))


func test_autosave_does_not_run_during_preview_or_clean_state() -> void:
	playground.session.begin_gesture()
	playground.idle_seconds = 61
	playground.autosave_seconds = 61
	playground._process(0.0)
	assert_false(playground.saves.is_busy())
	playground._cancel_edit()
	playground._start_save(0, "clean")
	await _settle()
	playground.idle_seconds = 61
	playground.autosave_seconds = 61
	playground._process(0.0)
	assert_false(playground.saves.is_busy())


func test_user_input_and_camera_motion_reset_idle_timer() -> void:
	playground.idle_seconds = 59
	playground._input(InputEventKey.new())
	assert_eq(playground.idle_seconds, 0.0)
	playground.idle_seconds = 59
	playground.hud.settings.window_input.emit(InputEventKey.new())
	assert_eq(playground.idle_seconds, 0.0)
	playground.idle_seconds = 59
	playground.camera_rig.yaw += 0.1
	playground._refresh_dirty_keys()
	assert_eq(playground.idle_seconds, 0.0)


func test_dirty_load_prompts_and_cancel_retains_source() -> void:
	var before: Dictionary = playground.document.snapshot()
	playground._slot_requested("load", 0, "")
	assert_eq(playground._intent, "load")
	assert_true(playground.hud.decision.visible)
	playground._decision_made("cancel")
	assert_eq(playground._intent, "")
	assert_eq_deep(playground.document.snapshot(), before)
	playground.hud.decision.hide()


func test_dirty_exit_prompts_and_cancel_does_not_quit() -> void:
	playground._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	assert_eq(playground._intent, "quit")
	assert_true(playground.hud.decision.visible)
	playground._decision_made("cancel")
	assert_eq(playground._intent, "")
	playground.hud.decision.hide()


func test_save_then_load_continuation_uses_original_target_slot() -> void:
	SlotStore.write_slot(playground.saves.directory, 4, ForestTemplate.empty(), "另一园")
	playground._slot_requested("load", 4, "")
	playground._decision_made("save")
	playground.hud.decision.hide()
	await _settle()
	assert_eq(playground.active_slot, 4)
	assert_eq(playground.active_title, "另一园")
	assert_true(playground.document.state["buildings"].is_empty())
	assert_eq(SlotStore.read_slot(playground.saves.directory, 0)["snapshot"]["buildings"].size(), 2)


func test_dof_off_and_on_are_local_preferences_without_history() -> void:
	var before: Dictionary = playground.document.snapshot()
	playground._preference_changed("dof", true)
	assert_true(playground.camera_rig.camera.attributes.dof_blur_far_enabled)
	playground._preference_changed("dof", false)
	assert_false(playground.camera_rig.camera.attributes.dof_blur_far_enabled)
	assert_false(playground.camera_rig.camera.attributes.dof_blur_near_enabled)
	assert_eq_deep(playground.document.snapshot(), before)
	assert_eq(playground.session.history_count(), 0)


func test_reduced_motion_overrides_source_and_survives_new_materials() -> void:
	playground._preference_changed("reduce_motion", true)
	var draft: Dictionary = playground.document.snapshot()
	HedgeRules.allocate(draft, [[4, 12], [7, 12]])
	playground._submit_async(draft, "new hedge")
	await _settle()
	assert_false(playground.document.state["environment"]["reduce_motion"])
	assert_gt(playground.wind_materials.size(), 1)
	for paint: ShaderMaterial in playground.wind_materials:
		assert_true(paint.get_shader_parameter("reduce_motion"))


func test_zero_wind_is_applied_to_all_plant_and_cloth_materials() -> void:
	var draft: Dictionary = playground.document.snapshot()
	draft["environment"]["wind_strength"] = 0.0
	playground._submit_async(draft, "still")
	await _settle()
	for paint: ShaderMaterial in playground.wind_materials:
		assert_eq(paint.get_shader_parameter("wind_strength"), 0.0)


func test_scaling_keeps_tool_dock_and_access_buttons_in_view() -> void:
	playground._preference_changed("ui_scale", 1.5)
	var hud: CanvasLayer = playground.hud
	assert_eq(hud._scale_value, 1.5)
	var dimensions: Vector2 = Vector2(viewport.size) / 1.5
	assert_lte(hud._dock.position.y + hud._dock.size.y, dimensions.y)
	for action: String in ["library", "preferences"]:
		assert_lt(hud.buttons[action].get_global_rect().end.y, float(viewport.size.y))


func test_preferences_reset_restores_ui_motion_and_clear_focus() -> void:
	playground._preference_changed("ui_scale", 1.5)
	playground._preference_changed("reduce_motion", true)
	playground._preference_changed("dof", true)
	playground._reset_preferences()
	assert_eq(playground.hud._scale_value, 1.0)
	assert_false(playground.preferences.values["reduce_motion"])
	assert_false(playground.camera_rig.camera.attributes.dof_blur_far_enabled)


func test_recommended_views_keep_world_and_history_unchanged() -> void:
	var before: Dictionary = playground.document.snapshot()
	playground._on_action(&"view_garden")
	assert_eq(playground.camera_rig.distance, 19.0)
	playground._on_action(&"view_day")
	assert_eq(playground.camera_rig.distance, 31.0)
	assert_eq_deep(playground.document.snapshot(), before)


func test_load_locks_edits_but_camera_remains_usable() -> void:
	SlotStore.write_slot(playground.saves.directory, 0, ForestTemplate.empty(), "empty")
	playground._start_load(0)
	var mode: String = playground.tools.mode
	playground._on_action(&"lamp_tool")
	assert_eq(playground.tools.mode, mode)
	playground.camera_rig.yaw += 0.1
	playground.camera_rig.refresh()
	await _settle()
	assert_true(playground.document.state["buildings"].is_empty())


func test_save_service_serializes_immutable_source_and_rejects_overlapping_io() -> void:
	var source: Dictionary = playground.document.snapshot()
	assert_true(playground.saves.request("save", 0, source, "worker"))
	source["buildings"].clear()
	assert_false(playground.saves.request("save", 1, source, "overlap"))
	await _settle()
	assert_eq(SlotStore.read_slot(playground.saves.directory, 0)["snapshot"]["buildings"].size(), 2)
