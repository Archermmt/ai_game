class_name SurfaceHandles
extends DirectHandles
## White contextual glyphs stay anchored to the edited geometry.

var caption: Label


func _ready() -> void:
	super._ready()
	for pair: Array in [["roof", "屋顶"], ["end_a", "端点A"], ["end_b", "端点B"]]:
		var chip: PanelContainer = PanelContainer.new()
		chip.name = String(pair[0]).to_pascal_case()
		chip.custom_minimum_size = Vector2(32, 32)
		chip.mouse_default_cursor_shape = Control.CURSOR_DRAG
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color("fff8e5ed")
		style.set_corner_radius_all(16)
		chip.add_theme_stylebox_override("panel", style)
		var label: Label = Label.new()
		label.text = "△" if pair[0] == "roof" else "◆"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_color_override("font_color", Color("40594b"))
		chip.add_child(label)
		chip.tooltip_text = "拖动%s · 松手完成 · Esc取消" % pair[1]
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
	for key: String in handles:
		var chip: Control = handles[key]
		for connection: Dictionary in chip.gui_input.get_connections():
			chip.gui_input.disconnect(connection["callable"])
		chip.gui_input.connect(
			func(event: InputEvent) -> void:
				if (
					event is InputEventMouseButton
					and event.pressed
					and event.button_index == MOUSE_BUTTON_LEFT
					and not event.alt_pressed
					and not event.shift_pressed
				):
					drag_requested.emit(key, chip.get_global_transform() * event.position)
					chip.accept_event()
		)
	caption = Label.new()
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.add_theme_color_override("font_color", Color("fff8e5"))
	caption.add_theme_color_override("font_outline_color", Color("40594b"))
	caption.add_theme_constant_override("outline_size", 4)
	add_child(caption)
	clear()


func clear() -> void:
	super.clear()
	if caption != null:
		caption.hide()


func contains(screen: Vector2, margin: float = 10) -> bool:
	for chip: Control in handles.values():
		if chip.is_visible_in_tree() and chip.get_global_rect().grow(margin).has_point(screen):
			return true
	return false


func near_group(screen: Vector2) -> bool:
	var region: Rect2 = Rect2()
	for chip: Control in handles.values():
		if chip.is_visible_in_tree():
			region = (
				chip.get_global_rect()
				if region.size == Vector2.ZERO
				else region.merge(chip.get_global_rect())
			)
	return region.size != Vector2.ZERO and region.grow(12).has_point(screen)


func surface(
	source: Dictionary, target: Dictionary, camera: Camera3D, ui_scale: float, active: String = ""
) -> void:
	clear()
	var item: Dictionary = SurfaceEditData.resolve(source, target)
	if item.is_empty():
		return
	var origin: Vector3 = SurfaceEditData.origin(source, target)
	if camera.is_position_behind(origin):
		return
	var points: Dictionary = {}
	match target["family"]:
		"house":
			present(item, true, camera, ui_scale, origin, active)
			var size: Array = item["size"]
			points["roof"] = origin + Vector3(0, size[1] + RoofProfile.rise(item) + 0.15, 0)
			# Keep the height guide on the visible eave, separate from the roof apex.
			points["height"] = (
				origin
				+ Vector3(0, size[1], signf(camera.global_position.z - origin.z) * size[2] * 0.5)
			)
		"opening":
			var home: Dictionary = DirectEditData.find(source, target["parent"], true)
			var u: float = item["center"] * DoorRules._length(home, item.get("facade", 0))
			var normal: Vector3 = BuildingGeometry._normal(
				u, item.get("facade", 0), home["size"][0], home["size"][2], home["shape"] == "round"
			)
			points = {
				"move": origin,
				"height": origin + Vector3.UP * (item["height"] * 0.5 + 0.15),
				"width": origin + Vector3(normal.z, 0, -normal.x) * (item["width"] * 0.5 + 0.18)
			}
		"bridge", "stair":
			points = {
				"move": origin,
				"end_a": Vector3(item["a"][0], origin.y, item["a"][1]),
				"end_b": Vector3(item["b"][0], origin.y, item["b"][1])
			}
			var normal: Vector2 = (
				(Vector2(item["b"][0], item["b"][1]) - Vector2(item["a"][0], item["a"][1]))
				. normalized()
				. orthogonal()
			)
			points["width"] = origin + Vector3(normal.x, 0, normal.y) * (item["width"] * 0.5 + 0.2)
		"prop":
			present(item, false, camera, ui_scale, origin, active)
	var bounds: Rect2 = Rect2(
		Vector2(18, 18), get_viewport_rect().size / ui_scale - Vector2(36, 175)
	)
	var placed: Array[Vector2] = []
	for key: String in points:
		if not active.is_empty() and key != active:
			continue
		var point: Vector2 = camera.unproject_position(points[key]) / ui_scale
		for previous: Vector2 in placed:
			if point.distance_to(previous) < 42:
				point.x += 44
		placed.append(point)
		var rect: Rect2 = Rect2(point - Vector2(16, 16), Vector2(32, 32))
		if bounds.encloses(rect):
			handles[key].position = rect.position
			handles[key].size = rect.size
			handles[key].show()
	var key: String = active if not active.is_empty() else target.get("zone", "move")
	caption.text = (
		{
			"roof": "屋顶坡度 · 下拉至平顶",
			"width": "拖动改变宽度",
			"depth": "拖动改变深度",
			"height": "拖动改变高度",
			"end_a": "拖动桥头 A",
			"end_b": "拖动桥头 B"
		}
		. get(key, "拖动移动 · 松手完成")
	)
	if handles.has(key) and handles[key].visible:
		caption.position = handles[key].position + Vector2(24, -26)
		caption.position.x = clampf(caption.position.x, 18, maxf(18, bounds.end.x - 240))
		var top: float = INF
		var bottom: float = 0
		for chip: Control in handles.values():
			if chip.visible:
				top = minf(top, chip.position.y)
				bottom = maxf(bottom, chip.position.y + chip.size.y)
		caption.position.y = top - 30 if top >= 48 else bottom + 6
		caption.show()
	queue_redraw()
