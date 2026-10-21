extends "res://features/garden_presentation/garden_hud.gd"
## Direct-tool ribbon and compact palettes; the legacy inspector is an explicit option.

const SIMPLE_GROUPS: Array = [
	["build", "house", "建筑", "c78d68"],
	["path", "path", "石径", "c99b87"],
	["openings", "window", "门窗 / 摆件", "d8b56d"],
	["palette", "paint", "整园色板", "c1a47e"],
	["erase", "eraser", "橡皮 · 点删对象", "cb9f7b"],
	["terrain", "raise", "地形", "aaa977"],
	["plants", "plant", "花草", "b1bd84"],
	["trees", "tree", "树木", "8ea777"],
	["water", "pond", "池岸", "90b2b4"],
	["photo", "photo", "摄影", "9ba8aa"],
	["light", "sun", "光线", "c8c17c"]
]
var quick: PanelContainer
var quick_choices: HFlowContainer
var quick_assets: HFlowContainer
var radius_caption: Label
var width_caption: Label
var quick_path_width: HSlider
var quick_radius: HSlider
var object_bar: PanelContainer
var direct_handles: DirectHandles
var _quick_photo: Dictionary = {}
var _exact_group: String = "build"
var _quick_scroll: ScrollContainer
var _quick_body: VBoxContainer


func _ready() -> void:
	super._ready()
	quick = PanelContainer.new()
	quick.name = "QuickOptions"
	quick.theme = GardenTheme.create()
	quick.add_theme_stylebox_override("panel", _paper(Color("eee8d6"), 10))
	add_child(quick)
	_quick_scroll = ScrollContainer.new()
	_quick_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	quick.add_child(_quick_scroll)
	_quick_body = VBoxContainer.new()
	_quick_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quick_scroll.add_child(_quick_body)
	quick_choices = HFlowContainer.new()
	_quick_body.add_child(quick_choices)
	quick_assets = HFlowContainer.new()
	_quick_body.add_child(quick_assets)
	_grass_row.reparent(_quick_body)
	_grass_row.hide()
	radius_caption = Label.new()
	_quick_body.add_child(radius_caption)
	quick_radius = HSlider.new()
	quick_radius.name = "PlantRadius"
	quick_radius.tooltip_text = "种植笔刷半径；与地表动态草密度分开"
	quick_radius.min_value = 0.5
	quick_radius.max_value = 6
	quick_radius.step = 0.1
	quick_radius.value = brush_radius.value
	quick_radius.custom_minimum_size = Vector2(180, 24)
	quick_radius.value_changed.connect(
		func(value: float) -> void:
			brush_radius.value = value
			radius_caption.text = "种植半径 · %.1f米" % value
	)
	radius_caption.text = "种植半径 · %.1f米" % quick_radius.value
	_quick_body.add_child(quick_radius)
	width_caption = Label.new()
	width_caption.text = "石径宽度 · 1.2米"
	_quick_body.add_child(width_caption)
	quick_path_width = HSlider.new()
	quick_path_width.name = "PathWidth"
	quick_path_width.min_value = 0.5
	quick_path_width.max_value = 3
	quick_path_width.step = 0.1
	quick_path_width.value = 1.2
	quick_path_width.custom_minimum_size = Vector2(180, 24)
	quick_path_width.tooltip_text = "石径宽度（米）：0.5–3.0"
	quick_path_width.value_changed.connect(
		func(value: float) -> void:
			path_width_changed.emit(value)
			width_caption.text = "石径宽度 · %.1f米" % value
			set_status("石径宽 %.1f米 · 在场景拖绘，松手完成" % value)
	)
	_quick_body.add_child(quick_path_width)
	quick.hide()
	object_bar = PanelContainer.new()
	object_bar.name = "ObjectActions"
	object_bar.theme = GardenTheme.create()
	object_bar.add_theme_stylebox_override("panel", _paper(Color("eee8d6"), 6))
	add_child(object_bar)
	var row: HBoxContainer = HBoxContainer.new()
	object_bar.add_child(row)
	for pair: Array in [
		["direct_copy", "复制"], ["direct_delete", "删除"], ["exact", "精确参数"], ["finish_edit", "结束修改"]
	]:
		var button: Button = Button.new()
		button.text = pair[1]
		button.pressed.connect(
			func() -> void:
				if pair[0] == "exact":
					show_exact(_exact_group)
				else:
					action_requested.emit(StringName(pair[0]))
		)
		row.add_child(button)
	object_bar.hide()
	direct_handles = DirectHandles.new()
	direct_handles.name = "DirectHandles"
	add_child(direct_handles)
	breadcrumbs.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	breadcrumbs.add_theme_font_size_override("font_size", 13)
	_layout_panels()


func _make_ribbon() -> void:
	_dock = PanelContainer.new()
	_dock.name = "SimpleRibbon"
	_dock.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	add_child(_dock)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_dock.add_child(scroll)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	scroll.add_child(row)
	for card: Array in SIMPLE_GROUPS:
		var button: Button = Button.new()
		button.icon = (
			preload("res://features/garden_presentation/eraser.svg")
			if card[1] == "eraser"
			else _icon(card[1])
		)
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.custom_minimum_size = Vector2(50, 56)
		button.add_theme_constant_override("icon_max_width", 34)
		button.tooltip_text = card[2] + " · 点选后在场景操作"
		button.accessibility_name = card[2]
		button.toggle_mode = true
		for state: String in ["normal", "hover", "pressed"]:
			button.add_theme_stylebox_override(
				state, _paper(Color(card[3]).lightened(0.18 if state != "normal" else 0))
			)
		button.pressed.connect(func() -> void: open_group(card[0]))
		row.add_child(button)
		ribbon_buttons[card[0]] = button


