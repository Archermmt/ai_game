extends "res://ui/week_three_hud.gd"

signal path_selected(id_value: String)
signal asset_selected(asset_id: String)
signal opening_variant_selected(index: int)
signal environment_changed(key: String, value: float)

var path_list: ItemList
var opening_list: ItemList
var edit_width: SpinBox
var curved: CheckBox
var garden_list: ItemList
var garden_width: SpinBox
var _path_ids: Array[String] = []
var _four_sync: bool = false
var _garden_ids: Array[String] = []


func _ready() -> void:
	super._ready()
	for child: Node in get_children():
		if child is Control:
			child.visible = false
	buttons.clear()
	dimensions.clear()
	var left: VBoxContainer = _panel(Vector2(24, 24), Vector2(300, 750))
	_label(left, "风栖小筑 / WEEK 05", 21)
	_label(left, "庭园、池岸、短桥与短阶", 16)
	for row: Array in [
		[["rect", "矩形小屋"], ["round", "圆形小屋"]],
		[["undo", "撤销"], ["redo", "重做"], ["cancel", "取消"]],
		[["save", "保存"], ["load", "读取"], ["camera", "复位"]]
	]:
		_row(left, row)
	var tabs: TabContainer = TabContainer.new()
	tabs.custom_minimum_size = Vector2(276, 440)
	left.add_child(tabs)
	var edit: VBoxContainer = _tab(tabs, "编辑")
	for row: Array in [
		[["raise", "抬高"], ["lower", "降低"]],
		[["smooth", "平滑"], ["restore", "恢复地形"]],
		[["pool", "画圆池"], ["delete_pool", "删除池"]],
		[["path", "画曲线石径"], ["path_node", "拖控制点"]],
		[["select", "选择物件"], ["move", "移动"]],
		[["rotate", "旋转15°"], ["copy", "复制"], ["delete", "删除"]],
		[["scale_up", "放大"], ["scale_down", "缩小"]],
		[["fence", "连续围栏"], ["reset_defaults", "恢复布局"]]
	]:
		_row(edit, row)
	_label(edit, "拖绘多段围栏；回到起点自动闭合")
	var nature: VBoxContainer = _tab(tabs, "自然")
	var assets: OptionButton = OptionButton.new()
	var asset_entries: Array = [
		["PROP-01", "木长凳"],
		["PROP-02", "信箱"],
		["NAT-04", "林下蕨"],
		["NAT-05", "野花"],
		["NAT-06", "矮灌木"],
		["NAT-08", "苔石"],
		["NAT-09", "扁石"],
		["PROP-03", "盆栽"],
		["PROP-04", "晾衣架"],
		["PROP-05", "木箱"],
		["PROP-06", "浇水壶"]
	]
	for entry: Array in asset_entries:
		assets.add_item(entry[1])
	assets.item_selected.connect(
		func(index: int) -> void: asset_selected.emit(asset_entries[index][0])
	)
	nature.add_child(assets)
	_add_button(nature, "place_asset", "放置所选资源（拖动）")
	_row(nature, [["brush", "灰模刷植"], ["erase", "擦除刷植"]])
	_label(nature, "正式分类刷植继续 W06；手放内容受保护")
	var env: VBoxContainer = _tab(tabs, "环境")
	_row(env, [["light", "日间 / 黄昏"], ["age", "新居 / 岁月"]])
	_add_button(env, "wind", "减少动态 / 恢复")
	_slider(env, "风量", 0, 1, 0.45, "wind_strength")
	_slider(env, "风向（弧度）", 0, TAU, 0.4, "wind_direction")
	_label(env, "光线与窗光平滑切换；局部灯最多 4 盏")
	status_label = Label.new()
	status_label.custom_minimum_size = Vector2(270, 62)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(status_label)
	_label(left, "Option+左键环绕 · Shift+左键平移\n双指捏合/滑动缩放 · F 复位\nCmd/Ctrl+Z 撤销 · Shift+Z 重做")
	var right: VBoxContainer = _panel(Vector2(948, 24), Vector2(308, 750))
	_label(right, "作品属性", 21)
	var pages: TabContainer = TabContainer.new()
	pages.custom_minimum_size = Vector2(286, 620)
	right.add_child(pages)
	_building_page(_tab(pages, "小屋"))
	_path_page(_tab(pages, "石径"))
	_opening_page(_tab(pages, "门窗"))
	_garden_page(_tab(pages, "庭园"))
	_label(right, "先预览，再提交；Esc 取消\n门窗冲突时保留作品与历史")


