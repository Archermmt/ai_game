class_name DirectHandles
extends Control
## Scene-local, projected handles. Controls own the press; root owns capture until release.

signal drag_requested(kind: String, screen: Vector2)

var handles: Dictionary = {}
var outline: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for pair: Array in [
		["move", "移"],
		["width", "宽"],
		["depth", "深"],
		["height", "高"],
		["rotate", "转"],
		["scale", "大小"]
	]:
		var chip: PanelContainer = PanelContainer.new()
		chip.name = String(pair[0]).to_pascal_case()
		chip.custom_minimum_size = Vector2(32, 32)
		chip.mouse_default_cursor_shape = Control.CURSOR_DRAG
		chip.tooltip_text = "拖动调整%s；松手完成，右键或Esc取消" % pair[1]
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color("fff8e5ed")
		style.border_color = Color("667b64")
		style.set_border_width_all(1)
		style.set_corner_radius_all(16)
		chip.add_theme_stylebox_override("panel", style)
		var label: Label = Label.new()
		label.text = pair[1]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_color_override("font_color", Color("40594b"))
		chip.add_child(label)
		chip.gui_input.connect(
			func(event: InputEvent) -> void:
				if (
					event is InputEventMouseButton
					and event.pressed
					and event.button_index == MOUSE_BUTTON_LEFT
					and not event.alt_pressed
					and not event.shift_pressed
				):
					drag_requested.emit(pair[0], get_viewport().get_mouse_position())
					chip.accept_event()
		)
		add_child(chip)
		handles[pair[0]] = chip
	clear()


func clear() -> void:
	for chip: Control in handles.values():
		chip.hide()
	outline.clear()
	queue_redraw()


func present(
	item: Dictionary,
	house: bool,
	camera: Camera3D,
	ui_scale: float,
	origin: Vector3,
	active: String = ""
) -> void:
	clear()
	if item.is_empty() or camera.is_position_behind(origin):
		return
	var points: Dictionary = {}
	if house:
		var s: Array = item["size"]
		points = {
			"move": origin + Vector3(0, s[1] * 0.45, 0),
			"width": origin + Vector3(s[0] * 0.5, s[1] * 0.5, 0),
			"height": origin + Vector3(0, s[1] + 1.7, 0)
		}
		if item["shape"] != "round":
			points["depth"] = origin + Vector3(0, s[1] * 0.5, s[2] * 0.5)
		for corner: Vector3 in [
			Vector3(-s[0] / 2.0, 0.08, -s[2] / 2.0),
			Vector3(s[0] / 2.0, 0.08, -s[2] / 2.0),
			Vector3(s[0] / 2.0, 0.08, s[2] / 2.0),
			Vector3(-s[0] / 2.0, 0.08, s[2] / 2.0),
			Vector3(-s[0] / 2.0, 0.08, -s[2] / 2.0)
		]:
			outline.append(camera.unproject_position(origin + corner) / ui_scale)
	else:
		points = {
			"move": origin + Vector3(0, 0.55, 0),
			"rotate": origin + Vector3(0, 0.55, 0),
			"scale": origin + Vector3(0, 0.55, 0)
		}
	var placed: Array[Vector2] = []
	var bounds: Rect2 = Rect2(
		Vector2(18, 18), get_viewport_rect().size / ui_scale - Vector2(36, 175)
	)
	for key: String in points:
		if not active.is_empty() and key != active:
			continue
		var point: Vector2 = camera.unproject_position(points[key]) / ui_scale
		if not house and key != "move":
			point += Vector2(-52 if key == "rotate" else 52, -34)
		for previous: Vector2 in placed:
			if point.distance_to(previous) < 44:
				point.y -= 46
		placed.append(point)
		var rect: Rect2 = Rect2(point - Vector2(16, 16), Vector2(32, 32))
		if bounds.encloses(rect):
			handles[key].position = rect.position
			handles[key].size = rect.size
			handles[key].show()
	queue_redraw()


func _draw() -> void:
	if outline.size() > 1:
		draw_polyline(outline, Color(1, 0.98, 0.86, 0.8), 1.5, true)
