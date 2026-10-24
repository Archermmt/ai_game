extends "res://tests/ux_02/playground_test_base.gd"


func _mouse(
	point: Vector2, pressed: bool, button: MouseButton = MOUSE_BUTTON_LEFT
) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = point
	return event


func _select_home() -> Dictionary:
	var home: Dictionary = playground.document.state["buildings"][0]
	playground.selected_buildings.assign([home["id"]])
	playground.tools.selected.clear()
	playground.tools.mode = "inspect"
	return home


func _empty_house() -> Dictionary:
	var source: Dictionary = WorldDocument.new("ux-scene").snapshot()
	var home: Dictionary = WorldDocument.allocate_building(source, Vector3.ZERO, Vector3(4, 3, 4))
	assert_true(playground.session.replace_document(source, playground._prepare_views)["ok"])
	await _settle()
	playground.selected_buildings.assign([home["id"]])
	playground.tools.mode = "inspect"
	return home


func test_default_has_eleven_cards_without_modify_and_does_not_open_large_inspector() -> void:
	assert_eq(playground.hud.ribbon_buttons.size(), 11)
	assert_false(playground.hud.ribbon_buttons.has("edit"))
	assert_true(playground.hud.ribbon_buttons.has("erase"))
	playground.hud.open_group("build")
	assert_eq(playground.tools.mode, "rect")
	assert_true(playground.hud.quick.visible)
	assert_false(playground.hud.context.visible)
	assert_eq(playground.session.history_count(), 0)


func test_all_compact_groups_route_and_fit_at_150_percent() -> void:
	playground._preference_changed("ui_scale", 1.5)
	var before: Dictionary = playground.document.snapshot()
	for key: String in playground.hud.ribbon_buttons:
		if key == "photo":
			continue
		playground.hud.open_group(key)
		for i: int in range(4):
			await get_tree().process_frame
		assert_true(
			Rect2(Vector2.ZERO, Vector2(viewport.size)).encloses(
				playground.hud.quick.get_global_rect()
			),
			key
		)
		assert_false(playground.hud.context.visible)
	assert_eq_deep(playground.document.state, before)


func test_building_height_drag_commits_once_and_undo_redo_restore_source() -> void:
	await _empty_house()
	var before: Dictionary = playground.document.snapshot()
	playground.begin_direct("height", Vector2(600, 300))
	playground.update_direct(Vector2(600, 285))
	playground.update_direct(Vector2(600, 270))
	assert_eq_deep(playground.document.state, before)
	assert_ne(playground.session.preview["buildings"][0]["size"], before["buildings"][0]["size"])
	playground.finish_direct()
	await _settle()
	assert_eq(playground.session.history_count(), 1)
	var after: Dictionary = playground.document.snapshot()
	playground._on_action(&"undo")
	await _settle()
	assert_true(_same(playground.document.state, before))
	playground._on_action(&"redo")
	await _settle()
	assert_true(_same(playground.document.state, after))


func test_direct_cancel_rejects_late_preview_and_leaves_history_empty() -> void:
	await _empty_house()
	var before: Dictionary = playground.document.snapshot()
	playground.begin_direct("width", Vector2(600, 300))
	playground.update_direct(Vector2(650, 310))
	playground._on_action(&"cancel")
	await _settle()
	assert_eq_deep(playground.document.state, before)
	assert_eq(playground.session.history_count(), 0)
	assert_true(playground.direct.is_empty())


func test_right_short_click_enters_edit_from_any_creation_tool() -> void:
	var home: Dictionary = await _empty_house()
	playground.hud.open_group("path")
	var screen: Vector2 = playground.camera_rig.camera.unproject_position(Vector3(0, 1, 0))
	playground.camera_rig._unhandled_input(_mouse(screen, true, MOUSE_BUTTON_RIGHT))
	playground.camera_rig._input(_mouse(screen, false, MOUSE_BUTTON_RIGHT))
	assert_eq(playground.tools.mode, "inspect")
	assert_eq(playground.selected_buildings, [home["id"]])
	assert_false(playground.hud.context.visible)
	assert_false(playground.hud.quick.visible)


func test_right_drag_away_and_back_never_selects_on_release() -> void:
	await _empty_house()
	playground.selected_buildings.clear()
	playground.hud.open_group("path")
	var screen: Vector2 = playground.camera_rig.camera.unproject_position(Vector3(0, 1, 0))
	playground.camera_rig._unhandled_input(_mouse(screen, true, MOUSE_BUTTON_RIGHT))
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = screen + Vector2(40, 0)
	playground.camera_rig._input(motion)
	motion.position = screen
	playground.camera_rig._input(motion)
	playground.camera_rig._input(_mouse(screen, false, MOUSE_BUTTON_RIGHT))
	assert_eq(playground.tools.mode, "path")
	assert_true(playground.selected_buildings.is_empty())
	assert_eq(playground.session.history_count(), 0)


