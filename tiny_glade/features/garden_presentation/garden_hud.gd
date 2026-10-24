extends "res://features/audio/audio_hud.gd"
## Compact illustrated ribbon; existing transactional controls remain in a contextual drawer.

const EXTRA: Dictionary = {
	"paint": preload("res://assets/ui/garden/palette.svg"),
	"edit": preload("res://assets/ui/garden/edit.svg"),
	"photo": preload("res://assets/ui/garden/camera.svg"),
	"sun": preload("res://assets/ui/garden/sun.svg"),
	"settings": preload("res://assets/ui/garden/settings.svg"),
	"library": preload("res://assets/ui/garden/library.svg"),
	"undo": preload("res://assets/ui/garden/undo.svg"),
	"redo": preload("res://assets/ui/garden/redo.svg")
}
const GROUPS: Array = [
	["build", "house", "建造", "c78d68"],
	["path", "path", "石径", "c99b87"],
	["openings", "window", "门窗", "d8b56d"],
	["palette", "paint", "色板", "c1a47e"],
	["edit", "edit", "修改", "cb9f7b"],
	["terrain", "raise", "地形", "aaa977"],
	["plants", "plant", "花草", "b1bd84"],
	["trees", "tree", "树木", "8ea777"],
	["water", "pond", "池岸", "90b2b4"],
	["props", "props", "道具", "b8a281"],
	["photo", "photo", "摄影", "9ba8aa"],
	["light", "sun", "光线", "c8c17c"]
]
const TOOLS: Dictionary = {
	"build": [["rect", "矩形小屋"], ["round", "圆形小屋"]],
	"path": [["path", "画石径"], ["path_node", "修改路径"], ["fence", "画围栏"]],
	"openings": [["place_opening", "放置门窗"], ["move_opening", "移动开口"]],
	"edit": [["select", "选择"], ["move", "移动"], ["rotate", "旋转"], ["copy", "复制"], ["delete", "删除"]],
	"terrain": [["raise", "抬高"], ["lower", "降低"], ["smooth", "平滑"], ["restore", "恢复"]],
	"plants": [["plant_brush", "刷植"], ["plant_erase", "擦除刷植"], ["hedge", "绿篱"]],
	"water":
	[
		["shore", "画池岸"],
		["edit_garden", "修改池岸"],
		["bridge", "短桥"],
		["stair", "短阶"],
		["delete_pool", "删除池"]
	],
	"light": [["light", "日间 / 黄昏"], ["age", "新居 / 岁月"], ["view_day", "远景"], ["view_garden", "庭院"]]
}
var ribbon_buttons: Dictionary = {}
var context: PanelContainer
var context_body: VBoxContainer
var context_status: Label
var cancel_stroke: Button
var context_title: Label
var grass_slider: HSlider
var grass_caption: Label
var utilities: HBoxContainer
var breadcrumbs: Label
var group: String = ""
var active_group: String = "edit"
var _choices: HFlowContainer
var _assets: HFlowContainer
var _grass_row: VBoxContainer
var _brush_controls: VBoxContainer
var _environment: Control
var _properties: TabContainer
var _photo_chrome: Dictionary = {}
var _garden_sync: bool = false


