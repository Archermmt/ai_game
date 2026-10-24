class_name PaintedSky
extends RefCounted

var material: ShaderMaterial


func configure(environment: Environment) -> void:
	var sky: Sky = Sky.new()
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	material = ShaderMaterial.new()
	material.shader = preload("res://features/living_world/painted_sky.gdshader")
	sky.sky_material = material
	environment.sky = sky
	environment.background_mode = Environment.BG_SKY
	environment.fog_sky_affect = 0.15
	# Lighting remains analytic; the cubemap branch renders only the cheap gradient.
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR


func sync(elapsed: float, daylight: float, hour: float, summer: bool, blend: Dictionary) -> void:
	var altitude: float = sin((hour - 6.0) * PI / 12.0)
	var elevation: float = deg_to_rad(altitude * (66 if summer else 48))
	var azimuth: float = deg_to_rad(-105 + hour * 9)
	material.set_shader_parameter("sky_time", elapsed)
	material.set_shader_parameter("daylight", daylight)
	material.set_shader_parameter("cloud_cover", blend["cloud"])
	material.set_shader_parameter("dust_amount", blend["dust"])
	material.set_shader_parameter(
		"sun_direction",
		Vector3(sin(azimuth) * cos(elevation), sin(elevation), cos(azimuth) * cos(elevation))
	)
