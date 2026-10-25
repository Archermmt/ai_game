extends SceneTree
## Render evidence only; no frame-time or capacity benchmark is collected.

var lab: LandscapeLab
var results: Dictionary = {"checks": [], "images": [], "performance_gate_run": false}
var output: String = "res://reports/landscape_lab/native"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1600, 1000)
	root.content_scale_size = Vector2i(1600, 1000)
	lab = (load("res://app/landscape_lab.tscn") as PackedScene).instantiate() as LandscapeLab
	root.add_child(lab)
	current_scene = lab
	var deadline: int = Time.get_ticks_msec() + 90000
	while not lab.lab_ready and not lab.lab_failed and Time.get_ticks_msec() < deadline:
		await process_frame
	_check("Actual Terrain3D and four source layers prepared", lab.lab_ready and not lab.lab_failed)
	if lab.lab_ready:
		lab.set_paused(true)
		await _settle()
		for mode: int in 2:
			await lab.set_distribution(mode)
			_check(
				"Distribution %d is ready" % mode,
				lab.distribution == mode and not lab.distribution_busy
			)
			_check_native_roots(mode)
			for view: int in 3:
				lab.set_view(view)
				await _capture("mode%d_view%d" % [mode, view])
		lab.set_view(2)
		for kind: int in 4:
			for i: int in 4:
				lab.set_layer_enabled(i, i == kind)
			await _capture("layer%d_close" % kind)
		for i: int in 4:
			lab.set_layer_enabled(i, false)
		await _capture("terrain_only")
		for i: int in 4:
			lab.set_layer_enabled(i, true)
		lab.show_reference(true)
		await _capture("official_reference")
		lab.show_reference(false)
		_check("Reference closes", not lab.reference.visible)
		_check(
			"Real native Terrain3D height data",
			lab.terrain_adapter.terrain.data.get_region_count() == 4
		)
		await _check_scene_roundtrip()
	results["passed"] = true
	for item: Dictionary in results["checks"]:
		if not item["passed"]:
			results["passed"] = false
	results["rendering_driver"] = RenderingServer.get_current_rendering_driver_name()
	results["visual_acceptance"] = "requires user review"
	var file: FileAccess = FileAccess.open(output + "/result.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(results, "\t") + "\n")
	file.close()
	var succeeded: bool = results["passed"]
	lab.queue_free()
	for i: int in 12:
		await process_frame
	print("LANDSCAPE_NATIVE_", "PASS" if succeeded else "FAIL")
	quit(0 if succeeded else 1)


func _capture(label: String) -> void:
	await _settle()
	_check(label + " finite camera", lab.camera_rig.camera.global_transform.is_finite())
	# An occluded macOS window may stop emitting frame_post_draw. Explicitly
	# render our own viewport before readback so evidence cannot hang or go stale.
	RenderingServer.force_draw(false)
	var path: String = output + "/" + label + ".png"
	var image: Image = root.get_texture().get_image()
	_check(
		label + " renders", image.get_size() == Vector2i(1600, 1000) and image.save_png(path) == OK
	)
	results["images"].append(path)


func _settle() -> void:
	await create_timer(1.2).timeout
	for i: int in 12:
		await process_frame


func _check(label: String, passed: bool) -> void:
	results["checks"].append({"label": label, "passed": passed})
	if not passed:
		push_error(label)


func _check_native_roots(mode: int) -> void:
	var maximum: float = 0.0
	var count: int = 0
	var poses: Array[Array] = lab.source_poses if mode == 0 else lab.plugin_poses
	for kind: int in 4:
		var batch: MultiMesh = lab.layers[kind].multimesh
		for index: int in batch.instance_count:
			var actual: Transform3D = batch.get_instance_transform(index)
			maximum = maxf(maximum, actual.origin.distance_to(poses[kind][index].origin))
			count += 1
	_check("Mode %d actual GPU origins" % mode, count > 0 and maximum < 0.001)
	results["mode%d_gpu_origin_error_m" % mode] = maximum


func _check_scene_roundtrip() -> void:
	var back: Button = lab.find_child("BackToGrassLab", true, false) as Button
	back.pressed.emit()
	var deadline: int = Time.get_ticks_msec() + 30000
	while not current_scene is PainterlyGrassLab and Time.get_ticks_msec() < deadline:
		await process_frame
	_check("Return button reaches grass gallery", current_scene is PainterlyGrassLab)
	if not current_scene is PainterlyGrassLab:
		return
	var gallery: PainterlyGrassLab = current_scene as PainterlyGrassLab
	while not gallery.loaded and not gallery.failed and Time.get_ticks_msec() < deadline:
		await process_frame
	var enter: Button = gallery.find_child("OpenLandscape", true, false) as Button
	enter.pressed.emit()
	while not current_scene is LandscapeLab and Time.get_ticks_msec() < deadline:
		await process_frame
	_check("Gallery button reaches landscape sample", current_scene is LandscapeLab)
	if current_scene is LandscapeLab:
		lab = current_scene as LandscapeLab
		while not lab.lab_ready and not lab.lab_failed and Time.get_ticks_msec() < deadline:
			await process_frame
		_check("Roundtrip prepares real Terrain3D again", lab.lab_ready and not lab.lab_failed)
