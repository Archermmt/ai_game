extends SceneTree

var app
var previous_pointer := Vector2.ZERO
var buttons := 0

func _initialize() -> void:
	call_deferred("run")

func move(to: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = to
	event.global_position = to
	event.relative = to - previous_pointer
	event.button_mask = buttons
	previous_pointer = to
	root.push_input(event, true)

func button(index: MouseButton, pressed: bool) -> void:
	var bit := 1 << (index - 1)
	buttons = (buttons | bit) if pressed else (buttons & ~bit)
	var event := InputEventMouseButton.new()
	event.position = previous_pointer
	event.global_position = previous_pointer
	event.button_index = index
	event.pressed = pressed
	event.button_mask = buttons
	root.push_input(event, true)

func gesture(delta: Vector2) -> void:
	var event := InputEventPanGesture.new()
	event.position = previous_pointer
	event.delta = delta
	root.push_input(event, true)

func run() -> void:
	create_timer(35).timeout.connect(func(): push_error("Camera orbit timeout"); quit(1))
	app = load("res://game/island.tscn").instantiate()
	app.preferences.path = "user://orbit_input_%d.cfg" % Time.get_ticks_usec()
	root.add_child(app)
	await process_frame
	var world: Vector2 = root.get_visible_rect().size * Vector2(0.54, 0.48)
	var initial_angle: float = app.angle
	move(world)
	button(MOUSE_BUTTON_RIGHT, true)
	move(world + Vector2(60, 20))
	button(MOUSE_BUTTON_RIGHT, false)
	assert(app.angle == initial_angle and app.modal != null)
	app.close_modal()
	await process_frame
	move(world)
	var before: Dictionary = app.data.snapshot()
	app.moving_id = int(app.data.objects[0].id)
	button(MOUSE_BUTTON_RIGHT, true)
	move(world + Vector2(2, 0))
	assert(app.angle == initial_angle)
	move(world + Vector2(85, 45))
	assert(not is_equal_approx(initial_angle, app.angle) and app.pitch_offset < 0.0)
	assert(app.moving_id != 0)
	var terrain_point := Vector3(30.0, app.view.surface.height_at(Vector2(30, 33)), 33.0)
	var cell: Vector2i = app.pick_at(app.camera.unproject_position(terrain_point))
	assert(cell == Vector2i(30, 33))
	# An initiated camera drag can cross the toolbar and releases there.
	var over_ui: Vector2 = app.hud.title_panel.get_global_rect().get_center()
	move(over_ui)
	button(MOUSE_BUTTON_RIGHT, false)
	assert(not app.orbit_tracking and app.moving_id != 0)
	move(world)
	button(MOUSE_BUTTON_RIGHT, true)
	button(MOUSE_BUTTON_RIGHT, false)
	assert(app.moving_id == 0)
	# Starting on UI must not orbit when the pointer then moves into the world.
	var angle: float = app.angle
	move(over_ui)
	button(MOUSE_BUTTON_RIGHT, true)
	move(world)
	button(MOUSE_BUTTON_RIGHT, false)
	assert(app.angle == angle)
	# Turning while a brush is held can never commit an edit on button release.
	button(MOUSE_BUTTON_LEFT, true)
	assert(app.dragging)
	button(MOUSE_BUTTON_RIGHT, true)
	move(world + Vector2(37, 15))
	button(MOUSE_BUTTON_LEFT, false)
	button(MOUSE_BUTTON_RIGHT, false)
	assert(not app.dragging and app.data.snapshot() == before)
	var site: Vector2 = previous_pointer
	angle = app.angle
	var tilt_before: float = app.pitch_offset
	gesture(Vector2(7, 2))
	assert(is_equal_approx(angle_difference(angle, app.angle), 7.0 * 0.025))
	assert(is_equal_approx(app.pitch_offset - tilt_before, -rad_to_deg(2.0 * 0.02)))
	var zoom := InputEventMagnifyGesture.new()
	zoom.position = site
	zoom.factor = 1.15
	var size_before: float = app.camera.size
	root.push_input(zoom, true)
	assert(app.camera.size < size_before)
	var key := InputEventKey.new()
	key.keycode = KEY_E
	key.pressed = true
	angle = app.angle
	root.push_input(key, true)
	assert(is_equal_approx(angle_difference(angle, app.angle), PI / 2.0))
	button(MOUSE_BUTTON_RIGHT, true)
	app._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	angle = app.angle
	move(world + Vector2(100, 0))
	button(MOUSE_BUTTON_RIGHT, false)
	assert(not app.orbit_tracking and app.angle == angle)
	# Same gesture routing applies with all editing controls hidden for photography.
	app.photo_mode = true
	app.hud.root.hide()
	move(world)
	button(MOUSE_BUTTON_RIGHT, true)
	move(world + Vector2(48, 20))
	button(MOUSE_BUTTON_RIGHT, false)
	assert(not is_equal_approx(angle, app.angle))
	var pose: Transform3D = app.camera.transform
	var path := "user://test_camera_orbit_%d.json" % Time.get_ticks_usec()
	assert(app.save_current(path) == OK)
	app.turn_camera(1.2, -15)
	app.load_slot(path)
	assert(app.camera.transform.is_equal_approx(pose))
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	payload.presentation.camera.erase("pitch_offset")
	assert(SaveStore.validate(payload) == OK)
	payload.presentation.camera.pitch_offset = 99.0
	assert(SaveStore.validate(payload) == ERR_FILE_CORRUPT)
	assert(app.data.snapshot() == before)
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(app.preferences.path)
	app.free()
	await create_timer(0.2).timeout
	print("PASS viewport orbit: right-drag, click/cancel, toolbar, brush arbitration, touchpad, zoom, keys, photo, picking, focus loss and camera save compatibility")
	quit()
