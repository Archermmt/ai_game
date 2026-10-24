extends "res://tests/garden_presentation/playground_test_base.gd"


func test_default_ribbon_replaces_large_panels_and_is_within_viewport() -> void:
	for panel: PanelContainer in playground.hud._panels:
		assert_false(panel.visible)
	assert_false(playground.hud.context.visible)
	assert_false(playground.hud._feedback.visible)
	assert_eq(playground.hud.ribbon_buttons.size(), 12)
	assert_true(
		Rect2(Vector2.ZERO, Vector2(viewport.size)).encloses(playground.hud._dock.get_global_rect())
	)
	assert_eq(playground.tools.mode, "inspect")


func test_every_category_opens_and_closes_without_source_or_history_edits() -> void:
	var before: Dictionary = playground.document.snapshot()
	for key: String in playground.hud.ribbon_buttons:
		if key == "photo":
			continue
		playground.hud.ribbon_buttons[key].pressed.emit()
		assert_true(playground.hud.context.visible)
		assert_eq(playground.hud.group, key)
		playground.hud.open_group(key)
		assert_false(playground.hud.context.visible)
	assert_eq_deep(playground.document.state, before)
	assert_eq(playground.session.history_count(), 0)


func test_density_drag_changes_draw_count_without_regeneration_or_source_edits() -> void:
	var before: Dictionary = playground.document.snapshot()
	var batches: Array = playground.meadow.batches.duplicate()
	var transforms: Transform3D = batches[0].multimesh.get_instance_transform(0)
	playground.hud.open_group("plants")
	for density: float in [0.0, 0.2, 0.6, 1.0, 0.45]:
		playground.hud.grass_slider.value = density
		var count: int = playground.meadow.visible_count()
		assert_almost_eq(float(count), floor(playground.meadow.total * density), 36.0)
		assert_false(playground.meadow.is_busy())
		assert_eq(playground.meadow.batches, batches)
		assert_eq(batches[0].multimesh.get_instance_transform(0), transforms)
	assert_eq_deep(playground.document.state, before)
	assert_eq(playground.session.history_count(), 0)


func test_reduced_motion_stops_grass_and_photo_freeze_restores_it() -> void:
	playground._preference_changed("reduce_motion", true)
	assert_true(playground.meadow.material.get_shader_parameter("reduce_motion"))
	playground._preference_changed("reduce_motion", false)
	assert_false(playground.meadow.material.get_shader_parameter("reduce_motion"))
	assert_true(playground.enter_photo())
	assert_true(playground.meadow.material.get_shader_parameter("freeze_time"))
	assert_false(playground.hud._dock.visible)
	assert_false(playground.hud.utilities.visible)
	playground.exit_photo()
	assert_false(playground.meadow.material.get_shader_parameter("freeze_time"))
	assert_true(playground.hud._dock.visible)
	assert_true(playground.hud.utilities.visible)


func test_focus_tracks_camera_zoom_and_can_be_disabled() -> void:
	var before: Dictionary = playground.document.snapshot()
	assert_true(playground.camera_rig.camera.attributes.dof_blur_far_enabled)
	playground.camera_rig._zoom(0.7)
	playground._update_focus()
	assert_almost_eq(
		playground.camera_rig.camera.attributes.dof_blur_far_distance,
		playground.camera_rig.distance + 6,
		0.001
	)
	playground.hud.dof_control.toggled.emit(false)
	assert_false(playground.camera_rig.camera.attributes.dof_blur_far_enabled)
	assert_false(playground.preferences.values["garden_focus"])
	assert_eq_deep(playground.document.state, before)


func test_ribbon_and_context_remain_visible_at_150_percent() -> void:
	playground._preference_changed("ui_scale", 1.5)
	playground.hud.open_group("plants")
	await get_tree().process_frame
	var bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(viewport.size))
	assert_true(bounds.encloses(playground.hud._dock.get_global_rect()))
	assert_true(bounds.encloses(playground.hud.context.get_global_rect()))
	assert_true(playground.hud.grass_slider.is_visible_in_tree())


func test_real_category_tool_button_routes_into_transactional_creation() -> void:
	playground.hud.open_group("build")
	playground.hud._choices.get_child(1).pressed.emit()
	assert_eq(playground.tools.mode, "round")
	var before: Dictionary = playground.document.snapshot()
	var draft: Dictionary = before.duplicate(true)
	WorldDocument.allocate_building(draft, Vector3(17, 0.4, -17), Vector3(3, 3, 3), "round")
	playground._submit_async(draft, "garden create")
	await _settle()
	assert_eq(playground.document.state["buildings"].size(), before["buildings"].size() + 1)
	playground._on_action(&"undo")
	await _settle()
	assert_true(_same(playground.document.state, before))


