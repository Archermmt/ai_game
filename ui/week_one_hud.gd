class_name WeekOneHud
extends CanvasLayer

signal action_requested(action: StringName)

var status_label: Label
var buttons: Dictionary = {}


func _ready() -> void:
	var root: Control = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "Toolbar"
	panel.position = Vector2(24, 24)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.96, 0.93, 0.86, 0.95)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 7)
	panel.add_child(stack)
	var title: Label = Label.new()
	title.text = "风栖小筑  /  林间样板"
	title.add_theme_color_override("font_color", Color("405d4c"))
	title.add_theme_font_size_override("font_size", 22)
	stack.add_child(title)
	var subtitle: Label = Label.new()
	subtitle.text = "WEEK 01 · 工程与建造原型"
	subtitle.add_theme_color_override("font_color", Color("748371"))
	stack.add_child(subtitle)
	for row_actions: Array in [
		[["rect", "矩形小屋"], ["round", "圆形小屋"]],
		[["undo", "撤销"], ["redo", "重做"], ["cancel", "取消"]],
		[["save", "保存"], ["load", "读取"], ["camera", "复位视角"]],
		[["light", "日间 / 黄昏"], ["wind", "风动开关"]],
	]:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 5)
		stack.add_child(row)
		for entry: Array in row_actions:
			var button: Button = Button.new()
			button.name = String(entry[0]).to_pascal_case() + "Button"
			button.text = entry[1]
			button.focus_mode = Control.FOCUS_NONE
			button.custom_minimum_size = Vector2(84, 32)
			button.pressed.connect(func() -> void: action_requested.emit(StringName(entry[0])))
			row.add_child(button)
			buttons[entry[0]] = button
	status_label = Label.new()
	status_label.add_theme_color_override("font_color", Color("405d4c"))
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(275, 44)
	stack.add_child(status_label)
	var help: Label = Label.new()
	help.text = (
		"左键拖出小屋 · Esc 取消\n右键环绕 · 中键或 Shift+左键平移\n"
		+ "滚轮缩放 · F 复位\n⌘/Ctrl+Z 撤销 · ⇧+Z 重做\n"
		+ "⌘/Ctrl+S 保存 · ⌘/Ctrl+O 读取"
	)
	help.add_theme_color_override("font_color", Color("657260"))
	stack.add_child(help)
	set_status("已选矩形小屋；在右侧草地上拖动试试")


func set_status(message: String) -> void:
	if status_label != null:
		status_label.text = message
