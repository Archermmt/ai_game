extends SceneTree
## Diagnostic ablations only. No shipping quality changes and no G4 sign-off.

const OUT: String = "res://reports/week_14/winter_cost"
const MODES: Array[String] = ["full", "no_caps", "no_clouds", "no_grass", "no_snowfall", "all_off"]
var garden: Variant
var snow_gate: Node3D
var rows: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _busy() -> bool:
	return (
		garden.queue.is_busy()
		or garden.stage.is_busy()
		or garden.meadow.is_busy()
		or garden.landscape_terrain.is_busy()
		or garden.snow_cover.is_busy()
	)


func _mode(mode: String) -> void:
	garden.set_plugin_clouds(mode not in ["no_clouds", "all_off"])
	garden.meadow.visible = mode not in ["no_grass", "all_off"]
	snow_gate.visible = mode not in ["no_snowfall", "all_off"]
	for view: MeshInstance3D in garden.snow_cover._views:
		view.visible = mode not in ["no_caps", "all_off"]
	garden.pond_reflections.request_update()


func _camera(t: float) -> void:
	# Traverse the original 60s orbit in 10s; diagnostic, not the acceptance protocol.
	garden.camera_rig.yaw = 0.4 + t * 0.72
	garden.camera_rig.target = Vector3(sin(t * 0.6) * 6, 0, cos(t * 0.6) * 6)
	garden.camera_rig.refresh()


func _sample(mode: String, repeat: int) -> void:
	_mode(mode)
	_camera(0)
	await SceneShutdown.wait_wallclock(self, 3)
	var intervals: Array[float] = []
	var start: int = Time.get_ticks_usec()
	var previous: int = start
	while Time.get_ticks_usec() - start < 10000000:
		await process_frame
		var now: int = Time.get_ticks_usec()
		intervals.append(float(now - previous) / 1000.0)
		previous = now
		_camera(float(now - start) / 1000000.0)
	var ordered: Array[float] = intervals.duplicate()
	ordered.sort()
	assert(intervals.size() >= 100)
	rows.append(
		{
			"mode": mode,
			"repeat": repeat,
			"p50_ms": ordered[ceili(ordered.size() * 0.5) - 1],
			"p95_ms": ordered[ceili(ordered.size() * 0.95) - 1],
			"p99_ms": ordered[ceili(ordered.size() * 0.99) - 1],
			"duration_ms": float(previous - start) / 1000.0,
			"intervals_ms": intervals,
			"draw_calls":
			RenderingServer.get_rendering_info(
				RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME
			),
			"primitives":
			RenderingServer.get_rendering_info(
				RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME
			)
		}
	)
	print("WINTER_COST ", mode, " repeat ", repeat, " p95=", rows[-1]["p95_ms"])


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
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
	while _busy() and Time.get_ticks_msec() < deadline:
		await process_frame
	assert(not _busy() and garden.snow_cover._views.size() > 1000)
	assert(garden.meadow is ProductionGrassRenderer and garden.cloud_adapter.ready_for_clouds)
	assert(root.msaa_3d == Viewport.MSAA_DISABLED and root.use_taa)
	var source: Dictionary = garden.document.snapshot()
	var history: int = garden.session.history_count()
	garden._freeze_photo(true)
	garden.hud.hide()
	garden.camera_rig.camera.attributes = null
	garden.camera_rig.distance = 48
	garden.camera_rig.pitch = 0.72
	snow_gate = Node3D.new()
	garden.atmosphere.add_child(snow_gate)
	garden.atmosphere.snow.reparent(snow_gate, false)
	for repeat: int in range(1, 4):
		var order: Array[String] = MODES.duplicate()
		if repeat == 2:
			order.reverse()
		for mode: String in order:
			await _sample(mode, repeat)
	_mode("full")
	assert(garden.document.snapshot() == source and garden.session.history_count() == history)
	var result: Dictionary = {
		"rows": rows,
		"source_unchanged": true,
		"history_unchanged": true,
		"driver": RenderingServer.get_current_rendering_driver_name(),
		"viewport": [root.size.x, root.size.y],
		"vsync": DisplayServer.window_get_vsync_mode(),
		"max_fps": Engine.max_fps,
		"snow_views": garden.snow_cover._views.size(),
		"snow_bakes": garden.snow_cover.baked_count,
		"g4_accepted": false,
		"gpu_timing_available": false
	}
	var file: FileAccess = FileAccess.open(OUT.path_join("native.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	garden.soundscape.shutdown()
	await SceneShutdown.release_scene(garden)
	quit()
