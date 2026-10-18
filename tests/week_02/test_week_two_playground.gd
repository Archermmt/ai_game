extends GutTest

var playground: Node3D
var viewport: SubViewport


func before_each() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.own_world_3d = true
	add_child_autofree(viewport)
	playground = load("res://app/week_two_root.tscn").instantiate() as Node3D
	viewport.add_child(playground)
	await get_tree().process_frame


func _settle() -> void:
	for frame: int in range(600):
		if not playground.queue.is_busy():
			return
		await get_tree().process_frame
	fail_test("W02 worker did not settle")


func _button(point: Vector2, pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	viewport.push_input(event, true)


func _motion(point: Vector2) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = point
	viewport.push_input(event, true)


func test_week_two_scene_has_layered_terrain_window_frames_and_visible_tool_buttons() -> void:
	assert_eq(WorldDocument.validate(playground.document.snapshot()), "")
	assert_eq(playground.terrain_root.get_child_count(), 64)
	assert_true(playground.water_view.visible)
	assert_eq(playground.instance_root.get_child_count(), 2)
	assert_eq(playground.hud.week, 2)
	var last_button: Button = playground.hud.buttons["delete"]
	assert_lt(last_button.get_global_rect().end.y, 800.0)
	assert_true(playground.camera_rig.surface_height.is_valid())
	var mesh: MeshInstance3D = playground.building_root.get_child(0)
	assert_eq(mesh.get_child_count(), 2)


func test_actual_mouse_prop_gesture_is_async_once_and_undo_redo_restores_instances() -> void:
	playground._on_action(&"prop")
	var point: Vector2 = playground.camera_rig.camera.unproject_position(Vector3(9, 0, 6))
	_motion(point)
	_button(point, true)
	_button(point, false)
	assert_eq(playground.session.phase, EditSession.Phase.PENDING_COMMIT)
	assert_eq(playground.document.state["instances"].size(), 2)
	assert_false(playground.session.begin_gesture())
	await _settle()
	assert_eq(playground.document.state["instances"].size(), 3)
	assert_eq(playground.session.history_count(), 1)
	playground._on_action(&"undo")
	assert_eq(playground.document.state["instances"].size(), 2)
	playground._on_action(&"redo")
	assert_eq(playground.document.state["instances"].size(), 3)


func test_actual_mouse_building_release_uses_same_pending_barrier() -> void:
	playground._on_action(&"rect")
	var first: Vector2 = playground.camera_rig.camera.unproject_position(Vector3(-1, 0, 8))
	var last: Vector2 = playground.camera_rig.camera.unproject_position(Vector3(3, 0, 11))
	_motion(first)
	_button(first, true)
	_motion(last)
	_button(last, false)
	assert_eq(playground.session.phase, EditSession.Phase.PENDING_COMMIT)
	await _settle()
	assert_eq(playground.document.state["buildings"].size(), 3)
	assert_eq(playground.session.history_count(), 1)


func test_terrain_preview_cancel_restores_source_visuals_and_ignores_late_worker() -> void:
	var before: Dictionary = playground.document.snapshot()
	playground._on_action(&"raise")
	var point: Vector2 = playground.camera_rig.camera.unproject_position(Vector3(11, 0, 6))
	_motion(point)
	_button(point, true)
	await _settle()
	assert_true(playground._preview_visible)
	assert_eq_deep(playground.document.snapshot(), before)
	assert_gt(playground._field.height_at(Vector2(11, 6)), 0.1)
	playground._on_action(&"cancel")
	await _settle()
	assert_eq_deep(playground.document.snapshot(), before)
	assert_almost_eq(playground._field.height_at(Vector2(11, 6)), 0.0, 0.001)
	assert_eq(playground.session.history_count(), 0)


func test_pending_escape_does_not_publish_or_consume_history() -> void:
	var draft: Dictionary = playground.document.snapshot()
	InstanceEdits.allocate(draft, Vector3(11, 0, 7))
	playground._submit_async(draft, "pending cancel")
	assert_eq(playground.session.phase, EditSession.Phase.PENDING_COMMIT)
	playground._on_action(&"cancel")
	await _settle()
	assert_eq(playground.document.state["instances"].size(), 2)
	assert_eq(playground.session.history_count(), 0)


func test_rejected_core_build_keeps_visible_meshes_source_and_history() -> void:
	var before: Dictionary = playground.document.snapshot()
	var mesh_id: int = playground.building_root.get_child(0).get_instance_id()
	playground.queue.evaluator = func(_snapshot: Dictionary) -> Dictionary:
		return {"ok": false, "error": "injected geometry failure"}
	var draft: Dictionary = before.duplicate(true)
	InstanceEdits.allocate(draft, Vector3(11, 0, 7))
	playground._submit_async(draft, "failed")
	await _settle()
	assert_eq_deep(playground.document.snapshot(), before)
	assert_eq(playground.building_root.get_child(0).get_instance_id(), mesh_id)
	assert_eq(playground.session.history_count(), 0)
	assert_eq(playground.session.phase, EditSession.Phase.IDLE)


func test_delete_pond_and_undo_restore_visual_water_and_source_height_layer() -> void:
	var before: Dictionary = playground.document.snapshot()
	playground._on_action(&"delete_pool")
	await _settle()
	assert_false(playground.water_view.visible)
	assert_true(playground.document.state["pool"].is_empty())
	assert_eq_deep(playground.document.state["terrain"], before["terrain"])
	playground._on_action(&"undo")
	assert_true(playground.water_view.visible)
	assert_eq_deep(playground.document.state["pool"], before["pool"])


func test_material_age_and_window_emission_follow_source_and_undo() -> void:
	playground._on_action(&"age")
	assert_true(playground.architecture_material.get_shader_parameter("aged"))
	playground._on_action(&"undo")
	assert_false(playground.architecture_material.get_shader_parameter("aged"))
	playground._on_action(&"light")
	assert_true(playground.window_material.get_shader_parameter("dusk"))
	playground._on_action(&"undo")
	assert_false(playground.window_material.get_shader_parameter("dusk"))


func test_all_frames_keep_fixed_scale_and_match_curved_or_flat_wall_normal() -> void:
	for shape: String in ["rect", "round"]:
		for facade: int in range(1 if shape == "round" else 4):
			var draft: Dictionary = WorldDocument.new().snapshot()
			var spec: Dictionary = WorldDocument.allocate_building(
				draft, Vector3.ZERO, Vector3(3, 3, 3), shape
			)
			spec["openings"] = [
				{
					"kind": "round",
					"center": 0.3,
					"width": 0.8,
					"height": 0.8,
					"sill": 1.0,
					"facade": facade
				}
			]
			var view: MeshInstance3D = playground._building_view(spec, BuildingGeometry.build(spec))
			var frame: Node3D = view.get_child(0)
			assert_eq(frame.scale, Vector3.ONE)
			assert_almost_eq(frame.position.y, 1.0, 0.0001)
			var length: float = PI * 3 if shape == "round" else 3.0
			var normal: Vector3 = BuildingGeometry._normal(
				0.3 * length, facade, 3, 3, shape == "round"
			)
			assert_gt(frame.basis.z.dot(normal), 0.999)
			view.free()


func test_failed_release_after_visible_preview_restores_previous_meshes_and_instances() -> void:
	var before: Dictionary = playground.document.snapshot()
	playground._on_action(&"prop")
	var point: Vector2 = playground.camera_rig.camera.unproject_position(Vector3(11, 0, 7))
	_motion(point)
	_button(point, true)
	await _settle()
	assert_eq(playground.instance_root.get_child_count(), 3)
	assert_true(playground._preview_visible)
	playground.queue.evaluator = func(_snapshot: Dictionary) -> Dictionary:
		return {"ok": false, "error": "injected failure after preview"}
	_button(point, false)
	await _settle()
	assert_eq_deep(playground.document.snapshot(), before)
	assert_eq(playground.instance_root.get_child_count(), 2)
	assert_false(playground._preview_visible)
	assert_eq(playground.session.history_count(), 0)


func test_minimal_week_one_source_loads_and_rebuilds_without_optional_week_two_fields() -> void:
	var original: Dictionary = WorldDocument.new("old-world").snapshot()
	WorldDocument.allocate_building(original, Vector3.ZERO, Vector3(4, 3, 4))
	var decoded: Dictionary = SaveCodec.decode(SaveCodec.encode(original))
	assert_true(decoded["ok"])
	assert_true(
		playground.session.replace_document(decoded["snapshot"], playground._prepare_views)["ok"]
	)
	assert_eq(playground.document.state["world_seed"], "old-world")
	assert_false(playground.water_view.visible)
	assert_eq(playground.terrain_root.get_child_count(), 64)
	assert_eq(playground.building_root.get_child_count(), 1)
	assert_eq(playground.session.history_count(), 0)


func test_terrain_edit_reuses_unchanged_buildings_and_chunks() -> void:
	var building_id: int = playground.building_root.get_child(0).get_instance_id()
	var old_meshes: Array = []
	for view: MeshInstance3D in playground._terrain_views:
		old_meshes.append(view.mesh)
	var draft: Dictionary = TerrainField.brush(playground.document.snapshot(), Vector2(12, 8), 0.1)
	playground._submit_async(draft, "local terrain")
	await _settle()
	assert_eq(playground.building_root.get_child(0).get_instance_id(), building_id)
	var changed: int = 0
	for index: int in range(old_meshes.size()):
		if old_meshes[index] != playground._terrain_views[index].mesh:
			changed += 1
	assert_gt(changed, 0)
	assert_lt(changed, 8)


func test_low_orbit_stays_above_raised_ground_and_picks_actual_surface() -> void:
	var rig: OrbitCamera = playground.camera_rig
	rig.surface_height = func(_point: Vector2) -> float: return 8.0
	rig.distance = 7.0
	rig.pitch = 0.3
	rig.refresh()
	assert_gte(rig.camera.position.y, 8.6)
	var picked: Variant = rig.ground_point(Vector2(640, 400))
	assert_true(picked is Vector3)
	if picked is Vector3:
		assert_almost_eq(picked.y, 8.0, 0.001)
