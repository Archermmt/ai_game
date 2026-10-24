class_name PondReflections
extends Node3D
## Low-resolution planar capture, capped at8Hz; no ReflectionProbe atlas allocation.

const REFLECTION_LAYER: int = 1 << 18
var host: Node3D
var viewport: SubViewport
var camera: Camera3D
var enabled: bool = true
var captures: int = 0
var pending: bool = true
var age: float = 1.0
var climate_key: String = ""
var tagged: Array[Dictionary] = []
var last_camera: Transform3D


func configure(value: Node3D) -> void:
	host = value
	name = "PondReflections"
	viewport = SubViewport.new()
	viewport.name = "PlanarWaterCapture"
	viewport.size = Vector2i(480, 270)
	viewport.world_3d = get_world_3d()
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.positional_shadow_atlas_size = 0
	add_child(viewport)
	camera = Camera3D.new()
	camera.name = "ReflectionCamera"
	camera.cull_mask = REFLECTION_LAYER
	camera.far = 70
	viewport.add_child(camera)
	camera.current = true
	camera.environment = host.world_environment.environment.duplicate()
	camera.environment.ssao_enabled = false
	camera.environment.glow_enabled = false
	host.water_material.set_shader_parameter("reflection_texture", viewport.get_texture())
	request_update()


func request_update() -> void:
	pending = true
	tagged = tagged.filter(
		func(entry: Dictionary) -> bool: return is_instance_valid(entry["node"].get_ref())
	)
	_tag(host.world_view)


func _tag(node: Node) -> void:
	if (
		node
		in [
			host.water_view,
			host.terrain_root,
			host.path_root,
			host.foundation_root,
			host.gizmo_root,
			host.preview_root,
			host.meadow,
			host.atmosphere
		]
	):
		return
	if node is GeometryInstance3D and (node.layers & REFLECTION_LAYER) == 0:
		tagged.append({"node": weakref(node), "layers": node.layers})
		node.layers |= REFLECTION_LAYER
	for child: Node in node.get_children():
		_tag(child)


func tick(delta: float, state: Dictionary) -> void:
	age += delta
	var pool: Dictionary = host.document.state["pool"]
	host.water_material.set_shader_parameter("reflection_enabled", enabled and not pool.is_empty())
	if pool.is_empty() or not enabled:
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	host.water_material.set_shader_parameter(
		"rain_amount", float(host.atmosphere.blend.current.get("rain", 0.0))
	)
	var source: Camera3D = host.camera_rig.camera
	var key: String = (
		"%s:%s:%d" % [state["season"], state["weather"], floori(state["minute_of_day"] / 10)]
	)
	if key != climate_key or source.global_transform != last_camera or not host.atmosphere.frozen:
		pending = true
	if not pending or age < 0.125:
		return
	if host.queue.is_busy() or host.stage.is_busy() or host.meadow.is_busy():
		return
	climate_key = key
	last_camera = source.global_transform
	var pose: Transform3D = source.global_transform
	pose.origin.y = 2 * float(pool["water_y"]) - pose.origin.y
	pose.basis.x.y *= -1
	pose.basis.y.y *= -1
	pose.basis.z.y *= -1
	pose.basis.y *= -1
	camera.global_transform = pose
	camera.fov = source.fov
	camera.near = source.near
	var environment: Environment = host.world_environment.environment
	camera.environment.sky = environment.sky
	camera.environment.background_mode = environment.background_mode
	for property: String in [
		"ambient_light_color", "ambient_light_energy", "fog_density", "fog_light_color"
	]:
		camera.environment.set(property, environment.get(property))
	host.water_material.set_shader_parameter(
		"reflection_view", camera.global_transform.affine_inverse()
	)
	host.water_material.set_shader_parameter(
		"reflection_projection", camera.get_camera_projection()
	)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	captures += 1
	pending = false
	age = 0


func _exit_tree() -> void:
	if is_instance_valid(host) and host.water_material != null:
		host.water_material.set_shader_parameter("reflection_texture", null)
	for entry: Dictionary in tagged:
		var node: Node = entry["node"].get_ref()
		if is_instance_valid(node):
			node.layers = entry["layers"]
	tagged.clear()
