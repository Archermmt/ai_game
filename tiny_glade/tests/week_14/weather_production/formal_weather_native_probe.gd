extends SceneTree

const OUT: String = "res://reports/weather_production"
var garden: ProductionLandscapePlayground
var checks: Dictionary = {}
var images: Array[String] = []
var measures: Dictionary = {}
var photo_buffers: Dictionary = {}


func _process(_delta: float) -> bool:
	if is_instance_valid(garden) and garden.photography != null and garden.photography.busy:
		for adapter: SunshineCloudAdapter in garden._cloud_views.values():
			if adapter.clouds != null and adapter.clouds.last_size.x > 1000:
				photo_buffers[str(adapter.clouds.get_instance_id())] = adapter.clouds.last_size
		RenderingServer.force_draw(false)
	return false


func _initialize() -> void:
	_run.call_deferred()


func _check(label: String, ok: bool) -> void:
	checks[label] = ok
	if not ok:
		push_error(label)


func _frames(count: int) -> void:
	for index: int in count:
		await process_frame
		RenderingServer.force_draw(false)


func _picture(name: String) -> Image:
	await _frames(16)
	var image: Image = root.get_texture().get_image()
	_check("capture " + name, image.save_png(OUT.path_join(name + ".png")) == OK)
	images.append(OUT.path_join(name + ".png"))
	return image


func _difference(a: Image, b: Image) -> float:
	var total: float = 0
	var samples: int = 0
	for y: int in range(0, a.get_height(), 4):
		for x: int in range(0, a.get_width(), 4):
			var delta: Color = a.get_pixel(x, y) - b.get_pixel(x, y)
			total += absf(delta.r) + absf(delta.g) + absf(delta.b)
			samples += 3
	return total / maxf(samples, 1)


func _reflection_image() -> Image:
	garden.pond_reflections.request_update()
	garden.pond_reflections.age = 1
	garden.pond_reflections.tick(0, garden.calendar.sample())
	await _frames(32)
	return garden.pond_reflections.viewport.get_texture().get_image()


func _multiview() -> void:
	await _frames(64)
	var baseline: Image = root.get_texture().get_image()
	var reflection_on: Image = await _reflection_image()
	_check(
		"reflection cloud buffer has native size",
		garden._cloud_views.values()[0].clouds.last_size == Vector2i(480, 270)
	)
	garden.set_plugin_clouds(false)
	var reflection_off: Image = await _reflection_image()
	var reflection_delta: float = _difference(reflection_on, reflection_off)
	measures["reflection_cloud_pixels"] = reflection_delta
	_check("real reflection image contains plugin clouds", reflection_delta > 0.002)
	_check("reflection captures actual updates", garden.pond_reflections.captures > 0)
	_check(
		"save reflection on", reflection_on.save_png(OUT.path_join("reflection_clouds.png")) == OK
	)
	_check(
		"save reflection off",
		reflection_off.save_png(OUT.path_join("reflection_original.png")) == OK
	)
	var camera: Camera3D = garden.camera_rig.camera
	var pose: Transform3D = camera.global_transform
	var original_path: String = OUT.path_join("photo_2k_original.png")
	var plugin_path: String = OUT.path_join("photo_2k_clouds.png")
	var first: Dictionary = await garden.photography.capture(
		camera, Vector2i(2560, 1440), original_path
	)
	garden.set_plugin_clouds(true)
	var second: Dictionary = await garden.photography.capture(
		camera, Vector2i(2560, 1440), plugin_path
	)
	var fhd: Dictionary = await garden.photography.capture(
		camera, Vector2i(1920, 1080), OUT.path_join("photo_1080_clouds.png")
	)
	_check("paired 2K exports succeed", first["ok"] and second["ok"])
	_check("1080p export succeeds", fhd["ok"])
	var photo_delta: float = _difference(
		Image.load_from_file(original_path), Image.load_from_file(plugin_path)
	)
	measures["photo_cloud_pixels"] = photo_delta
	_check("2K export renders cloud compositor", photo_delta > 0.002)
	_check(
		"photo effect had its own full render target",
		photo_buffers.size() >= 2 and photo_buffers.values().has(Vector2i(2560, 1440))
	)
	_check("photo camera effects released", garden._cloud_views.size() == 1)
	_check("main camera pose restored", camera.global_transform == pose)
	await _frames(64)
	var recovered: Image = root.get_texture().get_image()
	var recovery_delta: float = _difference(baseline, recovered)
	measures["after_photo_history_pixels"] = recovery_delta
	_check("main history survives independent reflection and photo views", recovery_delta < 0.0005)
	_check("main buffer size unchanged", garden.cloud_adapter.clouds.last_size == root.size)
	await _frames(32)
	_check(
		"frozen multi camera pixels stable",
		_difference(recovered, root.get_texture().get_image()) < 0.0001
	)
	garden._freeze_photo(false)
	await _frames(32)
	var motion: float = _difference(recovered, root.get_texture().get_image())
	measures["resumed_cloud_pixels"] = motion
	_check("clouds resume after freeze", motion > 0.00001)
	garden._freeze_photo(true)


