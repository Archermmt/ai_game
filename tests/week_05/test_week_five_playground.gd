extends GutTest

var playground: Node3D
var viewport: SubViewport


func before_each() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.own_world_3d = true
	add_child_autofree(viewport)
	playground = load("res://app/week_five_root.tscn").instantiate() as Node3D
	viewport.add_child(playground)
	await get_tree().process_frame


func settle() -> void:
	for i: int in range(3000):
		if not playground.queue.is_busy():
			return
		await get_tree().process_frame
	fail_test("W05 queue failed to settle")


func test_scene_uses_polygon_water_real_props_and_bridge() -> void:
	assert_eq(WorldDocument.validate(playground.document.snapshot()), "")
	assert_true(playground.document.state["pool"].has("outline"))
	assert_true(playground.water_view.mesh is ArrayMesh)
	assert_eq(playground.document.state["bridges"].size(), 1)
	assert_gt(playground.structure_root.get_child_count(), 0)
	assert_true(playground.hud.buttons.has("shore"))
	assert_true(playground.hud.buttons.has("confirm_garden"))
	var count: int = 0
	for node: Node in playground.instance_root.get_children():
		if node.has_meta("w05_asset"):
			count += 1
	assert_eq(count, 4)


func test_bridge_drag_is_preview_until_explicit_confirmation() -> void:
	playground._on_action(&"bridge")
	playground.session.begin_gesture()
	playground._five_before = playground.document.snapshot()
	playground.drag_start = Vector3(6.8, 0, -3)
	playground._update_garden(Vector3(6.8, 0, 2))
	await settle()
	assert_eq(playground.document.state["bridges"].size(), 1)
	assert_eq(playground.session.phase, EditSession.Phase.PREVIEW)
	playground._on_action(&"confirm_garden")
	await settle()
	assert_eq(playground.document.state["bridges"].size(), 2)
	assert_eq(playground.session.history_count(), 1)
	playground._on_action(&"undo")
	assert_eq(playground.document.state["bridges"].size(), 1)


func test_invalid_bridge_confirmation_keeps_original_geometry() -> void:
	var before: Dictionary = playground.document.snapshot()
	playground._on_action(&"bridge")
	playground.session.begin_gesture()
	playground._five_before = before
	playground.drag_start = Vector3(7, 0, 0)
	playground._update_garden(Vector3(7, 0, 0.5))
	playground._on_action(&"confirm_garden")
	await settle()
	assert_eq_deep(playground.document.snapshot(), before)
	assert_eq(playground.session.history_count(), 0)


func test_cancel_pending_pond_keeps_source_and_history() -> void:
	var before: Dictionary = playground.document.snapshot()
	var draft: Dictionary = PondShape.draw(before, [[5, -3], [9, -3], [9, 2], [5, 2]])
	playground._submit_async(draft, "pond")
	playground._on_action(&"cancel")
	await settle()
	assert_eq_deep(playground.document.snapshot(), before)
	assert_eq(playground.session.history_count(), 0)


func test_invalid_bridge_remains_listed_after_pond_delete_and_undo() -> void:
	playground._on_action(&"delete_pool")
	await settle()
	assert_true(playground.document.state["pool"].is_empty())
	assert_eq(playground.document.state["bridges"].size(), 1)
	assert_eq(playground._structure_issues.size(), 1)
	assert_gt(playground.structure_root.get_child_count(), 0)
	assert_string_contains(playground.hud.garden_list.get_item_text(0), "调整")
	playground._on_action(&"undo")
	assert_true(playground._structure_issues.is_empty())
	assert_true(playground.water_view.visible)


func test_fence_freehand_records_turns_and_closed_flag_one_transaction() -> void:
	playground._on_action(&"fence")
	playground.session.begin_gesture()
	playground._five_before = playground.document.snapshot()
	playground._fence_points = [[-12.0, 0, 4.0]]
	for p: Vector3 in [
		Vector3(-9, 0, 4), Vector3(-9, 0, 7), Vector3(-12, 0, 7), Vector3(-12, 0, 4)
	]:
		playground._update_garden(p)
	playground._submit_async(playground.session.preview, "fence")
	await settle()
	assert_true(playground.document.state["fences"].back()["closed"])
	assert_eq(playground.document.state["fences"].back()["points"].size(), 4)
	assert_eq(playground.session.history_count(), 1)


