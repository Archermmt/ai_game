extends "res://features/hover_edit/hover_hud.gd"

var weather_controls: WeatherControls
var calendar: CalendarPanel
var _weather_visible: bool = false
var _calendar_visible: bool = true


func attach_calendar(clock: CalendarState) -> void:
	calendar = CalendarPanel.new()
	calendar.configure(clock)
	add_child(calendar)
	weather_controls = WeatherControls.new()
	weather_controls.configure(clock)
	weather_controls.changed.connect(
		func() -> void:
			calendar.sync()
			calendar.changed.emit()
	)
	add_child(weather_controls)
	weather_controls.hide()
	ribbon_buttons["light"].tooltip_text = "四季天气 · 出现比例"
	ribbon_buttons["light"].accessibility_name = "四季天气设置"
	_layout_panels()


func _layout_panels() -> void:
	super._layout_panels()
	if calendar != null:
		var available: Vector2 = get_viewport().get_visible_rect().size / _scale_value
		calendar.position = Vector2(available.x - 296, 76)
		calendar.size = Vector2(280, 310)
		if weather_controls != null:
			weather_controls.position = Vector2(
				available.x * 0.5 - 280, maxf(76, available.y - 530)
			)
			weather_controls.size = Vector2(560, minf(400, available.y - 200))


func blocks_scene_at(screen: Vector2) -> bool:
	return (
		super.blocks_scene_at(screen)
		or (
			weather_controls != null
			and weather_controls.visible
			and weather_controls.get_global_rect().has_point(screen)
		)
		or (calendar != null and calendar.visible and calendar.get_global_rect().has_point(screen))
	)


func set_photo_mode(enabled: bool) -> void:
	super.set_photo_mode(enabled)
	if calendar == null:
		return
	if enabled:
		_weather_visible = weather_controls.visible
		weather_controls.hide()
		_calendar_visible = calendar.visible
		calendar.hide()
	else:
		calendar.visible = _calendar_visible
		weather_controls.visible = _weather_visible


func open_group(key: String, activate: bool = true) -> void:
	if weather_controls != null:
		weather_controls.hide()
	if key != "light" or weather_controls == null:
		super.open_group(key, activate)
		return
	if not activate:
		return
	action_requested.emit(&"finish_edit")
	quick.hide()
	context.hide()
	group = key
	active_group = key
	for id_value: String in ribbon_buttons:
		ribbon_buttons[id_value].set_pressed_no_signal(id_value == key)
	weather_controls.sync()
	weather_controls.show()
	_layout_panels()


func close_context() -> void:
	super.close_context()
	if weather_controls != null:
		weather_controls.hide()
