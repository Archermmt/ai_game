extends GutTest

var playground: Node3D
var viewport: SubViewport


func before_each() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.own_world_3d = true
	add_child_autofree(viewport)
	playground = load("res://app/week_four_root.tscn").instantiate() as Node3D
	viewport.add_child(playground)
	await get_tree().process_frame


func _settle() -> void:
	for i: int in range(1200):
		if not playground.queue.is_busy():
			return
		await get_tree().process_frame
	fail_test("W04 worker did not settle")


func test_w04_scene_has_formal_assets_terrain_and_bounded_ui() -> void:
	assert_eq(WorldDocument.validate(playground.document.snapshot()), "")
	assert_eq(playground.document.state["terrain"]["base_profile"], "forest_slope_v1")
	assert_eq(playground._w4_kinds.size(), 8)
	assert_lt(playground.hud.buttons["cancel"].get_global_rect().end.y, 800.0)
	assert_true(playground.hud.buttons.has("smooth"))
	assert_true(playground.hud.buttons.has("place_opening"))
	assert_true(playground.hud.buttons.has("apply_path"))


func test_path_node_drag_is_one_transaction_and_escape_preserves_source() -> void:
	var id_value: String = playground.document.state["paths"][0]["id"]
	playground.selected_path = id_value
	playground._on_action(&"path_node")
	var source: Dictionary = playground.document.snapshot()
	var p: Array = source["paths"][0]["points"][0]
	var first: Vector2 = playground.camera_rig.camera.unproject_position(Vector3(p[0], -0.1, p[2]))
	var last: Vector2 = playground.camera_rig.camera.unproject_position(
		Vector3(p[0] + 0.6, -0.1, p[2] + 0.5)
	)
	_motion(first)
	_button(first, true)
	_motion(last)
	_button(last, false)
	await _settle()
	assert_eq(playground.session.history_count(), 1)
	assert_ne(playground.document.state["paths"][0]["points"], source["paths"][0]["points"])
	playground._on_action(&"undo")
	assert_eq_deep(playground.document.state["paths"], source["paths"])
	_motion(first)
	_button(first, true)
	_motion(last)
	playground._on_action(&"cancel")
	await _settle()
	assert_eq_deep(playground.document.state["paths"], source["paths"])


func test_auto_entry_delete_road_undo_and_locked_preservation_through_ui() -> void:
	var draft: Dictionary = playground.document.snapshot()
	var home: Dictionary = WorldDocument.allocate_building(
		draft, Vector3(6, 0, 11), Vector3(5, 3, 5)
	)
	var road: String = PathGeometry.allocate(draft, [[6, 0, 18], [6, 0, 13.5]])
	playground._submit_async(draft, "road and bare home")
	await _settle()
	assert_eq(playground.document.state["buildings"].back()["openings"].size(), 1)
	playground.selected_path = road
	playground._on_action(&"delete_path")
	await _settle()
	assert_true(playground.document.state["buildings"].back()["openings"].is_empty())
	playground._on_action(&"undo")
	var selected: Array[String] = [home["id"]]
	playground._select_buildings(selected)
	playground._refresh_inspector()
	playground._on_action(&"lock_opening")
	await _settle()
	playground.selected_path = road
	playground._on_action(&"delete_path")
	await _settle()
	assert_true(playground.document.state["buildings"].back()["openings"][0]["locked"])


func test_manual_window_gesture_rejects_conflicting_placement_and_keeps_history() -> void:
	var before: Dictionary = playground.document.snapshot()
	playground.opening_variant = 3
	playground._on_action(&"place_opening")
	# Existing front window: placing another at the same wall region is rejected.
	var point: Vector2 = playground.camera_rig.camera.unproject_position(Vector3(1.4, 0, 1.5))
	_motion(point)
	_button(point, true)
	_button(point, false)
	await _settle()
	assert_eq(playground.session.history_count(), 0)
	assert_eq_deep(playground.document.snapshot(), before)


func test_new_terrain_brush_undo_restores_delta_and_far_tree_node() -> void:
	var before: Dictionary = playground.document.snapshot()
	var key: String = before["instances"].back()["id"]
	var node_id: int = playground._instance_views[key].get_instance_id()
	var draft: Dictionary = TerrainEdits.stroke(before, Vector2(12, 10), "raise")
	playground._submit_async(draft, "raise")
	await _settle()
	assert_eq(playground._instance_views[key].get_instance_id(), node_id)
	playground._on_action(&"undo")
	assert_eq_deep(playground.document.state["terrain"], before["terrain"])


func test_lighting_transition_is_smooth_and_local_lights_never_exceed_four() -> void:
	playground._on_action(&"light")
	assert_eq(playground._light_target, 1.0)
	assert_lt(playground._light_mix, 0.1)
	playground._advance_light(0.6)
	assert_gt(playground._light_mix, 0.3)
	assert_lt(playground._light_mix, 0.8)
	playground._advance_light(1.0)
	assert_almost_eq(playground._light_mix, 1.0, 0.001)
	assert_eq(playground.light_rig.active_ids.size(), 4)
	assert_almost_eq(playground.window_material.get_shader_parameter("dusk_mix"), 1.0, 0.001)
	playground._on_action(&"undo")
	playground._advance_light(2)
	assert_true(playground.light_rig.active_ids.is_empty())


func test_shared_wind_direction_and_reduce_motion_reach_all_asset_materials() -> void:
	playground._environment_value("wind_direction", 1.8)
	await _settle()
	playground._on_action(&"wind")
	for material: ShaderMaterial in playground.wind_materials:
		assert_almost_eq(material.get_shader_parameter("wind_direction"), 1.8, 0.001)
		assert_true(material.get_shader_parameter("reduce_motion"))


