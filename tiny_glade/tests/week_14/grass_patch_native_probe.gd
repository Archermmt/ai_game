extends SceneTree
## Serial same-world pairs, actual GUI controls and two matched 60s local walking traces.

var patch: PainterlyGrassPatch
var folder: String
var checks: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _capture(name_value: String) -> Image:
	for i: int in 48:
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	assert(image.get_size() == Vector2i(1920, 1080))
	assert(image.save_png(folder.path_join(name_value + ".png")) == OK)
	return image


func _click(control: Control) -> void:
	var point: Vector2 = control.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		Input.parse_input_event(event)
	await process_frame
	await process_frame


func _difference(a: Image, b: Image) -> float:
	var total: float = 0
	var count: int = 0
	for y: int in range(220, 1000, 4):
		for x: int in range(100, 1820, 4):
			var delta: Color = a.get_pixel(x, y) - b.get_pixel(x, y)
			total += absf(delta.r) + absf(delta.g) + absf(delta.b)
			count += 3
	return total / count


func _walk_trace(enabled: bool) -> Dictionary:
	patch.set_patch_view(0)
	patch.set_variant(enabled)
	patch.set_patch_light(0)
	patch.set_patch_paused(false)
	patch.toggle_patch_walk()
	assert(patch.walk_controller.active)
	var controller: FirstPersonWalk = patch.walk_controller
	# Fixed safe start, then identical timed key/look protocol; real collision still runs.
	controller.feet = controller.surface.find_spawn(Vector2(5, 9))
	controller.yaw = 0.0
	controller.pitch = -0.05
	controller.reset_input()
	for i: int in 120:
		await process_frame
	controller.keys[KEY_W] = true
	var start: int = Time.get_ticks_usec()
	var previous: int = start
	var intervals: Array[float] = []
	var trajectory: Array[Dictionary] = []
	while Time.get_ticks_usec() - start < 60000000:
		await process_frame
		var now: int = Time.get_ticks_usec()
		var delta: float = float(now - previous) / 1000000
		intervals.append(delta * 1000)
		controller.look(Vector2(delta * 0.3, 0))
		previous = now
		if int((now - start) / 1000000) >= trajectory.size():
			trajectory.append({"elapsed_ms": float(now - start) / 1000, "feet": controller.feet})
	controller.reset_input()
	var sorted: Array[float] = intervals.duplicate()
	sorted.sort()
	var result: Dictionary = {
		"variant": "new" if enabled else "old",
		"requested_seconds": 60,
		"duration_ms": float(previous - start) / 1000,
		"frames": intervals.size(),
		"p95_ms": sorted[ceili(sorted.size() * 0.95) - 1],
		"p99_ms": sorted[ceili(sorted.size() * 0.99) - 1],
		"max_ms": sorted[-1],
		"frames_over_50ms": intervals.filter(func(v: float) -> bool: return v > 50).size(),
		"frame_intervals_ms": intervals,
		"trajectory": trajectory,
		"safe_support": controller.surface.can_stand(Vector2(controller.feet.x, controller.feet.z))
	}
	patch.set_patch_view(0)
	return result


