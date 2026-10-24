extends "res://tests/ux_02/native_probe.gd"

var checks: Dictionary = {}
var observations: Dictionary = {}


func _key(code: Key, down: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	await process_frame


func _click(button: Button) -> void:
	# Settle layout, then deliver a complete GUI click in one input batch. OS
	# motion between synthetic press/release frames must not cancel the click.
	for i: int in range(5):
		await process_frame
	var point: Vector2 = button.get_global_rect().get_center()
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	for down: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		event.pressed = down
		Input.parse_input_event(event)
	await process_frame


func _during_export() -> void:
	# Deferred callback runs while capture awaits rendering; this is actual routed input.
	var walk: FirstPersonWalk = playground.walk_controller
	var before: Vector2 = Vector2(walk.yaw, walk.pitch)
	var pan: InputEventPanGesture = InputEventPanGesture.new()
	pan.delta = Vector2(30, 20)
	var busy: bool = playground.photography.busy
	Input.parse_input_event(pan)
	await process_frame
	checks["export_blocks_view_input"] = busy and before == Vector2(walk.yaw, walk.pitch)


func _run() -> void:
	folder = OS.get_cmdline_user_args()[-1]
	DirAccess.make_dir_recursive_absolute(folder)
	playground = load("res://app/living_root.tscn").instantiate()
	playground.qa_mode = true
	root.add_child(playground)
	await _settle()
	playground.calendar.speed = 0
	playground.calendar.month = 7
	playground.calendar.weather = "clear"
	playground.calendar.minute_of_day = 720
	playground.atmosphere.blend.advance(0, playground.calendar.sample())
	playground.atmosphere.blend.advance(WeatherBlend.DURATION, playground.calendar.sample())
	playground.atmosphere.update(0, playground.calendar.sample())
	var source: Dictionary = playground.document.snapshot()
	var history: int = playground.session.history_count()
	var editor: Dictionary = playground._camera_record()
	var fov: float = playground.camera_rig.camera.fov
	await _click(playground.hud.ribbon_buttons["photo"])
	checks["photo_button_real_click"] = (
		playground.photo_active and playground.hud.photo_panel.visible
	)
	await _click(playground.hud.walk_toggle)
	var walk: FirstPersonWalk = playground.walk_controller
	checks["walk_button_real_click"] = walk.active
	checks["safe_eye_level_spawn"] = (
		walk.surface.can_stand(Vector2(walk.feet.x, walk.feet.z))
		and absf(playground.camera_rig.camera.global_position.y - walk.feet.y - 1.65) < 0.01
	)
	checks["natural_world_unfrozen"] = not playground._climate_frozen
	for angle: float in [0.0, PI * 0.5, PI, PI * 1.5, PI * 0.25, PI * 0.75]:
		var offset: Vector2 = -Vector2(sin(angle), cos(angle)) * 0.7
		var target: Vector3 = walk.surface.move_grounded(walk.feet, offset)
		if Vector2(target.x - walk.feet.x, target.z - walk.feet.z).length() > 0.5:
			walk.yaw = angle
			break
	playground.hud.walk_toggle.release_focus()
	var before: Vector3 = walk.feet
	await _key(KEY_W, true)
	await SceneShutdown.wait_wallclock(self, 0.25)
	await _key(KEY_W, false)
	await SceneShutdown.wait_wallclock(self, 0.3)
	checks["real_w_key_moves_player"] = walk.feet.distance_to(before) > 0.05
	observations["walk_distance"] = walk.feet.distance_to(before)
	var old_yaw: float = walk.yaw
	var old_pitch: float = walk.pitch
	var point: Vector2 = Vector2(1200, 500)
	await _motion(point, Vector2.ZERO)
	await _mouse(point, true, MOUSE_BUTTON_RIGHT)
	await _motion(point + Vector2(80, 30), Vector2(80, 30))
	checks["right_drag_looks_around"] = walk.yaw != old_yaw and walk.pitch != old_pitch
	await _mouse(point, false, MOUSE_BUTTON_RIGHT)
	checks["mouse_release_restores_cursor"] = (
		not walk.looking and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED
	)
	var pan: InputEventPanGesture = InputEventPanGesture.new()
	pan.position = point
	pan.delta = Vector2(2, -3)
	old_yaw = walk.yaw
	Input.parse_input_event(pan)
	await process_frame
	checks["trackpad_gesture_looks_around"] = walk.yaw != old_yaw
	await _click(playground.hud.photo_settings)
	var directory: String = playground.hud.photo_directory.text
	playground.hud.photo_directory.grab_focus()
	await process_frame
	before = walk.feet
	await _key(KEY_W, true)
	await SceneShutdown.wait_wallclock(self, 0.15)
	await _key(KEY_W, false)
	checks["typing_directory_does_not_walk"] = walk.feet.distance_to(before) < 0.001
	playground.hud.photo_directory.text = directory
	playground.hud.photo_directory.release_focus()
	await _key(KEY_W, true)
	playground._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	before = walk.feet
	await SceneShutdown.wait_wallclock(self, 0.15)
	await _key(KEY_W, false)
	checks["focus_loss_clears_movement"] = (
		walk.feet.distance_to(before) < 0.001 and not walk.looking
	)
	var marker: ColorRect = ColorRect.new()
	marker.color = Color.MAGENTA
	marker.position = Vector2(1000, 20)
	marker.size = Vector2(80, 80)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	playground.hud.add_child(marker)
	await _frame("walk_ui_marker")
	var marked: Color = root.get_texture().get_image().get_pixel(1040, 60)
	checks["ui_marker_visible_in_game"] = marked.r > 0.9 and marked.b > 0.9 and marked.g < 0.1
	playground.hud.photo_directory.text = folder
	playground.hud.photo_size.select(0)
	_during_export.call_deferred()
	await playground._photo_action("export")
	var path: String = playground.hud.photo_note.text.trim_prefix("已导出：")
	var image: Image = Image.load_from_file(path)
	checks["first_person_photo_png"] = image != null and image.get_size() == Vector2i(1920, 1080)
	if image != null:
		var pixel: Color = image.get_pixel(1040, 60)
		checks["export_excludes_ui"] = not (pixel.r > 0.9 and pixel.b > 0.9 and pixel.g < 0.1)
		image.save_png(folder.path_join("walk_export.png"))
	checks["export_resumes_walk"] = (
		walk.active and not playground.photography.busy and not playground._climate_frozen
	)
	marker.queue_free()
	playground.hud.photo_panel.hide()
	await _frame("first_person_view")
	var scenic: Variant = walk.surface.find_spawn(Vector2(-2, 11))
	if scenic != null:
		walk.feet = scenic
		var direction: Vector3 = (
			Vector3(-5.3, 0.7, 5.7) - (walk.feet + Vector3.UP * walk.eye_height)
		)
		direction = direction.normalized()
		walk.yaw = atan2(-direction.x, -direction.z)
		walk.pitch = asin(direction.y)
		walk.look(Vector2.ZERO)
		await SceneShutdown.wait_wallclock(self, 0.2)
		await _frame("forest_walk_view")
	playground.hud.photo_panel.show()
	await _click(playground.hud.walk_toggle)
	checks["toggle_restores_overview"] = (
		not walk.active and playground.photo_active and playground.camera_rig.camera.fov == fov
	)
	await _click(playground.hud.walk_toggle)
	await _key(KEY_ESCAPE, true)
	await _key(KEY_ESCAPE, false)
	checks["escape_restores_editor"] = (
		not playground.photo_active and not walk.active and playground._camera_record() == editor
	)
	checks["source_and_history_unchanged"] = (
		playground.document.state == source and playground.session.history_count() == history
	)
	var passed: bool = not checks.values().has(false)
	var output: FileAccess = FileAccess.open(folder.path_join("walk_report.json"), FileAccess.WRITE)
	output.store_string(
		JSON.stringify({"checks": checks, "observations": observations, "passed": passed}, "\t")
	)
	output.close()
	playground.soundscape.shutdown()
	await SceneShutdown.wait_wallclock(self, 0.4)
	await SceneShutdown.release_scene(playground)
	for i: int in range(8):
		await process_frame
	quit(0 if passed else 1)
