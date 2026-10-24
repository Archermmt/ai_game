extends GutTest

var playground: Node3D
var viewport: SubViewport


func before_all() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.own_world_3d = true
	add_child(viewport)
	playground = load("res://app/living_root.tscn").instantiate()
	playground.qa_mode = true
	viewport.add_child(playground)
	playground.calendar.speed = 0
	var deadline: int = Time.get_ticks_msec() + 15000
	while (
		(playground.queue.is_busy() or playground.stage.is_busy() or playground.meadow.is_busy())
		and Time.get_ticks_msec() < deadline
	):
		await get_tree().process_frame


func after_all() -> void:
	playground.soundscape.shutdown()
	await SceneShutdown.wait_wallclock(get_tree(), 0.4)
	await SceneShutdown.release_scene(playground)
	viewport.queue_free()
	await get_tree().process_frame


func test_new_entry_has_real_relief_and_calendar() -> void:
	assert_eq(playground.document.state["buildings"].size(), 3)
	assert_eq(playground.document.state["terrain"]["base_profile"], "rolling_hills_v2")
	assert_true(playground.hud.calendar.visible)
	assert_true(
		playground.hud.blocks_scene_at(playground.hud.calendar.get_global_rect().get_center())
	)


func test_every_quick_tool_and_asset_uses_picture_with_accessible_description() -> void:
	for group: String in [
		"build", "path", "openings", "plants", "trees", "water", "props", "erase"
	]:
		playground.hud.open_group(group)
		await get_tree().process_frame
		await get_tree().process_frame
		for row: Control in [playground.hud.quick_choices, playground.hud.quick_assets]:
			for button: Button in row.get_children():
				assert_eq(button.text, "")
				assert_not_null(button.icon)
				assert_false(button.accessibility_name.is_empty())
	playground.hud.quick.hide()
	playground.tools.mode = "inspect"


func test_calendar_controls_change_date_weather_speed_without_source_or_history_edits() -> void:
	var source: Dictionary = playground.document.snapshot()
	var history: int = playground.session.history_count()
	var panel: CalendarPanel = playground.hud.calendar
	panel._selected("Month", 0)
	panel._selected("Day", 29)
	panel._selected("Weather", 3)
	panel._toggle_pause()
	assert_eq(playground.calendar.season(), "winter")
	assert_eq(playground.calendar.day, 30)
	assert_eq(playground.calendar.weather, "snow")
	assert_eq(playground.document.state, source)
	assert_eq(playground.session.history_count(), history)


func test_daynight_seasons_and_weather_render_state() -> void:
	var clock: CalendarState = playground.calendar
	var atmosphere: LivingAtmosphere = playground.atmosphere
	clock.weather = "clear"
	clock.month = 7
	clock.minute_of_day = 720
	playground.window_material.set_shader_parameter("dusk", true)
	atmosphere.update(0, clock.sample())
	assert_false(playground.window_material.get_shader_parameter("dusk"))
	var noon: float = playground.sun.light_energy
	clock.minute_of_day = 0
	atmosphere.update(0, clock.sample())
	assert_lt(playground.sun.light_energy, noon * 0.1)
	clock.weather = "rain"
	atmosphere.update(0, clock.sample())
	assert_true(atmosphere.rain.visible)
	assert_false(atmosphere.snow.visible)
	clock.weather = "snow"
	clock.month = 1
	atmosphere.update(0, clock.sample())
	assert_true(atmosphere.snow.visible)
	assert_false(atmosphere.rain.visible)
	# GPU global uniform effects are verified by the native four-season render suite.


func test_reduced_motion_and_photo_freeze_weather_and_clock() -> void:
	playground.tools.mode = "inspect"
	playground.hud.quick.hide()
	playground.calendar.weather = "rain"
	playground.atmosphere.elapsed = 17.8
	playground.atmosphere.reduced_motion = true
	playground.atmosphere.update(0, playground.calendar.sample())
	assert_false(playground.atmosphere.bolt.visible)
	playground.atmosphere.reduced_motion = false
	playground.atmosphere.update(0, playground.calendar.sample())
	assert_true(playground.atmosphere.bolt.visible)
	playground.calendar.speed = 20
	assert_true(playground.enter_photo())
	playground._freeze_photo(true)
	var record: Dictionary = playground.calendar.record()
	var phase: float = playground.atmosphere.elapsed
	playground._process(5)
	assert_eq(playground.calendar.record(), record)
	assert_eq(playground.atmosphere.elapsed, phase)
	assert_false(playground.hud.calendar.visible)
	playground.exit_photo()
	playground.calendar.speed = 0
	assert_true(playground.hud.calendar.visible)


