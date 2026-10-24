extends GutTest

var world: Node3D
var viewport: SubViewport


func before_all() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.own_world_3d = true
	add_child(viewport)
	world = load("res://app/living_root.tscn").instantiate()
	world.qa_mode = true
	viewport.add_child(world)
	world.calendar.speed = 0
	var deadline: int = Time.get_ticks_msec() + 15000
	while (
		(world.queue.is_busy() or world.stage.is_busy() or world.meadow.is_busy())
		and Time.get_ticks_msec() < deadline
	):
		await get_tree().process_frame


func after_each() -> void:
	world.photography.busy = false
	if world.photo_active:
		world.exit_photo()
	world.walk_controller.reset_input()


func after_all() -> void:
	world.soundscape.shutdown()
	await SceneShutdown.wait_wallclock(get_tree(), 0.4)
	await SceneShutdown.release_scene(world)
	viewport.queue_free()
	await get_tree().process_frame


func _key(code: Key, down: bool) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	return event


func _button(down: bool) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = down
	return event


func _enter_flat_walk() -> FirstPersonWalk:
	assert_true(world.enter_photo())
	assert_true(world.start_walk())
	var controller: FirstPersonWalk = world.walk_controller
	controller.surface.configure(WorldDocument.new().state)
	var ground: Variant = controller.surface.ground_at(Vector2.ZERO)
	assert_not_null(ground)
	controller.feet = Vector3(0, float(ground), 0)
	controller.yaw = 0
	controller.pitch = 0
	controller.reset_input()
	return controller


func test_walking_requires_photo_and_restores_exact_editor_camera() -> void:
	var source: Dictionary = world.document.snapshot()
	var history: int = world.session.history_count()
	var record: Dictionary = world._camera_record()
	var camera: Camera3D = world.camera_rig.camera
	var fov: float = camera.fov
	var attributes: CameraAttributes = camera.attributes
	assert_false(world.start_walk())
	assert_true(world.enter_photo())
	assert_true(world.start_walk())
	assert_true(world.walk_controller.active)
	assert_true(
		world.walk_controller.surface.can_stand(
			Vector2(world.walk_controller.feet.x, world.walk_controller.feet.z)
		)
	)
	assert_almost_eq(camera.global_position.y - world.walk_controller.feet.y, 1.65, 0.001)
	assert_eq(camera.fov, 65.0)
	assert_almost_eq(camera.near, 0.06, 0.0001)
	assert_eq(camera.far, 90.0)
	assert_null(camera.attributes)
	assert_false(world.camera_rig.is_processing_input())
	assert_false(world.camera_rig.is_processing_unhandled_input())
	world.exit_photo()
	assert_false(world.walk_controller.active)
	assert_false(world.photo_active)
	assert_eq(world._camera_record(), record)
	assert_eq(camera.fov, fov)
	assert_same(camera.attributes, attributes)
	assert_eq(world.document.state, source)
	assert_eq(world.session.history_count(), history)


func test_walk_key_input_moves_forward_and_normalizes_diagonals() -> void:
	var controller: FirstPersonWalk = _enter_flat_walk()
	controller.handle(_key(KEY_W, true))
	controller.step(0.1)
	assert_lt(controller.feet.z, 0.0)
	assert_almost_eq(controller.feet.x, 0.0, 0.0001)
	var straight: float = Vector2(controller.feet.x, controller.feet.z).length()
	controller.feet = Vector3.ZERO
	controller.reset_input()
	controller.handle(_key(KEY_W, true))
	controller.handle(_key(KEY_D, true))
	controller.step(0.1)
	var diagonal: float = Vector2(controller.feet.x, controller.feet.z).length()
	assert_gt(controller.feet.x, 0.0)
	assert_lt(controller.feet.z, 0.0)
	assert_lte(diagonal, straight * 1.01)


func test_shift_is_faster_and_long_frames_cannot_teleport() -> void:
	var controller: FirstPersonWalk = _enter_flat_walk()
	controller.handle(_key(KEY_W, true))
	for i: int in range(5):
		controller.step(0.1)
	var normal: float = absf(controller.feet.z)
	controller.feet = Vector3.ZERO
	controller.reset_input()
	controller.handle(_key(KEY_W, true))
	controller.handle(_key(KEY_SHIFT, true))
	for i: int in range(5):
		controller.step(0.1)
	assert_gt(absf(controller.feet.z), normal)
	var before: Vector3 = controller.feet
	controller.step(20)
	assert_lte(controller.feet.distance_to(before), FirstPersonWalk.FAST_SPEED * 0.101)


