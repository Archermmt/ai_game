extends "res://features/hover_edit/hover_playground.gd"
## Scene-owned clock/atmosphere. Source edits retain the existing transactions.

var pond_reflections: PondReflections
var seasonal_music: SeasonalMusic
var calendar: CalendarState = CalendarState.new()
var atmosphere: LivingAtmosphere
var _music_quitting: bool = false
var _calendar_refresh: float = 0.0
var _climate_frozen: bool = false
var _calendar_revision: int = 0


func _setup_initial_buildings() -> void:
	var source: Dictionary = ArtLayout.create()
	if "--w09-stress" in OS.get_cmdline_user_args():
		source = StressLayout.create()
	else:
		source = TerrainRelief.apply(source)
	_show_result(session.replace_document(source, _prepare_views), "四季林间庭园")


func _ready() -> void:
	super._ready()
	if qa_mode:
		saves.directory = "user://qa_week13_native"
	soundscape.ambient_gain = 0.5
	soundscape.music_override = true
	soundscape.music.stop()
	seasonal_music = SeasonalMusic.new()
	soundscape.add_child(seasonal_music)
	seasonal_music.configure(preferences.values["music_volume"])
	_persist_preferences()
	pond_reflections = PondReflections.new()
	world_view.add_child(pond_reflections)
	pond_reflections.configure(self)
	hud.attach_calendar(calendar)
	atmosphere = LivingAtmosphere.new()
	world_view.add_child(atmosphere)
	atmosphere.configure(self)
	hud.calendar.changed.connect(_calendar_changed)
	for argument: String in OS.get_cmdline_user_args():
		if qa_mode and argument.begins_with("--season="):
			calendar.month = {"spring": 4, "summer": 7, "autumn": 10, "winter": 1}.get(
				argument.trim_prefix("--season="), 5
			)
		if (
			qa_mode
			and argument.begins_with("--weather=")
			and argument.trim_prefix("--weather=") in CalendarState.WEATHER
		):
			calendar.weather = argument.trim_prefix("--weather=")
		if qa_mode and argument.begins_with("--hour="):
			calendar.minute_of_day = (
				clampf(argument.trim_prefix("--hour=").to_float(), 0, 23.99) * 60
			)
	atmosphere.update(0, calendar.sample())
	calendar.align_weather()
	hud.calendar.sync()
	hud.set_status("点示意图建造 · 右侧林间历可选择日期、天气与时间流速")


func _advance_light(delta: float) -> void:
	if atmosphere == null:
		super._advance_light(delta)


func _process(delta: float) -> void:
	super._process(delta)
	if atmosphere == null:
		return
	atmosphere.reduced_motion = preferences.values.get("reduce_motion", false)
	if not _climate_frozen:
		calendar.advance(delta)
	atmosphere.frozen = _climate_frozen
	atmosphere.update(delta, calendar.sample())
	if pond_reflections != null:
		pond_reflections.tick(delta, calendar.sample())
	if seasonal_music != null:
		seasonal_music.sync_calendar(calendar.sample())
	if soundscape != null:
		var wind: float = float(document.state["environment"]["wind_strength"])
		soundscape.wind = (
			maxf(wind, 0.95) if calendar.weather in ["storm", "blizzard", "duststorm"] else wind
		)
	_calendar_refresh += delta
	if _calendar_refresh > 0.2:
		_calendar_refresh = 0
		hud.calendar.sync()


func _freeze_photo(enabled: bool) -> void:
	super._freeze_photo(enabled)
	_climate_frozen = enabled


func _calendar_changed() -> void:
	_calendar_revision += 1
	atmosphere.update(0, calendar.sample())


func _extra_dirty_key() -> int:
	return _calendar_revision


func _extra_presentation() -> Dictionary:
	return {"calendar": calendar.record()}


func _restore_extra_presentation(value: Dictionary) -> void:
	_calendar_revision = 0
	var fallback: Dictionary = CalendarState.new().record()
	if document.state["environment"].get("dusk", false):
		fallback["minute_of_day"] = 1050.0
	calendar.restore(value.get("calendar", fallback))
	if hud.calendar != null:
		hud.calendar.sync()
		hud.weather_controls.sync()


func _apply_layout() -> void:
	_cancel_edit()
	var source: Dictionary = TerrainRelief.apply(
		ArtLayout.empty() if _layout_kind == "empty" else ArtLayout.create()
	)
	var result: Dictionary = session.replace_document(source, _prepare_views)
	if result["ok"]:
		active_slot = -1
		active_title = "林间新作"
		tools.selected.clear()
		_show_selection()
		_recommended_view(0)


func _on_action(action: StringName) -> void:
	if action == &"light" and atmosphere != null:
		calendar.minute_of_day = 1050.0 if calendar.minute_of_day < 1000 else 630.0
		hud.calendar.sync()
		_calendar_changed()
		return
	super._on_action(action)


func _delivery_metrics() -> Dictionary:
	var result: Dictionary = super._delivery_metrics()
	result["calendar"] = calendar.sample()
	result["water_reflection_captures"] = (
		pond_reflections.captures if pond_reflections != null else 0
	)
	result["terrain_profile"] = document.state.get("terrain", {}).get("base_profile", "flat")
	if atmosphere != null:
		result["weather_particles"] = (
			(1400 if atmosphere.rain.visible else 0)
			+ (900 if atmosphere.snow.visible else 0)
			+ (700 if atmosphere.dust.visible else 0)
		)
		result["living_sun_energy"] = sun.light_energy
	return result


func _apply_preferences() -> void:
	if not preferences.values.get("seasonal_music_initialized", false):
		preferences.values["seasonal_music_initialized"] = true
		if preferences.values["music_volume"] == 0:
			preferences.values["music_volume"] = 0.5
	super._apply_preferences()
	if seasonal_music != null:
		seasonal_music.configure(preferences.values["music_volume"])


func _request_quit() -> void:
	if _music_quitting:
		return
	_music_quitting = true
	if seasonal_music != null:
		seasonal_music.fade_out()
		await SceneShutdown.wait_wallclock(get_tree(), 1.6)
	super._request_quit()


func _setup_materials() -> void:
	super._setup_materials()
	water_material.shader = preload("res://features/pond_water/reflective_pond.gdshader")


func _on_published(snapshot: Dictionary, prepared: Dictionary) -> void:
	super._on_published(snapshot, prepared)
	if pond_reflections != null:
		pond_reflections.request_update()