func test_exact_inspector_is_explicit_and_photo_restores_selection_and_chrome() -> void:
	_select_home()
	await get_tree().process_frame
	assert_true(playground.hud.object_bar.visible)
	assert_false(playground.hud.context.visible)
	var selected: Array = playground.selected_buildings.duplicate()
	assert_true(playground.enter_photo())
	assert_false(playground.hud.object_bar.visible)
	assert_false(playground.hud.direct_handles.visible)
	playground.exit_photo()
	await get_tree().process_frame
	assert_eq(playground.selected_buildings, selected)
	assert_true(playground.hud.object_bar.visible)
	playground.hud.show_exact("build")
	assert_true(playground.hud.context.visible)


func test_copy_house_is_preview_until_drop_and_can_be_cancelled() -> void:
	await _empty_house()
	var before: Dictionary = playground.document.snapshot()
	playground.begin_direct("copy", Vector2(600, 300))
	assert_eq(playground.document.state["buildings"].size(), 1)
	assert_eq(playground.session.preview["buildings"].size(), 2)
	playground._on_action(&"cancel")
	await _settle()
	assert_eq_deep(playground.document.state, before)
	assert_eq(playground.selected_buildings, [before["buildings"][0]["id"]])
	assert_eq(playground.session.history_count(), 0)


func test_delete_building_is_targeted_reversible_and_cannot_bypass_pending_commit() -> void:
	var home: Dictionary = _select_home()
	var before: Dictionary = playground.document.snapshot()
	playground._on_action(&"direct_delete")
	assert_eq(playground.session.phase, EditSession.Phase.PENDING_COMMIT)
	playground._on_action(&"direct_delete")
	await _settle()
	assert_eq(playground.document.state["buildings"].size(), before["buildings"].size() - 1)
	assert_eq(playground.session.history_count(), 1)
	assert_true(DirectEditData.find(playground.document.state, home["id"], true).is_empty())
	playground._on_action(&"undo")
	await _settle()
	assert_true(_same(playground.document.state, before))


func test_opening_click_finds_target_without_selecting_a_house_first() -> void:
	var home: Dictionary = await _empty_house()
	playground.selected_buildings.clear()
	playground.hud.open_group("openings")
	var screen: Vector2 = playground.camera_rig.camera.unproject_position(Vector3(0, 1, 2))
	playground._unhandled_input(_mouse(screen, true))
	playground._unhandled_input(_mouse(screen, false))
	await _settle()
	assert_eq(playground.selected_buildings, [home["id"]])
	assert_eq(playground.document.state["buildings"][0]["openings"].size(), 1)
	assert_eq(playground.session.history_count(), 1)


func test_failed_bridge_release_does_not_wait_for_a_second_confirmation() -> void:
	await _empty_house()
	playground._on_action(&"bridge")
	var a: Vector2 = playground.camera_rig.camera.unproject_position(Vector3(10, 0, 10))
	var b: Vector2 = playground.camera_rig.camera.unproject_position(Vector3(13, 0, 10))
	playground._unhandled_input(_mouse(a, true))
	playground._unhandled_input(_mouse(b, false))
	await _settle()
	assert_eq(playground.session.phase, EditSession.Phase.IDLE)
	assert_eq(playground.document.state["bridges"].size(), 0)
	assert_eq(playground.session.history_count(), 0)
	assert_false("确认桥" in playground.hud.breadcrumbs.text)