func test_mac_option_left_does_not_start_garden_gesture() -> void:
	playground._on_action(&"shore")
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.alt_pressed = true
	event.position = Vector2(650, 450)
	playground._unhandled_input(event)
	assert_false(playground._five_drag)
	assert_eq(playground.session.phase, EditSession.Phase.IDLE)


func test_w05_save_roundtrip_includes_polygon_bridge_and_props() -> void:
	var path: String = "user://w05-suite.wgs"
	var before: Dictionary = playground.document.snapshot()
	assert_eq(SaveCodec.write_file(path, before), OK)
	var result: Dictionary = SaveCodec.read_file(path)
	assert_true(result["ok"])
	assert_eq(result["snapshot"]["bridges"].size(), 1)
	assert_eq(result["snapshot"]["pool"]["outline"].size(), 6)
	assert_eq(result["snapshot"]["instances"].size(), before["instances"].size())
	DirAccess.remove_absolute(path)


func test_invalid_shore_preserves_twenty_manual_objects_ids_and_transforms() -> void:
	var draft: Dictionary = playground.document.snapshot()
	for i: int in range(20):
		var item: Dictionary = InstanceEdits.allocate(draft, Vector3(-20 + i * 0.6, 0, -10))
		item["asset_id"] = "PROP-06"
	playground._submit_async(draft, "objects")
	await settle()
	var before: Array = playground.document.state["instances"].duplicate(true)
	draft = PondShape.draw(
		playground.document.snapshot(), [[-21, -12], [-7, -12], [-7, -8], [-21, -8]]
	)
	playground._submit_async(draft, "bad")
	await settle()
	assert_eq_deep(playground.document.state["instances"], before)
	assert_eq(playground.session.history_count(), 1)


func test_new_assets_have_source_models_and_triangle_budgets() -> void:
	for name: String in ["pot", "clothesline", "crate", "watering_can", "tea_set", "lantern"]:
		var metadata: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string("res://assets/week_05/" + name + ".asset.json")
		)
		assert_lte(metadata["triangles"], metadata["budget"])
		assert_true(FileAccess.file_exists("res://" + metadata["source"]))
		var node: Node3D = WeekFiveCatalog.create(
			metadata["asset_id"], "audit", playground.wood_material, playground.stone_material
		)
		assert_true(node.has_meta("w05_asset"))
		node.free()


func test_actual_bridge_mouse_release_waits_for_confirmation_and_escape_cancels() -> void:
	playground._on_action(&"bridge")
	var a: Vector2 = playground.camera_rig.camera.unproject_position(Vector3(7, 0, -3))
	var b: Vector2 = playground.camera_rig.camera.unproject_position(Vector3(7, 0, 2))
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = a
	playground._unhandled_input(event)
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = b
	playground._unhandled_input(motion)
	event.pressed = false
	event.position = b
	playground._unhandled_input(event)
	await settle()
	assert_false(playground._five_drag)
	assert_eq(playground.session.phase, EditSession.Phase.PREVIEW)
	assert_eq(playground.document.state["bridges"].size(), 1)
	playground._on_action(&"cancel")
	await settle()
	assert_eq(playground.session.phase, EditSession.Phase.IDLE)
	assert_eq(playground.session.history_count(), 0)


func test_save_preserves_computed_float_heights_exactly() -> void:
	var before: Dictionary = playground.document.snapshot()
	var restored: Dictionary = SaveCodec.decode(SaveCodec.encode(before))
	assert_true(restored["ok"])
	for i: int in range(2):
		assert_eq(
			restored["snapshot"]["bridges"][0]["heights"][i], before["bridges"][0]["heights"][i]
		)
