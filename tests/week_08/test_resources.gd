extends "res://tests/week_08/playground_test_base.gd"


func test_repeated_object_sync_preserves_in_progress_spinbox_text() -> void:
	var ids: Array[String] = [playground.document.state["instances"][0]["id"]]
	playground._select_objects(ids)
	playground.hud.object_x.value = 12.3
	playground.hud.sync_objects(playground.document.snapshot(), ids)
	assert_almost_eq(playground.hud.object_x.value, 12.3, 0.00001)


func test_cached_batch_parts_share_meshes_and_materials_between_cells() -> void:
	var parts: Array[Dictionary] = FoliageBatches.describe(
		"NAT-04", playground.wood_material, playground.stone_material
	)
	var item: Dictionary = {"id": "a", "seed": "a", "asset_id": "NAT-04", "position": [0, 0, 0]}
	var a: Node3D = FoliageBatches.build(
		[item],
		{"a": Transform3D.IDENTITY},
		playground.wood_material,
		playground.stone_material,
		parts
	)
	var b: Node3D = FoliageBatches.build(
		[item],
		{"a": Transform3D.IDENTITY},
		playground.wood_material,
		playground.stone_material,
		parts
	)
	assert_same(a.get_child(0).multimesh.mesh, b.get_child(0).multimesh.mesh)
	assert_same(a.get_child(0).material_override, b.get_child(0).material_override)
	a.free()
	b.free()


func test_repeated_cancel_frees_all_detached_stage_nodes() -> void:
	var original: Dictionary = playground.document.snapshot()
	playground.stage.budget_usec = 1
	for i: int in range(8):
		var draft: Dictionary = ForestTemplate.empty()
		draft["revision"] = original["revision"]
		HedgeRules.allocate(draft, [[-3, -3], [-1, -3]])
		HedgeRules.allocate(draft, [[2, 2], [4, 2]])
		playground._submit_async(draft, "cancel after allocation")
		var started: int = Time.get_ticks_msec()
		while playground.stage._owned.is_empty() and Time.get_ticks_msec() - started < 5000:
			await get_tree().process_frame
		var allocated: Array = playground.stage._owned.duplicate()
		assert_gt(allocated.size(), 0, "A real detached node must exist before cancel")
		assert_eq_deep(playground.document.snapshot(), original)
		playground._on_action(&"cancel")
		for node: Variant in allocated:
			assert_false(is_instance_valid(node))
		await _settle()
		assert_eq_deep(playground.document.snapshot(), original)
		assert_eq(playground.stage._owned.size(), 0)


func test_frozen_layouts_are_valid_source_and_share_ground_periphery() -> void:
	var filled: Dictionary = preload("res://levels/forest_slope/scn_01_filled.tres").snapshot()
	var empty: Dictionary = preload("res://levels/forest_slope/scn_01_empty.tres").snapshot()
	assert_eq(WorldDocument.validate(filled), "")
	assert_eq(WorldDocument.validate(empty), "")
	assert_eq_deep(filled, ForestTemplate.create())
	assert_eq_deep(empty, ForestTemplate.empty())
	assert_eq_deep(filled["terrain"], empty["terrain"])
	assert_eq_deep(filled["camera_bookmarks"], empty["camera_bookmarks"])
	assert_eq(empty["instances"].size(), 12)
	for i: int in range(12):
		assert_eq_deep(filled["instances"][i], empty["instances"][i])
	assert_false(filled.has("generated_cache"))


func test_prepared_replacement_rejects_mismatched_source_without_publication() -> void:
	var before: Dictionary = playground.document.snapshot()
	var candidate: Dictionary = ForestTemplate.empty()
	var result: Dictionary = playground.session.replace_prepared(
		candidate, {"ok": true, "source": before}
	)
	assert_false(result["ok"])
	assert_eq_deep(playground.document.snapshot(), before)


func test_property_card_cache_invalidates_when_source_changes() -> void:
	var draft: Dictionary = playground.document.snapshot()
	InstanceEdits.allocate(draft, Vector3(16, 0, -16))["asset_id"] = "PROP-05"
	var count_value: int = playground.hud.instance_list.item_count
	var selected: Array[String] = []
	playground.hud.sync_objects(draft, selected)
	assert_eq(playground.hud.instance_list.item_count, count_value + 1)


