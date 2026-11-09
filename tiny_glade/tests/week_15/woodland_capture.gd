extends SceneTree
## Capture the same editable scene and camera presented by F5. Never open player slots.

const FOLDER: String = "res://reports/week_15/woodland"
var garden: ProductionLandscapePlayground
var checks: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


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
		await _capture("editor")
		garden.hud.hide()
		await _capture("spring")
		_check("daylight porch lantern rests", garden.lanterns.active_ids.is_empty())
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
			await _capture("walk")
		garden.exit_photo()
		_check("orbit restored", not garden.walk_controller.active and not garden.photo_active)
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
