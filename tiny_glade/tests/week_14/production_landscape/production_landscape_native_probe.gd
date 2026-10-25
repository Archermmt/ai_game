extends SceneTree
## Real F5 scene, actual input routing and GPU evidence. No capacity/FPS/RSS trace.

var garden: Variant
var folder: String = "res://reports/week_14/production_landscape/native"
var checks: Dictionary = {}
var images: Array[String] = []
var gpu_origin_error: float = 0.0


func _initialize() -> void:
	_run.call_deferred()


func _process(_delta: float) -> bool:
	# PhotoExport uses frame_post_draw. An occluded macOS test window must not
	# block those signals; explicitly render only while this test export is busy.
	if is_instance_valid(garden) and garden.photography != null and garden.photography.busy:
		RenderingServer.force_draw(false)
	return false


func _settle() -> void:
	var deadline: int = Time.get_ticks_msec() + 60000
	while _busy() and Time.get_ticks_msec() < deadline:
		await process_frame
	_check("current scene detail publication finishes", not _busy())


func _busy() -> bool:
	return (
		garden.queue.is_busy()
		or garden.stage.is_busy()
		or garden.meadow.is_busy()
		or garden.landscape_terrain.is_busy()
		or garden.saves.is_busy()
		or garden._loading
	)


func _capture(label: String) -> Image:
	for i: int in 12:
		await process_frame
		RenderingServer.force_draw(false)
	_check(label + " finite camera", garden.camera_rig.camera.global_transform.is_finite())
	var image: Image = root.get_texture().get_image()
	var path: String = folder.path_join(label + ".png")
	_check(
		label + " image saved",
		image.get_size() == Vector2i(1920, 1080) and image.save_png(path) == OK
	)
	images.append(path)
	return image


func _click(control: Control) -> void:
	if control == null:
		_check("required GUI control exists", false)
		return
	for i: int in 4:
		await process_frame
	var point: Vector2 = control.get_global_rect().get_center()
	var window: Window = control.get_window()
	if window != root:
		_check("dialog uses embedded viewport", window.is_embedded())
		point += Vector2(window.position)
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
	await process_frame


func _button(parent: Node, text: String) -> Button:
	for button: Node in parent.find_children("*", "Button", true, false):
		if button.text == text:
			return button as Button
	return null


func _climate(month: int, weather: String) -> void:
	garden.calendar.month = month
	garden.calendar.weather = weather
	garden.calendar.minute_of_day = 690
	garden.hud.calendar.sync()
	garden.atmosphere.blend.advance(0, garden.calendar.sample())
	garden.atmosphere.blend.advance(18, garden.calendar.sample())
	garden.atmosphere.update(0, garden.calendar.sample())


func _native_surface_matches() -> bool:
	var source: Dictionary = garden.document.snapshot()
	var field: TerrainField = TerrainField.new(source)
	var points: Array[Vector2] = [Vector2.ZERO, Vector2(16, 16), Vector2(-12, 12), Vector2(20, -20)]
	if not source["pool"].is_empty():
		var center: Array = source["pool"]["center"]
		points.append(Vector2(center[0], center[1]).snapped(Vector2.ONE * 0.25))
	for point: Vector2 in points:
		var value: float = garden.landscape_terrain.terrain.data.get_height(
			Vector3(point.x, 0, point.y)
		)
		if not is_finite(value) or absf(value - field.height_at(point)) >= 0.02:
			return false
	return true


func _check_gpu_origins() -> void:
	var checked: int = 0
	var maximum: float = 0.0
	for key: Vector2i in garden.meadow.groups:
		var views: Array = garden.meadow.groups[key]
		for view: MultiMeshInstance3D in views:
			var kind: int = int(view.get_meta("grass_layer"))
			var items: Array = garden.meadow.published_chunks[key][kind]
			var batch: MultiMesh = view.multimesh
			var stride: int = maxi(1, batch.instance_count / 8)
			for index: int in range(0, batch.instance_count, stride):
				var pose: Transform3D = view.global_transform * batch.get_instance_transform(index)
				maximum = maxf(maximum, pose.origin.distance_to(items[index]["pose"].origin))
				checked += 1
	gpu_origin_error = maximum
	_check("actual GPU roots match current published transforms", checked > 100 and maximum < 0.002)


