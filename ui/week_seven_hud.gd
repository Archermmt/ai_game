extends "res://ui/week_six_hud.gd"
## Scene-owned tool dock and source-bound property cards.

signal instance_selected(ids: Array[String])
signal palette_selected(group: String, id_value: String)

var instance_list: ItemList
var object_x: SpinBox
var object_z: SpinBox
var object_yaw: SpinBox
var object_scale: SpinBox
var hedge_width: SpinBox
var object_lock: CheckBox
var object_lamp: OptionButton
var _instance_ids: Array[String] = []
var _object_sync: bool = false
var _palette_buttons: Dictionary = {}
var _dock: PanelContainer
var _dock_buttons: Dictionary = {}


func _ready() -> void:
	super._ready()
	for node: Node in _panels[0].find_children("*", "Label", true, false):
		if "WEEK 06" in node.text:
			node.text = "风栖小筑 / WEEK 07"
	var pages: TabContainer = _panels[1].find_children("*", "TabContainer", true, false)[0]
	_object_page(_tab(pages, "物件"))
	_palette_page(_tab(pages, "色板"))
	var nature: Node = buttons["place_asset"].get_parent()
	_add_button(nature, "hedge", "拖绘绿篱 / 转角")
	_add_button(nature, "edit_hedge", "拖动所选绿篱控制点")
	_add_button(nature, "camera_bookmark", "记住当前构图")
	_dock = PanelContainer.new()
	_dock.name = "ToolDock"
	_dock.theme = GardenTheme.create()
	_dock.add_theme_stylebox_override("panel", GardenTheme.box(GardenTheme.CREAM))
	add_child(_dock)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_dock.add_child(scroll)
	var row: HBoxContainer = HBoxContainer.new()
	scroll.add_child(row)
	for entry: Array in [
		["rect", "house", "矩形屋"],
		["round", "round_house", "圆屋"],
		["path", "path", "石径"],
		["place_opening", "door", "门"],
		["window_tool", "window", "窗"],
		["raise", "raise", "抬高"],
		["lower", "lower", "降低"],
		["smooth", "smooth", "平滑"],
		["shore", "pond", "池岸"],
		["bridge", "bridge", "短桥"],
		["stair", "stair", "短阶"],
		["fence", "fence", "围栏"],
		["tree_tool", "tree", "种树"],
		["plant_brush", "plant", "刷植"],
		["place_asset", "props", "道具"],
		["lamp_tool", "light", "提灯"]
	]:
		var button: Button = Button.new()
		button.name = entry[0].to_pascal_case()
		button.text = entry[2]
		button.icon = ICONS[entry[1]]
		button.add_theme_constant_override("icon_max_width", 20)
		button.tooltip_text = entry[2] + " · 在场景左键拖动"
		button.pressed.connect(func() -> void: action_requested.emit(StringName(entry[0])))
		row.add_child(button)
		_dock_buttons[entry[0]] = button
		button.set_meta("label", entry[2])
	_layout_panels()


func _object_page(parent: Node) -> void:
	_label(parent, "道具与草木 · 点列表或场景选择")
	instance_list = ItemList.new()
	instance_list.select_mode = ItemList.SELECT_MULTI
	instance_list.custom_minimum_size = Vector2(265, 130)
	instance_list.multi_selected.connect(_instance_selection)
	parent.add_child(instance_list)
	object_x = _number(parent, "X 位置（米）", -23, 23, 0.1)
	object_z = _number(parent, "Z 位置（米）", -23, 23, 0.1)
	object_yaw = _number(parent, "朝向（度）", -360, 360, 1)
	object_scale = _number(parent, "整体比例", 0.5, 2, 0.05)
	hedge_width = _number(parent, "绿篱宽（米）", 0.5, 1.6, 0.1)
	hedge_width.value = 0.8
	object_lock = CheckBox.new()
	object_lock.text = "锁定当前高度"
	parent.add_child(object_lock)
	object_lamp = OptionButton.new()
	for text: String in ["提灯：自动", "提灯：开启", "提灯：关闭"]:
		object_lamp.add_item(text)
	parent.add_child(object_lamp)
	_row(parent, [["apply_object", "提交属性"], ["select", "场景选择"]])
	_row(parent, [["move", "移动"], ["copy", "复制"], ["delete", "删除"]])
	_label(parent, "多选提交以首项为基准平移/旋转/等比缩放\n长凳/木箱中心可放茶具；先移开上层再删支撑")


