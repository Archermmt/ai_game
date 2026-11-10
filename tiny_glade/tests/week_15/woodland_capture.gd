extends SceneTree
## Capture the same editable scene and camera presented by F5. Never open player slots.

const FOLDER: String = "res://reports/week_15/woodland"
var garden: ProductionLandscapePlayground
var checks: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _process(_delta: float) -> bool:
	# An occluded native window must still deliver the exporter's post-draw frames.
	if is_instance_valid(garden) and garden.photography != null and garden.photography.busy:
		RenderingServer.force_draw(false)
	return false


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(FOLDER)
	root.size = Vector2i(1600, 900)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	garden = (
		(load(ProjectSettings.get_setting("application/run/main_scene")) as PackedScene)
		. instantiate()
	)
	garden.qa_mode = true
	root.add_child(garden)
	current_scene = garden
	garden.calendar.speed = 0
	garden.calendar.automatic_weather = false
	var deadline: int = Time.get_ticks_msec() + 60000
	while (
		not garden.landscape_ready
		and not garden.landscape_failed
		and Time.get_ticks_msec() < deadline
	):
		await process_frame
	_check(
		"formal garden ready",
		garden.landscape_ready and garden.document.state["world_seed"] == "woodland-clearing"
	)
	if garden.landscape_ready:
		var source: Dictionary = garden.document.snapshot()
		_check("same source passes edit rules", WorldDocument.validate(source).is_empty())
		_check("procedural pond follows shore", garden._pond_bank.has_node("FloatingLeaves"))
		_check("native cloud renderer ready", garden.cloud_adapter.ready_for_clouds)
		if garden.cloud_adapter.ready_for_clouds:
			var clouds: SunshineCloudsGD = garden.cloud_adapter.clouds
			for key: String in [
				"dither_noise",
				"height_gradient",
				"extra_large_noise_patterns",
				"large_scale_noise",
				"medium_scale_noise",
				"small_scale_noise",
				"curl_noise"
			]:
				_check(
					"authored cloud input " + key,
					clouds.get(key).resource_path.begins_with("res://assets/woodland/")
				)
		_climate(5, 10.5, "clear")
		var pointer: InputEventMouseMotion = InputEventMouseMotion.new()
		pointer.position = _screen_rect(garden.hud.calendar).position + Vector2(6, 6)
		pointer.global_position = pointer.position
		Input.parse_input_event(pointer)
		await _capture("editor")
		var environment: Environment = garden.world_environment.environment
		_check("daylight is side lit", absf(garden.sun.rotation.y - garden.camera_rig.yaw) > 1.0)
		_check(
			"main camera uses sky fill and AgX",
			(
				environment.tonemap_mode == Environment.TONE_MAPPER_AGX
				and environment.ambient_light_source == Environment.AMBIENT_SOURCE_SKY
			)
		)
		var reflected: Environment = garden.pond_reflections.camera.environment
		_check(
			"pond shares the sky and exposure",
			(
				reflected.sky == environment.sky
				and reflected.ambient_light_source == environment.ambient_light_source
				and is_equal_approx(reflected.tonemap_exposure, environment.tonemap_exposure)
			)
		)
		garden.hud.open_group("build")
		_check("build tray visible", garden.hud.quick.is_visible_in_tree())
		await _capture("build_tools")
		var choices: HFlowContainer = garden.hud.quick_choices
		_check("all building choices fit on one row", choices.get_line_count() == 1)
		garden.hud.open_group("light")
		_check("weather controls visible", garden.hud.weather_controls.is_visible_in_tree())
		await _capture("weather_controls")
		_check(
			"weather panel clears tool rail",
			not _screen_rect(garden.hud.weather_controls).intersects(_screen_rect(garden.hud._dock))
		)
		garden.hud.close_context()
		garden.hud.settings.popup_centered()
		_check("settings open", garden.hud.settings.visible)
		await _capture("settings")
		garden.hud.settings.hide()
		garden.hud.hide()
		await _capture("spring")
		var photo: Dictionary = await garden.photography.capture(
			garden.camera_rig.camera, Vector2i(1920, 1080), FOLDER.path_join("spring_export.png")
		)
		_check("production photography exports 1080p", photo.get("ok", false))
		_check("daylight porch lantern rests", garden.lanterns.active_ids.is_empty())
		garden._recommended_view(0)
		garden._freeze_photo(true)
		for hour: float in [6.5, 8.5, 10.5]:
			_climate(10, hour, "clear")
			await _capture("autumn_mist_" + str(int(hour)))
			if hour == 6.5:
				garden.set_process(false)
				var with_mist: Image = root.get_texture().get_image()
				garden.world_environment.environment.volumetric_fog_enabled = false
				garden.atmosphere.morning_fog.hide()
				await _capture("autumn_without_mist")
				var without_mist: Image = root.get_texture().get_image()
				var difference: float = 0.0
				for y: int in range(200, 800, 16):
					for x: int in range(100, 1500, 16):
						var delta: Color = with_mist.get_pixel(x, y) - without_mist.get_pixel(x, y)
						difference += absf(delta.r) + absf(delta.g) + absf(delta.b)
				_check("morning volume changes visible forest pixels", difference > 2.0)
				garden.set_process(true)
		_check("late morning disperses low mist", not garden.atmosphere.morning_fog.visible)
		_climate(1, 7.5, "clear")
		await _capture("winter_mist")
		_check(
			"winter dawn has ground mist",
			(
				garden.atmosphere.morning_fog.visible
				and garden.world_environment.environment.volumetric_fog_enabled
			)
		)
		garden._freeze_photo(false)
		garden._recommended_view(1)
		_climate(5, 17.85, "clear")
		await _capture("evening")
		_check(
			"automatic porch lantern warms the steps at dusk",
			not garden.lanterns.active_ids.is_empty()
		)
		garden._recommended_view(0)
		_climate(1, 11, "snow")
		await _capture("winter")
		_check(
			"winter snow cover",
			garden.atmosphere.blend.current["cover"] >= 0.95 and garden.atmosphere.snow.visible
		)
		_climate(5, 10.5, "clear")
		_check("photo entry", garden.enter_photo())
		_check("walk entry", garden.start_walk())
		if garden.walk_controller.active:
			garden.hud.hide()
			await _capture("walk")
			garden.hud.show()
			await _capture("walk_controls")
		garden.exit_photo()
		_check("orbit restored", not garden.walk_controller.active and not garden.photo_active)
		await _check_scaled_hud()
		_check("views leave editable state intact", source == garden.document.snapshot())
	var driver: String = RenderingServer.get_current_rendering_driver_name()
	_check("actual GPU", driver in ["metal", "vulkan"])
	var result: Dictionary = {
		"checks": checks, "passed": not checks.values().has(false), "driver": driver
	}
	var file: FileAccess = FileAccess.open(FOLDER.path_join("capture.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t") + "\n")
	file.close()
	garden.seasonal_music.shutdown()
	garden.soundscape.shutdown()
	await SceneShutdown.wait_wallclock(self, 0.4)
	await SceneShutdown.release_scene(garden)
	for i: int in 12:
		await process_frame
	print("WOODLAND CAPTURE ", result["passed"])
	quit(0 if result["passed"] else 1)


