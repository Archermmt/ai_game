class_name ProductionTerrainRenderer
extends LandscapeTerrainAdapter
## TerrainField remains authoritative. Native maps are disposable, versioned views.

signal published(snapshot: Dictionary)

const CLIMATE_DECLARATIONS: String = """
global uniform float living_time;
global uniform float living_cloud;
global uniform float living_snow;
global uniform float living_season;
uniform vec4 production_tint : source_color = vec4(1.0);
uniform float production_wetness = 0.0;
"""
const CLIMATE_FRAGMENT: String = """
    ALBEDO *= production_tint.rgb;
    vec2 production_cp = v_vertex.xz * 0.13 + vec2(living_time * 0.025, living_time * 0.011);
    float production_cloud_mask = smoothstep(0.40, 0.72,
        0.5 + sin(production_cp.x + sin(production_cp.y)) * 0.22
        + cos(production_cp.y * 0.8 - production_cp.x * 0.5) * 0.20);
    ALBEDO *= 1.0 - production_cloud_mask * living_cloud * 0.30;
    float production_autumn = 1.0 - step(0.45, abs(living_season - 2.0));
    float production_winter = step(2.5, living_season);
    ALBEDO = mix(ALBEDO, ALBEDO * vec3(1.35, 0.95, 0.65), production_autumn * 0.65);
    ALBEDO = mix(ALBEDO, ALBEDO * vec3(1.18, 1.03, 0.81), production_winter * 0.35);
    float production_cover = clamp(living_snow, 0.0, 1.0) * smoothstep(0.45, 0.9, w_normal.y);
    ALBEDO *= 1.0 - production_wetness * (1.0 - production_cover) * 0.24;
    ROUGHNESS = mix(ROUGHNESS, 0.55, production_wetness * (1.0 - production_cover));
    ALBEDO = mix(ALBEDO, vec3(0.80, 0.86, 0.86), production_cover);
    ROUGHNESS = mix(ROUGHNESS, 0.96, production_cover);
"""

var initialized: bool = false
var published_revision: int = -1
var published_signature: String = ""
var requested_signature: String = ""
var published_token: int = -1
var dropped_results: int = 0
var source_snapshot: Dictionary = {}
var _camera: Camera3D
var _latest: Dictionary = {}
var _pending: Dictionary = {}
var _task: int = -1
var _token: int = 0
var _closed: bool = false
var _climate_shader_installed: bool = false
var _environment: Dictionary = {}
var _visual: Dictionary = {}


func initialize(camera: Camera3D) -> void:
	_camera = camera
	initialized = true
	if is_instance_valid(terrain):
		set_camera(camera)
	if not _pending.is_empty() and _task < 0:
		_start()


func request(snapshot: Dictionary) -> void:
	if _closed:
		return
	_latest = snapshot.duplicate(true)
	_environment = snapshot.get("environment", {}).duplicate(true)
	var next_signature: String = signature(snapshot)
	if next_signature == requested_signature:
		if data_ready and not is_busy():
			_publish_metadata()
		return
	requested_signature = next_signature
	_token += 1
	if next_signature == published_signature and data_ready:
		_pending.clear()
		_publish_metadata()
		return
	_pending = {"snapshot": _latest, "signature": next_signature, "token": _token}
	if initialized and _task < 0:
		_start()


func is_busy() -> bool:
	return _task >= 0 or not _pending.is_empty()


func shutdown() -> void:
	if _closed:
		return
	_closed = true
	_token += 1
	_pending.clear()
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1


func sync_environment(environment: Dictionary, visual: Dictionary = {}) -> void:
	_environment = environment.duplicate(true)
	_visual = visual.duplicate(true)
	if not data_ready or not _climate_shader_installed:
		return
	terrain.material.set_shader_param(
		"production_tint", GardenPalette.tint(_environment, "foliage")
	)
	terrain.material.set_shader_param(
		"production_wetness", clampf(float(_visual.get("rain", 0.0)), 0.0, 1.0)
	)


