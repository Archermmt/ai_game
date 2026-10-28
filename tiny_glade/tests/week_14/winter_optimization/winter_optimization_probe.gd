extends SceneTree
## Compare actual pixels with only the invisible-grass fast path toggled.

const OUT: String = "res://reports/week_14/winter_optimization"
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


func _significant_pixels(a: Image, b: Image) -> float:
	var x: PackedByteArray = a.get_data()
	var y: PackedByteArray = b.get_data()
	assert(a.get_format() in [Image.FORMAT_RGBA8, Image.FORMAT_RGB8])
	var stride: int = 4 if a.get_format() == Image.FORMAT_RGBA8 else 3
	var changed: int = 0
	for at: int in range(0, x.size(), stride):
		var largest: int = 0
		for channel: int in 3:
			largest = maxi(largest, absi(x[at + channel] - y[at + channel]))
		changed += int(largest > 8)
	return float(changed) / (a.get_width() * a.get_height())


func _pixels_passed() -> bool:
	if rows.size() != 36:
		return false
	for row: Dictionary in rows:
		if row["difference"] > row["noise"] + 0.00025 or row["significant_fraction"] > 0.003:
			return false
	return true


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
	garden.camera_rig.camera.attributes = null
	var source: Dictionary = garden.document.snapshot()
	var history: int = garden.session.history_count()
	var instances: int = garden.meadow.total
	var cap_count: int = garden.snow_cover.cap_count
	for distance: float in [8.0, 28.0, 48.0]:
		garden.camera_rig.distance = distance
		garden.camera_rig.pitch = 0.2 if distance == 8.0 else 0.72
		garden.camera_rig.target = Vector3.ZERO
		garden.camera_rig.refresh()
		for cover: float in [0.0, 0.4, 0.65, 0.899, 0.9, 0.98]:
			RenderingServer.global_shader_parameter_set("living_snow", cover)
			garden.snow_cover.set_batching_enabled(false)
			garden.snow_cover.set_opaque_enabled(false)
			garden.snow_cover.sync(cover)
			garden.meadow.set_snow_cover(cover)
			garden.meadow.set_floor_culling_enabled(false)
			var reference: Image = await _frames()
			var repeated: Image = await _frames()
			var noise: float = _delta(reference, repeated)
			for opaque: bool in [false, true]:
				garden.snow_cover.set_batching_enabled(true)
				garden.snow_cover.set_opaque_enabled(opaque)
				garden.meadow.set_floor_culling_enabled(true)
				var optimized: Image = await _frames()
				var difference: float = _delta(repeated, optimized)
				var significant: float = _significant_pixels(repeated, optimized)
				rows.append(
					{
						"distance": distance,
						"cover": cover,
						"opaque": opaque,
						"noise": noise,
						"difference": difference,
						"significant_fraction": significant,
						"views": garden.snow_cover._views.size()
					}
				)
				if cover == 0.98 and distance == 48.0:
					assert(reference.save_png(OUT.path_join("before.png")) == OK)
					assert(
						(
							optimized.save_png(
								OUT.path_join("opaque.png" if opaque else "batch.png")
							)
							== OK
						)
					)
			assert(garden.snow_cover.cap_count == cap_count)
			var actual: Array[Transform3D] = []
			for view: GeometryInstance3D in garden.snow_cover._views:
				if view is MultiMeshInstance3D:
					for index: int in view.multimesh.instance_count:
						actual.append(view.transform * view.multimesh.get_instance_transform(index))
				else:
					actual.append(view.transform)
			assert(actual.size() == cap_count)
			for record: Dictionary in garden.snow_cover._records:
				assert(record["pose"] in actual, "Snow instance transform changed")
	assert(garden.document.snapshot() == source and garden.session.history_count() == history)
	assert(garden.meadow.total == instances)
	var result: Dictionary = {
		"passed": _pixels_passed(),
		"comparisons": rows,
		"cap_count": cap_count,
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
	quit(0 if result["passed"] else 1)