func test_settings_window_captures_new_shortcut_and_escape_cancels_capture() -> void:
	var hud: CanvasLayer = playground.hud
	hud.settings.popup_centered()
	hud._binding_buttons["save_work"].pressed.emit()
	var event: InputEventKey = InputEventKey.new()
	event.keycode = KEY_K
	event.alt_pressed = true
	event.pressed = true
	hud.settings.window_input.emit(event)
	assert_eq(hud._binding, "")
	assert_true(InputMap.action_get_events("save_work")[0].is_match(event))
	hud._binding_buttons["load_work"].pressed.emit()
	event.keycode = KEY_ESCAPE
	hud.settings.window_input.emit(event)
	assert_false(playground.preferences.values["bindings"].has("load_work"))
	hud.settings.hide()


func test_typing_in_object_properties_does_not_trigger_scene_shortcuts() -> void:
	var before: Dictionary = playground.document.snapshot()
	var edit: LineEdit = playground.hud.object_x.get_line_edit()
	edit.grab_focus()
	var event: InputEventKey = InputEventKey.new()
	event.keycode = KEY_S
	event.meta_pressed = true
	event.pressed = true
	playground._unhandled_input(event)
	assert_false(playground.saves.is_busy())
	assert_eq_deep(playground.document.snapshot(), before)


func test_exit_confirmation_never_allows_autosave_to_choose_for_user() -> void:
	playground._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	playground.idle_seconds = 61
	playground.autosave_seconds = 61
	playground._process(0.0)
	assert_false(playground.saves.is_busy())
	assert_eq(playground._intent, "quit")
	playground._decision_made("cancel")
	playground.hud.decision.hide()


func test_new_session_catalog_reserves_only_an_empty_slot_for_autosave() -> void:
	for i: int in range(3):
		SlotStore.write_slot(playground.saves.directory, i, ForestTemplate.empty(), "旧作%d" % i)
	playground.active_slot = -1
	playground._save_completed(
		"catalog", {"ok": true, "slots": SlotStore.catalog(playground.saves.directory)}
	)
	assert_eq(playground.active_slot, 3)
	playground.idle_seconds = 61
	playground.autosave_seconds = 61
	playground._process(0.0)
	await _settle()
	assert_true(
		SlotStore.read_slot(playground.saves.directory, 0)["snapshot"]["buildings"].is_empty()
	)
	assert_eq(SlotStore.read_slot(playground.saves.directory, 3)["snapshot"]["buildings"].size(), 2)


func test_full_library_does_not_autosave_template_over_existing_work() -> void:
	for i: int in range(5):
		SlotStore.write_slot(playground.saves.directory, i, ForestTemplate.empty(), "旧作%d" % i)
	playground.active_slot = -1
	playground._save_completed(
		"catalog", {"ok": true, "slots": SlotStore.catalog(playground.saves.directory)}
	)
	assert_eq(playground.active_slot, -1)
	playground.idle_seconds = 61
	playground.autosave_seconds = 61
	playground._process(0.0)
	assert_false(playground.saves.is_busy())
	for i: int in range(5):
		assert_eq(
			SlotStore.read_slot(playground.saves.directory, i)["metadata"]["title"], "旧作%d" % i
		)


func test_status_feedback_is_visible_outside_scrolling_tools_at_150_percent() -> void:
	playground._preference_changed("ui_scale", 1.5)
	await get_tree().process_frame
	var panel: PanelContainer = playground.hud._feedback
	assert_eq(playground.hud.status_label.get_parent(), panel)
	assert_lt(panel.get_global_rect().end.y, float(viewport.size.y) - 100)
	assert_gt(panel.get_global_transform_with_canvas().origin.x, 450.0)
	assert_eq(panel.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_tree_submeshes_share_shader_without_sharing_seed_state_between_trees() -> void:
	var a: Node3D = VegetationCatalog.instantiate_asset("NAT-01", "seed-a")
	var b: Node3D = VegetationCatalog.instantiate_asset("NAT-01", "seed-b")
	var first: ShaderMaterial = (
		a.find_children("*", "MeshInstance3D", true, false)[0].material_override
	)
	for part: MeshInstance3D in a.find_children("*", "MeshInstance3D", true, false):
		assert_same(part.material_override, first)
	var other: ShaderMaterial = (
		b.find_children("*", "MeshInstance3D", true, false)[0].material_override
	)
	assert_not_same(first, other)
	assert_ne(first.get_shader_parameter("phase"), other.get_shader_parameter("phase"))
	a.free()
	b.free()