func _ready() -> void:
	super._ready()
	for panel: PanelContainer in _panels:
		panel.hide()
	_feedback.hide()
	_dock.hide()
	_dock_buttons.clear()
	_properties = _panels[1].find_children("*", "TabContainer", true, false)[0]
	_properties.tabs_visible = false
	# Reuse bound property fields, while leaving legacy weekly scenes intact.
	context = PanelContainer.new()
	context.name = "ContextCard"
	context.theme = GardenTheme.create()
	context.add_theme_stylebox_override("panel", _paper(Color("eee8d6"), 14))
	add_child(context)
	var card_stack: VBoxContainer = VBoxContainer.new()
	card_stack.add_theme_constant_override("separation", 10)
	context.add_child(card_stack)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "ToolOptionsScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card_stack.add_child(scroll)
	context_body = VBoxContainer.new()
	context_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	context_body.add_theme_constant_override("separation", 10)
	scroll.add_child(context_body)
	var header: HBoxContainer = HBoxContainer.new()
	card_stack.add_child(header)
	card_stack.move_child(header, 0)
	context_title = Label.new()
	context_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(context_title)
	cancel_stroke = Button.new()
	cancel_stroke.text = "取消本笔"
	cancel_stroke.tooltip_text = "放弃预览或尚未完成的提交，保留已保存的作品和历史"
	cancel_stroke.pressed.connect(func() -> void: action_requested.emit(&"cancel"))
	header.add_child(cancel_stroke)
	var close: Button = Button.new()
	close.text = "收起 ×"
	close.pressed.connect(close_context)
	header.add_child(close)
	_choices = HFlowContainer.new()
	context_status = Label.new()
	context_status.name = "OperationFeedback"
	context_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	context_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	context_status.text = status_label.text
	var feedback_area: Control = Control.new()
	feedback_area.custom_minimum_size = Vector2(0, 52)
	feedback_area.clip_contents = true
	card_stack.add_child(feedback_area)
	card_stack.move_child(feedback_area, 1)
	feedback_area.add_child(context_status)
	context_status.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	context_body.add_child(_choices)
	_assets = HFlowContainer.new()
	context_body.add_child(_assets)
	_grass_row = VBoxContainer.new()
	context_body.add_child(_grass_row)
	grass_caption = Label.new()
	_grass_row.add_child(grass_caption)
	grass_slider = HSlider.new()
	grass_slider.name = "GrassDensity"
	grass_slider.accessibility_name = "地表动态草密度，0关闭，100%最高"
	grass_slider.min_value = 0
	grass_slider.max_value = 1
	grass_slider.step = 0.05
	grass_slider.custom_minimum_size = Vector2(260, 28)
	grass_slider.value_changed.connect(
		func(value: float) -> void:
			grass_caption.text = "地表动态草 · %d%%" % roundi(value * 100)
			if not _garden_sync:
				preference_changed.emit("grass_density", value)
	)
	_grass_row.add_child(grass_slider)
	var note: Label = Label.new()
	note.text = "向左更轻盈，0 关闭地表草；手工种植保留。"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_grass_row.add_child(note)
	_brush_controls = VBoxContainer.new()
	context_body.add_child(_brush_controls)
	_vegetation_page(_brush_controls)
	var tabs: TabContainer = _panels[0].find_children("*", "TabContainer", true, false)[0]
	_environment = tabs.get_tab_control(2)
	_environment.reparent(context_body)
	_environment.custom_minimum_size = Vector2(0, 220)
	_properties.reparent(context_body)
	_properties.custom_minimum_size = Vector2(0, 210)
	context.hide()
	_make_ribbon()
	_make_utilities()
	breadcrumbs = Label.new()
	breadcrumbs.text = "双指旋转 · 捏合缩放 · ⌥ + 左键平移"
	breadcrumbs.add_theme_color_override("font_color", Color("f8f2df"))
	breadcrumbs.add_theme_color_override("font_shadow_color", Color("40594b"))
	breadcrumbs.add_theme_constant_override("shadow_offset_y", 1)
	breadcrumbs.add_theme_font_size_override("font_size", 12)
	breadcrumbs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(breadcrumbs)
	_layout_panels()


static func _paper(color: Color, margin: int = 6) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(7)
	style.border_color = color.darkened(0.23)
	style.set_border_width_all(1)
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = margin
	style.content_margin_bottom = margin
	style.shadow_color = Color(0.1, 0.16, 0.1, 0.15)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	return style


func _icon(key: String) -> Texture2D:
	return EXTRA[key] if EXTRA.has(key) else ICONS[key]