func open_group(key: String, activate: bool = true) -> void:
	if quick == null or not activate:
		return
	if key == "photo":
		quick.hide()
		action_requested.emit(&"photography")
		return
	context.hide()
	group = key
	if key == "erase":
		action_requested.emit(&"erase_tool")
	elif key == "openings":
		action_requested.emit(&"window_tool")
	else:
		_activate_group(key)
	active_group = "openings" if key == "props" else key
	for id_value: String in ribbon_buttons:
		ribbon_buttons[id_value].set_pressed_no_signal(id_value == active_group)
	for box: Control in [quick_choices, quick_assets]:
		for child: Node in box.get_children():
			box.remove_child(child)
			child.queue_free()
	var choices: Array = TOOLS.get(key, []).duplicate(true)
	if key == "openings":
		choices = []
	if key == "path":
		choices = [["path", "画石径"], ["path_node", "修改路径"]]
	if key == "build":
		choices += [["fence", "围栏"], ["bridge", "短桥"], ["stair", "短阶"]]
	if key == "erase":
		choices = [["plant_erase", "擦除刷植"], ["select", "返回浏览"]]
	for pair: Array in choices:
		_choice(quick_choices, pair[1], func() -> void: action_requested.emit(StringName(pair[0])))
	if key == "openings":
		for i: int in range(5):
			_choice(
				quick_assets,
				["木板门", "拱门", "玻璃门", "方窗", "圆窗"][i],
				func() -> void:
					opening_variant_selected.emit(i)
					action_requested.emit(&"place_opening")
			)
		_choice(quick_assets, "生活摆件…", func() -> void: open_group("props"))
	for pair: Array in _asset_choices(key):
		_choice(
			quick_assets,
			pair[1],
			func() -> void:
				asset_selected.emit(pair[0])
				action_requested.emit(&"place_asset")
		)
	if key == "props":
		_choice(quick_assets, "返回门窗", func() -> void: open_group("openings"))
	if key == "palette":
		for card: Dictionary in GardenPalette.CARDS:
			var button: Button = _choice(
				quick_assets,
				card["label"],
				func() -> void: palette_selected.emit(card["group"], card["id"])
			)
			button.icon = PaletteThumbnails.TEXTURES[card["id"]]
			button.add_theme_constant_override("icon_max_width", 28)
	_grass_row.visible = key == "plants"
	quick_radius.visible = key in ["plants", "trees"]
	quick_path_width.visible = key == "path"
	radius_caption.visible = quick_radius.visible
	width_caption.visible = quick_path_width.visible
	_choice(quick_choices, "更多参数…", func() -> void: show_exact(key))
	_choice(quick_choices, "取消本笔", func() -> void: action_requested.emit(&"cancel"))
	_choice(quick_choices, "收起 ×", func() -> void: quick.hide())
	quick.show()
	breadcrumbs.show()
	_layout_panels()


func _choice(parent: Node, title: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = title
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func show_exact(key: String) -> void:
	quick.hide()
	# Historical inspector iterates its original twelve categories. Temporary
	# detached aliases preserve that contract without exposing extra ribbon cards.
	var aliases: Array[String] = []
	for card: Array in GROUPS:
		if not ribbon_buttons.has(card[0]):
			ribbon_buttons[card[0]] = Button.new()
			aliases.append(card[0])
	super.open_group("edit" if key in ["props", "erase"] else key, false)
	for alias: String in aliases:
		ribbon_buttons[alias].free()
		ribbon_buttons.erase(alias)


func show_object_actions(house: bool, enabled: bool) -> void:
	if object_bar == null:
		return
	_exact_group = "build" if house else "edit"
	object_bar.visible = enabled
	for button: Button in object_bar.get_child(0).get_children():
		button.disabled = not enabled


func close_context() -> void:
	super.close_context()
	if quick != null:
		quick.hide()


func _layout_panels() -> void:
	super._layout_panels()
	if quick == null:
		return
	var available: Vector2 = get_viewport().get_visible_rect().size / _scale_value
	var width: float = minf(610, available.x - 24)
	_dock.position.x = (available.x - width) * 0.5
	_dock.size.x = width
	quick.size = Vector2(
		width,
		(
			220
			if group == "plants"
			else (
				150
				if group in ["openings", "props", "palette", "trees"]
				else (110 if group == "path" else 65)
			)
		)
	)
	quick.position = Vector2((available.x - width) * 0.5, available.y - 125 - quick.size.y)
	object_bar.size = Vector2(330, 36)
	object_bar.position = Vector2((available.x - object_bar.size.x) * 0.5, available.y - 166)
	breadcrumbs.position.y = available.y - 119
	breadcrumbs.size = Vector2(width, 42)


func set_photo_mode(enabled: bool) -> void:
	super.set_photo_mode(enabled)
	for control: Control in [quick, object_bar, direct_handles]:
		if enabled:
			_quick_photo[control] = control.visible
			control.hide()
		elif _quick_photo.has(control):
			control.visible = _quick_photo[control]
	if not enabled:
		_quick_photo.clear()


func blocks_scene_at(screen: Vector2) -> bool:
	for control: Control in [quick, object_bar, context, utilities, _dock]:
		if (
			control != null
			and control.is_visible_in_tree()
			and control.get_global_rect().has_point(screen)
		):
			return true
	return false
