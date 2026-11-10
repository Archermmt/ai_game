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
	# Share the painted sky with diffuse lighting while keeping some forest fill at night.
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_sky_contribution = 0.48


static func sun_angles(hour: float, summer: bool) -> Vector2:
	# The low morning sun crosses the clearing from the side of the cottage.
	var altitude: float = sin((hour - 6.0) * PI / 12.0)
	return Vector2(-121.0 + hour * 15.0, altitude * (56.0 if summer else 42.0))


func sync(
	elapsed: float,
	daylight: float,
	hour: float,
	summer: bool,
	blend: Dictionary,
	season: String = "spring"
) -> void:
	var angles: Vector2 = sun_angles(hour, summer)
	var elevation: float = deg_to_rad(angles.y)
	var azimuth: float = deg_to_rad(angles.x)
	var ridge: Vector3 = (
		{
			"spring": Vector3(0.10, 0.21, 0.18),
			"summer": Vector3(0.085, 0.18, 0.18),
			"autumn": Vector3(0.19, 0.19, 0.14),
			"winter": Vector3(0.20, 0.26, 0.30)
		}
		. get(season, Vector3(0.10, 0.21, 0.18))
	)
	material.set_shader_parameter("ridge_tint", ridge)
	material.set_shader_parameter("sky_time", elapsed)
	material.set_shader_parameter("daylight", daylight)
	material.set_shader_parameter("cloud_cover", blend["cloud"])
	material.set_shader_parameter("dust_amount", blend["dust"])
	material.set_shader_parameter(
		"sun_direction",
		Vector3(sin(azimuth) * cos(elevation), sin(elevation), cos(azimuth) * cos(elevation))
	)
