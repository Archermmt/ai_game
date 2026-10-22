extends "res://tests/ux_03/hover_test_base.gd"


func _house() -> Dictionary:
	var source: Dictionary = WorldDocument.new("ux03-scene").snapshot()
	var home: Dictionary = WorldDocument.allocate_building(source, Vector3.ZERO, Vector3(6, 3.5, 6))
	DoorRules.manual_opening(source, home["id"], Vector2(0, 3), 3)
	assert_true(playground.session.replace_document(source, playground._prepare_views)["ok"])
	await _settle()
	return home


func _target(home: Dictionary, opening: bool = false) -> Dictionary:
	return (
		{"family": "opening", "parent": home["id"], "index": 0}
		if opening
		else {"family": "house", "id": home["id"], "zone": "roof"}
	)


func test_unselected_hover_reveals_roof_without_changing_tool_or_history() -> void:
	var home: Dictionary = await _house()
	playground.hud.open_group("build")
	var before: Dictionary = playground.document.snapshot()
	var screen: Vector2 = playground.camera_rig.camera.unproject_position(
		Vector3(0, 3.5 + RoofProfile.rise(home), 0)
	)
	playground.refresh_hover(screen)
	assert_eq(playground.hovered.get("zone"), "roof")
	assert_eq(playground.tools.mode, "rect")
	assert_true(playground.selected_buildings.is_empty())
	assert_eq_deep(playground.document.state, before)
	assert_eq(playground.session.history_count(), 0)


func test_roof_drag_one_transaction_with_undo_redo() -> void:
	var home: Dictionary = await _house()
	var before: Dictionary = playground.document.snapshot()
	playground.hovered = _target(home)
	playground.begin_direct("roof", Vector2(600, 300))
	playground.update_surface(Vector2(600, 250))
	assert_eq_deep(playground.document.state, before)
	playground.finish_surface()
	await _settle()
	assert_gt(RoofProfile.rise(playground.document.state["buildings"][0]), RoofProfile.rise(home))
	assert_eq(playground.session.history_count(), 1)
	var after: Dictionary = playground.document.snapshot()
	playground._on_action(&"undo")
	await _settle()
	assert_true(_same(playground.document.state, before))
	playground._on_action(&"redo")
	await _settle()
	assert_true(_same(playground.document.state, after))