func test_async_save_and_load_restore_calendar_presentation() -> void:
	playground.calendar.speed = 0
	playground.calendar.month = 10
	playground.calendar.day = 22
	playground.calendar.minute_of_day = 1134
	playground.calendar.weather = "cloudy"
	var expected: Dictionary = playground.calendar.record()
	playground._start_save(0, "W13历法回归")
	var deadline: int = Time.get_ticks_msec() + 15000
	while playground.saves.is_busy() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	assert_false(playground.saves.is_busy())
	var stored: Dictionary = SlotStore.read_slot(playground.saves.directory, 0)
	assert_true(stored["ok"])
	assert_eq(stored["metadata"]["presentation"]["calendar"], expected)
	playground.calendar.month = 1
	playground._start_load(0)
	deadline = Time.get_ticks_msec() + 15000
	while playground._loading and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	assert_false(playground._loading)
	assert_eq(playground.calendar.record(), expected)
	assert_false(playground.is_dirty())
	playground.hud.calendar._selected("Month", 2)
	assert_true(playground.is_dirty())
	for suffix: String in ["", ".tmp", ".bak1", ".bak2", ".bak3"]:
		var path: String = SlotStore.path_for(playground.saves.directory, 0) + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_legacy_dusk_maps_to_evening_and_can_return_to_daylight() -> void:
	var original: bool = playground.document.state["environment"]["dusk"]
	playground.document.state["environment"]["dusk"] = true
	playground._restore_extra_presentation({})
	playground.calendar.speed = 0
	playground.atmosphere.update(0, playground.calendar.sample())
	assert_gt(playground.sun.light_energy, 0.06)
	assert_lt(playground.sun.light_energy, 0.5)
	playground.calendar.minute_of_day = 720
	playground.atmosphere.update(0, playground.calendar.sample())
	assert_gt(playground.sun.light_energy, 1.0)
	assert_false(playground.window_material.get_shader_parameter("dusk"))
	playground.document.state["environment"]["dusk"] = original


func test_compact_calendar_groups_date_time_and_keeps_weather_in_heading() -> void:
	var panel: CalendarPanel = playground.hud.calendar
	var clock: CalendarState = playground.calendar
	var previous: Dictionary = clock.record()
	clock.month = 1
	clock.day = 1
	clock.minute_of_day = 420
	panel.sync()
	assert_eq(panel.fields["Month"].text + panel.fields["Day"].text, "Jan.1st")
	assert_eq(panel.fields["Hour"].text + ":" + panel.fields["Min"].text, "7:00")
	assert_eq(panel.fields["Month"].get_parent(), panel.fields["Day"].get_parent())
	assert_eq(panel.fields["Hour"].get_parent(), panel.fields["Min"].get_parent())
	assert_eq(panel.weather_icon.get_parent(), panel.season_label.get_parent())
	assert_eq(panel.weather_icon, panel.fields["Weather"])
	assert_eq(panel.weather_icon.text, "")
	assert_not_null(panel.weather_icon.icon)
	assert_eq(CalendarPanel._ordinal(11), "11th")
	assert_eq(CalendarPanel._ordinal(22), "22nd")
	panel._selected("Weather", 2)
	assert_eq(clock.weather, "rain")
	assert_eq(panel.weather_icon.text, "")
	panel._selected("Day", 29)
	panel._selected("Hour", 23)
	panel._selected("Min", 59)
	assert_eq(clock.day, 30)
	assert_eq(clock.minute_of_day, 1439.0)
	clock.restore(previous)
	panel.sync()


func test_speed_slider_covers_every_rate_and_pause_preserves_the_rate() -> void:
	var panel: CalendarPanel = playground.hud.calendar
	var previous: Dictionary = playground.calendar.record()
	var source: Dictionary = playground.document.snapshot()
	var history: int = playground.session.history_count()
	var slider: HSlider = panel.fields["Speed"]
	assert_eq(slider.min_value, 1.0)
	assert_eq(slider.max_value, 60.0)
	slider.value = 2
	for rate: float in [1.0, 17.0, 37.0, 60.0]:
		slider.value = rate
		assert_eq(playground.calendar.speed, rate)
		assert_eq(panel.speed_label.text, "%d×" % rate)
	panel._toggle_pause()
	assert_eq(playground.calendar.speed, 0.0)
	assert_eq(panel.speed_label.text, "暂停")
	panel._toggle_pause()
	assert_eq(playground.calendar.speed, 60.0)
	assert_eq(playground.document.state, source)
	assert_eq(playground.session.history_count(), history)
	assert_true(playground.calendar.restore(previous))
	panel.sync()


func test_current_hud_omits_legacy_modification_entries() -> void:
	for group: String in [
		"build", "path", "openings", "palette", "terrain", "plants", "trees", "water"
	]:
		playground.hud.open_group(group)
		await get_tree().process_frame
		for child: Button in playground.hud.quick_choices.get_children():
			assert_ne(child.accessibility_name, "更多参数…")
	assert_false(playground.hud.object_bar.get_child(0).get_child(2).visible)
	assert_true(playground.soundscape.music_override)
	assert_eq(playground.soundscape.ambient_gain, 0.5)
	playground.hud.quick.hide()
	playground.tools.mode = "inspect"