func _panel(position_value: Vector2, size: Vector2) -> VBoxContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.position = position_value
	panel.custom_minimum_size = size
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("eee8d7")
	style.set_corner_radius_all(10)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	var theme: Theme = Theme.new()
	theme.set_color("font_color", "Label", Color("405d4c"))
	var tab_style: StyleBoxFlat = style.duplicate()
	tab_style.content_margin_left = 4
	tab_style.content_margin_right = 4
	theme.set_stylebox("panel", "TabContainer", tab_style)
	panel.theme = theme
	add_child(panel)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 7)
	panel.add_child(stack)
	return stack


func _tab(parent: TabContainer, title: String) -> VBoxContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = (
		{
			"编辑": "Edit",
			"自然": "Nature",
			"环境": "Environment",
			"小屋": "Buildings",
			"石径": "Paths",
			"门窗": "Openings",
			"庭园": "Garden"
		}
		. get(title, "Page")
	)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	parent.set_tab_title(parent.get_tab_count() - 1, title)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 7)
	scroll.add_child(stack)
	return stack


func _label(parent: Node, text: String, size: int = 14) -> void:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 260
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)


func _row(parent: Node, entries: Array) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	parent.add_child(row)
	for entry: Array in entries:
		_add_button(row, entry[0], entry[1])


func _slider(
	parent: Node, label: String, low: float, high: float, value: float, key: String
) -> void:
	_label(parent, label)
	var slider: HSlider = HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = 0.01
	slider.value = value
	slider.custom_minimum_size.y = 30
	slider.drag_ended.connect(
		func(changed: bool) -> void:
			if changed:
				environment_changed.emit(key, slider.value)
	)
	parent.add_child(slider)


func _building_page(parent: Node) -> void:
	building_list = ItemList.new()
	building_list.select_mode = ItemList.SELECT_MULTI
	building_list.custom_minimum_size = Vector2(265, 105)
	building_list.multi_selected.connect(_selection_changed)
	parent.add_child(building_list)
	for entry: Array in [["宽 / 直径", 3.0, 12.0], ["檐高", 2.4, 7.2], ["进深", 3.0, 12.0]]:
		_label(parent, entry[0])
		var spin: SpinBox = SpinBox.new()
		spin.min_value = entry[1]
		spin.max_value = entry[2]
		spin.step = 0.1
		parent.add_child(spin)
		dimensions.append(spin)
		spin.value_changed.connect(
			func(_v: float) -> void:
				if not _syncing:
					size_preview_requested.emit(
						Vector3(dimensions[0].value, dimensions[1].value, dimensions[2].value)
					)
		)
	_add_button(parent, "apply_size", "提交尺寸")
	_add_button(parent, "delete_building", "删除所选小屋")
	_label(parent, "待重新附着的门窗")
	detached_list = ItemList.new()
	detached_list.custom_minimum_size = Vector2(265, 80)
	parent.add_child(detached_list)
	_add_button(parent, "reattach", "重新附着到所选小屋")


func _path_page(parent: Node) -> void:
	path_list = ItemList.new()
	path_list.custom_minimum_size = Vector2(265, 150)
	path_list.item_selected.connect(
		func(index: int) -> void:
			if not _four_sync:
				path_selected.emit(_path_ids[index])
	)
	parent.add_child(path_list)
	_label(parent, "选择路径后可拖动控制点")
	edit_width = SpinBox.new()
	edit_width.min_value = 0.5
	edit_width.max_value = 3
	edit_width.step = 0.1
	edit_width.value = 1.2
	edit_width.value_changed.connect(func(v: float) -> void: path_width_changed.emit(v))
	parent.add_child(edit_width)
	curved = CheckBox.new()
	curved.text = "平滑曲线"
	curved.button_pressed = true
	parent.add_child(curved)
	_add_button(parent, "apply_path", "提交路宽 / 曲线")
	_add_button(parent, "delete_path", "删除所选路径")
	_label(parent, "路端距墙≤0.6m、高差≤0.45m时生门\n删最后供门路径时，未锁自动门随事务移除")


