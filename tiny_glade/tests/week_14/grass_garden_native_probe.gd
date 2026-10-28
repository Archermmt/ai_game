extends SceneTree
## G3 native editing/environment/export proof; not a capacity performance gate.

var garden: PainterlyGrassGarden
var folder: String
var checks: Dictionary = {}
var weather_trajectory: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _settle() -> void:
	var deadline: int = Time.get_ticks_msec() + 45000
	while (
		(
			garden.queue.is_busy()
			or garden.stage.is_busy()
			or garden.meadow.is_busy()
			or garden.saves.is_busy()
			or garden._loading
		)
		and Time.get_ticks_msec() < deadline
	):
		await process_frame
	assert(
		not (
			garden.queue.is_busy()
			or garden.stage.is_busy()
			or garden.meadow.is_busy()
			or garden.saves.is_busy()
			or garden._loading
		)
	)


func _capture(name_value: String) -> Image:
	for i: int in 48:
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	assert(image.get_size() == Vector2i(1920, 1080))
	assert(image.save_png(folder.path_join(name_value + ".png")) == OK)
	return image


func _click(control: Control) -> void:
	for i: int in 5:
		await process_frame
	var point: Vector2 = control.get_global_rect().get_center()
	var window: Window = control.get_window()
	if window != root:
		assert(window.is_embedded())
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


func _difference(a: Image, b: Image) -> float:
	var value: float = 0
	var count: int = 0
	for y: int in range(220, 950, 4):
		for x: int in range(100, 1500, 4):
			var delta: Color = a.get_pixel(x, y) - b.get_pixel(x, y)
			value += absf(delta.r) + absf(delta.g) + absf(delta.b)
			count += 3
	return value / count


func _climate(month: int, weather: String) -> void:
	garden.calendar.month = month
	garden.calendar.weather = weather
	garden.calendar.minute_of_day = 690
	garden.hud.calendar.sync()
	garden.atmosphere.blend.advance(0, garden.calendar.sample())
	garden.atmosphere.blend.advance(18, garden.calendar.sample())
	garden.atmosphere.update(0, garden.calendar.sample())