func _run() -> void:
	folder = OS.get_cmdline_user_args()[-1]
	DirAccess.make_dir_recursive_absolute(folder)
	patch = preload("res://app/painterly_grass_patch.tscn").instantiate()
	root.add_child(patch)
	current_scene = patch
	var deadline: int = Time.get_ticks_msec() + 40000
	while not patch.patch_ready and not patch.patch_failed and Time.get_ticks_msec() < deadline:
		await process_frame
	assert(patch.patch_ready and not patch.patch_failed)
	var source: Dictionary = patch.document.snapshot()
	var history: int = patch.session._history.get_version()
	patch.set_patch_paused(true)
	var differences: Array[float] = []
	var names: Array[String] = ["overview", "house_low", "path_edge", "shade", "backlit"]
	for index: int in 5:
		patch.set_patch_view(index)
		patch.set_patch_light(1 if index == 4 else 0)
		var pose: Transform3D = patch.camera_rig.camera.global_transform
		patch.set_variant(false)
		var old: Image = await _capture(names[index] + "_old")
		await _click(patch.variant_button)
		var fresh: Image = await _capture(names[index] + "_new")
		differences.append(_difference(old, fresh))
		checks[names[index] + "_same_camera"] = patch.camera_rig.camera.global_transform == pose
		checks[names[index] + "_new_visible"] = patch.use_new_grass and differences[-1] > 0.00001
		checks[names[index] + "_no_dof"] = patch.camera_rig.camera.attributes == null
	checks["readonly_f6"] = patch.qa_mode and patch.active_slot == -1 and patch.photo_active
	checks["dedicated_save_directory"] = patch.saves.directory == "user://qa_painterly_grass/g2"
	await _click(patch.pause_button)
	var resumed: float = patch.patch_time
	await process_frame
	checks["resume_real_gui"] = not patch.patch_paused and patch.patch_time > resumed
	await _click(patch.pause_button)
	var frozen: float = patch.patch_time
	await process_frame
	checks["pause_real_gui"] = patch.patch_paused and patch.patch_time == frozen
	await _click(patch.walk_button)
	checks["walk_real_gui"] = patch.walk_controller.active
	var escape: InputEventKey = InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	Input.parse_input_event(escape)
	await process_frame
	checks["escape_returns_readonly_overview"] = (
		not patch.walk_controller.active and patch.photo_active and patch._climate_frozen
	)
	checks["toolbar_visible"] = Rect2(Vector2.ZERO, Vector2(1920, 1080)).encloses(
		patch.gallery_button.get_global_rect()
	)
	var traces: Array[Dictionary] = []
	for enabled: bool in [false, true]:
		traces.append(await _walk_trace(enabled))
	checks["two_real_60s_traces"] = traces.all(
		func(t: Dictionary) -> bool:
			return t["duration_ms"] >= 60000 and t["frames"] > 100 and t["safe_support"]
	)
	checks["local_frame_budget"] = traces.all(func(t: Dictionary) -> bool: return t["p95_ms"] <= 20)
	checks["no_new_50ms_stalls"] = traces[1]["frames_over_50ms"] <= traces[0]["frames_over_50ms"]
	checks["source_unchanged"] = patch.document.snapshot() == source
	checks["history_unchanged"] = patch.session._history.get_version() == history
	var count: int = 0
	for view: MultiMeshInstance3D in patch.patch_views:
		count += view.multimesh.instance_count
	var report: Dictionary = {
		"passed": not checks.values().has(false),
		"checks": checks,
		"viewport": [1920, 1080],
		"pair_pixel_differences": differences,
		"normal_views_taa": root.use_taa,
		"world_seed": source["world_seed"],
		"source_sha256": JSON.stringify(source).sha256_text(),
		"new_instances": count,
		"new_batches": 3,
		"new_triangles": count * 8,
		"old_rank_estimate": patch.patch_data["old_rank_selected"],
		"old_visible_origins": patch.patch_data["old_visible_origins"],
		"setting_density": patch.meadow.density,
		"traces": traces,
		"capacity_benchmark": false,
		"cold_start_verified": false,
		"ui_input": "synthetic press/release via actual viewport GUI",
		"audio": "Dummy"
	}
	await _click(patch.gallery_button)
	deadline = Time.get_ticks_msec() + 30000
	while (
		not (current_scene is PainterlyGrassLab and current_scene.loaded)
		and Time.get_ticks_msec() < deadline
	):
		await process_frame
	checks["g2_to_g1_real_gui"] = current_scene is PainterlyGrassLab and current_scene.loaded
	assert(checks["g2_to_g1_real_gui"])
	var lab: PainterlyGrassLab = current_scene
	await _click(lab.find_child("OpenPatch", true, false) as Button)
	deadline = Time.get_ticks_msec() + 40000
	while (
		not (current_scene is PainterlyGrassPatch and current_scene.patch_ready)
		and Time.get_ticks_msec() < deadline
	):
		await process_frame
	checks["g1_to_g2_real_gui"] = current_scene is PainterlyGrassPatch and current_scene.patch_ready
	assert(checks["g1_to_g2_real_gui"])
	patch = current_scene
	checks["one_active_preview_world"] = root.get_child_count() == 1
	report["passed"] = not checks.values().has(false)
	var file: FileAccess = FileAccess.open(folder.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	patch.seasonal_music.shutdown()
	patch.soundscape.shutdown()
	await SceneShutdown.wait_wallclock(self, 0.4)
	await SceneShutdown.release_scene(patch)
	for i: int in 8:
		await process_frame
	quit(0 if report["passed"] else 1)
