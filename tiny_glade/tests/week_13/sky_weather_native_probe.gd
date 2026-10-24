extends "res://tests/ux_02/native_probe.gd"

var checks: Dictionary = {}
var measures: Dictionary = {}


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


func _render_sky(name_value: String, hour: float, direction: Vector3) -> Image:
	playground.calendar.minute_of_day = hour * 60
	playground.atmosphere.update(0, playground.calendar.sample())
	var camera: Camera3D = playground.camera_rig.camera
	camera.attributes = null
	camera.global_position = Vector3(0, 3, 16)
	camera.look_at(camera.global_position + direction)
	await _frame(name_value)
	return root.get_texture().get_image()


func _difference(a: Image, b: Image) -> float:
	var total: float = 0
	var count: int = 0
	for y: int in range(20, 650, 8):
		for x: int in range(20, 1900, 8):
			var p: Color = a.get_pixel(x, y)
			var q: Color = b.get_pixel(x, y)
			total += absf(p.r - q.r) + absf(p.g - q.g) + absf(p.b - q.b)
			count += 1
	return total / (count * 3)


func _run() -> void:
	folder = OS.get_cmdline_user_args()[-1]
	DirAccess.make_dir_recursive_absolute(folder)
	playground = load("res://app/living_root.tscn").instantiate()
	playground.qa_mode = true
	root.add_child(playground)
	await _settle()
	playground.calendar.speed = 0
	playground.calendar.automatic_weather = false
	playground.calendar.weather = "clear"
	playground.calendar.month = 7
	var source: Dictionary = playground.document.snapshot()
	await _click(playground.hud.ribbon_buttons["build"])
	await _frame("selected_build")
	checks["active_card_enlarged"] = playground.hud.ribbon_buttons["build"].scale.x > 1.0
	await _settle()
	checks["ready_before_camera_click"] = (
		not playground.queue.is_busy()
		and not playground.stage.is_busy()
		and not playground.meadow.is_busy()
	)
	await _click(playground.hud.ribbon_buttons["photo"])
	checks["camera_real_click"] = playground.photo_active
	if not playground.photo_active:
		push_error(
			(
				"Photo UI click failed: busy=%s phase=%s mouse=%s hovered=%s"
				% [
					playground._busy(),
					playground.session.phase,
					root.get_mouse_position(),
					root.gui_get_hovered_control()
				]
			)
		)
		quit(1)
		return
	checks["photo_actions_all_icons"] = true
	for button: Button in playground.hud.photo_icons.get_children():
		checks["photo_actions_all_icons"] = (
			checks["photo_actions_all_icons"]
			and button.text.is_empty()
			and button.icon != null
			and not button.tooltip_text.is_empty()
		)
	await _frame("photo_icon_bar")
	await _click(playground.hud.photo_settings)
	checks["photo_settings_real_click"] = playground.hud.photo_details.visible
	await _click(playground.hud.photo_settings)
	await _click(playground.hud.walk_toggle)
	checks["walk_icon_real_click"] = playground.walk_controller.active
	var walk: FirstPersonWalk = playground.walk_controller
	walk.yaw = 0
	walk.pitch = 0
	var event: InputEventPanGesture = InputEventPanGesture.new()
	event.position = Vector2(1200, 300)
	event.delta = Vector2(2, 3)
	await _motion(event.position, Vector2.ZERO)
	Input.parse_input_event(event)
	await process_frame
	checks["walk_direction_reversed"] = walk.yaw > 0 and walk.pitch > 0
	await _click(playground.hud.walk_toggle)
	playground.exit_photo()
	playground.hud.hide()
	playground._freeze_photo(false)
	var look: Vector3 = Vector3(-0.6, 0.65, -0.45).normalized()
	var day: Image = await _render_sky("day_clouds", 10, look)
	var elapsed: float = playground.atmosphere.elapsed
	playground.atmosphere.elapsed += 40
	var moved: Image = await _render_sky("moving_clouds", 10, look)
	measures["cloud_pixel_difference"] = _difference(day, moved)
	checks["clouds_move"] = measures["cloud_pixel_difference"] > 0.001
	playground.atmosphere.elapsed = elapsed
	var night: Image = await _render_sky("night_stars", 23, look)
	measures["day_night_difference"] = _difference(day, night)
	var star_count: int = 0
	for y: int in range(8, 650, 2):
		for x: int in range(8, 1900, 2):
			var luma: float = night.get_pixel(x, y).get_luminance()
			if (
				luma > night.get_pixel(x + 4, y).get_luminance() + 0.025
				and luma > night.get_pixel(x - 4, y).get_luminance() + 0.025
			):
				star_count += 1
	measures["star_samples"] = star_count
	checks["stars_visible"] = star_count > 20
	checks["night_visibly_distinct"] = measures["day_night_difference"] > 0.05
	var material: ShaderMaterial = playground.atmosphere.sky.material
	var sun: Vector3
	playground.calendar.minute_of_day = 600
	playground.atmosphere.update(0, playground.calendar.sample())
	sun = material.get_shader_parameter("sun_direction")
	var sun_image: Image = await _render_sky("sun", 10, sun)
	checks["sun_visible"] = (
		sun_image.get_pixel(960, 540).get_luminance()
		> sun_image.get_pixel(300, 200).get_luminance() + 0.05
	)
	playground.calendar.minute_of_day = 1380
	playground.atmosphere.update(0, playground.calendar.sample())
	sun = material.get_shader_parameter("sun_direction")
	var moon_image: Image = await _render_sky("moon", 23, -sun)
	checks["moon_visible"] = (
		moon_image.get_pixel(960, 540).get_luminance()
		> moon_image.get_pixel(300, 200).get_luminance() + 0.15
	)
	await _render_sky("sunset", 18, Vector3(-0.8, 0.15, -0.5).normalized())
	await _render_sky("rain_start", 12, look)
	playground.calendar.weather = "storm"
	var before: float = playground.sun.light_energy
	playground.atmosphere.update(0, playground.calendar.sample())
	checks["no_switch_frame_jump"] = is_equal_approx(before, playground.sun.light_energy)
	await SceneShutdown.wait_wallclock(self, 4)
	measures["early_rain"] = playground.atmosphere.blend.current["rain"]
	checks["clouds_before_rain"] = (
		measures["early_rain"] == 0 and playground.atmosphere.blend.current["cloud"] > 0.18
	)
	await _frame("rain_clouding")
	await SceneShutdown.wait_wallclock(self, 5)
	measures["middle_rain"] = playground.atmosphere.blend.current["rain"]
	checks["rain_gradually_increases"] = measures["middle_rain"] > 0 and measures["middle_rain"] < 1
	await _frame("rain_building")
	await SceneShutdown.wait_wallclock(self, 9)
	checks["storm_reached_target"] = playground.atmosphere.blend.age == WeatherBlend.DURATION
	await _frame("rain_full")
	playground._freeze_photo(true)
	# Compare two frozen frames after the newly pinned state has rendered and TAA settles.
	for i: int in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	var image_a: Image = root.get_texture().get_image()
	await SceneShutdown.wait_wallclock(self, 0.3)
	await _frame("frozen")
	var image_b: Image = root.get_texture().get_image()
	measures["frozen_difference"] = _difference(image_a, image_b)
	checks["sky_and_weather_freeze"] = measures["frozen_difference"] < 0.003
	checks["source_unchanged"] = playground.document.state == source
	var file: FileAccess = FileAccess.open(folder.path_join("report.json"), FileAccess.WRITE)
	file.store_string(
		JSON.stringify(
			{"checks": checks, "measures": measures, "passed": not checks.values().has(false)}, "\t"
		)
	)
	file.close()
	playground.soundscape.shutdown()
	await SceneShutdown.wait_wallclock(self, 0.4)
	await SceneShutdown.release_scene(playground)
	for i: int in range(8):
		await process_frame
	quit(0 if not checks.values().has(false) else 1)
