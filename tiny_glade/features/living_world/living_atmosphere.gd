class_name LivingAtmosphere
extends Node3D
## Fixed rain/snow/dust budgets; only the active weather draws.
## Seasonal uniforms never rebuild world geometry.

var host: Node3D
var rain: MultiMeshInstance3D
var snow: MultiMeshInstance3D
var dust: MultiMeshInstance3D
var bolt: MeshInstance3D
var flash: OmniLight3D
var elapsed: float = 0.0
var frozen: bool = false
var reduced_motion: bool = false
var lightning_enabled: bool = true
var sky: PaintedSky = PaintedSky.new()
var blend: WeatherBlend = WeatherBlend.new()
var phase: Vector3 = Vector3.ZERO
var morning_fog: FogVolume
var morning_fog_material: FogMaterial
var _season: String = ""
var _weather: String = ""


func configure(root: Node3D) -> void:
	host = root
	var environment: Environment = host.world_environment.environment
	sky.configure(environment)
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.tonemap_exposure = 1.55
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 1.10
	name = "LivingAtmosphere"
	morning_fog_material = FogMaterial.new()
	morning_fog_material.albedo = Color("dbe8ea")
	morning_fog_material.edge_fade = 0.7
	morning_fog_material.height_falloff = 0.0
	morning_fog_material.emission = Color(0.3, 0.36, 0.4)
	morning_fog = FogVolume.new()
	morning_fog.name = "ForestMorningMist"
	morning_fog.size = Vector3(76, 5.2, 76)
	morning_fog.position.y = 0.9
	morning_fog.material = morning_fog_material
	add_child(morning_fog)
	environment.volumetric_fog_density = 0.0
	environment.volumetric_fog_length = 78.0
	environment.volumetric_fog_anisotropy = 0.3
	rain = _precipitation(false, 1400)
	snow = _precipitation(true, 900)
	dust = _precipitation(false, 700)
	dust.name = "Duststorm"
	var dust_quad: QuadMesh = dust.multimesh.mesh
	dust_quad.size = Vector2(0.10, 0.10)
	dust.material_override.set_shader_parameter("dust", true)
	flash = OmniLight3D.new()
	flash.position = Vector3(0, 18, 0)
	flash.omni_range = 90
	flash.omni_attenuation = 0.08
	flash.name = "LightningGlow"
	flash.light_color = Color("b7cced")
	flash.light_energy = 0
	add_child(flash)
	bolt = MeshInstance3D.new()
	bolt.name = "DistantLightning"
	var mesh: ImmediateMesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var points: Array[Vector3] = [
		Vector3(12, 23, -20),
		Vector3(10, 18, -20),
		Vector3(13, 15, -20),
		Vector3(9, 10, -20),
		Vector3(10, 5, -20)
	]
	for i: int in range(points.size() - 1):
		for p: Vector3 in [
			points[i] - Vector3(0.10, 0, 0),
			points[i] + Vector3(0.10, 0, 0),
			points[i + 1],
			points[i + 1],
			points[i] + Vector3(0.10, 0, 0),
			points[i + 1] + Vector3(0.10, 0, 0)
		]:
			mesh.surface_add_vertex(p)
	mesh.surface_end()
	bolt.mesh = mesh
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("e6edf9")
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	bolt.material_override = material
	bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bolt)
	bolt.hide()


func _precipitation(is_snow: bool, count: int) -> MultiMeshInstance3D:
	var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
	node.name = "Snowfall" if is_snow else "Rainfall"
	var instances: MultiMesh = MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.12, 0.12) if is_snow else Vector2(0.025, 0.65)
	instances.mesh = quad
	instances.instance_count = count
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 3341 if is_snow else 7129
	for i: int in range(count):
		instances.set_instance_transform(
			i,
			Transform3D(
				Basis.IDENTITY,
				Vector3(rng.randf_range(-32, 32), rng.randf_range(0, 22), rng.randf_range(-32, 32))
			)
		)
	node.multimesh = instances
	node.custom_aabb = AABB(Vector3(-38, -2, -38), Vector3(76, 28, 76))
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = preload("res://features/living_world/precipitation.gdshader")
	material.set_shader_parameter("snow", is_snow)
	node.material_override = material
	add_child(node)
	node.hide()
	return node


static func morning_mist(hour: float, season: String) -> float:
	var seasonal: float = {"spring": 0.34, "summer": 0.12, "autumn": 0.86, "winter": 1.0}.get(
		season, 0.34
	)
	return seasonal * smoothstep(4.5, 6.0, hour) * (1.0 - smoothstep(6.5, 10.5, hour))


