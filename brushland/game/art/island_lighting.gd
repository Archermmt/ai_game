class_name IslandLighting
extends RefCounted

static func apply(sun: DirectionalLight3D, environment: Environment, sunset: bool) -> void:
	if environment.sky == null:
		var sky := Sky.new()
		var atmosphere := ShaderMaterial.new()
		atmosphere.shader = preload("res://game/art/shaders/lake_sky.gdshader")
		sky.sky_material = atmosphere
		environment.sky = sky
	environment.background_mode = Environment.BG_SKY
	environment.sky.sky_material.set_shader_parameter("dusk", 1.0 if sunset else 0.0)
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d7c9df") if sunset else Color("e1e2ed")
	environment.fog_sky_affect = 0.08
	environment.fog_enabled = true
	environment.fog_density = 0.003
	environment.fog_light_color = Color("a89196") if sunset else Color("bfc0bb")
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.rotation_degrees = Vector3(-25.0 if sunset else -37.0, 64.0, 0.0)
	sun.light_color = Color("ffc397") if sunset else Color("ffe3b8")
	var scale := 0.50 if RenderingServer.get_current_rendering_method() == "gl_compatibility" else 1.0
	sun.light_energy = (0.83 if sunset else 1.00) * scale
	environment.ambient_light_energy = (0.53 if sunset else 0.56) * scale