func _opening_page(parent: Node) -> void:
	_label(parent, "先在小屋列表选择目标建筑")
	opening_list = ItemList.new()
	opening_list.custom_minimum_size = Vector2(265, 160)
	parent.add_child(opening_list)
	var variants: OptionButton = OptionButton.new()
	for label: String in ["木板门", "拱门", "玻璃门", "方窗", "圆窗"]:
		variants.add_item(label)
	variants.item_selected.connect(func(index: int) -> void: opening_variant_selected.emit(index))
	parent.add_child(variants)
	_add_button(parent, "place_opening", "手放门窗：拖到目标墙边")
	_add_button(parent, "move_opening", "移动列表选中的门窗")
	_add_button(parent, "lock_opening", "锁定 / 解锁（转为手工）")
	_add_button(parent, "delete_opening", "删除所选门窗")
	_label(parent, "窗与门冲突时不会挤掉先前内容\n自动门手动移动或锁定后独立于路径保留")


func sync_extra(snapshot: Dictionary, selected: Array[String], path_id: String) -> void:
	if path_list == null:
		return
	_four_sync = true
	path_list.clear()
	_path_ids.clear()
	for path: Dictionary in snapshot["paths"]:
		var index: int = _path_ids.size()
		_path_ids.append(path["id"])
		path_list.add_item("石径 " + str(index + 1) + " · " + str(path["points"].size()) + " 点")
		if path["id"] == path_id:
			path_list.select(index)
			edit_width.set_value_no_signal(path["width"])
			curved.set_pressed_no_signal(path.get("curved", false))
	var previous_opening: int = opening_index()
	opening_list.clear()
	for home: Dictionary in snapshot["buildings"]:
		if home["id"] not in selected:
			continue
		for opening: Dictionary in home["openings"]:
			opening_list.add_item(
				(
					("门" if opening["height"] >= 1.8 else "窗")
					+ " · "
					+ ("手工" if opening.get("source", "manual") != "auto_path" else "自动")
					+ (" [锁]" if opening.get("locked", false) else "")
				)
			)
		break
	if opening_list.item_count > 0:
		opening_list.select(clampi(previous_opening, 0, opening_list.item_count - 1))
	_four_sync = false


func opening_index() -> int:
	var selected: PackedInt32Array = opening_list.get_selected_items()
	return selected[0] if not selected.is_empty() else -1


func _garden_page(parent: Node) -> void:
	_label(parent, "自由池岸：按住左键绕一圈，松手闭合")
	_row(parent, [["shore", "绘制 / 重画池岸"], ["delete_pool", "删除池"]])
	_label(parent, "池水最窄 2m；水位固定；非法整笔保留原态")
	_row(parent, [["bridge", "预览短木桥"], ["stair", "预览短石阶"]])
	garden_width = SpinBox.new()
	garden_width.min_value = 0.8
	garden_width.max_value = 2.0
	garden_width.step = 0.1
	garden_width.value = 1.2
	parent.add_child(garden_width)
	_add_button(parent, "confirm_garden", "确认桥 / 阶")
	_label(parent, "桥长 1.5–6m，高差≤0.5m\n短阶高差 0.15–0.9m；超界请调整地形")
	garden_list = ItemList.new()
	garden_list.custom_minimum_size = Vector2(265, 130)
	parent.add_child(garden_list)
	_add_button(parent, "edit_garden", "拖动所选结构的端点 / 围栏点")
	_add_button(parent, "delete_garden", "删除所选庭园结构")
	_label(parent, "改岸失效桥仍保留，以暖红色标记；调整桥头或撤销")


func garden_id() -> String:
	if garden_list == null:
		return ""
	var selected: PackedInt32Array = garden_list.get_selected_items()
	return _garden_ids[selected[0]] if not selected.is_empty() else ""


func sync_garden(snapshot: Dictionary, issues: Array) -> void:
	if garden_list == null:
		return
	var previous: String = garden_id()
	garden_list.clear()
	_garden_ids.clear()
	for collection: String in ["bridges", "stairs", "fences"]:
		for item: Dictionary in snapshot.get(collection, []):
			var issue_text: String = ""
			for issue: Dictionary in issues:
				if issue["id"] == item["id"]:
					issue_text = " · 调整桥头/地形"
			_garden_ids.append(item["id"])
			garden_list.add_item(
				{"bridges": "短桥", "stairs": "短阶", "fences": "围栏"}[collection] + issue_text
			)
			if item["id"] == previous:
				garden_list.select(_garden_ids.size() - 1)
