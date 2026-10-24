class_name FirstPersonWalk
extends RefCounted
## A view-only grounded camera, sharing the editor camera so photo export stays consistent.

const SPEED: float = 2.0
const FAST_SPEED: float = 3.5
var active: bool = false
var feet: Vector3 = Vector3.ZERO
var yaw: float = 0
var pitch: float = -0.05
var eye_height: float = 1.65
var looking: bool = false
var surface: WalkSurface = WalkSurface.new()
var rig: OrbitCamera
var velocity: Vector2 = Vector2.ZERO
var keys: Dictionary = {}
var _saved_pose: Transform3D
var _saved_fov: float
var _saved_near: float
var _saved_far: float
var _saved_attributes: CameraAttributes
var _input_enabled: bool
var _unhandled_enabled: bool
var _mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE


func begin(value: OrbitCamera, snapshot: Dictionary) -> bool:
	if active:
		return true
	surface.configure(snapshot)
	var backward: Vector3 = value.camera.global_basis.z
	var preferred: Vector2 = (
		Vector2(value.target.x, value.target.z) + Vector2(backward.x, backward.z).normalized() * 4.5
	)
	var spawn: Variant = _find_spawn(preferred)
	if spawn == null:
		return false
	rig = value
	feet = spawn
	_saved_pose = rig.camera.transform
	_saved_fov = rig.camera.fov
	_saved_near = rig.camera.near
	_saved_far = rig.camera.far
	_saved_attributes = rig.camera.attributes
	_input_enabled = rig.is_processing_input()
	_unhandled_enabled = rig.is_processing_unhandled_input()
	_mouse_mode = Input.mouse_mode
	rig.set_process_input(false)
	rig.set_process_unhandled_input(false)
	rig._orbiting = false
	rig._panning = false
	rig._orbit_button = MOUSE_BUTTON_NONE
	if rig is DirectOrbitCamera:
		rig.tracking = false
	yaw = atan2(backward.x, backward.z)
	pitch = -0.05
	rig.camera.fov = 65
	rig.camera.near = 0.06
	rig.camera.far = 90
	rig.camera.attributes = null
	active = true
	reset_input()
	_apply_view()
	return true


func _find_spawn(preferred: Vector2) -> Variant:
	return surface.find_spawn(preferred)


func handle(event: InputEvent, over_ui: bool = false, typing: bool = false) -> bool:
	if not active:
		return false
	if event is InputEventKey:
		return _handle_key(event, typing)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		return _handle_button(event, over_ui)
	if event is InputEventMouseMotion and looking:
		look(event.relative * 0.003)
		return true
	if event is InputEventPanGesture and not over_ui:
		look(event.delta * 0.025)
		return true
	return false


func _handle_key(event: InputEventKey, typing: bool) -> bool:
	var key: Key = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if key not in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_SHIFT]:
		return false
	if not event.pressed:
		keys.erase(key)
		return not typing
	if typing:
		reset_input()
		return false
	keys[key] = true
	return true


func _handle_button(event: InputEventMouseButton, over_ui: bool) -> bool:
	if not event.pressed:
		_release_look()
		return true
	if over_ui:
		return false
	looking = true
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	return true


func look(delta: Vector2) -> void:
	if not delta.is_finite():
		return
	yaw = wrapf(yaw + delta.x, -PI, PI)
	pitch = clampf(pitch + delta.y, -1.25, 1.25)
	_apply_view()


func step(delta: float, enabled: bool = true) -> void:
	if not active or not is_finite(delta) or delta <= 0:
		return
	if not enabled:
		reset_input()
		return
	var dt: float = minf(delta, 0.1)
	var input: Vector2 = (
		Vector2(
			(
				int(keys.has(KEY_D) or keys.has(KEY_RIGHT))
				- int(keys.has(KEY_A) or keys.has(KEY_LEFT))
			),
			int(keys.has(KEY_S) or keys.has(KEY_DOWN)) - int(keys.has(KEY_W) or keys.has(KEY_UP))
		)
		. limit_length()
	)
	var right: Vector2 = Vector2(cos(yaw), -sin(yaw))
	var back: Vector2 = Vector2(sin(yaw), cos(yaw))
	var speed: float = FAST_SPEED if keys.has(KEY_SHIFT) else SPEED
	velocity = velocity.move_toward((right * input.x + back * input.y) * speed, dt * 10)
	feet = surface.move_grounded(feet, velocity * dt)
	_apply_view()


func _apply_view() -> void:
	if active and is_instance_valid(rig):
		rig.camera.global_transform = Transform3D(
			Basis.from_euler(Vector3(pitch, yaw, 0)), feet + Vector3.UP * eye_height
		)


func _release_look() -> void:
	looking = false
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = _mouse_mode


func reset_input() -> void:
	keys.clear()
	velocity = Vector2.ZERO
	_release_look()


func stop() -> void:
	if not active:
		return
	reset_input()
	active = false
	if is_instance_valid(rig) and is_instance_valid(rig.camera):
		rig.camera.transform = _saved_pose
		rig.camera.fov = _saved_fov
		rig.camera.near = _saved_near
		rig.camera.far = _saved_far
		rig.camera.attributes = _saved_attributes
		rig.set_process_input(_input_enabled)
		rig.set_process_unhandled_input(_unhandled_enabled)
