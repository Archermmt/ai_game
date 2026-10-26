extends SceneTree
## Real F5 scene: compare seasonal ground and grass pixels at one fixed camera.

var garden: Variant
var folder: String = "res://reports/week_14/winter_cover"
var checks: Dictionary = {}
var images: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _climate(month: int, weather: String) -> void:
	garden.calendar.month = month
	garden.calendar.weather = weather
	garden.calendar.minute_of_day = 720
	garden.atmosphere.blend.advance(18, garden.calendar.sample())
	garden.atmosphere.update(0, garden.calendar.sample())


func _capture(label: String) -> Image:
	for i: int in 12:
		await process_frame
		RenderingServer.force_draw(false)
	var picture: Image = root.get_texture().get_image()
	var path: String = folder.path_join(label + ".png")
	checks[label + " saved"] = picture.save_png(path) == OK
	images[label] = path
	return picture


func _metrics(grass: Image, ground: Image) -> Dictionary:
	var changed: int = 0
	var white: int = 0
	var green: int = 0
	var count: int = 0
	for y: int in range(200, 800, 2):
		for x: int in range(240, 1200, 2):
			var a: Color = grass.get_pixel(x, y)
			var b: Color = ground.get_pixel(x, y)
			var difference: float = absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
			changed += int(difference > 0.06)
			white += int(minf(a.r, minf(a.g, a.b)) > 0.45 and absf(a.r - a.b) < 0.16)
			green += int(a.g > a.r * 1.12 and a.g > a.b * 1.12)
			count += 1
	return {
		"grass_pixel_fraction": float(changed) / count,
		"snow_pixel_fraction": float(white) / count,
		"green_pixel_fraction": float(green) / count
	}


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1440, 900)
	root.content_scale_size = root.size
	garden = (load("res://app/living_root.tscn") as PackedScene).instantiate()
	garden.qa_mode = true
	root.add_child(garden)
	current_scene = garden
	garden.calendar.speed = 0
	garden.calendar.automatic_weather = false
	var deadline: int = Time.get_ticks_msec() + 120000
	while (
		not garden.landscape_ready
		and not garden.landscape_failed
		and Time.get_ticks_msec() < deadline
	):
		await process_frame
	checks["actual production scene ready"] = garden.landscape_ready and not garden.landscape_failed
	if not checks["actual production scene ready"]:
		await _finish({})
		return
	garden._freeze_photo(true)
	garden.hud.hide()
	root.use_taa = false
	garden.camera_rig.target = Vector3(12, 0, 12)
	garden.camera_rig.distance = 12
	garden.camera_rig.pitch = 1.1
	garden.camera_rig.refresh()
	garden.camera_rig.camera.attributes = null
	var source: Dictionary = garden.document.snapshot()
	var versions: Dictionary = garden.meadow._published_versions.duplicate(true)
	var terrain_signature: String = garden.landscape_terrain.published_signature
	var samples: Dictionary = {}
	for climate: Array in [
		[7, "clear", "summer"],
		[1, "clear", "winter_clear"],
		[1, "snow", "winter_snow"],
		[4, "clear", "spring"]
	]:
		_climate(climate[0], climate[1])
		garden.meadow.show()
		var with_grass: Image = await _capture(climate[2])
		garden.meadow.hide()
		var ground: Image = await _capture(climate[2] + "_ground")
		samples[climate[2]] = _metrics(with_grass, ground)
		garden.meadow.show()
		checks[climate[2] + " preserves source"] = garden.document.snapshot() == source
		checks[climate[2] + " preserves grass geometry"] = (
			garden.meadow._published_versions == versions
		)
		checks[climate[2] + " preserves terrain geometry"] = (
			garden.landscape_terrain.published_signature == terrain_signature
		)
	for label: String in ["winter_clear", "winter_snow"]:
		checks[label + " continuous snow"] = samples[label]["snow_pixel_fraction"] > 0.65
		checks[label + " sparse grass"] = (
			samples[label]["grass_pixel_fraction"]
			< samples["summer"]["grass_pixel_fraction"] * 0.25
		)
		checks[label + " some remaining tufts"] = samples[label]["grass_pixel_fraction"] > 0.001
		checks[label + " green buried"] = samples[label]["green_pixel_fraction"] < 0.08
	checks["spring regrows grass"] = (
		samples["spring"]["grass_pixel_fraction"] > samples["summer"]["grass_pixel_fraction"] * 0.8
	)
	checks["spring melts snow"] = samples["spring"]["snow_pixel_fraction"] < 0.25
	await _finish(samples)


func _finish(samples: Dictionary) -> void:
	var passed: bool = checks.values().all(func(value: bool) -> bool: return value)
	if is_instance_valid(garden):
		garden.soundscape.shutdown()
		await SceneShutdown.wait_wallclock(self, 0.4)
		await SceneShutdown.release_scene(garden)
	var file: FileAccess = FileAccess.open(folder.path_join("result.json"), FileAccess.WRITE)
	file.store_string(
		JSON.stringify(
			{
				"passed": passed,
				"checks": checks,
				"samples": samples,
				"images": images,
				"rendering_driver": RenderingServer.get_current_rendering_driver_name()
			},
			"\t"
		)
	)
	file.close()
	quit(0 if passed or "--baseline" in OS.get_cmdline_user_args() else 1)