func _settle_snow() -> void:
	var deadline: int = Time.get_ticks_msec() + 180000
	while (
		(
			garden.queue.is_busy()
			or garden.stage.is_busy()
			or garden.meadow.is_busy()
			or garden.landscape_terrain.is_busy()
			or garden.snow_cover.is_busy()
		)
		and Time.get_ticks_msec() < deadline
	):
		await _frames(1)
	_check("snow publication settles", not garden.snow_cover.is_busy())


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	root.size = Vector2i(1440, 900)
	garden = (load("res://app/living_root.tscn") as PackedScene).instantiate()
	garden.qa_mode = true
	root.add_child(garden)
	garden.saves.directory = "user://qa_weather_production/native/saves"
	garden.active_slot = -1
	var deadline: int = Time.get_ticks_msec() + 120000
	while (
		(not garden.landscape_ready or garden.queue.is_busy() or garden.stage.is_busy())
		and Time.get_ticks_msec() < deadline
	):
		await _frames(1)
	_check("main landscape ready", garden.landscape_ready)
	_check(
		"main camera owns cloud effect",
		garden.camera_rig.camera.compositor != null and garden.cloud_adapter.ready_for_clouds
	)
	_check("environment has no shared cloud history", garden.world_environment.compositor == null)
	_check(
		"reflection has independent cloud effect",
		(
			garden._cloud_views.size() == 1
			and garden.pond_reflections.camera.compositor != garden.camera_rig.camera.compositor
		)
	)
	garden.calendar.speed = 0
	garden.calendar.automatic_weather = false
	garden.calendar.month = 7
	garden.calendar.minute_of_day = 720
	garden.calendar.weather = "clear"
	garden.atmosphere.blend.advance(WeatherBlend.DURATION, garden.calendar.sample())
	garden._freeze_photo(true)
	garden.hud.hide()
	garden.camera_rig.camera.attributes = null
	garden.camera_rig.target = Vector3(0, 16, 0)
	garden.camera_rig.distance = 30
	garden.camera_rig.pitch = -0.20
	garden.camera_rig.yaw = 0.6
	garden.camera_rig.refresh()
	await _frames(32)
	await _picture("main_clouds_default_aa")
	root.use_taa = false
	await _picture("main_clouds")
	await _multiview()
	garden.calendar.month = 1
	garden.atmosphere.blend.advance(WeatherBlend.DURATION, garden.calendar.sample())
	await _frames(2)
	deadline = Time.get_ticks_msec() + 180000
	while garden.snow_cover.is_busy() and Time.get_ticks_msec() < deadline:
		await _frames(1)
	_check("snow jobs complete", not garden.snow_cover.is_busy())
	_check(
		"native terrain has snow display thickness",
		(
			float(
				garden.landscape_terrain.terrain.material.get_shader_param("production_snow_depth")
			)
			> 0.1
		)
	)
	var roofs: int = 0
	var nature: int = 0
	for view: MeshInstance3D in garden.snow_cover._views:
		roofs += int(view.get_meta("snow_kind") == "roof")
		nature += int(view.get_meta("snow_kind") == "nature")
	print("SNOW_CAPS roofs=", roofs, " nature=", nature, " bakes=", garden.snow_cover.baked_count)
	_check("all three roofs covered", roofs == 3)
	_check("trees and rocks covered", nature > 5)
	garden._recommended_view(1)
	await _picture("winter_garden")
	root.use_taa = true
	await _frames(32)
	await _picture("winter_garden_default_aa")
	root.use_taa = false
	garden.camera_rig.target = Vector3(0, 2.6, 0)
	garden.camera_rig.distance = 11
	garden.camera_rig.pitch = 0.20
	garden.camera_rig.yaw = 0.65
	garden.camera_rig.refresh()
	await _picture("winter_eaves")
	var terrain_material: Terrain3DMaterial = garden.landscape_terrain.terrain.material
	terrain_material.set_shader_param("production_snow_depth", 0.0)
	var no_depth: Image = await _picture("snow_depth_zero")
	terrain_material.set_shader_param("production_snow_depth", ProductionTerrainRenderer.SNOW_DEPTH)
	var raised: Image = await _picture("snow_depth_14cm")
	var displaced_pixels: float = _difference(no_depth, raised)
	measures["terrain_displacement_pixels"] = displaced_pixels
	_check("terrain snow displacement changes actual pixels", displaced_pixels > 0.00001)
	var before_edit: Dictionary = garden.document.snapshot()
	var candidate: Dictionary = before_edit.duplicate(true)
	candidate["buildings"][0]["size"][1] += 0.3
	garden._submit_async(candidate, "Snow roof publication regression")
	await _settle_snow()
	_check(
		"snow follows committed roof edit",
		(
			garden.snow_cover._snapshot["buildings"][0]["size"][1]
			== candidate["buildings"][0]["size"][1]
		)
	)
	garden._on_action(&"undo")
	await _settle_snow()
	_check(
		"snow follows undo", garden.snow_cover._snapshot["buildings"] == before_edit["buildings"]
	)
	var source: Dictionary = garden.document.snapshot()
	garden.calendar.month = 4
	garden.atmosphere.blend.advance(WeatherBlend.DURATION, garden.calendar.sample())
	await _frames(3)
	_check("spring hides caps", not garden.snow_cover.visible)
	_check("snow is display only", garden.document.snapshot() == source)
	var passed: bool = not checks.is_empty() and not checks.values().has(false)
	var data: Dictionary = {
		"passed": passed,
		"checks": checks,
		"images": images,
		"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"performance_gate_run": false,
		"measurements": measures,
		"camera_histories_independent": true,
		"geometric_object_snow": true,
		"terrain_snow_displacement_m": ProductionTerrainRenderer.SNOW_DEPTH
	}
	FileAccess.open(OUT.path_join("result.json"), FileAccess.WRITE).store_string(
		JSON.stringify(data, "\t")
	)
	garden.seasonal_music.shutdown()
	garden.soundscape.shutdown()
	await SceneShutdown.wait_wallclock(self, 0.4)
	await SceneShutdown.release_scene(garden)
	await _frames(8)
	quit(0 if passed else 1)
