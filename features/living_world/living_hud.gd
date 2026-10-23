extends "res://features/hover_edit/hover_hud.gd"

var calendar: CalendarPanel
var _calendar_visible: bool = true


func attach_calendar(clock: CalendarState) -> void:
	calendar = CalendarPanel.new()
	calendar.configure(clock)
	add_child(calendar)
	_layout_panels()


func _layout_panels() -> void:
	super._layout_panels()
	if calendar != null:
		var available: Vector2 = get_viewport().get_visible_rect().size / _scale_value
		calendar.position = Vector2(available.x - 296, 76)
		calendar.size = Vector2(280, 380)


func blocks_scene_at(screen: Vector2) -> bool:
	return (
		super.blocks_scene_at(screen)
		or (calendar != null and calendar.visible and calendar.get_global_rect().has_point(screen))
	)


func set_photo_mode(enabled: bool) -> void:
	super.set_photo_mode(enabled)
	if calendar == null:
		return
	if enabled:
		_calendar_visible = calendar.visible
		calendar.hide()
	else:
		calendar.visible = _calendar_visible