func test_look_clamps_pitch_releases_cursor_and_does_not_orbit() -> void:
	var controller: FirstPersonWalk = _enter_flat_walk()
	var yaw: float = world.camera_rig.yaw
	var mode: Input.MouseMode = Input.mouse_mode
	assert_false(controller.handle(_button(true), true))
	assert_false(controller.looking)
	controller.handle(_button(true))
	assert_true(controller.looking)
	controller.yaw = 0
	controller.pitch = 0
	controller.look(Vector2(0.1, 0.1))
	assert_gt(controller.yaw, 0.0)
	assert_gt(controller.pitch, 0.0)
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.relative = Vector2(300, 999999)
	controller.handle(motion)
	assert_lte(absf(controller.pitch), 1.25)
	assert_ne(controller.yaw, 0.0)
	assert_eq(world.camera_rig.yaw, yaw)
	controller.handle(_button(false))
	assert_false(controller.looking)
	assert_eq(Input.mouse_mode, mode)
	var pan: InputEventPanGesture = InputEventPanGesture.new()
	pan.delta = Vector2(2, -3)
	var before: float = controller.yaw
	controller.handle(pan)
	assert_ne(controller.yaw, before)
	controller.look(Vector2(INF, 0))
	assert_true(is_finite(controller.yaw))


func test_typing_export_and_focus_loss_clear_held_movement() -> void:
	var controller: FirstPersonWalk = _enter_flat_walk()
	controller.handle(_key(KEY_W, true), false, true)
	controller.step(0.1)
	assert_eq(controller.feet, Vector3.ZERO)
	controller.handle(_key(KEY_W, true))
	controller.step(0.1, false)
	assert_eq(controller.feet, Vector3.ZERO)
	controller.handle(_button(true))
	controller.handle(_key(KEY_W, true))
	world._notification(NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	assert_false(controller.looking)
	assert_true(controller.keys.is_empty())
	var before: Vector3 = controller.feet
	controller.step(0.1)
	assert_eq(controller.feet, before)


func test_escape_exits_walk_and_photo_without_edit_history() -> void:
	var source: Dictionary = world.document.snapshot()
	var history: int = world.session.history_count()
	var record: Dictionary = world._camera_record()
	assert_true(world.enter_photo())
	assert_true(world.start_walk())
	world._input(_key(KEY_ESCAPE, true))
	assert_false(world.walk_controller.active)
	assert_false(world.photo_active)
	assert_eq(world._camera_record(), record)
	assert_eq(world.document.state, source)
	assert_eq(world.session.history_count(), history)


func test_walk_toggle_and_bookmark_guard_preserve_valid_camera_records() -> void:
	assert_true(world.enter_photo())
	world.hud.walk_toggle.pressed.emit()
	assert_true(world.walk_controller.active)
	assert_true(world.hud.walk_bookmark.disabled)
	var source: Dictionary = world.document.snapshot()
	world._photo_action("bookmark")
	assert_eq(world.document.state, source)
	world.hud.walk_toggle.pressed.emit()
	assert_false(world.walk_controller.active)
	assert_true(world.photo_active)
	assert_false(world.hud.walk_bookmark.disabled)
	for record: Dictionary in world.document.state["camera_bookmarks"]:
		assert_true(CameraRecord.valid(record))


func test_busy_export_cannot_switch_walk_or_exit_photo() -> void:
	assert_true(world.enter_photo())
	assert_true(world.start_walk())
	world.photography.busy = true
	var controller: FirstPersonWalk = world.walk_controller
	var before: Vector2 = Vector2(controller.yaw, controller.pitch)
	var pan: InputEventPanGesture = InputEventPanGesture.new()
	pan.delta = Vector2(20, 20)
	world._input(pan)
	assert_eq(Vector2(controller.yaw, controller.pitch), before)
	controller.looking = true
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.relative = Vector2(50, 20)
	world._input(motion)
	assert_eq(Vector2(controller.yaw, controller.pitch), before)
	assert_false(controller.looking)
	assert_true(controller.keys.is_empty())
	world._photo_action("walk")
	world.exit_photo()
	assert_true(world.walk_controller.active)
	assert_true(world.photo_active)
	world.photography.busy = false
	world.stop_walk()
	assert_false(world.walk_controller.active)
	assert_true(world.photo_active)