func test_cancel_and_focus_loss_leave_source_unchanged() -> void:
	var home: Dictionary = await _house()
	var before: Dictionary = playground.document.snapshot()
	playground.hovered = _target(home)
	playground.begin_direct("roof", Vector2(600, 300))
	playground.update_surface(Vector2(600, 250))
	playground._notification(NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	await _settle()
	assert_eq_deep(playground.document.state, before)
	assert_true(playground.surface_drag.is_empty())
	assert_eq(playground.session.history_count(), 0)


func test_window_width_and_wall_move_use_one_commit_each() -> void:
	var home: Dictionary = await _house()
	playground.hovered = _target(home, true)
	playground.begin_direct("width", Vector2(600, 300))
	playground.update_surface(Vector2(620, 300))
	playground.finish_surface()
	await _settle()
	assert_eq(playground.session.history_count(), 1)
	assert_ne(playground.document.state["buildings"][0]["openings"][0]["width"], 0.9)
	assert_eq(WorldDocument.validate(playground.document.state), "")


func test_invalid_window_drag_reverts_history_and_keeps_selected_identity() -> void:
	var home: Dictionary = await _house()
	var before: Dictionary = playground.document.snapshot()
	playground.hovered = _target(home, true)
	playground.begin_direct("height", Vector2(600, 300))
	playground.update_surface(Vector2(600, -800))
	playground.finish_surface()
	await _settle()
	assert_eq_deep(playground.document.state, before)
	assert_eq(playground.session.history_count(), 0)
	assert_false(playground.surface_selected.is_empty())


func test_surface_drag_release_over_ui_cancels() -> void:
	var home: Dictionary = await _house()
	var before: Dictionary = playground.document.snapshot()
	playground.hovered = _target(home)
	playground.begin_direct("roof", Vector2(600, 300))
	playground.update_surface(Vector2(600, 250))
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = playground.hud._dock.get_global_rect().get_center()
	event.pressed = false
	playground._input(event)
	await _settle()
	assert_eq_deep(playground.document.state, before)
	assert_eq(playground.session.history_count(), 0)


func test_selected_window_delete_and_undo_restore_its_parent() -> void:
	var home: Dictionary = await _house()
	playground._choose_surface(_target(home, true))
	playground._on_action(&"direct_delete")
	await _settle()
	assert_true(playground.document.state["buildings"][0]["openings"].is_empty())
	assert_eq(playground.document.state["buildings"].size(), 1)
	playground._on_action(&"undo")
	await _settle()
	assert_eq(playground.document.state["buildings"][0]["openings"].size(), 1)


func test_roof_save_reload_and_photo_hide_hover_handles() -> void:
	var home: Dictionary = await _house()
	playground.hovered = _target(home)
	playground.begin_direct("roof", Vector2(600, 300))
	playground.update_surface(Vector2(600, 350))
	playground.finish_surface()
	await _settle()
	var saved: Dictionary = playground.document.snapshot()
	playground._start_save(0, "屋顶修改")
	await _settle()
	playground._on_action(&"undo")
	await _settle()
	playground._start_load(0)
	await _settle()
	assert_true(_same(playground.document.state, saved))
	playground.enter_photo()
	playground._process(0)
	for handle: Control in playground.hud.direct_handles.handles.values():
		assert_false(handle.visible)
	playground.exit_photo()


func test_150_percent_surface_handles_stay_inside_viewport() -> void:
	var home: Dictionary = await _house()
	playground._preference_changed("ui_scale", 1.5)
	playground.hud.direct_handles.surface(
		playground.document.state, _target(home), playground.camera_rig.camera, 1.5
	)
	for handle: Control in playground.hud.direct_handles.handles.values():
		if handle.visible:
			assert_true(
				Rect2(Vector2.ZERO, Vector2(viewport.size)).encloses(handle.get_global_rect())
			)
	assert_true(playground.hud.direct_handles.handles["roof"].visible)


func test_zero_roof_drag_does_not_create_history() -> void:
	var home: Dictionary = await _house()
	playground.hovered = _target(home)
	playground.begin_direct("roof", Vector2(600, 300))
	playground.finish_surface()
	await _settle()
	assert_eq(playground.session.history_count(), 0)


func _bridge() -> Dictionary:
	var source: Dictionary = PondShape.draw(
		WorldDocument.new("ux03-bridge-scene").snapshot(), [[-2, -2], [2, -2], [2, 2], [-2, 2]]
	)
	var item: Dictionary = GardenStructures.allocate(
		source, "bridge", Vector2(-2.5, 0), Vector2(2.5, 0)
	)
	assert_true(playground.session.replace_document(source, playground._prepare_views)["ok"])
	await _settle()
	return {"family": "bridge", "id": item["id"], "zone": "end_a"}


func test_bridge_head_drag_commits_once_and_undo_restores_both_heads() -> void:
	var target: Dictionary = await _bridge()
	var before: Dictionary = playground.document.snapshot()
	playground.hovered = target
	var screen: Vector2 = playground.camera_rig.camera.unproject_position(Vector3(-2.5, 0.2, 0))
	playground.begin_direct("end_a", screen)
	playground.update_surface(screen + Vector2(-10, 0))
	playground.finish_surface()
	await _settle()
	assert_eq(playground.session.history_count(), 1)
	assert_ne(playground.document.state["bridges"][0]["a"], before["bridges"][0]["a"])
	assert_eq(playground.document.state["bridges"][0]["b"], before["bridges"][0]["b"])
	playground._on_action(&"undo")
	await _settle()
	assert_true(_same(playground.document.state, before))


func test_illegal_bridge_head_drag_is_rejected_and_late_preview_cannot_publish() -> void:
	var target: Dictionary = await _bridge()
	var before: Dictionary = playground.document.snapshot()
	playground.hovered = target
	playground.begin_direct("end_a", Vector2(500, 350))
	playground.update_surface(Vector2(50, 350))
	playground.finish_surface()
	await _settle()
	assert_eq_deep(playground.document.state, before)
	assert_eq(playground.session.history_count(), 0)
	assert_eq(playground.session.phase, EditSession.Phase.IDLE)


func test_pending_commit_blocks_a_second_surface_gesture() -> void:
	var home: Dictionary = await _house()
	playground.hovered = _target(home)
	playground.begin_direct("roof", Vector2(600, 300))
	playground.update_surface(Vector2(600, 250))
	playground.finish_surface()
	playground.begin_direct("height", Vector2(600, 300))
	assert_true(playground.direct.is_empty())
	assert_true(playground.surface_drag.is_empty())
	await _settle()
	assert_eq(playground.session.history_count(), 1)


func test_camera_gestures_do_not_start_hover_edits() -> void:
	var home: Dictionary = await _house()
	playground.hovered = _target(home)
	var before: Dictionary = playground.document.snapshot()
	var event: InputEventPanGesture = InputEventPanGesture.new()
	event.delta = Vector2(1, 1)
	playground.camera_rig._unhandled_input(event)
	assert_true(playground.surface_drag.is_empty())
	assert_true(playground.direct.is_empty())
	assert_eq_deep(playground.document.state, before)


func test_window_handles_remain_targetable_when_pointer_leaves_the_hole() -> void:
	var home: Dictionary = await _house()
	playground.hovered = _target(home, true)
	playground.hud.direct_handles.surface(
		playground.document.state, playground.hovered, playground.camera_rig.camera, 1.0
	)
	playground._pointer = (
		playground.hud.direct_handles.handles["width"].get_global_rect().get_center()
	)
	playground._hover_signature = ""
	playground._process(0)
	assert_eq(playground._display_target()["family"], "opening")
	assert_true(playground.hud.direct_handles.handles["width"].visible)


func test_slow_pointer_travel_to_window_handle_does_not_switch_to_parent_wall() -> void:
	var home: Dictionary = await _house()
	playground.hovered = _target(home, true)
	playground.hud.direct_handles.surface(
		playground.document.state, playground.hovered, playground.camera_rig.camera, 1.0
	)
	var start: Vector2 = (
		playground.hud.direct_handles.handles["move"].get_global_rect().get_center()
	)
	var end: Vector2 = playground.hud.direct_handles.handles["width"].get_global_rect().get_center()
	for step: int in range(11):
		playground._pointer = start.lerp(end, float(step) / 10)
		playground._hover_signature = ""
		playground._process(0)
		assert_eq(playground._display_target()["family"], "opening")


func test_bridge_width_drag_follows_its_own_cross_axis() -> void:
	var target: Dictionary = await _bridge()
	playground.hovered = target
	var source: Dictionary = playground.document.snapshot()
	var origin: Vector3 = SurfaceEditData.origin(source, target)
	var axis: Vector3 = SurfaceEditData.width_axis(source, target)
	var start: Vector2 = playground.camera_rig.camera.unproject_position(origin)
	var end: Vector2 = playground.camera_rig.camera.unproject_position(origin + axis * 0.1)
	playground.begin_direct("width", start)
	playground.update_surface(end)
	playground.finish_surface()
	await _settle()
	assert_almost_eq(
		playground.document.state["bridges"][0]["width"], source["bridges"][0]["width"] + 0.2, 0.02
	)
	assert_eq(playground.session.history_count(), 1)


func test_house_copy_drop_keeps_the_new_house_as_edit_target() -> void:
	var home: Dictionary = await _house()
	playground.hovered = _target(home)
	playground.begin_direct("copy", Vector2(600, 300))
	var screen: Vector2 = playground.camera_rig.camera.unproject_position(Vector3(12, 0, 0))
	playground.update_direct(screen)
	playground.finish_direct()
	await _settle()
	assert_eq(playground.document.state["buildings"].size(), 2)
	playground.hovered = {}
	assert_eq(playground._display_target()["id"], playground.selected_buildings[0])
	assert_ne(playground._display_target()["id"], home["id"])


func test_promoted_auto_opening_stays_selected_after_reordering() -> void:
	await _house()
	var source: Dictionary = playground.document.snapshot()
	var home: Dictionary = source["buildings"][0]
	home["openings"] = []
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
	assert_true(playground.session.replace_document(source, playground._prepare_views)["ok"])
	await _settle()
	playground.hovered = {"family": "opening", "parent": home["id"], "index": 2}
	playground.begin_direct("width", Vector2(600, 300))
	playground.update_surface(Vector2(603, 300))
	assert_false(
		SurfaceEditData.resolve(playground.session.preview, playground._display_target()).is_empty()
	)
	playground.finish_surface()
	await _settle()
	var selected: Dictionary = SurfaceEditData.resolve(
		playground.document.state, playground.surface_selected
	)
	assert_false(selected.is_empty())
	assert_eq(selected.get("center"), 0.8)
	assert_true(playground.surface_selected.has("attachment_id"))