func test_focus_loss_cancels_direct_drag_without_source_changes() -> void:
	await _empty_house()
	var before: Dictionary = playground.document.snapshot()
	playground.begin_direct("height", Vector2(600, 300))
	playground.update_direct(Vector2(600, 270))
	playground._notification(NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	await _settle()
	assert_eq_deep(playground.document.state, before)
	assert_true(playground.direct.is_empty())


func test_valid_bridge_release_commits_and_undo_without_confirm_button() -> void:
	var source: Dictionary = PondShape.draw(
		WorldDocument.new("ux-bridge").snapshot(), [[-2, -2], [2, -2], [2, 2], [-2, 2]]
	)
	assert_true(playground.session.replace_document(source, playground._prepare_views)["ok"])
	await _settle()
	playground._on_action(&"bridge")
	var a: Vector2 = playground.camera_rig.camera.unproject_position(Vector3(0, 0, -2.5))
	var b: Vector2 = playground.camera_rig.camera.unproject_position(Vector3(0, 0, 2.5))
	playground._unhandled_input(_mouse(a, true))
	playground._unhandled_input(_mouse(b, false))
	await _settle()
	assert_eq(playground.document.state["bridges"].size(), 1)
	assert_eq(playground.session.history_count(), 1)
	playground._on_action(&"undo")
	await _settle()
	assert_true(playground.document.state["bridges"].is_empty())


func test_copy_house_drop_allocates_a_new_id_and_one_history_item() -> void:
	var home: Dictionary = await _empty_house()
	var origin: Vector2 = playground.camera_rig.camera.unproject_position(Vector3.ZERO)
	var destination: Vector2 = playground.camera_rig.camera.unproject_position(Vector3(12, 0, 12))
	playground.begin_direct("copy", origin)
	playground.update_direct(destination)
	playground.finish_direct()
	await _settle()
	assert_eq(playground.document.state["buildings"].size(), 2)
	assert_ne(playground.document.state["buildings"][1]["id"], home["id"])
	assert_eq(playground.session.history_count(), 1)
	assert_eq(WorldDocument.validate(playground.document.state), "")


func test_object_drag_rotation_and_copy_preserve_original_seed() -> void:
	var source: Dictionary = WorldDocument.new("ux-object").snapshot()
	var item: Dictionary = InstanceEdits.allocate(source, Vector3.ZERO)
	item["asset_id"] = "PROP-02"
	assert_true(playground.session.replace_document(source, playground._prepare_views)["ok"])
	await _settle()
	playground.selected_buildings.clear()
	playground.tools.selected.assign([item["id"]])
	playground.tools.mode = "inspect"
	playground.begin_direct("rotate", Vector2(600, 300))
	playground.update_direct(Vector2(640, 300))
	playground.finish_direct()
	await _settle()
	assert_almost_eq(playground.document.state["instances"][0]["yaw"], 0.6, 0.00001)
	assert_eq(playground.document.state["instances"][0]["seed"], item["seed"])
	var origin: Vector2 = playground.camera_rig.camera.unproject_position(Vector3.ZERO)
	playground.begin_direct("copy", origin)
	playground.update_direct(playground.camera_rig.camera.unproject_position(Vector3(10, 0, 10)))
	playground.finish_direct()
	await _settle()
	assert_eq(playground.document.state["instances"].size(), 2)
	assert_ne(playground.document.state["instances"][1]["id"], item["id"])
	assert_eq(playground.session.history_count(), 2)


func test_locked_window_conflict_rejects_resize_without_touching_source_or_history() -> void:
	await _empty_house()
	var source: Dictionary = playground.document.snapshot()
	source["buildings"][0]["size"] = [8.0, 3.0, 4.0]
	source["buildings"][0]["openings"] = [
		{
			"kind": "rect",
			"center": 0.5,
			"width": 4.0,
			"height": 1.0,
			"sill": 1.0,
			"locked": true,
			"source": "manual"
		}
	]
	assert_true(playground.session.replace_document(source, playground._prepare_views)["ok"])
	await _settle()
	var before: Dictionary = playground.document.snapshot()
	playground.begin_direct("width", Vector2(600, 300))
	var draft: Dictionary = DirectEditData.transform(
		before, before["buildings"][0]["id"], true, "width", Vector3(-5, 0, 0)
	)
	playground.session.update_gesture(draft)
	playground.finish_direct()
	await _settle()
	assert_eq_deep(playground.document.state, before)
	assert_eq(playground.session.history_count(), 0)


func test_path_width_and_grass_density_are_distinct_live_controls() -> void:
	playground.hud.open_group("path")
	playground.hud.quick_path_width.value = 2.1
	assert_almost_eq(playground.path_width, 2.1, 0.00001)
	playground.hud.open_group("plants")
	var before: Dictionary = playground.document.snapshot()
	playground.hud.grass_slider.value = 0.2
	assert_almost_eq(playground.meadow.density, 0.2, 0.00001)
	assert_false(playground.hud.quick_path_width.visible)
	assert_eq_deep(playground.document.state, before)


func test_new_scene_save_reload_preserves_direct_edits_and_local_preferences() -> void:
	await _empty_house()
	playground.begin_direct("height", Vector2(600, 300))
	playground.update_direct(Vector2(600, 280))
	playground.finish_direct()
	await _settle()
	var source: Dictionary = playground.document.snapshot()
	playground._start_save(0, "直接编辑")
	await _settle()
	playground._on_action(&"undo")
	await _settle()
	playground._start_load(0)
	await _settle()
	assert_true(_same(playground.document.state, source))
	assert_eq(playground.session.history_count(), 0)


func test_release_over_toolbar_cancels_direct_drag_without_publishing() -> void:
	await _empty_house()
	var before: Dictionary = playground.document.snapshot()
	playground.begin_direct("height", Vector2(600, 300))
	playground.update_direct(Vector2(600, 280))
	var release: Vector2 = playground.hud._dock.get_global_rect().get_center()
	playground._input(_mouse(release, false))
	await _settle()
	assert_eq_deep(playground.document.state, before)
	assert_eq(playground.session.history_count(), 0)
	assert_true(playground.direct.is_empty())


func test_mac_camera_gestures_preserve_selection_and_source_in_the_new_scene() -> void:
	var home: Dictionary = _select_home()
	var before: Dictionary = playground.document.snapshot()
	var yaw: float = playground.camera_rig.yaw
	var pan: InputEventPanGesture = InputEventPanGesture.new()
	pan.delta = Vector2(1, 1)
	playground.camera_rig._unhandled_input(pan)
	assert_ne(playground.camera_rig.yaw, yaw)
	var distance: float = playground.camera_rig.distance
	var pinch: InputEventMagnifyGesture = InputEventMagnifyGesture.new()
	pinch.factor = 1.1
	playground.camera_rig._unhandled_input(pinch)
	assert_lt(playground.camera_rig.distance, distance)
	assert_eq(playground.selected_buildings, [home["id"]])
	assert_eq_deep(playground.document.state, before)
	assert_eq(playground.session.history_count(), 0)
