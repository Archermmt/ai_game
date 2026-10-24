extends "res://features/hover_edit/hover_hud.gd"

var walk_toggle: Button
var walk_hint: Label
var walk_bookmark: Button
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


func _ready() -> void:
	super._ready()
	var stack: VBoxContainer = photo_note.get_parent()
	walk_toggle = Button.new()
	walk_toggle.name = "FirstPersonWalk"
	walk_toggle.icon = IllustratedIcons.texture("walk")
	walk_toggle.expand_icon = true
	walk_toggle.add_theme_constant_override("icon_max_width", 24)
	walk_toggle.pressed.connect(func() -> void: photo_requested.emit("walk"))
	stack.add_child(walk_toggle)
	stack.move_child(walk_toggle, 1)
	walk_hint = Label.new()
	walk_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	walk_hint.text = "WASD/方向键行走 · Shift稍快\n右键拖动/双指环顾 · 松开右键操作面板\nEsc返回编辑；可隐藏面板沉浸漫步"
	stack.add_child(walk_hint)
	stack.move_child(walk_hint, 2)
	for child: Node in stack.get_children():
		if child is Button and child.text == "保存当前构图":
			walk_bookmark = child
	set_walk_mode(false)


func set_walk_mode(enabled: bool) -> void:
	var title: Label = photo_note.get_parent().get_child(0)
	title.text = "摄影 · 林间漫步" if enabled else "摄影 · 双指移动旋转 / 捏合缩放"
	walk_toggle.text = "返回俯瞰视角" if enabled else "林间漫步 · 第一人称"
	walk_toggle.accessibility_name = walk_toggle.text
	walk_hint.visible = enabled
	if walk_bookmark != null:
		walk_bookmark.disabled = enabled
		walk_bookmark.tooltip_text = "漫步时可导出照片；返回俯瞰后可保存构图" if enabled else "保存当前构图"
