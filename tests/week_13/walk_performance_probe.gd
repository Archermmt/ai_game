extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world: Node3D = load("res://app/living_root.tscn").instantiate()
	world.qa_mode = true
	root.add_child(world)
	var deadline: int = Time.get_ticks_msec() + 15000
	while (
		(world.queue.is_busy() or world.stage.is_busy() or world.meadow.is_busy())
		and Time.get_ticks_msec() < deadline
	):
		await process_frame
	world.calendar.month = 7
	world.calendar.weather = "clear"
	world.calendar.speed = 0
	world.calendar.minute_of_day = 720
	assert(world.enter_photo() and world.start_walk())
	world.hud.photo_panel.hide()
	var source: Dictionary = world.document.snapshot()
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_W
	key.keycode = KEY_W
	key.pressed = true
	world.walk_controller.handle(key)
	var start: int = Time.get_ticks_usec()
	var previous: int = start
	var intervals: Array[float] = []
	var start_foot: Vector3 = world.walk_controller.feet
	while Time.get_ticks_usec() - start < 30000000:
		await process_frame
		var now: int = Time.get_ticks_usec()
		var delta: float = float(now - previous) / 1000000
		intervals.append(delta * 1000)
		previous = now
		world.walk_controller.look(Vector2(delta * 0.3, 0))
	var sorted: Array[float] = intervals.duplicate()
	sorted.sort()
	var report: Dictionary = {
		"frames": intervals.size(),
		"p95_frame_ms": sorted[ceili(sorted.size() * 0.95) - 1],
		"max_frame_ms": sorted[-1],
		"frame_intervals_ms": intervals,
		"duration_ms": float(previous - start) / 1000,
		"position": world.walk_controller.feet,
		"distance_from_start": world.walk_controller.feet.distance_to(start_foot),
		"safe_support":
		world.walk_controller.surface.can_stand(
			Vector2(world.walk_controller.feet.x, world.walk_controller.feet.z)
		),
		"source_unchanged": world.document.state == source,
		"reflections": world.pond_reflections.captures
	}
	var file: FileAccess = FileAccess.open(OS.get_cmdline_user_args()[-1], FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	world.exit_photo()
	world.soundscape.shutdown()
	await SceneShutdown.wait_wallclock(self, 0.4)
	await SceneShutdown.release_scene(world)
	for i: int in range(8):
		await process_frame
	quit()
