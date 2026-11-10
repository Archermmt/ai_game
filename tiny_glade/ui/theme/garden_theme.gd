class_name GardenTheme
extends RefCounted
## Oiled timber, parchment, moss and brass shared by the garden controls.

const FONT: FontFile = preload("res://assets/fonts/NotoSansSC-Regular.otf")
const INK: Color = Color("343d32")
const CREAM: Color = Color("f0e7cf")
const PARCHMENT: Color = Color("e5d6b3")
const TIMBER: Color = Color("423c32")
const MOSS: Color = Color("586748")
const BRASS: Color = Color("b89862")

static var _shared: Theme


static func create() -> Theme:
	if _shared != null:
		return _shared
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
		"TabContainer",
		"PopupMenu"
	]:
		theme.set_color("font_color", type_name, INK)
		theme.set_color("font_hover_color", type_name, INK)
		theme.set_color("font_pressed_color", type_name, CREAM)
		theme.set_color("font_selected_color", type_name, CREAM)
		theme.set_color("font_unselected_color", type_name, INK)
		theme.set_color("font_focus_color", type_name, INK)
		theme.set_color("font_disabled_color", type_name, Color("756e61"))
	var fill: StyleBoxFlat = box(PARCHMENT)
	var hover: StyleBoxFlat = box(Color("fcf2d9"))
	var selected: StyleBoxFlat = box(MOSS)
	var focus: StyleBoxFlat = box(Color.TRANSPARENT)
	focus.border_color = Color("a36332")
	focus.set_border_width_all(2)
	focus.draw_center = false
	for type_name: String in [
		"Button", "OptionButton", "CheckBox", "LineEdit", "ItemList", "TabBar", "TabContainer"
	]:
		for state: String in ["normal", "panel", "tab_unselected"]:
			theme.set_stylebox(state, type_name, fill)
		for state: String in ["hover", "tab_hovered"]:
			theme.set_stylebox(state, type_name, hover)
		for state: String in [
			"pressed", "hover_pressed", "selected", "selected_focus", "tab_selected"
		]:
			theme.set_stylebox(state, type_name, selected)
		theme.set_stylebox("disabled", type_name, box(Color("d9d0ba")))
		theme.set_stylebox("focus", type_name, focus)
		theme.set_color("font_hover_pressed_color", type_name, CREAM)
	theme.set_stylebox("normal", "LineEdit", box(Color("fbf4e4")))
	theme.set_color("caret_color", "LineEdit", INK)
	theme.set_color("selection_color", "LineEdit", MOSS)
	theme.set_color("font_selected_color", "LineEdit", CREAM)
	theme.set_stylebox("panel", "TabContainer", box(CREAM))
	theme.set_stylebox("panel", "PopupMenu", panel(6))
	theme.set_stylebox("hover", "PopupMenu", selected)
	theme.set_color("font_hover_color", "PopupMenu", CREAM)
	theme.set_stylebox("panel", "AcceptDialog", panel(12))
	theme.set_stylebox("panel", "TooltipPanel", box(TIMBER))
	theme.set_color("font_color", "TooltipLabel", CREAM)
	var track: StyleBoxFlat = box(Color("c8b995"))
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	theme.set_stylebox("slider", "HSlider", track)
	var progress: StyleBoxFlat = track.duplicate() as StyleBoxFlat
	progress.bg_color = MOSS
	theme.set_stylebox("grabber_area", "HSlider", progress)
	theme.set_stylebox("grabber_area_highlight", "HSlider", progress)
	for state: String in ["grabber", "grabber_highlight", "grabber_disabled"]:
		theme.set_icon(state, "HSlider", preload("res://assets/ui/garden/slider_bead.svg"))
	var divider: StyleBoxLine = StyleBoxLine.new()
	divider.color = Color("c8b995")
	divider.thickness = 1
	theme.set_stylebox("separator", "HSeparator", divider)
	var frame: StyleBoxFlat = box(TIMBER)
	frame.expand_margin_top = 29
	frame.expand_margin_left = 2
	frame.expand_margin_right = 2
	frame.expand_margin_bottom = 2
	theme.set_stylebox("embedded_border", "Window", frame)
	theme.set_stylebox("embedded_unfocused_border", "Window", frame)
	theme.set_color("title_color", "Window", CREAM)
	theme.set_constant("title_height", "Window", 29)
	_shared = theme
	return theme


static func box(color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(5)
	style.border_color = Color("ab997a")
	style.set_border_width_all(1)
	style.content_margin_left = 7
	style.content_margin_right = 7
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style


static func panel(margin: int = 12) -> StyleBoxTexture:
	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.texture = preload("res://assets/ui/garden/field_paper.svg")
	# Tile the unprinted paper between fixed corner marks at any panel size.
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, 22)
		style.set_content_margin(side, margin)
	return style


static func rail() -> StyleBoxTexture:
	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.texture = preload("res://assets/ui/garden/oak_rail.svg")
	for side: Side in [SIDE_LEFT, SIDE_RIGHT]:
		style.set_texture_margin(side, 13)
		style.set_content_margin(side, 11)
	for side: Side in [SIDE_TOP, SIDE_BOTTOM]:
		style.set_texture_margin(side, 13)
		style.set_content_margin(side, 6)
	return style


static func icon_key(button: Button) -> void:
	# The held tool has a moss lip; focus remains a separate keyboard outline.
	var normal: StyleBoxFlat = box(PARCHMENT)
	normal.border_width_bottom = 2
	var pressed: StyleBoxFlat = box(Color("acbd8c"))
	pressed.border_color = MOSS
	pressed.border_width_bottom = 4
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", box(Color("fcf1d5")))
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover_pressed", pressed)
