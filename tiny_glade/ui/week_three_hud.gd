extends "res://ui/week_one_hud.gd"

signal building_selection_changed(ids: Array[String])
signal size_preview_requested(size: Vector3)
signal path_width_changed(width: float)

var building_list: ItemList
var detached_list: ItemList
var dimensions: Array[SpinBox] = []
var _building_ids: Array[String] = []
var _attachment_ids: Array[String] = []
var _syncing: bool = false


func _ready() -> void:
	super._ready()
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "BuildingInspector"
	panel.position = Vector2(948, 54)
	var theme: Theme = Theme.new()
	for type_name: String in ["Label", "SpinBox", "LineEdit"]:
		theme.set_color("font_color", type_name, Color("405d4c"))
	theme.set_color("font_color", "LineEdit", Color("f5f0de"))
	theme.set_color("font_color", "ItemList", Color("f5f0de"))
	panel.theme = theme
	var toggle: Button = Button.new()
	toggle.position = Vector2(1090, 16)
	toggle.text = "收起 / 展开小屋面板"
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.pressed.connect(func() -> void: panel.visible = not panel.visible)
	add_child(toggle)
	panel.custom_minimum_size = Vector2(300, 0)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.96, 0.93, 0.86, 0.97)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	panel.add_theme_color_override("font_color", Color("405d4c"))
	add_child(panel)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 5)
	panel.add_child(stack)
	var title: Label = Label.new()
	title.text = "W03 · 小屋与恢复"
	stack.add_child(title)
	building_list = ItemList.new()
	building_list.select_mode = ItemList.SELECT_MULTI
	building_list.custom_minimum_size = Vector2(280, 90)
	stack.add_child(building_list)
	building_list.multi_selected.connect(_selection_changed)
	for entry: Array in [["宽度 / 直径", 3.0, 12.0], ["檐高", 2.4, 7.2], ["进深（圆屋同直径）", 3.0, 12.0]]:
		var row: HBoxContainer = HBoxContainer.new()
		stack.add_child(row)
		var label: Label = Label.new()
		label.text = entry[0]
		label.custom_minimum_size.x = 168
		row.add_child(label)
		var spin: SpinBox = SpinBox.new()
		spin.min_value = entry[1]
		spin.max_value = entry[2]
		spin.step = 0.1
		spin.value = 5.0 if dimensions.size() != 1 else 3.0
		row.add_child(spin)
		dimensions.append(spin)
		spin.value_changed.connect(
			func(_value: float) -> void:
				if not _syncing:
					size_preview_requested.emit(
						Vector3(dimensions[0].value, dimensions[1].value, dimensions[2].value)
					)
		)
	for entry: Array in [
		["apply_size", "提交尺寸"],
		["delete_building", "删除所选小屋"],
		["reset_defaults", "恢复初始布局（可撤销）"],
		["path", "画石径（拖动）"],
		["delete_path", "删除最后一条石径"]
	]:
		_add_button(stack, entry[0], entry[1])
	var width: SpinBox = SpinBox.new()
	width.prefix = "路宽 "
	width.min_value = 0.5
	width.max_value = 3.0
	width.step = 0.1
	width.value = 1.2
	width.value_changed.connect(func(value: float) -> void: path_width_changed.emit(value))
	stack.add_child(width)
	var waiting: Label = Label.new()
	waiting.text = "待重新附着的门窗"
	stack.add_child(waiting)
	detached_list = ItemList.new()
	detached_list.custom_minimum_size = Vector2(280, 90)
	stack.add_child(detached_list)
	_add_button(stack, "reattach", "重新附着到所选小屋正面")
	var tip: Label = Label.new()
	tip.text = "Cmd/Ctrl 多选；一次提交一条历史\n尺寸修改先预览，提交或 Esc 取消\n石径暂为笔刷折线，曲线编辑下周完成"
	stack.add_child(tip)


func _add_button(parent: Node, key: String, text: String) -> void:
	var button: Button = Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void: action_requested.emit(StringName(key)))
	parent.add_child(button)
	buttons[key] = button


func _selection_changed(_index: int, _selected: bool) -> void:
	if _syncing:
		return
	var ids: Array[String] = []
	for index: int in building_list.get_selected_items():
		ids.append(_building_ids[index])
	building_selection_changed.emit(ids)


func sync(snapshot: Dictionary, selected: Array[String]) -> void:
	if building_list == null:
		return
	_syncing = true
	building_list.clear()
	_building_ids.clear()
	for building: Dictionary in snapshot["buildings"]:
		var index: int = _building_ids.size()
		_building_ids.append(building["id"])
		building_list.add_item(("圆屋 " if building["shape"] == "round" else "矩形 ") + str(index + 1))
		if building["id"] in selected:
			building_list.select(index, false)
			for axis: int in range(3):
				dimensions[axis].set_value_no_signal(building["size"][axis])
	detached_list.clear()
	_attachment_ids.clear()
	for item: Dictionary in snapshot["attachments"]:
		_attachment_ids.append(item["id"])
		detached_list.add_item(
			("门 " if item["opening"]["height"] >= 1.8 else "窗 ") + item["id"].left(8)
		)
	if detached_list.item_count > 0:
		detached_list.select(0)
	_syncing = false


func selected_attachment() -> String:
	var selected: PackedInt32Array = detached_list.get_selected_items()
	return _attachment_ids[selected[0]] if not selected.is_empty() else ""
