extends SceneTree
## Actual input through the isolated G4 toolbar, renderer reload and gallery return.

var checks: Dictionary = {}
var folder: String = "res://reports/week_14/g4/ui"


func _initialize() -> void:
	_run.call_deferred()


func _wait_scene(previous_id: int = 0) -> Variant:
	var deadline: int = Time.get_ticks_msec() + 120000
	while Time.get_ticks_msec() < deadline:
		var world: Node = current_scene
		if is_instance_valid(world) and world.get_instance_id() != previous_id:
			if world.get_script().resource_path.ends_with("grass_lab.gd"):
				return world
			if bool(world.get("landscape_ready")):
				return world
			if bool(world.get("landscape_failed")):
				break
		await process_frame
	checks["scene switch finishes"] = false
	return null


func _click(button: Button) -> void:
	if button == null:
		checks["required button exists"] = false
		return
	for i: int in 4:
		await process_frame
	var point: Vector2 = button.get_global_rect().get_center()
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	for down: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame


func _button(world: Node, text: String) -> Button:
	for button: Node in world.find_children("*", "Button", true, false):
		if button.text == text:
			return button as Button
	return null


func _capture(label: String) -> void:
	for i: int in 12:
		await process_frame
		RenderingServer.force_draw(false)
	var image: Image = root.get_texture().get_image()
	checks[label + " saved"] = (
		image.get_size() == Vector2i(1920, 1080)
		and image.save_png(folder.path_join(label + ".png")) == OK
	)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	var scene: Node = (load("res://app/grass_capacity.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	var garden: Variant = await _wait_scene()
	if garden == null:
		await _finish()
		return
	var source: Dictionary = garden.document.snapshot()
	checks["new grass and full capacity"] = (
		garden.meadow is ProductionGrassRenderer
		and source["buildings"].size() == 24
		and source["instances"].size() == 1000
	)
	checks["toolbar fits viewport"] = Rect2(Vector2.ZERO, Vector2(root.size)).encloses(
		garden.capacity_panel.get_global_rect()
	)
	await _capture("new_grass")
	await _click(_button(garden, "100% 草"))
	checks["actual pointer selects full density"] = (
		garden.meadow.density == 1.0 and garden.meadow.visible_count() == garden.meadow.total
	)
	await _click(_button(garden, "45% 草"))
	checks["actual pointer restores default density"] = garden.meadow.density == 0.45
	checks["density preserves source"] = garden.document.snapshot() == source
	var previous_id: int = garden.get_instance_id()
	await _click(_button(garden, "切到原草"))
	garden = await _wait_scene(previous_id)
	if garden == null:
		await _finish()
		return
	checks["actual pointer switches to old renderer"] = not garden.meadow is ProductionGrassRenderer
	checks["old renderer retains source and terrain"] = (
		garden.document.snapshot() == source and garden.landscape_terrain.data_ready
	)
	await _capture("legacy_grass")
	previous_id = garden.get_instance_id()
	await _click(_button(garden, "切到新草"))
	garden = await _wait_scene(previous_id)
	if garden == null:
		await _finish()
		return
	checks["actual pointer restores new renderer"] = (
		garden.meadow is ProductionGrassRenderer and garden.document.snapshot() == source
	)
	previous_id = garden.get_instance_id()
	await _click(_button(garden, "返回草地展示台"))
	var gallery: Variant = await _wait_scene(previous_id)
	checks["gallery return and capacity entry"] = (
		gallery != null and _button(gallery, "满容量体验 G4") != null
	)
	await _finish()


func _finish() -> void:
	if is_instance_valid(current_scene):
		await SceneShutdown.wait_wallclock(self, 0.4)
		await SceneShutdown.release_scene(current_scene)
	var passed: bool = checks.values().all(func(value: bool) -> bool: return value)
	var file: FileAccess = FileAccess.open(folder.path_join("result.json"), FileAccess.WRITE)
	file.store_string(
		JSON.stringify(
			{
				"passed": passed,
				"checks": checks,
				"rendering_driver": RenderingServer.get_current_rendering_driver_name()
			},
			"\t"
		)
	)
	file.close()
	quit(0 if passed else 1)