func _screen_rect(control: Control) -> Rect2:
	return control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)


func _check_scaled_hud() -> void:
	root.size = Vector2i(1280, 800)
	root.content_scale_size = root.size
	garden._preference_changed("ui_scale", 1.5)
	garden.hud.open_group("light")
	await _capture("scaled_weather")
	var bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(root.size))
	var panel: Rect2 = _screen_rect(garden.hud.weather_controls)
	var rail: Rect2 = _screen_rect(garden.hud._dock)
	_check("scaled weather panel fits game window", bounds.encloses(panel))
	_check("scaled tool rail fits game window", bounds.encloses(rail))
	_check("scaled calendar fits game window", bounds.encloses(_screen_rect(garden.hud.calendar)))
	_check("scaled weather panel clears tool rail", not panel.intersects(rail))
	_check(
		"scaled weather panel clears calendar",
		not panel.intersects(_screen_rect(garden.hud.calendar))
	)


func _climate(month: int, hour: float, weather: String) -> void:
	garden.calendar.month = month
	garden.calendar.minute_of_day = hour * 60
	garden.calendar.weather = weather
	var state: Dictionary = garden.calendar.sample()
	garden.atmosphere.blend.advance(0, state)
	garden.atmosphere.blend.advance(WeatherBlend.DURATION, state)
	garden.atmosphere.update(0, state)
	garden.hud.calendar.sync()


func _capture(label: String) -> void:
	for i: int in 18:
		await process_frame
		RenderingServer.force_draw(false)
	var frame: Image = root.get_texture().get_image()
	_check(
		label + " saved",
		(
			frame != null
			and frame.get_size() == root.size
			and frame.save_png(FOLDER.path_join(label + ".png")) == OK
		)
	)


func _check(label: String, result: bool) -> void:
	checks[label] = result
	if not result:
		push_error(label)
