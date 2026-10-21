class_name DirectOrbitCamera
extends OrbitCamera
## Classifies the right click before the camera consumes its release in _input.

signal secondary_clicked(screen: Vector2)

var tracking: bool = false
var anchor: Vector2
var travel: float = 0


func _unhandled_input(event: InputEvent) -> void:
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_RIGHT
		and event.pressed
	):
		tracking = true
		anchor = event.position
		travel = 0
	super._unhandled_input(event)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and tracking:
		travel = maxf(travel, anchor.distance_to(event.position))
	var clicked: bool = false
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_RIGHT
		and not event.pressed
	):
		clicked = (
			tracking
			and maxf(travel, anchor.distance_to(event.position)) <= 6
			and get_viewport().gui_get_hovered_control() == null
		)
		tracking = false
	super._input(event)
	if clicked:
		secondary_clicked.emit(event.position)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		tracking = false
		_orbiting = false
		_panning = false