func _make_ribbon() -> void:
	_dock = PanelContainer.new()
	_dock.name = "GardenRibbon"
	_dock.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	add_child(_dock)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var ribbon_scroll: ScrollContainer = ScrollContainer.new()
	ribbon_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	ribbon_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_dock.add_child(ribbon_scroll)
	ribbon_scroll.add_child(row)
	for card: Array in GROUPS:
		var button: Button = Button.new()
		button.name = String(card[0]).to_pascal_case()
		button.icon = _icon(card[1])
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.expand_icon = true
		button.custom_minimum_size = Vector2(50, 56)
		button.add_theme_constant_override("icon_max_width", 34)
		button.tooltip_text = card[2]
		button.accessibility_name = card[2]
		button.toggle_mode = true
		button.add_theme_stylebox_override("normal", _paper(Color(card[3])))
		button.add_theme_stylebox_override("hover", _paper(Color(card[3]).lightened(0.18)))
		button.add_theme_stylebox_override("pressed", _paper(Color(card[3]).lightened(0.3)))
		button.pressed.connect(func() -> void: open_group(card[0]))
		row.add_child(button)
		ribbon_buttons[card[0]] = button


func _make_utilities() -> void:
	utilities = HBoxContainer.new()
	utilities.name = "QuietUtilities"
	utilities.add_theme_constant_override("separation", 8)
	add_child(utilities)
	for item: Array in [["undo", "撤销"], ["redo", "重做"], ["library", "我的作品"], ["settings", "设置"]]:
		var button: Button = Button.new()
		button.icon = _icon(item[0])
		button.custom_minimum_size = Vector2(34, 34)
		button.add_theme_constant_override("icon_max_width", 23)
		button.tooltip_text = item[1]
		button.accessibility_name = item[1]
		button.add_theme_stylebox_override("normal", _paper(Color("e9e5d2")))
		button.pressed.connect(
			func() -> void:
				action_requested.emit(
					&"preferences" if item[0] == "settings" else StringName(item[0])
				)
		)
		utilities.add_child(button)


func close_context() -> void:
	group = ""
	context.hide()
	if breadcrumbs != null:
		breadcrumbs.show()
	for key: String in ribbon_buttons:
		ribbon_buttons[key].set_pressed_no_signal(key == active_group)


func open_group(key: String, activate: bool = true) -> void:
	if key == "photo":
		close_context()
		action_requested.emit(&"photography")
		return
	if key == group and context.visible:
		close_context()
		return
	group = key
	if activate:
		_activate_group(key)
	for card: Array in GROUPS:
		ribbon_buttons[card[0]].set_pressed_no_signal(card[0] == key)
		if card[0] == key:
			context_title.text = card[2] + " · 选择工具，再在场景左键操作"
	for container: Control in [_choices, _assets]:
		for child: Node in container.get_children():
			container.remove_child(child)
			child.queue_free()
	for tool: Array in TOOLS.get(key, []):
		var button: Button = Button.new()
		button.text = tool[1]
		button.pressed.connect(func() -> void: action_requested.emit(StringName(tool[0])))
		_choices.add_child(button)
	_grass_row.visible = key == "plants"
	_brush_controls.visible = key in ["plants", "trees"]
	_environment.visible = key == "light"
	_properties.visible = key in ["build", "path", "openings", "palette", "edit", "water"]
	_properties.current_tab = (
		{"build": 0, "path": 1, "openings": 2, "water": 3, "edit": 4, "palette": 5}.get(key, 0)
	)
	for pair: Array in _asset_choices(key):
		var button: Button = Button.new()
		button.text = pair[1]
		button.pressed.connect(
			func() -> void:
				asset_selected.emit(pair[0])
				action_requested.emit(&"place_asset")
		)
		_assets.add_child(button)
	context.show()
	if breadcrumbs != null:
		breadcrumbs.hide()
	_layout_panels()


func _asset_choices(key: String) -> Array:
	match key:
		"trees":
			return [["NAT-01", "阔叶树"], ["NAT-02", "针叶树"], ["NAT-03", "果树"]]
		"plants":
			return [
				["NAT-04", "蕨叶"],
				["NAT-05", "野花"],
				["NAT-06", "灌木"],
				["NAT-08", "苔石"],
				["NAT-09", "扁石"]
			]
		"props":
			return [
				["PROP-01", "长凳"],
				["PROP-02", "信箱"],
				["PROP-03", "盆栽"],
				["PROP-04", "晾衣架"],
				["PROP-05", "木箱"],
				["PROP-06", "浇水壶"],
				["PROP-07", "茶具"],
				["PROP-08", "提灯"]
			]
	return []


