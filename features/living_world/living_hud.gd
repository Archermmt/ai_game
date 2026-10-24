extends "res://features/hover_edit/hover_hud.gd"

var photo_icons: HBoxContainer
var photo_details: VBoxContainer
var photo_settings: Button
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
	if photo_icons != null:
		var available: Vector2 = get_viewport().get_visible_rect().size / _scale_value
		var width: float = minf(720, available.x - 24)
		var height: float = 400 if photo_details.visible else (210 if walk_hint.visible else 125)
		_photo_scroll.custom_minimum_size = Vector2(width, minf(height, available.y - 40))
		photo_panel.custom_minimum_size = Vector2.ZERO
		photo_panel.size = _photo_scroll.custom_minimum_size
		photo_panel.position = Vector2(
			(available.x - width) * 0.5, maxf(12, available.y - photo_panel.size.y - 28)
		)
		_refresh_mode_icons.call_deferred()


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
	_refresh_mode_icons.call_deferred()
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
	_refresh_mode_icons.call_deferred()
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
	_make_photo_icons(stack)
	set_walk_mode(false)
	var hooked: Array[Container] = []
	for button: Button in ribbon_buttons.values():
		button.resized.connect(_refresh_mode_icons.call_deferred)
		var parent: Container = button.get_parent()
		if parent not in hooked:
			parent.sort_children.connect(_refresh_mode_icons.call_deferred)
			hooked.append(parent)
	for box: Container in [quick_choices, quick_assets]:
		box.sort_children.connect(_refresh_choice_icons.call_deferred)
	photo_icons.sort_children.connect(_refresh_photo_icons.call_deferred)
	_refresh_mode_icons.call_deferred()


func set_walk_mode(enabled: bool) -> void:
	var title: Label = photo_note.get_parent().get_child(0)
	title.text = "摄影 · 林间漫步" if enabled else "摄影 · 双指移动旋转 / 捏合缩放"
	walk_toggle.text = ""
	walk_toggle.icon = IllustratedIcons.texture("overview" if enabled else "walk")
	walk_toggle.tooltip_text = "返回俯瞰视角" if enabled else "林间漫步 · 第一人称"
	walk_toggle.accessibility_name = walk_toggle.tooltip_text
	ModeIconFeedback.apply(walk_toggle, enabled)
	walk_toggle.add_theme_constant_override("icon_max_width", 48 if enabled else 44)
	walk_hint.visible = enabled
	if walk_bookmark != null:
		walk_bookmark.disabled = enabled
		walk_bookmark.tooltip_text = "漫步时可导出照片；返回俯瞰后可保存构图" if enabled else "保存当前构图"

	_layout_panels.call_deferred()


func _make_photo_icons(stack: VBoxContainer) -> void:
	photo_icons = HBoxContainer.new()
	photo_icons.name = "PhotoIconBar"
	photo_icons.add_theme_constant_override("separation", 8)
	stack.add_child(photo_icons)
	stack.move_child(photo_icons, 1)
	photo_details = VBoxContainer.new()
	photo_details.name = "PhotoDetails"
	stack.add_child(photo_details)
	for control: Control in [photo_size, photo_directory, bookmarks]:
		control.reparent(photo_details)
	photo_details.hide()
	var keys: Dictionary = {
		"选择本地目录": "folder",
		"导出 PNG / 重试": "photo",
		"保存当前构图": "bookmark",
		"应用选中构图": "overview",
		"隐藏摄影面板（Esc 返回）": "hide",
		"返回编辑": "back"
	}
	for child: Node in stack.get_children():
		if child is Button:
			var key: String = (
				"walk"
				if child == walk_toggle
				else ("freeze" if child == freeze else keys.get(child.text, "photo"))
			)
			child.tooltip_text = child.text
			child.accessibility_name = child.text
			child.text = ""
			child.icon = IllustratedIcons.texture(key)
			child.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			child.expand_icon = true
			child.custom_minimum_size = Vector2(64, 64)
			child.add_theme_constant_override("icon_max_width", 44)
			child.reparent(photo_icons)
			for state: String in ["normal", "hover", "pressed"]:
				child.add_theme_stylebox_override(
					state, _paper(Color("b8c1b1").lightened(0.12 if state != "normal" else 0))
				)
	photo_settings = Button.new()
	photo_settings.icon = IllustratedIcons.texture("settings")
	photo_settings.expand_icon = true
	photo_settings.custom_minimum_size = Vector2(64, 64)
	photo_settings.add_theme_constant_override("icon_max_width", 44)
	photo_settings.tooltip_text = "照片尺寸、目录与已存构图"
	photo_settings.accessibility_name = photo_settings.tooltip_text
	photo_settings.toggle_mode = true
	photo_settings.toggled.connect(
		func(enabled: bool) -> void:
			photo_details.visible = enabled
			ModeIconFeedback.apply(photo_settings, enabled)
			_layout_panels()
	)
	photo_icons.add_child(photo_settings)
	photo_icons.move_child(photo_settings, 3)
	var clear: Image = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	clear.fill(Color.TRANSPARENT)
	for key: String in ["checked", "unchecked", "checked_disabled", "unchecked_disabled"]:
		freeze.add_theme_icon_override(key, ImageTexture.create_from_image(clear))
	freeze.toggled.connect(func(enabled: bool) -> void: ModeIconFeedback.apply(freeze, enabled))


func _refresh_mode_icons() -> void:
	for key: String in ribbon_buttons:
		ModeIconFeedback.apply(ribbon_buttons[key], key == active_group)


func set_active_tool(mode: String) -> void:
	super.set_active_tool(mode)
	_refresh_mode_icons.call_deferred()


func _choice(parent: Node, title: String, callback: Callable) -> Button:
	var button: Button = super._choice(parent, title, callback)
	if title in ["取消本笔", "收起 ×", "更多参数…", "生活摆件…", "返回门窗", "返回浏览"]:
		return button
	button.toggle_mode = true
	button.pressed.connect(
		func() -> void:
			if button.get_parent() == null:
				return
			for box: Control in [quick_choices, quick_assets]:
				for item: Node in box.get_children():
					if item is Button:
						item.set_pressed_no_signal(item == button)
						ModeIconFeedback.apply(item, item == button)
						item.add_theme_constant_override(
							"icon_max_width", 52 if item == button else 48
						)
	)
	return button


func _refresh_choice_icons() -> void:
	for box: Container in [quick_choices, quick_assets]:
		for item: Node in box.get_children():
			if item is Button and item.toggle_mode:
				ModeIconFeedback.apply(item, item.button_pressed)


func _refresh_photo_icons() -> void:
	ModeIconFeedback.apply(walk_toggle, walk_hint.visible)
	ModeIconFeedback.apply(freeze, freeze.button_pressed)
	ModeIconFeedback.apply(photo_settings, photo_settings.button_pressed)
