extends "res://tests/ux_02/native_probe.gd"

var observations: Array[Dictionary] = []


func _key(code: Key) -> void:
	for down: bool in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.window_id = playground.hud.calendar.fields["Month"].get_popup().get_window_id()
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame


func _run() -> void:
	folder = OS.get_cmdline_user_args()[-1]
	DirAccess.make_dir_recursive_absolute(folder)
	playground = load("res://app/living_root.tscn").instantiate()
	playground.qa_mode = true
	root.add_child(playground)
	playground.calendar.speed = 0
	await _settle()
	var source: Dictionary = playground.document.snapshot()
	var button: Button = playground.hud.ribbon_buttons["build"]
	var position: Vector2 = button.get_global_rect().get_center()
	await _motion(position, Vector2.ZERO)
	await _mouse(position, true)
	await _mouse(position, false)
	evidence["real_build_button"] = playground.hud.quick.visible and playground.hud.group == "build"
	evidence["all_build_options_illustrated"] = true
	for choice: Button in playground.hud.quick_choices.get_children():
		evidence["all_build_options_illustrated"] = (
			evidence["all_build_options_illustrated"]
			and choice.text.is_empty()
			and choice.icon != null
			and not choice.accessibility_name.is_empty()
		)
	await _frame("illustrated_build")
	playground.hud.close_context()
	var month: OptionButton = playground.hud.calendar.fields["Month"]
	position = month.get_global_rect().get_center()
	await _motion(position, Vector2.ZERO)
	await _mouse(position, true)
	await _mouse(position, false)
	# A newly opened PopupMenu starts with no keyboard focus; Down selects item0.
	await _key(KEY_DOWN)
	await _key(KEY_ENTER)
	evidence["month_dropdown_input"] = playground.calendar.month == 1
	observations.append(
		{
			"case": "dropdown",
			"actual_month": playground.calendar.month,
			"popup_visible": month.get_popup().visible
		}
	)
	month.get_popup().hide()
	var slider: HSlider = playground.hud.calendar.fields["Speed"]
	var rect: Rect2 = slider.get_global_rect()
	var start: Vector2 = Vector2(rect.position.x + 6, rect.get_center().y)
	var end: Vector2 = Vector2(rect.end.x - 6, rect.get_center().y)
	await _motion(start, Vector2.ZERO)
	await _mouse(start, true)
	await _motion(end, end - start)
	await _mouse(end, false)
	evidence["speed_slider_real_drag"] = playground.calendar.speed >= 55
	evidence["no_legacy_modify_button"] = true
	for choice: Button in playground.hud.quick_choices.get_children():
		if choice.accessibility_name == "更多参数…":
			evidence["no_legacy_modify_button"] = false
	playground.calendar.speed = 37

	for entry: Array in [
		["spring", 4, "clear", 12.0],
		["summer", 7, "clear", 12.0],
		["autumn_cloud", 10, "cloudy", 15.0],
		["winter_snow", 1, "snow", 10.5],
		["rain_lightning", 7, "rain", 14.0],
		["night", 7, "clear", 0.0]
	]:
		playground.calendar.month = entry[1]
		playground.calendar.weather = entry[2]
		playground.calendar.minute_of_day = entry[3] * 60
		playground.atmosphere.elapsed = 17.82 if entry[0] == "rain_lightning" else 6.0
		playground._freeze_photo(true)
		playground.hud.calendar.sync()
		playground.atmosphere.update(0, playground.calendar.sample())
		await _frame(entry[0])
		observations.append(
			{
				"case": entry[0],
				"calendar": playground.calendar.sample(),
				"sun_energy": playground.sun.light_energy,
				"sun_rotation": str(playground.sun.rotation_degrees),
				"rain": playground.atmosphere.rain.visible,
				"snow": playground.atmosphere.snow.visible,
				"lightning": playground.atmosphere.bolt.visible,
				"grass": playground.meadow.total
			}
		)
		playground._freeze_photo(false)
	evidence["summer_sun_stronger"] = observations[2]["sun_energy"] > observations[1]["sun_energy"]
	evidence["night_darker"] = observations[6]["sun_energy"] < observations[2]["sun_energy"] * 0.1
	evidence["snow_visible"] = observations[4]["snow"] and not observations[4]["rain"]
	evidence["rain_and_lightning_visible"] = (
		observations[5]["rain"] and observations[5]["lightning"]
	)
	evidence["date_not_a_source_edit"] = playground.document.state == source
	playground._preference_changed("ui_scale", 1.5)
	await _frame("calendar_150")
	evidence["calendar_150_inside"] = Rect2(Vector2.ZERO, Vector2(root.size)).encloses(
		playground.hud.calendar.get_global_rect()
	)
	playground._preference_changed("ui_scale", 1.0)
	playground.calendar.weather = "cloudy"
	playground.calendar.minute_of_day = 720
	playground.atmosphere.elapsed = 0
	playground._freeze_photo(true)
	playground.atmosphere.update(0, playground.calendar.sample())
	await _frame("cloud_shadow_a")
	playground.atmosphere.elapsed = 20
	playground.atmosphere.update(0, playground.calendar.sample())
	await _frame("cloud_shadow_b")
	var image_a: Image = Image.load_from_file(folder.path_join("cloud_shadow_a.png"))
	var image_b: Image = Image.load_from_file(folder.path_join("cloud_shadow_b.png"))
	var difference: float = 0.0
	var pixels: int = 0
	for y: int in range(400, 950, 25):
		for x: int in range(100, 1500, 25):
			var a: Color = image_a.get_pixel(x, y)
			var b: Color = image_b.get_pixel(x, y)
			difference += absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
			pixels += 1
	var mean_difference: float = difference / (pixels * 3)
	evidence["moving_cloud_shadow_pixels"] = mean_difference > 0.003
	observations.append(
		{"case": "cloud_motion", "mean_rgb_difference": mean_difference, "pixels": pixels}
	)
	var camera_record: Dictionary = playground._camera_record()
	playground.camera_rig.distance = 43
	playground.camera_rig.pitch = 0.62
	playground.camera_rig.refresh()
	await _frame("relief_overview")
	playground._restore_camera(camera_record)
	await _motion(Vector2(700, 80), Vector2.ZERO)
	playground.calendar.automatic_weather = false
	for entry: Array in [["storm", 7], ["blizzard", 1], ["duststorm", 7], ["fog", 4]]:
		playground.calendar.month = entry[1]
		playground.calendar.weather = entry[0]
		playground.calendar.minute_of_day = 720
		playground.calendar.align_weather()
		playground.atmosphere.elapsed = 5.8
		playground.atmosphere.update(0, playground.calendar.sample())
		playground.hud.calendar.sync()
		await _frame("weather_" + entry[0])
		evidence["effect_" + entry[0]] = (
			playground.atmosphere.rain.visible
			if entry[0] == "storm"
			else (
				playground.atmosphere.snow.visible
				if entry[0] == "blizzard"
				else (
					playground.atmosphere.dust.visible
					if entry[0] == "duststorm"
					else playground.world_environment.environment.fog_density > 0.01
				)
			)
		)
	playground.calendar.automatic_weather = true
	playground.calendar.month = 2
	playground.calendar.day = 30
	playground.hud.calendar.sync()
	position = playground.hud.calendar.next_day_button.get_global_rect().get_center()
	await _motion(position, Vector2.ZERO)
	await _mouse(position, true)
	await _mouse(position, false)
	evidence["next_morning_real_click"] = (
		playground.calendar.month == 3
		and playground.calendar.day == 1
		and playground.calendar.minute_of_day == 360
	)
	position = playground.hud.ribbon_buttons["light"].get_global_rect().get_center()
	await _motion(position, Vector2.ZERO)
	await _mouse(position, true)
	await _mouse(position, false)
	var controls: WeatherControls = playground.hud.weather_controls
	evidence["bottom_weather_controls"] = controls.visible and playground.tools.mode == "inspect"
	var weight: HSlider = controls.sliders["storm"]
	rect = weight.get_global_rect()
	start = Vector2(rect.position.x + 6, rect.get_center().y)
	end = Vector2(rect.end.x - 6, rect.get_center().y)
	await _motion(start, Vector2.ZERO)
	await _mouse(start, true)
	await _motion(end, end - start)
	await _mouse(end, false)
	evidence["probability_real_drag"] = (
		playground.calendar.weather_weights["spring"]["storm"] >= 95
		and WeatherCycle.valid(playground.calendar.weather_weights)
	)
	playground._preference_changed("ui_scale", 1.5)
	await _frame("weather_weights_150")
	evidence["weather_controls_150_inside"] = Rect2(Vector2.ZERO, Vector2(root.size)).encloses(
		controls.get_global_rect()
	)
	controls.season_choice.select(3)
	controls.sync()
	evidence["winter_forbids_rain"] = (
		not controls.sliders["rain"].editable
		and not controls.sliders["storm"].editable
		and controls.sliders["blizzard"].editable
	)
	await _frame("winter_weights_150")
	evidence["weather_settings_not_geometry"] = playground.document.state == source
	var passed: bool = true
	for value: bool in evidence.values():
		passed = passed and value
	var file: FileAccess = FileAccess.open(folder.path_join("native_report.json"), FileAccess.WRITE)
	file.store_string(
		JSON.stringify({"checks": evidence, "observations": observations, "passed": passed}, "\t")
	)
	file.close()
	playground.soundscape.shutdown()
	await SceneShutdown.wait_wallclock(self, 0.4)
	await SceneShutdown.release_scene(playground)
	quit(0 if passed else 1)