func _number(parent: Node, label: String, low: float, high: float, step: float) -> SpinBox:
	_label(parent, label)
	var spin: SpinBox = SpinBox.new()
	spin.min_value = low
	spin.max_value = high
	spin.step = step
	parent.add_child(spin)
	return spin


func _palette_page(parent: Node) -> void:
	_label(parent, "整园色板 · 随作品保存")
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	parent.add_child(grid)
	for card: Dictionary in GardenPalette.CARDS:
		var stack: VBoxContainer = VBoxContainer.new()
		grid.add_child(stack)
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(112, 110)
		button.toggle_mode = true
		button.tooltip_text = card["label"]
		button.set_meta("palette_id", card["id"])
		button.pressed.connect(func() -> void: palette_selected.emit(card["group"], card["id"]))
		stack.add_child(button)
		var label: Label = Label.new()
		label.text = card["label"]
		label.add_theme_font_size_override("font_size", 12)
		stack.add_child(label)
		_palette_buttons[card["id"]] = button
		button.icon = PaletteThumbnails.TEXTURES[card["id"]]
		button.add_theme_constant_override("icon_max_width", 96)


func sync_objects(snapshot: Dictionary, selected: Array[String]) -> void:
	if instance_list == null:
		return
	_object_sync = true
	instance_list.clear()
	_instance_ids.clear()
	var first: Dictionary = {}
	for item: Dictionary in snapshot["instances"]:
		_instance_ids.append(item["id"])
		instance_list.add_item(
			AssetRegistry.LABELS.get(item["asset_id"], "物件") + " · " + str(_instance_ids.size())
		)
		if item["id"] in selected:
			instance_list.select(_instance_ids.size() - 1, false)
			if first.is_empty():
				first = item
	if not first.is_empty():
		instance_list.ensure_current_is_visible()
		object_x.set_value_no_signal(first["position"][0])
		object_z.set_value_no_signal(first["position"][2])
		object_yaw.set_value_no_signal(rad_to_deg(first["yaw"]))
		object_scale.set_value_no_signal(first["scale"])
		object_lock.set_pressed_no_signal(first.get("height_locked", false))
		object_lamp.select(["auto", "on", "off"].find(first.get("lamp_mode", "auto")))
		object_lamp.disabled = first["asset_id"] != "PROP-08"
		hedge_width.editable = first.has("hedge")
		hedge_width.set_value_no_signal(first.get("hedge", {}).get("width", 0.8))
	for card: Dictionary in GardenPalette.CARDS:
		var active: bool = (
			snapshot["environment"].get("palette", {}).get(
				card["group"], GardenPalette.DEFAULTS[card["group"]]
			)
			== card["id"]
		)
		_palette_buttons[card["id"]].set_pressed_no_signal(active)
		_palette_buttons[card["id"]].text = "✓" if active else ""
		_palette_buttons[card["id"]].tooltip_text = card["label"] + (" · 已选 ✓" if active else "")
	_object_sync = false


func _instance_selection(_index: int, _selected: bool) -> void:
	if _object_sync:
		return
	var ids: Array[String] = []
	for i: int in instance_list.get_selected_items():
		ids.append(_instance_ids[i])
	instance_selected.emit(ids)


func _layout_panels() -> void:
	super._layout_panels()
	if _dock == null:
		return
	var viewport: Vector2 = Vector2(get_viewport().get_visible_rect().size) / _scale_value
	for panel: PanelContainer in _panels:
		panel.size.y = maxf(100, viewport.y - 104)
	_dock.position = Vector2(16, viewport.y - 76)
	_dock.size = Vector2(viewport.x - 32, 60)


func set_active_tool(mode: String) -> void:
	super.set_active_tool(mode)
	for key: String in _dock_buttons:
		_dock_buttons[key].modulate = Color("f7dab2") if key == mode else Color.WHITE
		_dock_buttons[key].text = (
			("✓ " if key == mode else "") + _dock_buttons[key].get_meta("label")
		)


func set_status(message: String) -> void:
	super.set_status(EditorFeedback.humanize(message))


func choose_asset(id_value: String) -> void:
	for option: OptionButton in _panels[0].find_children("*", "OptionButton", true, false):
		for i: int in range(option.item_count):
			if option.get_item_metadata(i) == id_value:
				option.select(i)