func test_path_change_emits_local_bounds_covering_old_and_new_control_points() -> void:
	watch_signals(playground)
	var draft: Dictionary = playground.document.snapshot()
	var before: Array = draft["paths"][0]["points"][0].duplicate()
	draft["paths"][0]["points"][0] = [-4, 0, 9]
	playground._submit_async(draft, "move path")
	await _settle()
	assert_signal_emitted(playground, "dependencies_changed")
	var args: Array = get_signal_parameters(playground, "dependencies_changed")
	assert_true(args[0].has_point(Vector2(before[0], before[2])))
	assert_true(args[0].has_point(Vector2(-4, 9)))


func test_visible_preview_failure_restores_doors_paths_and_scene() -> void:
	var before: Dictionary = playground.document.snapshot()
	playground.selected_path = before["paths"][0]["id"]
	playground._on_action(&"path_node")
	assert_true(playground.session.begin_gesture())
	var draft: Dictionary = before.duplicate(true)
	draft["paths"][0]["points"][0] = [-3, 0, 10]
	playground.session.update_gesture(draft)
	playground._preview_linked()
	await _settle()
	assert_true(playground._preview_visible)
	playground.queue.evaluator = func(_snapshot: Dictionary) -> Dictionary:
		return {"ok": false, "error": "injected W04 prepare failure"}
	playground._submit_async(playground.session.preview, "failed")
	await _settle()
	assert_eq_deep(playground.document.snapshot(), before)
	assert_false(playground._preview_visible)
	assert_eq(playground.session.history_count(), 0)


func test_option_orbit_and_pinch_do_not_paint_in_new_tools() -> void:
	var before: Dictionary = playground.document.snapshot()
	var point: Vector2 = Vector2(700, 400)
	for mode: StringName in [
		&"place_asset",
		&"place_opening",
		&"move_opening",
		&"path_node",
		&"fence",
		&"smooth",
		&"restore"
	]:
		playground._on_action(mode)
		_motion(point)
		_button(point, true, true)
		_motion(point, Vector2(15, 0))
		_button(point, false)
		var event: InputEventMagnifyGesture = InputEventMagnifyGesture.new()
		event.position = point
		event.factor = 1.1
		viewport.push_input(event, true)
	assert_eq_deep(playground.document.snapshot(), before)
	assert_eq(playground.session.history_count(), 0)


func test_asset_place_uses_selected_model_and_undo_removes_same_id() -> void:
	var before: int = playground.document.state["instances"].size()
	playground.selected_asset = "PROP-02"
	playground._on_action(&"place_asset")
	var point: Vector2 = playground.camera_rig.camera.unproject_position(Vector3(0, 0, 10))
	_motion(point)
	_button(point, true)
	_button(point, false)
	await _settle()
	assert_eq(playground.document.state["instances"].size(), before + 1)
	assert_eq(playground.document.state["instances"].back()["asset_id"], "PROP-02")
	playground._on_action(&"undo")
	assert_eq(playground.document.state["instances"].size(), before)


func test_fence_drag_is_one_history_and_undo_restores_source() -> void:
	playground._on_action(&"fence")
	var a: Vector2 = playground.camera_rig.camera.unproject_position(Vector3(-1, 0, 10))
	var b: Vector2 = playground.camera_rig.camera.unproject_position(Vector3(3, 0, 10))
	_motion(a)
	_button(a, true)
	_motion(b)
	_button(b, false)
	await _settle()
	assert_eq(playground.document.state["fences"].size(), 1)
	assert_eq(playground.session.history_count(), 1)
	assert_eq(playground.fence_root.get_child_count(), 1)
	playground._on_action(&"undo")
	assert_true(playground.document.state.get("fences", []).is_empty())


func _motion(point: Vector2, relative: Vector2 = Vector2.ZERO) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = point
	event.relative = relative
	viewport.push_input(event, true)


func _button(point: Vector2, pressed: bool, alt: bool = false) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.alt_pressed = alt
	viewport.push_input(event, true)


func test_missing_control_and_zero_length_fence_do_not_consume_history() -> void:
	var before: Dictionary = playground.document.snapshot()
	for mode: StringName in [&"path_node", &"fence"]:
		playground._on_action(mode)
		var point: Vector2 = playground.camera_rig.camera.unproject_position(Vector3(0, 0, 10))
		_motion(point)
		_button(point, true)
		_button(point, false)
		await _settle()
	assert_eq_deep(playground.document.snapshot(), before)
	assert_eq(playground.session.history_count(), 0)


func test_custom_release_over_toolbar_cancels_visible_asset_preview() -> void:
	var before: Dictionary = playground.document.snapshot()
	playground._on_action(&"place_asset")
	var point: Vector2 = playground.camera_rig.camera.unproject_position(Vector3(0, 0, 10))
	_motion(point)
	_button(point, true)
	await _settle()
	assert_true(playground._preview_visible)
	var toolbar: Vector2 = playground.hud.buttons["save"].get_global_rect().get_center()
	_motion(toolbar)
	_button(toolbar, false)
	await _settle()
	assert_eq_deep(playground.document.snapshot(), before)
	assert_eq(playground.session.history_count(), 0)
	assert_false(playground._custom_drag)


func test_nature_instances_align_up_to_slope_without_changing_source_yaw() -> void:
	for item: Dictionary in playground.document.state["instances"]:
		if item["asset_id"] not in ["NAT-04", "NAT-05", "NAT-06", "NAT-08", "NAT-09"]:
			continue
		var view: Node3D = playground._instance_views[item["id"]]
		var p: Array = item["position"]
		var normal: Vector3 = playground._field.normal_at(Vector2(p[0], p[2]))
		assert_gt(view.basis.y.normalized().dot(normal), 0.999)
		assert_almost_eq(item["yaw"], 0.0, 0.001)
