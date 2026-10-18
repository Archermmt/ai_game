class_name OrbitCamera
extends Node3D

const MIN_DISTANCE: float = 7.0
const MAX_DISTANCE: float = 60.0

var target: Vector3 = Vector3.ZERO
var distance: float = 29.0
var yaw: float = 0.65
var pitch: float = 0.68
var camera: Camera3D
var surface_height: Callable = Callable()
var _orbiting: bool = false
var _orbit_button: int = MOUSE_BUTTON_NONE
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
		if event.button_index == _orbit_button:
			_orbiting = false
			_orbit_button = MOUSE_BUTTON_NONE
			get_viewport().set_input_as_handled()
		if event.button_index == MOUSE_BUTTON_MIDDLE or event.button_index == MOUSE_BUTTON_LEFT:
			_panning = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventGesture:
		if get_viewport().gui_get_hovered_control() != null:
			return
		if event is InputEventMagnifyGesture:
			if is_finite(event.factor) and event.factor > 0.0:
				_zoom(1.0 / event.factor)
		elif event is InputEventPanGesture:
			# macOS sends precise two-finger scrolling as PanGesture, not wheel ticks.
			if is_finite(event.delta.y):
				_zoom(exp(clampf(event.delta.y, -20.0, 20.0) * 0.08))
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		if (
			event.button_index == MOUSE_BUTTON_RIGHT
			or (event.button_index == MOUSE_BUTTON_LEFT and event.alt_pressed and event.pressed)
		):
			_orbiting = event.pressed
			_orbit_button = event.button_index if event.pressed else MOUSE_BUTTON_NONE
			_panning = false
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = event.pressed
		elif event.button_index == MOUSE_BUTTON_LEFT and event.shift_pressed:
			_panning = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(pow(0.9, clampf(event.factor, 0.0, 100.0)))
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(pow(1.1, clampf(event.factor, 0.0, 100.0)))
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


func _zoom(multiplier: float) -> void:
	if not is_finite(multiplier) or multiplier <= 0.0:
		return
	distance = clampf(distance * multiplier, MIN_DISTANCE, MAX_DISTANCE)
	refresh()


func pan_by(relative: Vector2) -> void:
	var right: Vector3 = Vector3(cos(yaw), 0.0, -sin(yaw))
	var forward: Vector3 = Vector3(sin(yaw), 0.0, cos(yaw))
	target += (-right * relative.x + forward * relative.y) * distance * 0.0016
	target.x = clampf(target.x, -20.0, 20.0)
	target.z = clampf(target.z, -20.0, 20.0)


func ground_point(screen: Vector2) -> Variant:
	var origin: Vector3 = camera.project_ray_origin(screen)
	var direction: Vector3 = camera.project_ray_normal(screen)
	if surface_height.is_valid():
		var previous: float = 0.0
		for index: int in range(1, 361):
			var distance: float = float(index) * 0.5
			var point: Vector3 = origin + direction * distance
			if (
				absf(point.x) <= 32
				and absf(point.z) <= 32
				and point.y <= surface_height.call(Vector2(point.x, point.z))
			):
				for refinement: int in range(12):
					var middle: float = (previous + distance) * 0.5
					var sample: Vector3 = origin + direction * middle
					if sample.y > surface_height.call(Vector2(sample.x, sample.z)):
						previous = middle
					else:
						distance = middle
				return origin + direction * ((previous + distance) * 0.5)
			previous = distance
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
	var look_target: Vector3 = target
	if surface_height.is_valid():
		camera.position.y = maxf(
			camera.position.y,
			float(surface_height.call(Vector2(camera.position.x, camera.position.z))) + 0.6
		)
		look_target.y = maxf(look_target.y, float(surface_height.call(Vector2(target.x, target.z))))
	camera.look_at(look_target)
