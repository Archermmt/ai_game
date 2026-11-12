extends SceneTree
## Hardware-render an island parameter study at the exact production viewport resolution.
## godot --path . --disable-render-loop --script tools/render_island_study.gd -- --study=res://examples/island/studies/lighting.json
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var study_path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--study="):
			study_path = arg.trim_prefix("--study=")
	if study_path.is_empty() or RenderingServer.get_rendering_device() == null:
		push_error("Provide a study JSON and use a hardware rendering backend.")
		quit(1)
		return
	var variants: Array = JSON.parse_string(FileAccess.get_file_as_string(study_path))
	root.disable_3d = true
	var port := SubViewport.new()
	port.size = Vector2i(1704,960)
	port.msaa_3d = Viewport.MSAA_4X
	port.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(port)
	port.world_3d = World3D.new()
	for settings: Dictionary in variants:
		var scene: Node3D = load(settings.get("scene","res://examples/island/island.tscn")).instantiate()
		port.add_child(scene)
		await process_frame
		await process_frame
		var sun: DirectionalLight3D = scene.get_node("Sun")
		var env: Environment = scene.get_node("Evening").environment.duplicate(true)
		scene.get_node("Evening").environment = env
		for key in settings.get("environment", {}):
			env.set(key, _value(settings.environment[key]))
		for key in settings.get("sun", {}):
			sun.set(key, _value(settings.sun[key]))
		if settings.has("camera_attributes"):
			var attributes := CameraAttributesPractical.new()
			for key in settings.camera_attributes:
				attributes.set(key, _value(settings.camera_attributes[key]))
			scene.get_node("Camera3D").attributes = attributes
		if settings.has("rotation"):
			var r: Array = settings.rotation
			sun.rotation_degrees = Vector3(r[0],r[1],r[2])
		# Node3D transforms flush through the scene tree, not force_draw().
		await process_frame
		await process_frame
		for i in 24:
			RenderingServer.force_draw(false, 1.0/60.0)
		var img := port.get_texture().get_image()
		var target := ProjectSettings.globalize_path(settings.output)
		DirAccess.make_dir_recursive_absolute(target.get_base_dir())
		var error := img.save_png(target)
		if error != OK:
			push_error(error_string(error))
			quit(1)
			return
		print("STUDY ",settings.output)
		scene.free()
		await process_frame
	quit()

func _value(value: Variant) -> Variant:
	if value is String and value.begins_with("#"):
		return Color(value)
	return value
