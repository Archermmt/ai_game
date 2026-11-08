class_name IslandLighting
extends RefCounted
static func apply(sun:DirectionalLight3D,environment:Environment,sunset:bool) -> void:
	sun.directional_shadow_mode=DirectionalLight3D.SHADOW_ORTHOGONAL
	# Calibrated separately: Compatibility accumulates light differently.
	if environment.sky==null:
		var sky=Sky.new();var material=ProceduralSkyMaterial.new();material.sky_top_color=Color("89b9c5");material.sky_horizon_color=Color("cadbc5");sky.sky_material=material;environment.sky=sky
	environment.reflected_light_source=Environment.REFLECTION_SOURCE_SKY
	environment.fog_enabled=true;environment.fog_density=0.0015;environment.fog_light_color=Color("a6c9bf")
	var scale=0.5 if RenderingServer.get_current_rendering_method()=="gl_compatibility" else 1.0
	sun.light_color=Color("ffd4a3") if sunset else Color("fff3de")
	sun.light_energy=(0.75 if sunset else 0.9)*scale
	sun.rotation_degrees.x=-20 if sunset else -48
	environment.ambient_light_energy=(0.6 if sunset else 0.5)*scale
