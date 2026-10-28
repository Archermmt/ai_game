extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var seconds: int = 30
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--walk-seconds="):
			seconds = argument.trim_prefix("--walk-seconds=").to_int()
	assert(seconds in [30, 60])
	var output: String = OS.get_cmdline_user_args()[-1]
	var capture: bool = "--baseline-capture" in OS.get_cmdline_user_args()
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
	var history: int = world.session.history_count()
	var trajectory: Array[Dictionary] = []
	if capture:
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(output.get_basename() + "_start.png") == OK)
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_W
	key.keycode = KEY_W
	key.pressed = true
	world.walk_controller.handle(key)
	var transition: bool = "--climate-cycle" in OS.get_cmdline_user_args()
	var visible_types: int = 0
	var start: int = Time.get_ticks_usec()
	var previous: int = start
	var intervals: Array[float] = []
	var start_foot: Vector3 = world.walk_controller.feet
	while Time.get_ticks_usec() - start < seconds * 1000000:
		await process_frame
		if transition:
			var index: int = int((Time.get_ticks_usec() - start) / 6000000) % 3
			world.calendar.weather = ["storm", "blizzard", "duststorm"][index]
			world.calendar.month = 1 if index == 1 else 7
		visible_types = maxi(
			visible_types,
			(
				int(world.atmosphere.rain.visible)
				+ int(world.atmosphere.snow.visible)
				+ int(world.atmosphere.dust.visible)
			)
		)
		var now: int = Time.get_ticks_usec()
		var delta: float = float(now - previous) / 1000000
		intervals.append(delta * 1000)
		previous = now
		world.walk_controller.look(Vector2(delta * 0.3, 0))
		if capture and int((now - start) / 1000000) >= trajectory.size():
			trajectory.append(
				{
					"elapsed_ms": float(now - start) / 1000,
					"feet":
					[
						world.walk_controller.feet.x,
						world.walk_controller.feet.y,
						world.walk_controller.feet.z
					]
				}
			)
	var sorted: Array[float] = intervals.duplicate()
	sorted.sort()
	var report: Dictionary = {
		"requested_seconds": seconds,
		"layout": "capacity" if "--w09-stress" in OS.get_cmdline_user_args() else "demo",
		"buildings": source["buildings"].size(),
		"instances": source["instances"].size(),
		"world_seed": source["world_seed"],
		"source_sha256": JSON.stringify(source).sha256_text(),
		"grass_density": world.meadow.density,
		"grass_total": world.meadow.total,
		"viewport_size": [root.get_texture().get_width(), root.get_texture().get_height()],
		"trajectory": trajectory,
		"climate_transitions": transition,
		"max_visible_weather_types": visible_types,
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
		"history_unchanged": world.session.history_count() == history,
		"reflections": world.pond_reflections.captures
	}
	if capture:
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(output.get_basename() + "_end.png") == OK)
	var file: FileAccess = FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	world.exit_photo()
	world.soundscape.shutdown()
	await SceneShutdown.wait_wallclock(self, 0.4)
	await SceneShutdown.release_scene(world)
	for i: int in range(8):
		await process_frame
	quit()
