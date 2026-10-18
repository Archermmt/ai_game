extends GutTest

var playground: Node3D
var viewport: SubViewport


func before_each() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.own_world_3d = true
	add_child_autofree(viewport)
	playground = load("res://app/week_three_root.tscn").instantiate() as Node3D
	viewport.add_child(playground)
	await get_tree().process_frame


func _settle() -> void:
	for frame: int in range(900):
		if not playground.queue.is_busy():
			return
		await get_tree().process_frame
	fail_test("W03 worker did not settle")


func test_w03_scene_has_three_tree_kinds_lod_inspector_and_water() -> void:
	assert_eq(WorldDocument.validate(playground.document.snapshot()), "")
	assert_eq(playground._tree_views.size(), 9)
	assert_eq(playground.hud.building_list.item_count, 2)
	assert_eq(playground.hud.detached_list.item_count, 0)
	assert_eq(playground.path_root.get_child_count(), 1)
	assert_lt(playground.hud.buttons["reattach"].get_global_rect().end.y, 800.0)
	assert_eq(
		playground.water_material.shader, load("res://features/environment/pond_water.gdshader")
	)
	var tree: Node3D = playground._tree_views.values()[0]
	var high: MeshInstance3D = (
		tree.get_child(0).find_children("*", "MeshInstance3D", true, false)[0]
	)
	var low: MeshInstance3D = tree.get_child(1).find_children("*", "MeshInstance3D", true, false)[0]
	assert_eq(high.visibility_range_end, low.visibility_range_begin)


func test_repeated_size_preview_is_one_commit_with_fixed_frame_scale() -> void:
	var original: Dictionary = playground.document.snapshot()
	for size: Vector3 in [Vector3(5, 3.5, 5), Vector3(5, 4, 5), Vector3(5, 4.5, 5)]:
		playground._preview_size(size)
	assert_eq_deep(playground.document.snapshot(), original)
	playground._on_action(&"apply_size")
	await _settle()
	assert_eq(playground.session.history_count(), 1)
	assert_eq(playground.document.state["buildings"][0]["size"][1], 4.5)
	for frame: Node3D in playground.building_root.get_child(0).get_children():
		assert_eq(frame.scale, Vector3.ONE)
	playground._on_action(&"undo")
	assert_eq_deep(playground.document.state["buildings"], original["buildings"])


func test_cancel_after_visible_size_preview_restores_source_and_mesh() -> void:
	var old: Array = playground.document.state["buildings"][0]["size"].duplicate()
	playground._preview_size(Vector3(5, 5, 5))
	await _settle()
	assert_true(playground._preview_visible)
	playground._on_action(&"cancel")
	await _settle()
	assert_eq(playground.document.state["buildings"][0]["size"], old)
	assert_eq(playground.session.history_count(), 0)
	assert_false(playground._preview_visible)


func test_delete_parent_ui_lists_frames_and_undo_restores_them() -> void:
	playground._on_action(&"delete_building")
	await _settle()
	assert_eq(playground.document.state["buildings"].size(), 1)
	assert_eq(playground.hud.detached_list.item_count, 2)
	assert_eq(playground.document.state["attachments"].size(), 2)
	playground._on_action(&"undo")
	assert_eq(playground.hud.detached_list.item_count, 0)
	assert_eq(playground.building_root.get_child_count(), 2)


func test_ui_reattach_rebuilds_real_frame_and_undo_restores_detached_list() -> void:
	playground._on_action(&"delete_building")
	await _settle()
	var draft: Dictionary = playground.document.snapshot()
	var target: Dictionary = WorldDocument.allocate_building(
		draft, Vector3(0, 0, 9), Vector3(5, 3, 5)
	)
	assert_true(
		playground.session.commit_snapshot(draft, "target", playground._prepare_views)["ok"]
	)
	var selected: Array[String] = [target["id"]]
	playground._select_buildings(selected)
	playground.hud.buttons["reattach"].pressed.emit()
	await _settle()
	assert_eq(playground.hud.detached_list.item_count, 1)
	assert_eq(playground.document.state["buildings"].back()["openings"].size(), 1)
	playground._on_action(&"undo")
	assert_eq(playground.hud.detached_list.item_count, 2)


func test_reset_default_is_undoable_and_preserves_previous_work() -> void:
	playground._preview_size(Vector3(5, 4, 5))
	playground._on_action(&"apply_size")
	await _settle()
	playground._on_action(&"reset_defaults")
	await _settle()
	assert_eq(playground.document.state["buildings"][0]["size"][1], 3.0)
	playground._on_action(&"undo")
	assert_eq(playground.document.state["buildings"][0]["size"][1], 4.0)