func update(delta: float, state: Dictionary) -> void:
	if not frozen:
		elapsed += delta * (0.25 if reduced_motion else 1.0)
	RenderingServer.global_shader_parameter_set("living_time", elapsed)
	var season_value: String = state["season"]
	var weather_value: String = state["weather"]
	_season = season_value
	_weather = weather_value
	var visual: Dictionary = blend.advance(delta, state, frozen)
	RenderingServer.global_shader_parameter_set(
		"living_season", ["spring", "summer", "autumn", "winter"].find(_season)
	)
	RenderingServer.global_shader_parameter_set(
		"living_cloud", clampf((visual["cloud"] - 0.18) / 0.82, 0, 1)
	)
	RenderingServer.global_shader_parameter_set("living_snow", visual["cover"])
	_precipitation_blend(delta, visual)
	var hour: float = float(state["minute_of_day"]) / 60.0
	var altitude: float = sin((hour - 6.0) * PI / 12.0)
	var daylight: float = smoothstep(-0.12, 0.35, altitude)
	var summer: bool = _season == "summer"
	var energy: float = (1.24 if summer else 1.05) * maxf(0.0, altitude)
	energy *= float(visual["energy"])
	host.sun.light_energy = maxf(0.035, energy)
	var angles: Vector2 = PaintedSky.sun_angles(hour, summer)
	host.sun.rotation_degrees = Vector3(-maxf(9.0, angles.y), angles.x, 0)
	host.sun.light_color = Color("a5b9d9").lerp(Color("fff1cf"), daylight)
	host.sun.light_color = host.sun.light_color.lerp(
		Color("edb18c"), (1.0 - smoothstep(0.0, 0.35, absf(altitude))) * daylight
	)
	var environment: Environment = host.world_environment.environment
	environment.ambient_light_color = Color("8298bc").lerp(Color("c1cec7"), daylight)
	environment.ambient_light_energy = lerpf(0.31, 0.64 + 0.10 * float(visual["cloud"]), daylight)
	environment.fog_light_color = Color("536783").lerp(Color("c0ccbf"), daylight)
	environment.fog_density = float(visual["fog"]) + 0.0012 * daylight
	var mist: float = morning_mist(hour, season_value)
	morning_fog_material.density = mist * 0.45
	morning_fog.visible = mist > 0.001
	environment.volumetric_fog_enabled = morning_fog.visible
	environment.fog_light_color = environment.fog_light_color.lerp(Color("bda277"), visual["dust"])
	environment.ambient_light_color = environment.ambient_light_color.lerp(
		Color("b4a480"), visual["dust"]
	)
	host.sun.light_color = host.sun.light_color.lerp(Color("d7b57c"), visual["dust"])
	sky.sync(elapsed, daylight, hour, summer, visual, _season)
	if host.window_material != null:
		# The calendar owns continuous window light, including legacy dusk saves.
		host.window_material.set_shader_parameter("dusk", false)
		host.window_material.set_shader_parameter("dusk_mix", 1.0 - daylight)
	var pulse: bool = (
		float(visual["rain"]) > 0.45
		and _weather in ["rain", "storm"]
		and not reduced_motion
		and lightning_enabled
		and (
			fposmod(elapsed, 6.0 if _weather == "storm" else 18.0)
			> (5.7 if _weather == "storm" else 17.7)
		)
	)
	bolt.visible = pulse
	flash.light_energy = 0.65 if pulse else 0.0
	if host.lanterns != null:
		host.lanterns.advance(host.camera_rig.camera.global_position, 1.0 - daylight)
	if host.light_rig != null:
		host.light_rig.sync(
			host.document.state["environment"].get("lamp_probes", []),
			host.camera_rig.camera.global_position,
			1.0 - daylight
		)


func _precipitation_blend(delta: float, visual: Dictionary) -> void:
	var amounts: Vector3 = Vector3(visual["rain"], visual["snow"], visual["dust"])
	var severities: Vector3 = Vector3(
		lerpf(1, 2.4, smoothstep(0.55, 1, amounts.x)),
		lerpf(1, 3, smoothstep(0.55, 1, amounts.y)),
		1
	)
	if not frozen:
		phase += severities * maxf(0, delta) * (0.25 if reduced_motion else 1.0)
	var nodes: Array[MultiMeshInstance3D] = [rain, snow, dust]
	for i: int in range(nodes.size()):
		nodes[i].visible = amounts[i] > 0.001
		nodes[i].material_override.set_shader_parameter("amount", amounts[i])
		nodes[i].material_override.set_shader_parameter("severity", severities[i])
		nodes[i].material_override.set_shader_parameter("phase", phase[i])


func _exit_tree() -> void:
	for key: String in ["living_season", "living_cloud", "living_snow", "living_time"]:
		RenderingServer.global_shader_parameter_set(key, -1.0 if key == "living_season" else 0.0)
