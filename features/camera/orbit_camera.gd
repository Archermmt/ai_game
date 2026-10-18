class_name OrbitCamera
extends Node3D

const MIN_DISTANCE: float = 7.0
const MAX_DISTANCE: float = 60.0

var target: Vector3 = Vector3.ZERO
var distance: float = 29.0
var yaw: float = 0.65
var pitch: float = 0.68
var camera: Camera3D
var _orbiting: bool = false
var _panning: bool = false


func _ready() -> void:
	camera = Camera3D.new()
	camera.name = "ViewCamera"
	camera.fov = 43.0
	camera.near = 0.1
	camera.far = 180.0
	add_child(camera)
	camera.current = true
	refresh()


func _input(event: InputEvent) -> void:
	# Releases must clear camera capture even if the cursor finishes over UI.
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_orbiting = false
		if event.button_index == MOUSE_BUTTON_MIDDLE or event.button_index == MOUSE_BUTTON_LEFT:
			_panning = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_orbiting = event.pressed
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = event.pressed
		elif event.button_index == MOUSE_BUTTON_LEFT and event.shift_pressed:
			_panning = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = clampf(distance * 0.9, MIN_DISTANCE, MAX_DISTANCE)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = clampf(distance * 1.1, MIN_DISTANCE, MAX_DISTANCE)
		else:
			return
		get_viewport().set_input_as_handled()
		refresh()
	elif event is InputEventMouseMotion and (_orbiting or _panning):
		if _orbiting:
			yaw -= event.relative.x * 0.006
			pitch = clampf(pitch + event.relative.y * 0.004, 0.3, 1.3)
		else:
			pan_by(event.relative)
		refresh()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("reset_camera"):
		reset_view()
		get_viewport().set_input_as_handled()


func pan_by(relative: Vector2) -> void:
	var right: Vector3 = Vector3(cos(yaw), 0.0, -sin(yaw))
	var forward: Vector3 = Vector3(sin(yaw), 0.0, cos(yaw))
	target += (-right * relative.x + forward * relative.y) * distance * 0.0016
	target.x = clampf(target.x, -20.0, 20.0)
	target.z = clampf(target.z, -20.0, 20.0)


func ground_point(screen: Vector2) -> Variant:
	var origin: Vector3 = camera.project_ray_origin(screen)
	var direction: Vector3 = camera.project_ray_normal(screen)
	return Plane(Vector3.UP, 0.0).intersects_ray(origin, direction)


func reset_view() -> void:
	target = Vector3.ZERO
	distance = 29.0
	yaw = 0.65
	pitch = 0.68
	refresh()


func refresh() -> void:
	if camera == null:
		return
	camera.position = (
		target + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
	)
	camera.look_at(target)
