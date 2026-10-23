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
	panel._selected("Speed", 0)
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
	atmosphere.update(0, clock.sample())
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
	assert_true(playground.enter_photo())
	playground._freeze_photo(true)
	var record: Dictionary = playground.calendar.record()
	var phase: float = playground.atmosphere.elapsed
	playground._process(5)
	assert_eq(playground.calendar.record(), record)
	assert_eq(playground.atmosphere.elapsed, phase)
	assert_false(playground.hud.calendar.visible)
	playground.exit_photo()
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
