class_name GardenTheme
extends RefCounted

const FONT: FontFile = preload("res://assets/fonts/NotoSansSC-Regular.otf")
const INK: Color = Color("405d4c")
const CREAM: Color = Color("eee8d7")


static func create() -> Theme:
	var theme: Theme = Theme.new()
	theme.default_font = FONT
	theme.default_font_size = 14
	for type_name: String in [
		"Label",
		"Button",
		"LineEdit",
		"SpinBox",
		"OptionButton",
		"CheckBox",
		"ItemList",
		"TabBar",
		"TabContainer"
	]:
		theme.set_color("font_color", type_name, INK)
		theme.set_color("font_hover_color", type_name, INK)
		theme.set_color("font_pressed_color", type_name, CREAM)
		theme.set_color("font_selected_color", type_name, CREAM)
		theme.set_color("font_unselected_color", type_name, INK)
		theme.set_color("font_focus_color", type_name, INK)
	for type_name: String in [
		"Button", "OptionButton", "LineEdit", "ItemList", "TabBar", "TabContainer"
	]:
		for state: String in ["normal", "panel", "tab_unselected"]:
			theme.set_stylebox(state, type_name, box(Color("e3e3cf")))
		for state: String in ["hover", "hover_pressed", "tab_hovered"]:
			theme.set_stylebox(state, type_name, box(Color("f1d5a3")))
		for state: String in ["pressed", "selected", "selected_focus", "tab_selected"]:
			theme.set_stylebox(state, type_name, box(INK))
		var focus: StyleBoxFlat = box(CREAM)
		focus.bg_color.a = 0
		focus.border_color = Color("b66f52")
		focus.set_border_width_all(2)
		theme.set_stylebox("focus", type_name, focus)
	theme.set_stylebox("pressed", "Button", box(Color("edca91")))
	theme.set_color("font_pressed_color", "Button", INK)
	theme.set_stylebox("panel", "TabContainer", box(CREAM))
	theme.set_color("font_color", "TooltipLabel", CREAM)
	return theme


static func box(color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(6)
	style.content_margin_left = 7
	style.content_margin_right = 7
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style