func _run() -> void:
	folder = OS.get_cmdline_user_args()[-1]
	DirAccess.make_dir_recursive_absolute(folder)
	garden = preload("res://app/painterly_grass_garden.tscn").instantiate()
	garden.preview_directory = (
		"user://qa_painterly_grass/tests/g3_native_%d" % Time.get_ticks_usec()
	)
	root.add_child(garden)
	current_scene = garden
	var deadline: int = Time.get_ticks_msec() + 60000
	while not garden.garden_ready and not garden.garden_failed and Time.get_ticks_msec() < deadline:
		await process_frame
	assert(garden.garden_ready)
	garden.calendar.speed = 0
	garden.calendar.automatic_weather = false
	garden.camera_rig.camera.attributes = null
	_climate(5, "clear")
	garden._freeze_photo(true)
	var source: Dictionary = garden.document.snapshot()
	var original_versions: Dictionary = garden.grass_renderer._published_versions.duplicate(true)
	var fresh: Image = await _capture("editor_new")
	await _click(garden.grass_variant)
	await _settle()
	var old: Image = await _capture("editor_old")
	checks["variant_gui_rebuilds_real_old_grass"] = (
		not garden.grass_renderer.use_new_grass and _difference(fresh, old) > 0.0001
	)
	checks["ab_source_unchanged"] = garden.document.snapshot() == source
	await _click(garden.grass_variant)
	await _settle()
	checks["new_grass_versions_restore"] = (
		garden.grass_renderer._published_versions == original_versions
	)
	checks["f6_isolated"] = (
		garden.qa_mode and garden.saves.directory.begins_with("user://qa_painterly_grass/tests/")
	)
	checks["editable_hud_visible"] = garden.hud.visible and not garden.photo_active
	checks["toolbar_inside_viewport"] = Rect2(Vector2.ZERO, Vector2(1920, 1080)).encloses(
		garden.grass_note.get_global_rect()
	)
	# Actual terrain tool button then scene pointer press/release through input routing.
	garden._freeze_photo(false)
	garden.camera_rig.target = Vector3(16, 0, 16)
	garden.camera_rig.distance = 18
	garden.camera_rig.pitch = 0.8
	garden.camera_rig.refresh()
	await _click(garden.hud.ribbon_buttons["terrain"])
	checks["terrain_tool_gui"] = garden.tools.mode == "raise"
	garden.hud.close_context()
	var field: TerrainField = TerrainField.new(garden.document.state)
	var point: Vector2 = garden.camera_rig.camera.unproject_position(
		Vector3(16, field.height_at(Vector2(16, 16)), 16)
	)
	var before_revision: int = garden.document.state["revision"]
	for down: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		event.pressed = down
		Input.parse_input_event(event)
		for i: int in 8:
			await process_frame
	await _settle()
	checks["terrain_edit_actual_pointer"] = garden.document.state["revision"] > before_revision
	checks["latest_grass_matches_edit"] = (
		garden.grass_renderer.published_signature == MeadowData.signature(garden.document.state)
	)
	await _capture("edited_slope")
	await _click(garden.hud.utilities.get_child(0))
	await _settle()
	checks["undo_real_gui"] = garden.document.state["terrain"] == source["terrain"]
	await _click(garden.hud.utilities.get_child(1))
	await _settle()
	checks["redo_real_gui"] = garden.document.state["terrain"] != source["terrain"]
	garden.tools.mode = "inspect"
	# Real library/save button in its own Window viewport; storage is test-only.
	await _click(garden.hud.utilities.get_child(2))
	checks["library_real_gui"] = garden.hud.library.visible
	garden.hud.title_entry.text = "G3 native regression"
	await _click(_button(garden.hud.library, "保存到此槽"))
	await _settle()
	print("G3_SAVE_GUI busy=", garden.saves.is_busy(), " title=", garden.active_title)
	var saved: Dictionary = SlotStore.read_slot(garden.saves.directory, 0)
	checks["save_real_gui"] = saved["ok"] and garden.last_thumbnail_bytes > 0
	print("G3_GUI_CHECKS ", JSON.stringify(checks))
	if not checks["save_real_gui"]:
		push_error("G3 actual GUI save failed")
		quit(1)
		return
	var saved_versions: Dictionary = garden.grass_renderer._published_versions.duplicate(true)
	garden.hud.library.hide()
	garden._start_load(0)
	await _settle()
	checks["load_regenerates_same_grass"] = (
		garden.grass_renderer._published_versions == saved_versions
	)
	# Eight matched representative season/weather views, with no DOF.
	garden._recommended_view(1)
	garden.camera_rig.camera.attributes = null
	for month: int in [4, 7, 10, 1]:
		for weather: String in ["clear", "cloudy"]:
			_climate(month, weather)
			await _capture("season_%d_%s" % [month, weather])
			checks["season_%d_%s_no_rebuild" % [month, weather]] = (
				garden.grass_renderer._published_versions == saved_versions
			)
	_climate(7, "rain")
	await _capture("rain")
	checks["rain_visible"] = garden.atmosphere.rain.visible
	_climate(1, "snow")
	await _capture("snow")
	checks["snow_visible"] = garden.atmosphere.snow.visible
	# Redirect before the first transition completes; record real wall-clock samples.
	garden._freeze_photo(false)
	var start: int = Time.get_ticks_usec()
	var previous: int = start
	var redirected: bool = false
	garden.calendar.month = 7
	garden.calendar.weather = "rain"
	while Time.get_ticks_usec() - start < 6000000:
		await process_frame
		var now: int = Time.get_ticks_usec()
		if not redirected and now - start > 2000000:
			garden.calendar.month = 1
			garden.calendar.weather = "snow"
			redirected = true
		if now - previous > 250000:
			weather_trajectory.append(
				{
					"elapsed_ms": float(now - start) / 1000,
					"weather": garden.calendar.weather,
					"blend": garden.atmosphere.blend.current.duplicate()
				}
			)
			previous = now
	checks["weather_midblend_redirect"] = (
		redirected
		and garden.atmosphere.blend.weather == "snow"
		and garden.atmosphere.blend.age < WeatherBlend.DURATION
	)
	await _capture("weather_redirect")
	# Real photo/walk controls, exports share World3D only, excluding both HUD layers.
	await _click(garden.hud.ribbon_buttons["photo"])
	checks["photo_real_gui"] = garden.photo_active
	checks["preview_toolbar_hidden_in_photo"] = not garden.grass_toolbar.visible
	await _click(garden.hud.walk_toggle)
	checks["walk_real_gui"] = garden.walk_controller.active
	await _click(garden.hud.walk_toggle)
	checks["walk_exit_real_gui"] = not garden.walk_controller.active
	garden._freeze_photo(true)
	var pose: Transform3D = garden.camera_rig.camera.global_transform
	var exported: Array[Dictionary] = []
	for size: Vector2i in PhotoExport.SIZES:
		var title: String = "photo_1080.png" if size.x == 1920 else "photo_2k.png"
		exported.append(
			await garden.photography.capture(
				garden.camera_rig.camera, size, folder.path_join(title)
			)
		)
	checks["two_no_ui_exports"] = exported.all(func(r: Dictionary) -> bool: return r["ok"])
	checks["photo_camera_preserved"] = garden.camera_rig.camera.global_transform == pose
	checks["photo_freezes_new_and_old"] = (
		garden.grass_renderer.material.get_shader_parameter("freeze_time")
		and garden.grass_renderer.old_material.get_shader_parameter("freeze_time")
	)
	# Isolate shader motion from temporal AA jitter on both sides of each pixel control.
	root.use_taa = false
	_climate(5, "clear")
	garden.camera_rig.target = Vector3(12, 0, 12)
	garden.camera_rig.distance = 10
	garden.camera_rig.refresh()
	garden.camera_rig.camera.attributes = null
	garden.grass_renderer.material.set_shader_parameter("sample_time", 0.0)
	var wind_a: Image = await _capture("wind_a")
	garden.grass_renderer.material.set_shader_parameter("sample_time", 3.0)
	var wind_b: Image = await _capture("wind_b")
	var wind_difference: float = _difference(wind_a, wind_b)
	checks["new_grass_wind_pixels"] = wind_difference > 0.00001
	garden.preferences.values["reduce_motion"] = true
	garden._apply_preferences()
	garden.camera_rig.camera.attributes = null
	garden.grass_renderer.material.set_shader_parameter("sample_time", 0.0)
	var quiet_a: Image = await _capture("reduced_a")
	garden.grass_renderer.material.set_shader_parameter("sample_time", 9.0)
	var quiet_b: Image = await _capture("reduced_b")
	var reduced_difference: float = _difference(quiet_a, quiet_b)
	checks["reduced_motion_pixels_stable"] = reduced_difference < 0.0001
	checks["environment_did_not_change_source"] = (
		garden.document.state["instances"] == source["instances"]
		and garden.document.state["schema_version"] == source["schema_version"]
	)
	checks["new_grass_excluded_from_reflection"] = garden.meadow.batches.all(
		func(b: MultiMeshInstance3D) -> bool:
			return (b.layers & PondReflections.REFLECTION_LAYER) == 0
	)
	var report: Dictionary = {
		"checks": checks,
		"passed": false,
		"viewport": [1920, 1080],
		"wind_pixel_difference": wind_difference,
		"reduced_pixel_difference": reduced_difference,
		"pixel_controls_taa": false,
		"representative_views_taa": true,
		"weather_trajectory": weather_trajectory,
		"exports": exported,
		"new_grass_instances": garden.meadow.visible_count(),
		"new_grass_batches": garden.meadow.batches.size(),
		"capacity_benchmark": false,
		"edit_latency_verified": false,
		"ui_input": "actual viewport GUI press/release; own-viewport routing for library dialog"
	}
	garden.exit_photo()
	await _settle()
	await _click(garden.grass_toolbar.get_child(1))
	checks["unsaved_return_requires_decision"] = garden.hud.decision.visible
	await _click(_button(garden.hud.decision, "放弃修改并继续"))
	deadline = Time.get_ticks_msec() + 30000
	while (
		not (current_scene is PainterlyGrassLab and current_scene.loaded)
		and Time.get_ticks_msec() < deadline
	):
		await process_frame
	checks["return_to_lab_real_gui"] = current_scene is PainterlyGrassLab and current_scene.loaded
	print("G3_PRE_NAV_CHECKS ", JSON.stringify(checks))
	assert(checks["return_to_lab_real_gui"])
	var lab: PainterlyGrassLab = current_scene
	await _click(lab.find_child("OpenGarden", true, false) as Button)
	deadline = Time.get_ticks_msec() + 60000
	while (
		not (current_scene is PainterlyGrassGarden and current_scene.garden_ready)
		and Time.get_ticks_msec() < deadline
	):
		await process_frame
	checks["lab_to_garden_real_gui"] = (
		current_scene is PainterlyGrassGarden and current_scene.garden_ready
	)
	assert(checks["lab_to_garden_real_gui"])
	garden = current_scene
	checks["one_preview_world"] = root.get_child_count() == 1
	report["passed"] = not checks.values().has(false)
	var file: FileAccess = FileAccess.open(folder.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	garden.seasonal_music.shutdown()
	garden.soundscape.shutdown()
	await SceneShutdown.wait_wallclock(self, 0.4)
	await SceneShutdown.release_scene(garden)
	for i: int in 8:
		await process_frame
	quit(0 if report["passed"] else 1)
