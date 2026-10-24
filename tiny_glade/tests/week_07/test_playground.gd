extends "res://tests/week_07/playground_test_base.gd"


func _first(asset_id: String) -> Dictionary:
	for item: Dictionary in playground.document.state["instances"]:
		if item["asset_id"] == asset_id:
			return item
	return {}


func test_scene_has_sixteen_mouse_tools_and_all_core_property_pages() -> void:
	assert_eq(playground.hud._dock_buttons.size(), 16)
	assert_eq(playground.hud._palette_buttons.size(), 12)
	assert_true(playground.hud.buttons.has("hedge"))
	assert_true(playground.hud.buttons.has("apply_object"))
	assert_eq(playground.document.state["buildings"].size(), 2)


func test_actual_mouse_toolbar_selects_tree_without_creating_object() -> void:
	var button: Button = playground.hud._dock_buttons["tree_tool"]
	var point: Vector2 = button.get_global_rect().get_center()
	var count_value: int = playground.document.state["instances"].size()
	_button(point, true)
	_button(point, false)
	await get_tree().process_frame
	assert_eq(playground.tools.mode, "place_asset")
	assert_eq(playground.selected_asset, "NAT-01")
	assert_eq(playground.document.state["instances"].size(), count_value)


func test_window_and_lamp_mouse_entries_set_explicit_catalog_values() -> void:
	playground.hud._dock_buttons["window_tool"].pressed.emit()
	assert_eq(playground.opening_variant, 3)
	assert_eq(playground.tools.mode, "place_opening")
	playground.hud._dock_buttons["lamp_tool"].pressed.emit()
	assert_eq(playground.selected_asset, "PROP-08")
	assert_eq(playground.tools.mode, "place_asset")


func test_object_card_applies_numbers_as_one_transaction_and_undoes() -> void:
	var item: Dictionary = _first("PROP-08")
	var before: Dictionary = playground.document.snapshot()
	playground._select_objects(_ids(item["id"]))
	playground.hud.object_x.value = -5.5
	playground.hud.object_yaw.value = 90
	playground.hud.object_scale.value = 1.25
	playground.hud.object_lamp.select(1)
	playground.hud.buttons["apply_object"].pressed.emit()
	await _settle()
	var changed: Dictionary = _first("PROP-08")
	assert_eq(changed["position"][0], -5.5)
	assert_almost_eq(changed["yaw"], PI / 2, 0.00001)
	assert_eq(changed["scale"], 1.25)
	assert_eq(changed["lamp_mode"], "on")
	playground._on_action(&"undo")
	assert_eq(playground.document.state["instances"], before["instances"])


func test_invalid_object_card_keeps_entire_source_and_history() -> void:
	var item: Dictionary = _first("PROP-08")
	playground._select_objects(_ids(item["id"]))
	var before: Dictionary = playground.document.snapshot()
	playground.hud.object_x.value = -2
	playground.hud.object_z.value = -1
	playground._on_action(&"apply_object")
	await _settle()
	assert_eq(playground.document.snapshot(), before)
	assert_true("不能" in playground.hud.status_label.text)


func test_palette_selection_reuses_world_nodes_and_is_undoable() -> void:
	var item: Dictionary = _first("PROP-01")
	var node: Node3D = playground._instance_views[item["id"]]
	playground._choose_palette("wood", "wood_walnut")
	await _settle()
	assert_same(playground._instance_views[item["id"]], node)
	assert_eq(playground.document.state["environment"]["palette"]["wood"], "wood_walnut")
	assert_true(playground.hud._palette_buttons["wood_walnut"].button_pressed)
	playground._on_action(&"undo")
	assert_eq(playground.document.state["environment"]["palette"]["wood"], "wood_honey")


func test_hedge_commit_reuses_distant_props_and_cancels_without_half_publication() -> void:
	var before: Dictionary = playground.document.snapshot()
	var draft: Dictionary = before.duplicate(true)
	HedgeRules.allocate(draft, [[3, 12], [6, 12], [6, 15]])
	playground._submit_async(draft, "hedge")
	assert_eq(playground.document.snapshot(), before)
	playground._on_action(&"cancel")
	await _settle()
	assert_eq(playground.document.snapshot(), before)


func test_hedge_commit_is_one_history_entry_and_full_wrapped_view() -> void:
	var item: Dictionary = _first("PROP-01")
	var distant: Node3D = playground._instance_views[item["id"]]
	var draft: Dictionary = playground.document.snapshot()
	var hedge: Dictionary = HedgeRules.allocate(draft, [[3, 12], [6, 12], [6, 15]])
	playground._submit_async(draft, "hedge")
	await _settle()
	assert_same(playground._instance_views[item["id"]], distant)
	assert_true(playground._instance_views.has(hedge["id"]))
	assert_true(playground._instance_views[hedge["id"]].has_node("PickProxy"))
	playground._on_action(&"undo")
	assert_false(playground._instance_views.has(hedge["id"]))
	playground._on_action(&"redo")
	assert_true(playground._instance_views.has(hedge["id"]))


