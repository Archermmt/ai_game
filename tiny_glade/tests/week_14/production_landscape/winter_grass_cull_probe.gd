extends SceneTree
## Compare actual pixels with only the invisible-grass fast path toggled.

const OUT: String = "res://reports/week_14/winter_grass_cull"
var garden: Variant
var rows: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _frames() -> Image:
	for frame: int in 12:
		await process_frame
		RenderingServer.force_draw(false)
	return root.get_texture().get_image()


func _delta(a: Image, b: Image) -> float:
	var x: PackedByteArray = a.get_data()
	var y: PackedByteArray = b.get_data()
	assert(x.size() == y.size())
	var total: float = 0.0
	for index: int in x.size():
		total += absf(float(x[index]) - float(y[index]))
	return total / (255.0 * x.size())


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	root.size = Vector2i(1280, 720)
	garden = (load("res://app/grass_capacity.tscn") as PackedScene).instantiate()
	root.add_child(garden)
	current_scene = garden
	var deadline: int = Time.get_ticks_msec() + 180000
	while not garden.landscape_ready and Time.get_ticks_msec() < deadline:
		await process_frame
	assert(garden.landscape_ready)
	garden.set_capacity_weather(2)
	garden.atmosphere.blend.advance(18, garden.calendar.sample())
	garden.atmosphere.update(0, garden.calendar.sample())
	await process_frame
	await process_frame
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
		await process_frame
	assert(not garden.snow_cover.is_busy() and garden.snow_cover.baked_count > 0)
	garden._freeze_photo(true)
	garden.set_plugin_clouds(false)
	garden.set_process(false)
	garden.hud.hide()
	root.use_taa = false
	var source: Dictionary = garden.document.snapshot()
	var history: int = garden.session.history_count()
	var instances: int = garden.meadow.total
	for near: bool in [false, true]:
		garden.camera_rig.distance = 8 if near else 48
		garden.camera_rig.pitch = 0.2 if near else 0.72
		garden.camera_rig.target = Vector3.ZERO
		garden.camera_rig.refresh()
		for cover: float in [0.0, 0.4, 0.65, 0.98]:
			RenderingServer.global_shader_parameter_set("living_snow", cover)
			garden.meadow.material.set_shader_parameter("winter_cull_enabled", false)
			var reference: Image = await _frames()
			var repeated: Image = await _frames()
			garden.meadow.material.set_shader_parameter("winter_cull_enabled", true)
			var optimized: Image = await _frames()
			var noise: float = _delta(reference, repeated)
			var difference: float = _delta(repeated, optimized)
			rows.append({"near": near, "cover": cover, "noise": noise, "difference": difference})
			assert(difference <= noise + 0.00001, "Winter optimization changed visible grass")
			if cover == 0.98 and not near:
				assert(reference.save_png(OUT.path_join("before.png")) == OK)
				assert(optimized.save_png(OUT.path_join("after.png")) == OK)
	assert(garden.document.snapshot() == source and garden.session.history_count() == history)
	assert(garden.meadow.total == instances)
	var result: Dictionary = {
		"passed": true,
		"comparisons": rows,
		"source_unchanged": true,
		"instance_count_unchanged": true,
		"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"taa": root.use_taa,
		"clouds_disabled_for_pixel_proof": true
	}
	var file: FileAccess = FileAccess.open(OUT.path_join("result.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	garden.soundscape.shutdown()
	await SceneShutdown.release_scene(garden)
	quit()
