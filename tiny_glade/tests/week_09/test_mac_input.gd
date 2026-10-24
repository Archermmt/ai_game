extends "res://tests/week_09/playground_test_base.gd"


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


func test_option_left_pans_without_editing_in_every_tool() -> void:
	var point: Vector2 = Vector2(950, 400)
	var before: Dictionary = playground.document.snapshot()
	for mode: String in [
		"rect", "round", "select", "move", "prop", "brush", "erase", "raise", "lower", "pool"
	]:
		playground._on_action(StringName(mode))
		var target: Vector3 = playground.camera_rig.target
		_motion(point)
		_button(point, true, true)
		_motion(point + Vector2(30, 10), Vector2(30, 10))
		assert_ne(playground.camera_rig.target, target, mode)
		var offset: Vector3 = playground.camera_rig.target - target
		var yaw: float = playground.camera_rig.yaw
		assert_lt(offset.dot(Vector3(sin(yaw), 0, cos(yaw))), 0.0, mode)
		assert_lt(offset.dot(Vector3(cos(yaw), 0, -sin(yaw))), 0.0, mode)
		# Option may be released before the mouse button.
		_button(point, false)
		assert_eq(playground.session.phase, EditSession.Phase.IDLE, mode)
		assert_false(playground.dragging, mode)
		assert_false(playground._tool_dragging, mode)
	assert_eq_deep(playground.document.snapshot(), before)
	assert_eq(playground.session.history_count(), 0)


func test_option_shift_also_pans() -> void:
	var point: Vector2 = Vector2(950, 400)
	var target: Vector3 = playground.camera_rig.target
	var yaw: float = playground.camera_rig.yaw
	_motion(point)
	_button(point, true, true, true)
	_motion(point, Vector2(40, 0))
	_button(point, false)
	assert_eq(playground.camera_rig.yaw, yaw)
	assert_ne(playground.camera_rig.target, target)


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


func test_two_finger_scroll_rotates_both_axes_without_zoom() -> void:
	var point: Vector2 = Vector2(950, 400)
	_motion(point)
	var original: float = playground.camera_rig.distance
	var yaw: float = playground.camera_rig.yaw
	var pitch: float = playground.camera_rig.pitch
	_scroll(point, Vector2(2, 3))
	assert_gt(playground.camera_rig.yaw, yaw)
	assert_lt(playground.camera_rig.pitch, pitch)
	assert_eq(playground.camera_rig.distance, original)
	_scroll(point, Vector2(-2, -3))
	assert_almost_eq(playground.camera_rig.yaw, yaw, 0.0001)
	assert_almost_eq(playground.camera_rig.pitch, pitch, 0.0001)
	for delta: Vector2 in [Vector2(INF, 0), Vector2(0, NAN)]:
		_scroll(point, delta)
	assert_eq(playground.camera_rig.distance, original)
	assert_almost_eq(playground.camera_rig.yaw, yaw, 0.0001)
	_scroll(point, Vector2(0, 1000))
	assert_eq(playground.camera_rig.pitch, 0.3)
	_scroll(point, Vector2(0, -1000))
	assert_eq(playground.camera_rig.pitch, 1.3)
	assert_eq(playground.session.history_count(), 0)


func test_gestures_over_toolbar_do_not_zoom_or_start_edits() -> void:
	var point: Vector2 = playground.hud.buttons["rect"].get_global_rect().get_center()
	_motion(point)
	var original: float = playground.camera_rig.distance
	_pinch(point, 1.5)
	_scroll(point, Vector2(0, 3))
	assert_eq(playground.camera_rig.distance, original)
	assert_eq(playground.session.phase, EditSession.Phase.IDLE)


func test_option_release_over_ui_stops_pan_after_modifier_was_released() -> void:
	var point: Vector2 = Vector2(950, 400)
	_motion(point)
	_button(point, true, true)
	_motion(point, Vector2(30, 0))
	var target: Vector3 = playground.camera_rig.target
	var toolbar: Vector2 = playground.hud.buttons["rect"].get_global_rect().get_center()
	_motion(toolbar)
	_button(toolbar, false)
	_motion(point, Vector2(50, 0))
	assert_eq(playground.camera_rig.target, target)
	assert_false(playground.camera_rig._panning)
	assert_eq(playground.session.history_count(), 0)