func test_actual_hedge_mouse_drag_is_undoable_and_option_does_not_draw() -> void:
	playground.hud.visible = false
	playground._on_action(&"hedge")
	var field: TerrainField = TerrainField.new(playground.document.snapshot())
	var p: Vector3 = Vector3(4, field.height_at(Vector2(4, 11)), 11)
	var q: Vector3 = Vector3(7, field.height_at(Vector2(7, 11)), 11)
	var a: Vector2 = playground.camera_rig.camera.unproject_position(p)
	var b: Vector2 = playground.camera_rig.camera.unproject_position(q)
	var count_value: int = playground.document.state["instances"].size()
	_button(a, true, true)
	_motion(b)
	_button(b, false, true)
	assert_eq(playground.document.state["instances"].size(), count_value)
	_button(a, true)
	_motion(b)
	_button(b, false)
	await _settle()
	assert_eq(playground.document.state["instances"].size(), count_value + 1)
	playground._on_action(&"undo")
	assert_eq(playground.document.state["instances"].size(), count_value)


func test_height_lock_on_card_follows_terrain_only_when_unlocked() -> void:
	var item: Dictionary = _first("PROP-05")
	playground._select_objects(_ids(item["id"]))
	var y: float = playground._six_poses[item["id"]].origin.y
	playground.hud.object_lock.button_pressed = true
	playground._apply_object()
	await _settle()
	var draft: Dictionary = TerrainField.brush(playground.document.snapshot(), Vector2(0, 5), 0.2)
	playground._submit_async(draft, "terrain")
	await _settle()
	assert_almost_eq(playground._six_poses[item["id"]].origin.y, y, 0.00001)


func test_ui_150_percent_panels_and_dock_stay_inside_viewport() -> void:
	playground.hud.set_ui_scale(1.5)
	await get_tree().process_frame
	for panel: PanelContainer in playground.hud._panels:
		assert_lte((panel.position.y + panel.size.y) * 1.5, 800.0)
		assert_lte((panel.position.x + panel.size.x) * 1.5, 1280.0)
	assert_lte((playground.hud._dock.position.y + playground.hud._dock.size.y) * 1.5, 800.0)
	assert_lte(playground.hud._panels[0].size.y, playground.hud._dock.position.y - 16)


func test_lamp_copy_keeps_mode_and_nearest_four_remains_bounded() -> void:
	var item: Dictionary = _first("PROP-08")
	playground._select_objects(_ids(item["id"]))
	playground._on_action(&"lamp_on")
	await _settle()
	playground._on_action(&"copy")
	await _settle()
	assert_eq(playground.document.state["instances"].back()["lamp_mode"], "on")
	playground.lanterns.advance(Vector3.ZERO, 1)
	assert_lte(playground.lanterns.active_ids.size(), 4)


func test_bookmark_is_source_data_and_does_not_change_layout() -> void:
	var before: Array = playground.document.state["instances"].duplicate(true)
	playground._on_action(&"camera_bookmark")
	await _settle()
	assert_eq(playground.document.state["camera_bookmarks"][0]["id"], "user_composition")
	assert_eq(playground.document.state["instances"], before)


func test_object_selection_pending_commit_is_blocked() -> void:
	var draft: Dictionary = playground.document.snapshot()
	draft["environment"]["dusk"] = true
	playground._submit_async(draft, "light")
	playground._select_objects(_ids(_first("PROP-01")["id"]))
	assert_true(playground.tools.selected.is_empty())
	await _settle()


func test_pending_property_click_does_not_change_selected_object_or_queue_another_edit() -> void:
	var item: Dictionary = _first("PROP-08")
	playground._select_objects(_ids(item["id"]))
	playground._choose_palette("wood", "wood_sage")
	var token: int = playground.queue.newest_token
	playground._on_action(&"apply_object")
	assert_eq(playground.queue.newest_token, token)
	await _settle()
	assert_eq(_first("PROP-08"), item)


func test_geometry_preparation_failure_keeps_object_properties_and_view() -> void:
	var before: Dictionary = playground.document.snapshot()
	var draft: Dictionary = before.duplicate(true)
	draft["environment"]["palette"]["wood"] = "wood_sage"
	playground.queue.evaluator = func(_snapshot: Dictionary) -> Dictionary:
		return {"ok": false, "error": "generation_failed"}
	playground._submit_async(draft, "failure")
	await _settle()
	assert_eq(playground.document.snapshot(), before)
	assert_eq(playground._six_snapshot, before)


func test_hedge_control_edit_preserves_id_and_undo_restores_points() -> void:
	var item: Dictionary = _first("NAT-07")
	# The template places the manual polyline before any compact brush variants.
	assert_true(item.has("hedge"))
	playground._select_objects(_ids(item["id"]))
	playground._on_action(&"edit_hedge")
	assert_true(playground.session.begin_gesture())
	playground._hedge_before = playground.document.snapshot()
	playground._hedge_id = item["id"]
	playground._hedge_control = 2
	playground._update_hedge(Vector3(-5, 0, 12))
	playground._submit_async(playground.session.preview, "control")
	await _settle()
	assert_eq(_first("NAT-07")["id"], item["id"])
	assert_ne(_first("NAT-07")["hedge"]["points"], item["hedge"]["points"])
	playground._on_action(&"undo")
	assert_eq(_first("NAT-07")["hedge"]["points"], item["hedge"]["points"])


func _ids(key: String) -> Array[String]:
	return [key]
