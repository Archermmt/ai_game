extends SceneTree
## Fixed analytic camera trajectory, identical TerrainField/Terrain3D, one renderer/process.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var seconds: int = 60
	var weather: String = "clear"
	var density: float = 0.45
	var output: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--g4-seconds="):
			seconds = argument.trim_prefix("--g4-seconds=").to_int()
		if argument.begins_with("--g4-weather="):
			weather = argument.trim_prefix("--g4-weather=")
		if argument.begins_with("--g4-density="):
			density = argument.trim_prefix("--g4-density=").to_float()
		if argument.begins_with("--g4-output="):
			output = argument.trim_prefix("--g4-output=")
	assert(seconds == 60 and not output.is_empty())
	assert(weather in ["clear", "storm", "blizzard", "duststorm"])
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var garden: Variant = (load("res://app/grass_capacity.tscn") as PackedScene).instantiate()
	root.add_child(garden)
	current_scene = garden
	var deadline: int = Time.get_ticks_msec() + 120000
	while (
		not garden.landscape_ready
		and not garden.landscape_failed
		and Time.get_ticks_msec() < deadline
	):
		await process_frame
	assert(garden.landscape_ready and not garden.landscape_failed)
	assert(garden.document.state["buildings"].size() == 24)
	assert(garden.document.state["instances"].size() == 1000)
	assert((garden.meadow is ProductionGrassRenderer) == (not garden.legacy_comparison))
	garden.set_capacity_density(density)
	garden.set_capacity_weather(["clear", "storm", "blizzard", "duststorm"].find(weather))
	garden.atmosphere.blend.advance(18, garden.calendar.sample())
	garden.atmosphere.update(0, garden.calendar.sample())
	await process_frame
	RenderingServer.force_draw(false)
	assert(
		Rect2(Vector2.ZERO, Vector2(root.size)).encloses(garden.capacity_panel.get_global_rect())
	)
	assert(root.get_texture().get_image().save_png(output.get_basename() + "_ui.png") == OK)
	garden.hud.hide()
	garden.camera_rig.camera.attributes = null
	garden.camera_rig.distance = 48
	garden.camera_rig.pitch = 0.72
	garden.camera_rig.target = Vector3.ZERO
	garden.camera_rig.yaw = 0.4
	garden.camera_rig.refresh()
	await SceneShutdown.wait_wallclock(self, 5)
	var source: Dictionary = garden.document.snapshot()
	var history: int = garden.session.history_count()
	var intervals: Array[float] = []
	var trajectory: Array[Dictionary] = []
	RenderingServer.force_draw(false)
	assert(root.get_texture().get_image().save_png(output.get_basename() + "_start.png") == OK)
	var start: int = Time.get_ticks_usec()
	var previous: int = start
	while Time.get_ticks_usec() - start < seconds * 1000000:
		await process_frame
		var now: int = Time.get_ticks_usec()
		intervals.append(float(now - previous) / 1000.0)
		previous = now
		var t: float = float(now - start) / 1000000.0
		garden.camera_rig.yaw = 0.4 + t * 0.12
		garden.camera_rig.target = Vector3(sin(t * 0.1) * 6, 0, cos(t * 0.1) * 6)
		garden.camera_rig.refresh()
		if int(t) >= trajectory.size():
			trajectory.append(
				{"seconds": t, "yaw": garden.camera_rig.yaw, "target": garden.camera_rig.target}
			)
	var sorted: Array[float] = intervals.duplicate()
	sorted.sort()
	RenderingServer.force_draw(false)
	assert(root.get_texture().get_image().save_png(output.get_basename() + "_end.png") == OK)
	var report: Dictionary = {
		"renderer": "legacy" if garden.legacy_comparison else "valley",
		"terrain_renderer": garden.landscape_terrain.terrain.get_class(),
		"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"source_sha256": JSON.stringify(source).sha256_text(),
		"world_seed": source["world_seed"],
		"buildings": source["buildings"].size(),
		"instances": source["instances"].size(),
		"weather": garden.calendar.weather,
		"season": garden.calendar.sample()["season"],
		"weather_blend_age": garden.atmosphere.blend.age,
		"grass_density": garden.meadow.density,
		"grass_visible": garden.meadow.visible_count(),
		"grass_total": garden.meadow.total,
		"grass_batches": garden.meadow.batches.size(),
		"msaa": root.msaa_3d,
		"taa": root.use_taa,
		"vsync_mode": DisplayServer.window_get_vsync_mode(),
		"viewport_size": [root.get_texture().get_width(), root.get_texture().get_height()],
		"frames": intervals.size(),
		"duration_ms": float(previous - start) / 1000.0,
		"p50_frame_ms": sorted[ceili(sorted.size() * 0.5) - 1],
		"p95_frame_ms": sorted[ceili(sorted.size() * 0.95) - 1],
		"p99_frame_ms": sorted[ceili(sorted.size() * 0.99) - 1],
		"max_frame_ms": sorted[-1],
		"frame_intervals_ms": intervals,
		"trajectory": trajectory,
		"source_unchanged": garden.document.snapshot() == source,
		"history_unchanged": garden.session.history_count() == history,
		"gpu_timing_ms": null,
		"draw_calls":
		RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME
		),
		"primitives":
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	}
	var file: FileAccess = FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	garden.soundscape.shutdown()
	await SceneShutdown.wait_wallclock(self, 0.4)
	await SceneShutdown.release_scene(garden)
	quit()
