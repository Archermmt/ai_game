extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var start: int = Time.get_ticks_usec()
	var previous: int = start
	var world: Node3D = load("res://app/living_root.tscn").instantiate()
	world.qa_mode = true
	root.add_child(world)
	world.calendar.speed = 0
	world.calendar.month = 7
	world.calendar.weather = "clear"
	world.calendar.minute_of_day = 720
	var source: Dictionary = world.document.snapshot()
	var intervals: Array[float] = []
	while Time.get_ticks_usec() - start < 30000000:
		await process_frame
		var now: int = Time.get_ticks_usec()
		var delta: float = float(now - previous) / 1000000.0
		intervals.append(delta * 1000)
		previous = now
		world.camera_rig.yaw += minf(delta, 0.1) * 0.3
		world.camera_rig.refresh()
	var sorted: Array[float] = intervals.duplicate()
	sorted.sort()
	var path: String = OS.get_cmdline_user_args()[-1]
	var output: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	output.store_string(
		JSON.stringify(
			{
				"frames": intervals.size(),
				"p95_frame_ms": sorted[ceili(sorted.size() * 0.95) - 1],
				"max_frame_ms": sorted[-1],
				"frame_intervals_ms": intervals,
				"captures": world.pond_reflections.captures,
				"duration_ms": float(previous - start) / 1000,
				"source_unchanged": world.document.state == source,
				"renderer": RenderingServer.get_current_rendering_method()
			},
			"\t"
		)
	)
	output.close()
	world.soundscape.shutdown()
	await SceneShutdown.wait_wallclock(self, 0.4)
	await SceneShutdown.release_scene(world)
	for i: int in range(8):
		await process_frame
	quit()