func _start() -> void:
	if _closed or _pending.is_empty() or _task >= 0:
		return
	var job: Dictionary = _pending
	_pending = {}
	_task = WorkerThreadPool.add_task(
		func() -> void:
			var maps: Dictionary = build_maps(job["snapshot"])
			_deliver.call_deferred(job["token"], job["signature"], maps),
		false,
		"Terrain3D source maps"
	)


func _deliver(token: int, map_signature: String, maps: Dictionary) -> void:
	if _closed:
		return
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	if token == _token and map_signature == requested_signature:
		if not is_instance_valid(terrain):
			super.configure(maps["height"], maps["color"])
			if is_instance_valid(_camera):
				set_camera(_camera)
			_install_climate_shader()
		else:
			height_image = maps["height"]
			color_image = maps["color"]
			_publish_maps()
		if data_ready:
			published_signature = map_signature
			published_token = token
			_publish_metadata()
	else:
		dropped_results += 1
	_start()


func _publish_metadata() -> void:
	source_snapshot = _latest.duplicate(true)
	published_revision = int(_latest.get("revision", 0))
	published_token = _token
	sync_environment(_environment, _visual)
	published.emit(source_snapshot)


func _resample_height() -> Image:
	# Production maps already use Terrain3D's aligned .25 m grid. The lab's
	# 64/255 resampling would silently change player brush and pond elevations.
	return _source_height.duplicate() as Image


func _install_climate_shader() -> void:
	var material: Terrain3DMaterial = terrain.material
	material.shader_override_enabled = true
	var generated: Shader = material.shader_override
	if generated == null:
		last_error = "Terrain3D did not generate its production shader override."
		push_error(last_error)
		return
	var code: String = generated.code
	var end: int = _function_end(code, "void fragment()")
	if end < 0 or not code.contains("v_vertex") or not code.contains("w_normal"):
		last_error = "Pinned Terrain3D shader interface changed; climate could not be applied."
		push_error(last_error)
		return
	code = code.insert(end, CLIMATE_FRAGMENT)
	code = code.replace("shader_type spatial;", "shader_type spatial;\n" + CLIMATE_DECLARATIONS)
	var decorated: Shader = Shader.new()
	decorated.code = code
	material.shader_override = decorated
	_climate_shader_installed = true


static func signature(snapshot: Dictionary) -> String:
	return JSON.stringify([snapshot["terrain"], snapshot.get("pool", {}), snapshot["world_seed"]])


static func build_maps(snapshot: Dictionary) -> Dictionary:
	var field: TerrainField = TerrainField.new(snapshot)
	var heights: Image = Image.create(256, 256, false, Image.FORMAT_RF)
	var colors: Image = Image.create(256, 256, false, Image.FORMAT_RGBA8)
	for z: int in 256:
		for x: int in 256:
			var point: Vector2 = SOURCE_ORIGIN + Vector2(x, z) * VERTEX_SPACING
			heights.set_pixel(x, z, Color(field.height_at(point), 0, 0, 1))
			var wet: float = 0.0
			if not field.pool.is_empty():
				wet = 1.0 - smoothstep(-0.2, 0.75, PondShape.distance(field.pool, point))
			var color: Color = Color.WHITE.lerp(Color("829287"), wet * 0.35)
			color.a = lerpf(0.5, 0.30, wet)
			colors.set_pixel(x, z, color)
	return {"height": heights, "color": colors}


static func _function_end(code: String, declaration: String) -> int:
	var start: int = code.find(declaration)
	if start < 0:
		return -1
	start = code.find("{", start)
	var depth: int = 0
	for index: int in range(start, code.length()):
		if code[index] == "{":
			depth += 1
		elif code[index] == "}":
			depth -= 1
			if depth == 0:
				return index
	return -1


func _exit_tree() -> void:
	shutdown()
