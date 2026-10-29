class_name IslandLighting
extends RefCounted
static func apply(sun:DirectionalLight3D,environment:Environment,sunset:bool) -> void:
	# Calibrated separately: Compatibility accumulates light differently.
	var scale=0.5 if RenderingServer.get_current_rendering_method()=="gl_compatibility" else 1.0
	sun.light_color=Color("ffd4a3") if sunset else Color("fff3de")
	sun.light_energy=(0.75 if sunset else 0.9)*scale
	sun.rotation_degrees.x=-20 if sunset else -48
	environment.ambient_light_energy=(0.6 if sunset else 0.5)*scale