func _difference(a: Image, b: Image) -> float:
	var total: float = 0.0
	var count: int = 0
	for y: int in range(220, 950, 4):
		for x: int in range(100, 1500, 4):
			var delta: Color = a.get_pixel(x, y) - b.get_pixel(x, y)
			total += absf(delta.r) + absf(delta.g) + absf(delta.b)
			count += 3
	return total / count


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = Vector2i(1920, 1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	garden = (load("res://app/living_root.tscn") as PackedScene).instantiate()
	garden.qa_mode = true
	root.add_child(garden)
	current_scene = garden
	var directory: String = "user://qa_production_landscape/native/%d" % Time.get_ticks_usec()
	garden.saves.directory = directory.path_join("saves")
	garden.hud.photo_directory.text = ProjectSettings.globalize_path(directory.path_join("photos"))
	garden.active_slot = -1
	var deadline: int = Time.get_ticks_msec() + 120000
	while (
		not bool(garden.get("landscape_ready"))
		and not bool(garden.get("landscape_failed"))
		and Time.get_ticks_msec() < deadline
	):
		await process_frame
	_check(
		"actual F5 production landscape initializes",
		bool(garden.get("landscape_ready")) and not bool(garden.get("landscape_failed"))
	)
	if not checks["actual F5 production landscape initializes"]:
		await _finish()
		return
	await _settle()
	garden.calendar.speed = 0
	garden.calendar.automatic_weather = false
	garden.camera_rig.camera.attributes = null
	_climate(5, "clear")
	garden._freeze_photo(true)
	var source: Dictionary = garden.document.snapshot()
	_check(
		"qa isolation precedes inherited storage setup",
		garden.qa_mode and garden.saves.directory.begins_with("user://qa_production_landscape/")
	)
	_check("production HUD remains editable", garden.hud.visible and not garden.photo_active)
	_check("all four real grass models loaded", garden.meadow.meshes.size() == 4)
	_check("Terrain3D uses current authoritative surface", _native_surface_matches())
	_check_gpu_origins()
	await _capture("formal_overview")
	# Actual terrain tool and pointer routing, then current-source terrain and grass.
	garden._freeze_photo(false)
	garden.camera_rig.target = Vector3(16, 0, 16)
	garden.camera_rig.distance = 18
	garden.camera_rig.pitch = 0.8
	garden.camera_rig.refresh()
	await _click(garden.hud.ribbon_buttons["terrain"])
	_check("terrain GUI activates raise tool", garden.tools.mode == "raise")
	garden.hud.close_context()
	var field: TerrainField = TerrainField.new(garden.document.snapshot())
	var screen: Vector2 = garden.camera_rig.camera.unproject_position(
		Vector3(16, field.height_at(Vector2(16, 16)), 16)
	)
	var revision: int = garden.document.state["revision"]
	for down: bool in [true, false]:
		var pointer: InputEventMouseButton = InputEventMouseButton.new()
		pointer.position = screen
		pointer.global_position = screen
		pointer.button_index = MOUSE_BUTTON_LEFT
		pointer.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		pointer.pressed = down
		Input.parse_input_event(pointer)
		for i: int in 8:
			await process_frame
	await _settle()
	_check(
		"actual pointer commits terrain transaction", garden.document.state["revision"] > revision
	)
	_check("edited native terrain equals transaction source", _native_surface_matches())
	_check(
		"edited grass rejects stale worker output",
		garden.meadow.published_signature == MeadowData.signature(garden.document.state)
	)
	_check_gpu_origins()
	await _capture("formal_edited_slope")
	await _click(garden.hud.utilities.get_child(0))
	await _settle()
	_check(
		"undo GUI restores terrain source", garden.document.state["terrain"] == source["terrain"]
	)
	_check("undo restores native terrain", _native_surface_matches())
	await _click(garden.hud.utilities.get_child(1))
	await _settle()
	_check(
		"redo GUI restores edited terrain",
		garden.document.state["terrain"] != source["terrain"] and _native_surface_matches()
	)
	garden.tools.mode = "inspect"
	await _click(garden.hud.utilities.get_child(2))
	_check("save library opens through GUI", garden.hud.library.visible)
	garden.hud.title_entry.text = "Formal landscape native regression"
	await _click(_button(garden.hud.library, "保存到此槽"))
	await _settle()
	var saved: Dictionary = SlotStore.read_slot(garden.saves.directory, 0)
	_check(
		"GUI saves isolated source with thumbnail", saved["ok"] and garden.last_thumbnail_bytes > 0
	)
	garden.hud.library.hide()
	var saved_versions: Dictionary = garden.meadow._published_versions.duplicate(true)
	garden._start_load(0)
	await _settle()
	_check(
		"save reload regenerates same four-layer chunks",
		garden.meadow._published_versions == saved_versions
	)
	_check("save reload regenerates native terrain", _native_surface_matches())
	garden._recommended_view(1)
	garden.camera_rig.camera.attributes = null
	_climate(4, "clear")
	garden._freeze_photo(true)
	await _capture("formal_spring")
	_climate(1, "snow")
	await _capture("formal_winter")
	_check("snow remains active on production landscape", garden.atmosphere.snow.visible)
	_check("climate preserves grass geometry", garden.meadow._published_versions == saved_versions)
	_climate(5, "clear")
	await _click(garden.hud.ribbon_buttons["photo"])
	_check("photo GUI opens", garden.photo_active)
	await _click(garden.hud.walk_toggle)
	_check("walk GUI enters current terrain", garden.walk_controller.active)
	await _capture("formal_eye_level")
	await _click(garden.hud.walk_toggle)
	_check("walk GUI returns to orbit", not garden.walk_controller.active)
	garden._freeze_photo(true)
	var pose: Transform3D = garden.camera_rig.camera.global_transform
	var exports: Array[Dictionary] = []
	for dimensions: Vector2i in PhotoExport.SIZES:
		var label: String = "photo_1080.png" if dimensions.x == 1920 else "photo_2k.png"
		exports.append(
			await garden.photography.capture(
				garden.camera_rig.camera, dimensions, folder.path_join(label)
			)
		)
	_check(
		"1080p and 2K no-UI photo exports",
		exports.all(func(value: Dictionary) -> bool: return value["ok"])
	)
	_check("photo export preserves camera", garden.camera_rig.camera.global_transform == pose)
	_check(
		"grass participates in photo freeze",
		garden.meadow.material.get_shader_parameter("freeze_time")
	)
	# Isolate grass shader motion from TAA and all other frozen scene animation.
	root.use_taa = false
	garden.camera_rig.target = Vector3(12, 0, 12)
	garden.camera_rig.distance = 10
	garden.camera_rig.refresh()
	garden.camera_rig.camera.attributes = null
	garden.meadow.material.set_shader_parameter("sample_time", 0.0)
	var moving_a: Image = await _capture("wind_a")
	garden.meadow.material.set_shader_parameter("sample_time", 3.0)
	var moving_b: Image = await _capture("wind_b")
	var wind_difference: float = _difference(moving_a, moving_b)
	_check("four-layer grass wind changes real pixels", wind_difference > 0.00001)
	garden.preferences.values["reduce_motion"] = true
	garden._apply_preferences()
	garden.camera_rig.camera.attributes = null
	garden.meadow.material.set_shader_parameter("sample_time", 0.0)
	var quiet_a: Image = await _capture("reduced_a")
	garden.meadow.material.set_shader_parameter("sample_time", 9.0)
	var quiet_b: Image = await _capture("reduced_b")
	var quiet_difference: float = _difference(quiet_a, quiet_b)
	_check("reduced motion remains visually stable", quiet_difference < 0.0001)
	_check("grass excluded from pond reflection", _reflection_excluded())
	var expected_keys: Array = source.keys()
	var current_keys: Array = garden.document.state.keys()
	expected_keys.sort()
	current_keys.sort()
	var instances_equal: bool = garden.document.state["instances"] == source["instances"]
	_check("source schema key set preserved", current_keys == expected_keys)
	_check("manual objects preserved", instances_equal)
	var report: Dictionary = {
		"wind_pixel_difference": wind_difference,
		"reduced_pixel_difference": quiet_difference,
		"exports": exports,
		"expected_schema_keys": expected_keys,
		"current_schema_keys": current_keys,
		"manual_instances_equal": instances_equal
	}
	await _finish(report)


func _check(label: String, passed: bool) -> void:
	checks[label] = bool(checks.get(label, true)) and passed
	if not passed:
		push_error(label)


func _reflection_excluded() -> bool:
	for view: MultiMeshInstance3D in garden.meadow.batches:
		if (view.layers & PondReflections.REFLECTION_LAYER) != 0:
			return false
	return true


func _finish(extra: Dictionary = {}) -> void:
	var passed: bool = not checks.is_empty() and not checks.values().has(false)
	var report: Dictionary = extra.duplicate(true)
	report.merge(
		{
			"checks": checks,
			"passed": passed,
			"images": images,
			"viewport": [1920, 1080],
			"gpu_origin_error_m": gpu_origin_error,
			"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
			"performance_gate_run": false,
			"windows_real_device_verified": false
		},
		true
	)
	var file: FileAccess = FileAccess.open(folder.path_join("result.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	if is_instance_valid(garden):
		garden.seasonal_music.shutdown()
		garden.soundscape.shutdown()
		await SceneShutdown.wait_wallclock(self, 0.4)
		await SceneShutdown.release_scene(garden)
	for i: int in 12:
		await process_frame
	print("PRODUCTION_LANDSCAPE_NATIVE_", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)
