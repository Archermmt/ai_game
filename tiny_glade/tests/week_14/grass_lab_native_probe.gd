extends SceneTree

var lab: PainterlyGrassLab
var folder: String
var checks: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _capture(name_value: String) -> Image:
	for i: int in 36:
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	assert(image.get_size() == Vector2i(1920, 1080))
	assert(image.save_png(folder.path_join(name_value + ".png")) == OK)
	return image


func _click(control: Control, fraction: float = 0.5) -> void:
	var rect: Rect2 = control.get_global_rect()
	var point: Vector2 = Vector2(rect.position.x + rect.size.x * fraction, rect.get_center().y)
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
	var sum_value: float = 0.0
	var count: int = 0
	for y: int in range(220, 1000, 4):
		for x: int in range(100, 1820, 4):
			var delta: Color = a.get_pixel(x, y) - b.get_pixel(x, y)
			sum_value += absf(delta.r) + absf(delta.g) + absf(delta.b)
			count += 3
	return sum_value / count


func _run() -> void:
	folder = OS.get_cmdline_user_args()[-1]
	DirAccess.make_dir_recursive_absolute(folder)
	lab = preload("res://app/painterly_grass_preview.tscn").instantiate()
	root.add_child(lab)
	var deadline: int = Time.get_ticks_msec() + 30000
	while not lab.loaded and not lab.failed and Time.get_ticks_msec() < deadline:
		await process_frame
	assert(lab.loaded and not lab.failed)
	checks["no_save_node"] = lab.find_children("*", "SaveRepository", true, false).is_empty()
	checks["loaded_three_new_meshes"] = lab.meshes.size() == 3
	checks["seven_sample_batches"] = (
		lab.samples.find_children("*", "MultiMeshInstance3D", true, false).size() == 7
	)
	lab.paused = true
	lab.elapsed = 0.0
	await _capture("overview")
	for index: int in [1, 2, 3, 4, 5]:
		lab.set_view(index)
		await _capture(["", "grass_a", "grass_b", "ground_cover", "low_angle", "back"][index])
	lab.set_view(1)
	lab.set_light(1)
	await _capture("shade")
	lab.set_light(2)
	await _capture("backlit")
	lab.set_light(0)
	# Disable temporal jitter for both motion controls; normal view captures retain TAA.
	root.use_taa = false
	lab.set_wind(1.0)
	lab.elapsed = 0.0
	var a: Image = await _capture("wind_a")
	lab.elapsed = 2.0
	var b: Image = await _capture("wind_b")
	var moving: float = _difference(a, b)
	checks["wind_is_visible"] = moving > 0.00001
	lab.paused = false
	await _click(lab.pause_button)
	var stopped: float = lab.elapsed
	await process_frame
	await process_frame
	checks["pause_real_gui"] = lab.paused and lab.elapsed == stopped
	await _click(lab.pause_button)
	var resumed: float = lab.elapsed
	await process_frame
	await process_frame
	checks["resume_real_gui"] = not lab.paused and lab.elapsed > resumed
	await _click(lab.wind_slider, 0.8)
	checks["wind_slider_real_gui"] = lab.wind > 0.6
	await _click(lab.rotate_button)
	var yaw_before: float = lab.rig.yaw
	for i: int in 6:
		await process_frame
	checks["orbit_real_gui"] = lab.rotating and lab.rig.yaw > yaw_before
	await _click(lab.motion_toggle)
	checks["reduced_motion_real_gui"] = (
		lab.reduced_motion and not lab.rotating and lab.rotate_button.disabled
	)
	lab.set_view(1)
	lab.paused = true
	lab.elapsed = 1.0
	a = await _capture("reduced_a")
	lab.elapsed = 9.0
	b = await _capture("reduced_b")
	var frozen: float = _difference(a, b)
	checks["reduced_motion_pixel_stable"] = frozen < 0.0001
	await _click(lab.reset_button)
	checks["reset_real_gui"] = (
		not lab.paused
		and not lab.reduced_motion
		and not lab.rotating
		and is_equal_approx(lab.wind, 0.45)
	)
	checks["toolbar_inside_viewport"] = Rect2(Vector2.ZERO, Vector2(1920, 1080)).encloses(
		lab.motion_toggle.get_global_rect()
	)
	var report: Dictionary = {
		"checks": checks,
		"passed": not checks.values().has(false),
		"wind_pixel_difference": moving,
		"reduced_pixel_difference": frozen,
		"viewport": [1920, 1080],
		"pixel_checks_taa": false,
		"normal_views_taa": true,
		"ui_input": "synthetic viewport press/release through GUI",
		"save_service_instantiated": false
	}
	var file: FileAccess = FileAccess.open(folder.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	await SceneShutdown.release_scene(lab)
	for i: int in 8:
		await process_frame
	quit(0 if report["passed"] else 1)