func sync_preferences(value: UserPreferences) -> void:
	super.sync_preferences(value)
	if grass_slider == null:
		return
	_garden_sync = true
	grass_slider.value = value.values.get("grass_density", 0.45)
	dof_control.text = "远景柔焦 · 小屋附近保持清晰"
	dof_control.set_pressed_no_signal(value.values.get("garden_focus", true))
	_garden_sync = false


func _layout_panels() -> void:
	super._layout_panels()
	if context == null or breadcrumbs == null:
		return
	var available: Vector2 = get_viewport().get_visible_rect().size / _scale_value
	var ribbon_width: float = minf(666, available.x - 24)
	_dock.position = Vector2((available.x - ribbon_width) * 0.5, available.y - 76)
	_dock.size = Vector2(ribbon_width, 56)
	var height: float = 355 if _properties.visible or group in ["plants", "trees", "light"] else 190
	context.size = Vector2(minf(610, available.x - 32), minf(height, available.y - 156))
	context.position = Vector2(
		(available.x - context.size.x) * 0.5, available.y - 94 - context.size.y
	)
	utilities.position = Vector2(available.x - 190, 18)
	breadcrumbs.position = Vector2(
		(available.x - minf(660, available.x - 40)) * 0.5, available.y - 96
	)
	breadcrumbs.size.x = minf(660, available.x - 40)


func set_photo_mode(enabled: bool) -> void:
	if enabled:
		for control: Control in [context, utilities, breadcrumbs]:
			_photo_chrome[control] = control.visible
			control.hide()
	else:
		for control: Control in _photo_chrome:
			control.visible = _photo_chrome[control]
		_photo_chrome.clear()


func set_status(message: String) -> void:
	super.set_status(message)
	if breadcrumbs != null:
		var readable: String = EditorFeedback.humanize(message)
		readable = readable.replace("右侧", "卡片中").replace("Esc 取消", "点取消本笔或 Esc 取消")
		breadcrumbs.text = readable
		context_status.text = readable
		context_status.tooltip_text = readable
		breadcrumbs.tooltip_text = breadcrumbs.text


func _activate_group(key: String) -> void:
	var actions: Dictionary = {
		"build": "rect",
		"path": "path",
		"openings": "place_opening",
		"edit": "select",
		"terrain": "raise",
		"plants": "plant_brush",
		"trees": "tree_tool",
		"water": "shore"
	}
	if actions.has(key):
		action_requested.emit(StringName(actions[key]))
	elif key in ["palette", "light"]:
		action_requested.emit(&"select")
	elif key == "props":
		asset_selected.emit("PROP-01")
		action_requested.emit(&"place_asset")
	active_group = key


func set_active_tool(mode: String) -> void:
	super.set_active_tool(mode)
	var mapping: Dictionary = {
		"rect": "build",
		"round": "build",
		"path": "path",
		"path_node": "path",
		"place_opening": "openings",
		"move_opening": "openings",
		"inspect": "edit",
		"select": "edit",
		"move": "edit",
		"rotate": "edit",
		"raise": "terrain",
		"lower": "terrain",
		"smooth": "terrain",
		"restore": "terrain",
		"plant_brush": "plants",
		"plant_erase": "plants",
		"hedge": "plants",
		"shore": "water",
		"bridge": "water",
		"stair": "water",
		"edit_garden": "water",
		"place_asset": "props"
	}
	active_group = (
		(group if group in ["trees", "plants", "props"] else "props")
		if mode == "place_asset"
		else mapping.get(mode, active_group)
	)
	for key: String in ribbon_buttons:
		ribbon_buttons[key].set_pressed_no_signal(key == active_group)
