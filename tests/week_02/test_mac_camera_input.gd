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


func _motion(point: Vector2, relative: Vector2 = Vector2.ZERO) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = point
	event.relative = relative
	viewport.push_input(event, true)


func _button(point: Vector2, pressed: bool, alt: bool = false, shift: bool = false) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.alt_pressed = alt
	event.shift_pressed = shift
	viewport.push_input(event, true)


func _pinch(point: Vector2, factor: float) -> void:
	var event: InputEventMagnifyGesture = InputEventMagnifyGesture.new()
	event.position = point
	event.factor = factor
	viewport.push_input(event, true)


func _scroll(point: Vector2, delta: Vector2) -> void:
	var event: InputEventPanGesture = InputEventPanGesture.new()
	event.position = point
	event.delta = delta
	viewport.push_input(event, true)


func test_option_left_orbits_without_editing_in_every_tool() -> void:
	var point: Vector2 = Vector2(950, 400)
	var before: Dictionary = playground.document.snapshot()
	for mode: String in [
		"rect", "round", "select", "move", "prop", "brush", "erase", "raise", "lower", "pool"
	]:
		playground._on_action(StringName(mode))
		var yaw: float = playground.camera_rig.yaw
		_motion(point)
		_button(point, true, true)
		_motion(point + Vector2(30, 10), Vector2(30, 10))
		assert_lt(playground.camera_rig.yaw, yaw, mode)
		# Option may be released before the mouse button.
		_button(point, false)
		assert_eq(playground.session.phase, EditSession.Phase.IDLE, mode)
		assert_false(playground.dragging, mode)
		assert_false(playground._tool_dragging, mode)
	assert_eq_deep(playground.document.snapshot(), before)
	assert_eq(playground.session.history_count(), 0)


func test_option_has_priority_over_shift_pan() -> void:
	var point: Vector2 = Vector2(950, 400)
	var target: Vector3 = playground.camera_rig.target
	var yaw: float = playground.camera_rig.yaw
	_motion(point)
	_button(point, true, true, true)
	_motion(point, Vector2(40, 0))
	_button(point, false)
	assert_ne(playground.camera_rig.yaw, yaw)
	assert_eq(playground.camera_rig.target, target)


func test_pinch_zoom_direction_bounds_and_invalid_factors() -> void:
	var point: Vector2 = Vector2(950, 400)
	_motion(point)
	var original: float = playground.camera_rig.distance
	_pinch(point, 1.2)
	assert_lt(playground.camera_rig.distance, original)
	_pinch(point, 1.0 / 1.2)
	assert_almost_eq(playground.camera_rig.distance, original, 0.001)
	for factor: float in [0.0, -1.0, INF, NAN]:
		_pinch(point, factor)
	assert_almost_eq(playground.camera_rig.distance, original, 0.001)
	_pinch(point, 1000.0)
	assert_eq(playground.camera_rig.distance, OrbitCamera.MIN_DISTANCE)
	_pinch(point, 0.001)
	assert_eq(playground.camera_rig.distance, OrbitCamera.MAX_DISTANCE)
	assert_eq(playground.session.history_count(), 0)


func test_two_finger_scroll_zoom_and_precise_wheel_factor() -> void:
	var point: Vector2 = Vector2(950, 400)
	_motion(point)
	var original: float = playground.camera_rig.distance
	_scroll(point, Vector2(0, 1))
	assert_gt(playground.camera_rig.distance, original)
	_scroll(point, Vector2(0, -1))
	assert_almost_eq(playground.camera_rig.distance, original, 0.001)
	_scroll(point, Vector2(4, 0))
	assert_almost_eq(playground.camera_rig.distance, original, 0.001)
	var wheel: InputEventMouseButton = InputEventMouseButton.new()
	wheel.position = point
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.factor = 0.1
	viewport.push_input(wheel, true)
	assert_lt(playground.camera_rig.distance, original)
	assert_gt(playground.camera_rig.distance, original * 0.9)
	assert_eq(playground.session.history_count(), 0)


func test_gestures_over_toolbar_do_not_zoom_or_start_edits() -> void:
	var point: Vector2 = playground.hud.buttons["prop"].get_global_rect().get_center()
	_motion(point)
	var original: float = playground.camera_rig.distance
	_pinch(point, 1.5)
	_scroll(point, Vector2(0, 3))
	assert_eq(playground.camera_rig.distance, original)
	assert_eq(playground.session.phase, EditSession.Phase.IDLE)


func test_option_release_over_ui_stops_orbit_after_modifier_was_released() -> void:
	var point: Vector2 = Vector2(950, 400)
	_motion(point)
	_button(point, true, true)
	_motion(point, Vector2(30, 0))
	var yaw: float = playground.camera_rig.yaw
	var toolbar: Vector2 = playground.hud.buttons["prop"].get_global_rect().get_center()
	_motion(toolbar)
	_button(toolbar, false)
	_motion(point, Vector2(50, 0))
	assert_eq(playground.camera_rig.yaw, yaw)
	assert_false(playground.camera_rig._orbiting)
	assert_eq(playground.session.history_count(), 0)