func test_edit_click_selects_building_and_opens_its_properties() -> void:
	var home: Dictionary = playground.document.state["buildings"][0]
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = playground.camera_rig.camera.unproject_position(
		Vector3(home["position"][0], home["position"][1] + 2, home["position"][2])
	)
	playground._on_action(&"select")
	playground._unhandled_input(event)
	assert_true(home["id"] in playground.selected_buildings)
	assert_eq(playground.hud.group, "build")


func test_save_load_keeps_manual_objects_and_density_stays_local() -> void:
	var source: Dictionary = playground.document.snapshot()
	playground._preference_changed("grass_density", 0.2)
	playground._start_save(0, "草地与底栏")
	await _settle()
	playground._preference_changed("grass_density", 0.9)
	playground._start_load(0)
	await _settle()
	assert_true(_same(playground.document.state, source))
	assert_eq(playground.meadow.density, 0.9)
	assert_false(playground.document.state.has("grass_density"))


func test_latest_meadow_wins_after_two_source_replacements() -> void:
	var source: Dictionary = playground.document.snapshot()
	var a: Dictionary = source.duplicate(true)
	a["world_seed"] = "grass-old"
	var b: Dictionary = source.duplicate(true)
	b["world_seed"] = "grass-latest"
	playground.meadow.request(a)
	playground.meadow.request(b)
	await _settle()
	assert_eq(playground.meadow._signature, MeadowData.signature(b))
	assert_eq(playground.meadow.total, MeadowData.generate(b)["count"])


func test_zero_density_does_not_lose_manual_plants_or_visible_sources() -> void:
	var source: Dictionary = playground.document.snapshot()
	playground._preference_changed("grass_density", 0.0)
	assert_eq(playground.meadow.visible_count(), 0)
	assert_eq_deep(playground.document.state["instances"], source["instances"])
	assert_gt(playground._live_units.size(), 0)


func test_modification_entry_does_not_cancel_a_pending_released_commit() -> void:
	var draft: Dictionary = TerrainField.brush(
		playground.document.snapshot(), Vector2(18, 18), 0.02
	)
	assert_true(playground.session.reserve_commit(draft, "pending")["ok"])
	playground._on_action(&"select")
	assert_eq(playground.session.phase, EditSession.Phase.PENDING_COMMIT)
	playground.session.cancel_gesture()


func test_zero_density_initial_renderer_allocates_no_batches_until_enabled() -> void:
	var renderer: MeadowRenderer = MeadowRenderer.new()
	add_child_autofree(renderer)
	renderer.set_density(0)
	renderer.request(playground.document.state)
	assert_false(renderer.is_busy())
	assert_eq(renderer.batches.size(), 0)
	renderer.set_density(0.2)
	var started: int = Time.get_ticks_msec()
	while renderer.is_busy() and Time.get_ticks_msec() - started < 10000:
		await get_tree().process_frame
	assert_false(renderer.is_busy())
	assert_gt(renderer.visible_count(), 0)


func test_enable_after_editing_while_disabled_rebuilds_latest_clearances() -> void:
	playground._preference_changed("grass_density", 0.0)
	var source: Dictionary = playground.document.snapshot()
	WorldDocument.allocate_building(source, Vector3(17, 0.4, -17), Vector3(3, 3, 3))
	playground._submit_async(source, "build while grass off")
	await _settle()
	assert_eq(playground.meadow.visible_count(), 0)
	playground._preference_changed("grass_density", 0.45)
	await _settle()
	var expected: Dictionary = MeadowData.generate(playground.document.state)
	assert_eq(playground.meadow.total, expected["count"])
	assert_gt(playground.meadow.visible_count(), 0)
	for batch: MultiMeshInstance3D in playground.meadow.batches:
		var valid: bool = true
		for i: int in range(batch.multimesh.instance_count):
			var p: Vector3 = batch.multimesh.get_instance_transform(i).origin + batch.position
			if TerrainField.conflicts(Vector2(p.x, p.z), 0.1, source["buildings"].back()):
				valid = false
		assert_true(valid)


func test_scene_modification_uses_visible_prop_proxy_and_opens_object_fields() -> void:
	var source: Dictionary = ArtLayout.empty()
	var item: Dictionary = InstanceEdits.allocate(source, Vector3.ZERO)
	item["asset_id"] = "PROP-02"
	assert_true(playground.session.replace_document(source, playground._prepare_views)["ok"])
	await _settle()
	var wrapper: Node3D = playground._instance_views[item["id"]]
	var shapes: Array[Node] = wrapper.find_children("*", "CollisionShape3D", true, false)
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = playground.camera_rig.camera.unproject_position(shapes[0].global_position)
	playground._on_action(&"select")
	playground._unhandled_input(event)
	assert_eq(playground.tools.selected, [item["id"]])
	assert_eq(playground.hud.group, "edit")
