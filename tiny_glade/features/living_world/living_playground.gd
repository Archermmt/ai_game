extends "res://features/hover_edit/hover_playground.gd"
## Scene-owned clock/atmosphere. Source edits retain the existing transactions.

var walk_controller: FirstPersonWalk = FirstPersonWalk.new()
var pond_reflections: PondReflections
var seasonal_music: SeasonalMusic
var calendar: CalendarState = CalendarState.new()
var atmosphere: LivingAtmosphere
var _walk_was_frozen: bool = false
var _walk_orbit_recording: bool = false
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
	if walk_controller.active:
		var focus: Control = get_viewport().gui_get_focus_owner()
		walk_controller.step(
			delta,
			(
				not photography.busy
				and not (focus is LineEdit or focus is TextEdit or focus is ItemList)
			)
		)
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
		var visual: Dictionary = atmosphere.blend.current
		var severity: float = maxf(visual["rain"], maxf(visual["snow"], visual["dust"]))
		soundscape.wind = lerpf(wind, maxf(wind, 0.95), smoothstep(0.55, 1.0, severity))
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


func start_walk() -> bool:
	if not photo_active or photography.busy:
		return false
	if walk_controller.active:
		return true
	if not walk_controller.begin(camera_rig, document.snapshot()):
		hud.photo_note.text = "附近没有安全的落脚点，请先换个俯瞰构图"
		return false
	_walk_was_frozen = hud.freeze.button_pressed
	_walk_orbit_recording = _orbit_recording
	_orbit_recording = false
	hud.freeze.set_pressed_no_signal(false)
	_freeze_photo(false)
	hud.set_walk_mode(true)
	hud.photo_note.text = "已进入林间漫步，可行走、环顾并导出照片"
	return true


func stop_walk() -> void:
	if not walk_controller.active:
		return
	walk_controller.stop()
	_orbit_recording = _walk_orbit_recording
	hud.set_walk_mode(false)
	hud.freeze.set_pressed_no_signal(_walk_was_frozen)
	_freeze_photo(_walk_was_frozen)


func exit_photo() -> void:
	if photography != null and photography.busy:
		return
	stop_walk()
	super.exit_photo()


func _photo_action(action: String) -> void:
	if photography.busy:
		return
	if action == "walk":
		if walk_controller.active:
			stop_walk()
		else:
			start_walk()
		return
	if walk_controller.active and action == "bookmark":
		hud.photo_note.text = "漫步照片可直接导出，返回俯瞰后可保存构图"
		return
	if walk_controller.active and action == "restore":
		stop_walk()
	if walk_controller.active and action == "export":
		walk_controller.reset_input()
		var was_frozen: bool = _climate_frozen
		_freeze_photo(true)
		await super._photo_action(action)
		if photo_active and walk_controller.active:
			_freeze_photo(was_frozen)
		return
	super._photo_action(action)


func _input(event: InputEvent) -> void:
	if walk_controller.active:
		if photography.busy:
			walk_controller.reset_input()
			get_viewport().set_input_as_handled()
			return
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			exit_photo()
			get_viewport().set_input_as_handled()
			return
		var focus: Control = get_viewport().gui_get_focus_owner()
		var typing: bool = focus is LineEdit or focus is TextEdit or focus is ItemList
		var over_ui: bool = get_viewport().gui_get_hovered_control() != null
		if walk_controller.handle(event, over_ui, typing):
			get_viewport().set_input_as_handled()
		return
	super._input(event)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and walk_controller != null:
		walk_controller.reset_input()
	super._notification(what)


func _exit_tree() -> void:
	if walk_controller != null:
		walk_controller.stop()
	super._exit_tree()
