extends GutTest

var playground: Node3D
var isolated_viewport: SubViewport


func before_each() -> void:
	# Isolate input from GUT's own GUI; exercise the actual gameplay viewport.
	isolated_viewport = SubViewport.new()
	isolated_viewport.size = Vector2i(1280, 800)
	isolated_viewport.own_world_3d = true
	add_child_autofree(isolated_viewport)
	playground = load("res://app/app_root.tscn").instantiate() as Node3D
	isolated_viewport.add_child(playground)
	await get_tree().process_frame


func test_scene_boots_with_editable_source_and_camera() -> void:
	assert_eq(playground.document.state["buildings"].size(), 2)
	assert_gt(playground.wind_materials.size(), 2)
	assert_not_null(playground.camera_rig.camera)
	assert_eq(WorldDocument.validate(playground.document.snapshot()), "")


func test_camera_pan_is_bounded_and_reset_restores_view() -> void:
	var rig: OrbitCamera = playground.camera_rig
	rig.pan_by(Vector2(99999, -99999))
	assert_lte(absf(rig.target.x), 20.0)
	assert_lte(absf(rig.target.z), 20.0)
	rig.reset_view()
	assert_eq(rig.target, Vector3.ZERO)
	assert_eq(rig.distance, 29.0)


func test_ground_projection_matches_horizontal_plane() -> void:
	var rig: OrbitCamera = playground.camera_rig
	var center: Vector2 = isolated_viewport.get_visible_rect().size * 0.5
	var hit: Variant = rig.ground_point(center)
	assert_true(hit is Vector3)
	if hit is Vector3:
		assert_almost_eq(hit.y, 0.0, 0.001)


func test_hud_buttons_use_same_transaction_and_undo_path() -> void:
	var hud: WeekOneHud = playground.hud
	var original: bool = playground.document.state["environment"]["dusk"]
	hud.buttons["light"].pressed.emit()
	assert_eq(playground.document.state["environment"]["dusk"], not original)
	assert_eq(playground.session.history_count(), 1)
	hud.buttons["undo"].pressed.emit()
	assert_eq(playground.document.state["environment"]["dusk"], original)


func test_reduce_motion_reaches_all_imported_wind_materials() -> void:
	playground.hud.buttons["wind"].pressed.emit()
	for material: ShaderMaterial in playground.wind_materials:
		assert_true(material.get_shader_parameter("reduce_motion"))


func test_source_environment_restore_reaches_shader_and_can_undo() -> void:
	var before: float = playground.document.state["environment"]["wind_strength"]
	var draft: Dictionary = playground.document.snapshot()
	draft["environment"]["wind_strength"] = 0.0
	assert_true(
		playground.session.commit_snapshot(draft, "test wind", playground._prepare_views)["ok"]
	)
	for material: ShaderMaterial in playground.wind_materials:
		assert_eq(material.get_shader_parameter("wind_strength"), 0.0)
	assert_true(playground.session.request_undo(playground._prepare_views)["ok"])
	assert_almost_eq(
		playground.wind_materials[0].get_shader_parameter("wind_strength"), before, 0.001
	)


func test_tool_switch_cancels_preview_instead_of_committing() -> void:
	playground.session.begin_gesture()
	playground.hud.buttons["round"].pressed.emit()
	assert_eq(playground.current_shape, "round")
	assert_eq(playground.session.phase, EditSession.Phase.IDLE)
	assert_eq(playground.session.history_count(), 0)


func test_viewport_mouse_drag_creates_one_building_and_can_undo() -> void:
	var camera: Camera3D = playground.camera_rig.camera
	var start: Vector2 = camera.unproject_position(Vector3(6, 0, 5))
	var finish: Vector2 = camera.unproject_position(Vector3(10, 0, 8))
	_mouse_motion(start)
	_mouse_button(start, true)
	_mouse_motion(finish)
	_mouse_button(finish, false)
	await get_tree().process_frame
	assert_eq(playground.document.state["buildings"].size(), 3)
	assert_eq(playground.session.history_count(), 1)
	playground.hud.buttons["undo"].pressed.emit()
	assert_eq(playground.document.state["buildings"].size(), 2)


func test_actual_toolbar_click_does_not_start_world_gesture() -> void:
	var button: Button = playground.hud.buttons["round"]
	var center: Vector2 = button.get_global_rect().get_center()
	_mouse_motion(center)
	_mouse_button(center, true)
	_mouse_button(center, false)
	await get_tree().process_frame
	assert_eq(playground.current_shape, "round")
	assert_false(playground.dragging)
	assert_eq(playground.session.history_count(), 0)


func _mouse_motion(position_value: Vector2) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = position_value
	isolated_viewport.push_input(event, true)


func _mouse_button(position_value: Vector2, pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = position_value
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	isolated_viewport.push_input(event, true)
