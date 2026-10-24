class_name ArtEnvironment
extends RefCounted
## Warm sun, cool open shade and quiet atmospheric depth, retained through day/dusk.


static func configure(environment: Environment, sun: DirectionalLight3D) -> void:
	environment.background_mode = Environment.BG_SKY
	var sky: Sky = Sky.new()
	var sky_material: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("9fbac1")
	sky_material.sky_horizon_color = Color("e3dfbd")
	sky_material.ground_horizon_color = Color("d9d8b5")
	sky_material.ground_bottom_color = Color("607052")
	sky_material.sun_angle_max = 6.0
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.ambient_light_energy = 0.48
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 0.96
	environment.ssao_enabled = true
	environment.ssao_radius = 0.7
	environment.ssao_intensity = 0.92
	environment.ssao_power = 1.0
	environment.ssao_detail = 0.15
	environment.fog_enabled = true
	environment.fog_density = 0.0008
	environment.fog_height = 0.0
	environment.fog_height_density = 0.0
	environment.fog_light_color = Color("cbd5b8")
	environment.fog_light_energy = 0.55
	environment.fog_sun_scatter = 0.12
	environment.glow_enabled = true
	environment.glow_intensity = 0.08
	environment.glow_hdr_threshold = 1.8
	sun.light_angular_distance = 2.2
	sun.directional_shadow_max_distance = 90.0
	sun.directional_shadow_blend_splits = true
	sun.shadow_bias = 0.10
	sun.shadow_normal_bias = 2.0


static func apply(root: Node3D, mix_value: float) -> void:
	root.sun.light_color = Color("fff5df").lerp(Color("ffce94"), mix_value)
	root.sun.light_energy = lerpf(1.35, 0.82, mix_value)
	root.sun.rotation_degrees = Vector3(lerpf(-43.0, -18.0, mix_value), -38, 0)
	var environment: Environment = root.world_environment.environment
	environment.ambient_light_color = Color("abc0c4").lerp(Color("9ba9ba"), mix_value)
	environment.ambient_light_energy = lerpf(0.37, 0.52, mix_value)
	environment.fog_light_color = Color("cbd5b8").lerp(Color("b8b5c0"), mix_value)
