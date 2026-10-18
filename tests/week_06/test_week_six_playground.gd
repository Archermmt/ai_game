extends "res://tests/week_06/playground_test_base.gd"


func test_scene_has_real_tea_lantern_and_classified_tools() -> void:
	assert_eq(WorldDocument.validate(playground.document.snapshot()), "")
	assert_true(playground.tools is WeekSixTools)
	assert_true(playground.hud.buttons.has("plant_brush"))
	assert_true(playground.hud.buttons.has("lamp_auto"))
	assert_eq(playground.lanterns.lights.size(), 2)
	assert_true(playground.document.state["environment"]["lamp_probes"].is_empty())


func test_commit_keeps_document_unchanged_until_all_preparation_finishes() -> void:
	var before: Dictionary = playground.document.snapshot()
	var draft: Dictionary = TerrainEdits.stroke(before, Vector2(18, -18), "raise")
	playground._submit_async(draft, "terrain")
	assert_eq(playground.session.phase, EditSession.Phase.PENDING_COMMIT)
	assert_eq_deep(playground.document.snapshot(), before)
	assert_eq(playground.session.history_count(), 0)
	await _settle()
	assert_eq(playground.session.phase, EditSession.Phase.IDLE)
	assert_ne(playground.document.state["terrain"], before["terrain"])
	assert_eq(playground.session.history_count(), 1)


func test_local_edit_reuses_distant_buildings_water_and_props_nodes() -> void:
	var water: ArrayMesh = playground.water_view.mesh
	var home: Node = playground._live_units[
		"building:" + playground.document.state["buildings"][0]["id"]
	]
	var views: Dictionary = playground._instance_views.duplicate()
	playground._submit_async(
		TerrainEdits.stroke(playground.document.snapshot(), Vector2(18, -18), "raise"), "terrain"
	)
	await _settle()
	assert_same(playground.water_view.mesh, water)
	assert_same(
		playground._live_units["building:" + playground.document.state["buildings"][0]["id"]], home
	)
	for key: String in views:
		assert_same(playground._instance_views[key], views[key])
	assert_lt(playground._terrain_rebuilt, 8)


func test_cancel_pending_resources_preserves_source_history_and_scene() -> void:
	var before: Dictionary = playground.document.snapshot()
	playground._submit_async(TerrainEdits.stroke(before, Vector2(16, -16), "raise"), "terrain")
	playground._on_action(&"cancel")
	await _settle()
	assert_eq_deep(playground.document.snapshot(), before)
	assert_eq(playground.session.history_count(), 0)
	assert_false(playground.stage.is_busy())


func test_brush_commit_builds_spatial_multimeshes_and_undo_restores() -> void:
	var draft: Dictionary = playground.document.snapshot()
	VegetationBrush.paint(draft, Vector2(14, 10), "plants", 4, 1, {})
	playground._submit_async(draft, "plants")
	await _settle()
	assert_gt(playground._batch_count, 0)
	var batches: Array = playground.instance_root.find_children(
		"*", "MultiMeshInstance3D", true, false
	)
	assert_gt(batches.size(), 0)
	for node: MultiMeshInstance3D in batches:
		assert_true(node.multimesh.use_custom_data)
		assert_gt(node.multimesh.instance_count, 0)
	playground._on_action(&"undo")
	assert_eq(playground._batch_count, 0)
	playground._on_action(&"redo")
	assert_gt(playground._batch_count, 0)


func test_actual_mouse_brush_is_one_history_transaction() -> void:
	playground._on_action(&"plant_brush")
	var p: Vector2 = playground.camera_rig.camera.unproject_position(Vector3(0, 0, 10))
	_motion(p)
	_button(p, true)
	_motion(p + Vector2(25, 0))
	_button(p + Vector2(25, 0), false)
	await _settle()
	assert_eq(playground.session.history_count(), 1)
	assert_gt(playground._batch_count, 0)


func test_option_left_camera_modifier_does_not_paint() -> void:
	playground._on_action(&"plant_brush")
	var before: Dictionary = playground.document.snapshot()
	_button(Vector2(650, 450), true, true)
	_button(Vector2(680, 470), false, true)
	await _settle()
	assert_eq_deep(playground.document.snapshot(), before)
	assert_eq(playground.session.history_count(), 0)


func test_ctrl_wheel_changes_brush_radius_without_editing_source() -> void:
	playground._on_action(&"plant_brush")
	var before: Dictionary = playground.document.snapshot()
	var wheel: InputEventMouseButton = InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.ctrl_pressed = true
	playground._unhandled_input(wheel)
	assert_eq(playground.tools.radius, 2.75)
	assert_eq_deep(playground.document.snapshot(), before)


func test_environment_only_commit_retains_all_world_units() -> void:
	var units: Dictionary = playground._live_units.duplicate()
	var draft: Dictionary = playground.document.snapshot()
	draft["environment"]["wind_strength"] = 0
	playground._submit_async(draft, "wind")
	await _settle()
	for key: String in units:
		assert_eq(playground._live_units[key], units[key], key)
	assert_true(playground._last_generated.is_empty())


func test_real_lantern_manual_on_off_modes_and_nearest_four_limit() -> void:
	var draft: Dictionary = playground.document.snapshot()
	for i: int in range(6):
		var item: Dictionary = InstanceEdits.allocate(draft, Vector3(-10 + i * 0.6, 0, 9))
		item["asset_id"] = "PROP-08"
		item["lamp_mode"] = "on"
	playground._submit_async(draft, "lamps")
	await _settle()
	playground._advance_light(0)
	assert_eq(playground.lanterns.active_ids.size(), 4)
	assert_eq(playground.lanterns.lights.size(), 8)
	var lamp: Dictionary = draft["instances"].back()
	var view: Node = playground._instance_views[lamp["id"]]
	var panes: Array = view.find_children("lamp_emission*", "MeshInstance3D", true, false)
	assert_eq(panes.size(), 4)
	for pane: MeshInstance3D in panes:
		assert_gt(pane.material_override.emission_energy_multiplier, 0.0)