func test_actual_mouse_path_gesture_commits_once_and_undo_removes_mesh() -> void:
	playground._on_action(&"path")
	var before: int = playground.document.state["paths"].size()
	var a: Vector2 = playground.camera_rig.camera.unproject_position(Vector3(1, 0, 8))
	var b: Vector2 = playground.camera_rig.camera.unproject_position(Vector3(4, 0, 10))
	_motion(a)
	_button(a, true)
	_motion(b)
	# Modifier pressed during an existing gesture must not swallow its release.
	_button(b, false, true)
	await _settle()
	assert_eq(playground.document.state["paths"].size(), before + 1)
	assert_eq(playground.session.history_count(), 1)
	playground._on_action(&"undo")
	assert_eq(playground.document.state["paths"].size(), before)


func test_option_orbit_in_path_mode_does_not_start_path() -> void:
	playground._on_action(&"path")
	var before: Dictionary = playground.document.snapshot()
	var point: Vector2 = Vector2(700, 400)
	_motion(point)
	_button(point, true, true)
	_motion(point + Vector2(30, 0), Vector2(30, 0))
	_button(point, false)
	assert_false(playground._path_drag)
	assert_eq_deep(playground.document.snapshot(), before)
	assert_eq(playground.session.history_count(), 0)


func test_far_tree_identity_seed_and_transform_survive_nearby_edit() -> void:
	var before: Dictionary = playground.document.state["instances"].back().duplicate(true)
	var node_id: int = playground._instance_views[before["id"]].get_instance_id()
	playground._preview_size(Vector3(5, 4, 5))
	playground._on_action(&"apply_size")
	await _settle()
	assert_eq_deep(playground.document.state["instances"].back(), before)
	var view: Node3D = playground._instance_views[before["id"]]
	assert_eq(view.get_instance_id(), node_id)
	assert_almost_eq(view.position.x, before["position"][0], 0.001)
	assert_eq(view.get_child(0).get_meta("object_id"), before["id"])


func test_wind_material_count_stays_bounded_across_rebuilds() -> void:
	var original: int = playground.wind_materials.size()
	for index: int in range(3):
		playground._on_action(&"light")
	assert_eq(playground.wind_materials.size(), original)
	playground._on_action(&"wind")
	for material: ShaderMaterial in playground.wind_materials:
		assert_true(material.get_shader_parameter("reduce_motion"))


func _button(point: Vector2, pressed: bool, alt: bool = false) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.alt_pressed = alt
	viewport.push_input(event, true)


func _motion(point: Vector2, relative: Vector2 = Vector2.ZERO) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = point
	event.relative = relative
	viewport.push_input(event, true)


func test_actual_inspector_multiselect_batches_parent_deletion() -> void:
	var list: ItemList = playground.hud.building_list
	var point: Vector2 = list.global_position + list.get_item_rect(1).get_center()
	_motion(point)
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.position = point
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.ctrl_pressed = true
	click.meta_pressed = true
	viewport.push_input(click, true)
	click = click.duplicate()
	click.pressed = false
	viewport.push_input(click, true)
	assert_eq(playground.selected_buildings.size(), 2)
	playground.hud.buttons["delete_building"].pressed.emit()
	await _settle()
	assert_true(playground.document.state["buildings"].is_empty())
	assert_eq(playground.document.state["attachments"].size(), 4)
	assert_eq(playground.session.history_count(), 1)


func test_rejected_size_after_preview_restores_derived_view_and_history() -> void:
	var original: Dictionary = playground.document.snapshot()
	playground._preview_size(Vector3(5, 4, 5))
	await _settle()
	playground.queue.evaluator = func(_snapshot: Dictionary) -> Dictionary:
		return {"ok": false, "error": "injected W03 generator failure"}
	playground._on_action(&"apply_size")
	await _settle()
	assert_eq_deep(playground.document.snapshot(), original)
	assert_eq(playground.session.history_count(), 0)
	assert_false(playground._preview_visible)


func test_mac_pinch_in_w03_preserves_source_and_edit_history() -> void:
	var point: Vector2 = Vector2(700, 400)
	_motion(point)
	var before: Dictionary = playground.document.snapshot()
	var distance: float = playground.camera_rig.distance
	var event: InputEventMagnifyGesture = InputEventMagnifyGesture.new()
	event.position = point
	event.factor = 1.2
	viewport.push_input(event, true)
	assert_lt(playground.camera_rig.distance, distance)
	assert_eq_deep(playground.document.snapshot(), before)
	assert_eq(playground.session.history_count(), 0)


func test_path_click_without_drag_does_not_consume_history_or_source_id() -> void:
	playground._on_action(&"path")
	var before: Dictionary = playground.document.snapshot()
	var point: Vector2 = Vector2(700, 400)
	_motion(point)
	_button(point, true)
	_button(point, false)
	await _settle()
	assert_eq_deep(playground.document.snapshot(), before)
	assert_eq(playground.session.history_count(), 0)
