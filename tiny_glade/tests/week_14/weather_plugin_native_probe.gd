extends SceneTree
## Native visual proof for the isolated lab, not a performance or thick-snow gate.

const FOLDER: String = "res://reports/weather_plugins/native"
const SIZE: Vector2i = Vector2i(1440, 900)
var garden: WeatherPluginLab
var checks: Dictionary = {}
var images: Array[String] = []
var measurements: Dictionary = {}
var photo_results: Array[Dictionary] = []
var source: Dictionary = {}
var history: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _process(_delta: float) -> bool:
	if is_instance_valid(garden) and garden.photography != null and garden.photography.busy:
		# The export waits on frame_post_draw, even when macOS occludes the window.
		RenderingServer.force_draw(false)
	return false


func _check(label: String, passed: bool) -> bool:
	checks[label] = passed
	if not passed:
		push_error(label)
	return passed


func _draw_frames(count: int) -> void:
	for i: int in count:
		await process_frame
		RenderingServer.force_draw(false)


func _capture(label: String, settle_frames: int = 32) -> Image:
	await _draw_frames(settle_frames)
	var picture: Image = root.get_texture().get_image()
	var path: String = FOLDER.path_join(label + ".png")
	_check(label + " saved", picture.get_size() == SIZE and picture.save_png(path) == OK)
	images.append(path)
	return picture


func _sky_rect(size: Vector2i) -> Rect2i:
	return Rect2i(Vector2i(size.x / 18, size.y / 12), Vector2i(size.x * 8 / 9, size.y / 2))


func _difference(a: Image, b: Image, rect: Rect2i) -> float:
	var total: float = 0.0
	var count: int = 0
	for y: int in range(rect.position.y, rect.end.y, 3):
		for x: int in range(rect.position.x, rect.end.x, 3):
			var delta: Color = a.get_pixel(x, y) - b.get_pixel(x, y)
			total += absf(delta.r) + absf(delta.g) + absf(delta.b)
			count += 3
	return total / maxf(count, 1)


func _luminance(picture: Image, rect: Rect2i) -> float:
	var total: float = 0.0
	var count: int = 0
	for y: int in range(rect.position.y, rect.end.y, 4):
		for x: int in range(rect.position.x, rect.end.x, 4):
			var pixel: Color = picture.get_pixel(x, y)
			total += pixel.r * 0.2126 + pixel.g * 0.7152 + pixel.b * 0.0722
			count += 1
	return total / maxf(count, 1)


func _pipeline_flags() -> Dictionary:
	if not is_instance_valid(garden) or garden.cloud_adapter.clouds == null:
		return {"main": false, "pre": false, "post": false, "display": false}
	return {
		"main": garden.cloud_adapter.clouds.pipeline.is_valid(),
		"pre": garden.cloud_adapter.clouds.prepass_pipeline.is_valid(),
		"post": garden.cloud_adapter.clouds.postpass_pipeline.is_valid(),
		"display": garden.cloud_adapter.clouds.display_pipeline.is_valid()
	}


func _motion() -> Dictionary:
	var positions: Array = []
	for point: Vector3 in [
		garden.cloud_adapter.driver.extra_large_clouds_pos,
		garden.cloud_adapter.driver.large_clouds_pos,
		garden.cloud_adapter.driver.medium_clouds_pos,
		garden.cloud_adapter.driver.small_clouds_pos
	]:
		positions.append([point.x, point.y, point.z])
	return {"time": garden.cloud_adapter.clouds.current_time, "positions": positions}


func _snow_bounds() -> Array:
	var result: Array = []
	for sample: MeshInstance3D in garden.snow_reference.samples:
		var box: AABB = sample.mesh.get_aabb()
		result.append(
			{
				"position": [box.position.x, box.position.y, box.position.z],
				"size": [box.size.x, box.size.y, box.size.z]
			}
		)
	return result


func _snow_rect() -> Rect2i:
	var minimum: Vector2 = Vector2(SIZE)
	var maximum: Vector2 = Vector2.ZERO
	for sample: MeshInstance3D in garden.snow_reference.samples:
		for corner: int in 8:
			var point: Vector3 = (
				sample.global_transform * sample.mesh.get_aabb().get_endpoint(corner)
			)
			var screen: Vector2 = garden.camera_rig.camera.unproject_position(point)
			minimum = minimum.min(screen)
			maximum = maximum.max(screen)
	return Rect2i(Rect2(minimum, maximum - minimum).grow(8)).intersection(
		Rect2i(Vector2i.ZERO, SIZE)
	)


func _snow_top_fraction(picture: Image) -> float:
	var snow_pixels: int = 0
	var count: int = 0
	for z: int in 4:
		for x: int in 16:
			var point: Vector3 = (
				garden.snow_reference.global_position
				+ Vector3(-2.4 + x * 0.3, 0.01, 1.5 + z * 0.15)
			)
			var screen: Vector2i = Vector2i(garden.camera_rig.camera.unproject_position(point))
			if Rect2i(Vector2i.ZERO, SIZE).has_point(screen):
				var pixel: Color = picture.get_pixelv(screen)
				snow_pixels += int(
					pixel.b > pixel.r * 0.82 and pixel.b > pixel.g * 0.82 and pixel.r > 0.3
				)
				count += 1
	return float(snow_pixels) / maxi(count, 1)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(FOLDER)
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	if not _check("native renderer required", DisplayServer.get_name() != "headless"):
		await _finish()
		return
	garden = (load("res://app/weather_plugin_lab.tscn") as PackedScene).instantiate()
	root.add_child(garden)
	current_scene = garden
	var qa_directory: String = "user://qa_weather_plugins/native/%d" % Time.get_ticks_usec()
	garden.saves.directory = qa_directory.path_join("saves")
	garden.active_slot = -1
	garden.hud.photo_directory.text = ProjectSettings.globalize_path(
		qa_directory.path_join("photos")
	)
	garden.pond_reflections.enabled = false
	garden.pond_reflections.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var deadline: int = Time.get_ticks_msec() + 120000
	while Time.get_ticks_msec() < deadline:
		await _draw_frames(1)
		if garden.landscape_failed:
			break
		if (
			garden.landscape_ready
			and garden.weather_lab_ready
			and _pipeline_flags().values().all(func(value: bool) -> bool: return value)
		):
			break
	if not _check(
		"garden and plugin configured", garden.landscape_ready and garden.weather_lab_ready
	):
		await _finish()
		return
	measurements["initial_pipeline_flags"] = _pipeline_flags()
	if not _check("all four GPU pipelines valid", not _pipeline_flags().values().has(false)):
		await _finish()
		return
	_check(
		"QA IO isolated",
		garden.qa_mode and garden.saves.directory.begins_with("user://qa_weather_plugins/native/")
	)
	_check(
		"upstream snow samples ready",
		garden.snow_reference.ready_for_preview and garden.snow_reference.samples.size() == 3
	)
	await SceneShutdown.wait_wallclock(self, 8)
	root.use_taa = false
	garden.hud.hide()
	garden.set_lab_view(1)
	garden.set_lab_climate(0, true)
	garden._freeze_photo(true)
	source = garden.document.snapshot()
	history = garden.session.history_count()
	garden.set_plugin_clouds(false)
	var original: Image = await _capture("cloud_original")
	garden.set_plugin_clouds(true)
	var clear_day: Image = await _capture("cloud_clear", 64)
	var cloud_difference: float = _difference(original, clear_day, _sky_rect(SIZE))
	measurements["original_to_plugin_pixel_difference"] = cloud_difference
	_check("plugin changes actual sky pixels", cloud_difference > 0.002)
	var clear_luminance: float = _luminance(clear_day, _sky_rect(SIZE))
	_check(
		"day sky is neither blank black nor clipped white",
		clear_luminance > 0.02 and clear_luminance < 0.98
	)
	var clear_coverage: float = garden.cloud_adapter.clouds.clouds_coverage
	for index: int in range(1, 5):
		garden.set_lab_climate(index, true)
		var label: String = ["cloudy", "dusk", "night", "snow"][index - 1]
		var picture: Image = await _capture(label)
		measurements[label] = {
			"sky_luminance": _luminance(picture, _sky_rect(SIZE)),
			"coverage": garden.cloud_adapter.clouds.clouds_coverage,
			"density": garden.cloud_adapter.clouds.clouds_density
		}
		if index == 1:
			_check(
				"overcast increases plugin coverage",
				garden.cloud_adapter.clouds.clouds_coverage > clear_coverage
			)
		if index == 3:
			_check(
				"night sky follows calendar darkness",
				_luminance(picture, _sky_rect(SIZE)) < clear_luminance * 0.85
			)
		if index == 4:
			_check("snowfall remains active", garden.atmosphere.snow.visible)
	await _motion_checks()
	await _snow_checks()
	await _photo_and_reflection_checks()
	_check("presentation preserves world source", garden.document.snapshot() == source)
	_check("presentation preserves undo history", garden.session.history_count() == history)
	measurements["final_pipeline_flags"] = _pipeline_flags()
	_check("GPU pipelines remain valid", not _pipeline_flags().values().has(false))
	await _finish()


func _motion_checks() -> void:
	garden.set_lab_climate(0, true)
	garden.set_lab_view(1)
	garden._freeze_photo(true)
	var frozen_a: Image = await _capture("cloud_frozen_a", 64)
	var frozen_state: Dictionary = _motion()
	await SceneShutdown.wait_wallclock(self, 0.6)
	var frozen_b: Image = await _capture("cloud_frozen_b")
	_check("freeze holds plugin time and all wind positions", _motion() == frozen_state)
	var frozen_difference: float = _difference(frozen_a, frozen_b, _sky_rect(SIZE))
	_check("frozen cloud pixels stay stable", frozen_difference < 0.0005)
	garden._freeze_photo(false)
	await SceneShutdown.wait_wallclock(self, 2.0)
	_check("resume advances plugin time", _motion()["time"] != frozen_state["time"])
	_check(
		"resume advances cloud wind positions", _motion()["positions"] != frozen_state["positions"]
	)
	garden._freeze_photo(true)
	var resumed: Image = await _capture("cloud_resumed")
	var resumed_difference: float = _difference(frozen_b, resumed, _sky_rect(SIZE))
	_check("resumed cloud motion changes pixels", resumed_difference > 0.00001)
	garden.preferences.values["reduce_motion"] = true
	garden._apply_preferences()
	garden._freeze_photo(false)
	var reduced_a: Image = await _capture("cloud_reduced_a", 64)
	var reduced_state: Dictionary = _motion()
	await SceneShutdown.wait_wallclock(self, 0.6)
	var reduced_b: Image = await _capture("cloud_reduced_b")
	_check("reduced motion holds plugin time and wind", _motion() == reduced_state)
	var reduced_difference: float = _difference(reduced_a, reduced_b, _sky_rect(SIZE))
	_check("reduced motion cloud pixels stay stable", reduced_difference < 0.0005)
	measurements["motion"] = {
		"frozen_pixel_difference": frozen_difference,
		"resumed_pixel_difference": resumed_difference,
		"reduced_pixel_difference": reduced_difference,
		"frozen_state": frozen_state,
		"reduced_state": reduced_state
	}
	garden._freeze_photo(true)
	garden.preferences.values["reduce_motion"] = false
	garden._apply_preferences()


func _snow_checks() -> void:
	garden.set_plugin_clouds(false)
	garden.set_lab_climate(0, true)
	garden.set_lab_view(2)
	garden.meadow.hide()
	var bounds: Array = _snow_bounds()
	garden.snow_reference.configure(0.9, 0.0)
	var smooth_snow: Image = await _capture("snow_normal_0")
	garden.snow_reference.set_normal_strength(0.8)
	var textured_snow: Image = await _capture("snow_normal_08")
	var rect: Rect2i = _snow_rect()
	_check("snow reference fills a visible image region", rect.size.x > 300 and rect.size.y > 200)
	var difference: float = _difference(smooth_snow, textured_snow, rect)
	var snow_top: float = _snow_top_fraction(textured_snow)
	_check("upward plane actually receives snow material", snow_top > 0.65)
	_check("upstream snow normals change real pixels", difference > 0.0001)
	_check("snow normal control preserves geometric AABBs", _snow_bounds() == bounds)
	_check(
		"reference does not claim geometric snow thickness",
		not garden.snow_reference.reference_state()["geometric_snow_thickness"]
	)
	measurements["snow"] = {
		"reference": garden.snow_reference.reference_state(),
		"normal_strengths": [0.0, 0.8],
		"pixel_difference": difference,
		"upward_plane_snow_fraction": snow_top,
		"image_rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
		"geometric_aabbs": bounds,
		"geometric_snow_thickness": false,
		"meadow_hidden_for_material_comparison": true
	}
	garden.snow_reference.configure()
	garden.meadow.show()
	garden.set_lab_view(1)
	garden.set_plugin_clouds(true)


func _photo_and_reflection_checks() -> void:
	garden.set_lab_climate(0, true)
	var camera: Camera3D = garden.camera_rig.camera
	var pose: Transform3D = camera.global_transform
	var size: Vector2i = Vector2i(2560, 1440)
	var plugin_path: String = FOLDER.path_join("photo_2k_plugin.png")
	photo_results.append(await garden.photography.capture(camera, size, plugin_path))
	garden.set_plugin_clouds(false)
	var original_path: String = FOLDER.path_join("photo_2k_original.png")
	photo_results.append(await garden.photography.capture(camera, size, original_path))
	_check(
		"paired 2K photo exports succeed",
		photo_results.all(func(row: Dictionary) -> bool: return row["ok"])
	)
	var plugin_photo: Image = Image.load_from_file(plugin_path)
	var original_photo: Image = Image.load_from_file(original_path)
	if _check(
		"2K photos decode at correct dimensions",
		(
			plugin_photo != null
			and original_photo != null
			and plugin_photo.get_size() == size
			and original_photo.get_size() == size
		)
	):
		var difference: float = _difference(plugin_photo, original_photo, _sky_rect(size))
		measurements["photo_cloud_pixel_difference"] = difference
		_check("plugin changes pixels in the 2K export", difference > 0.002)
	_check("photo restores source camera", camera.global_transform == pose)
	garden.set_plugin_clouds(true)
	await _draw_frames(24)
	_check(
		"main cloud viewport recovers after photo", garden.cloud_adapter.clouds.last_size == SIZE
	)
	var before: int = garden.pond_reflections.captures
	garden.pond_reflections.enabled = true
	garden.pond_reflections.request_update()
	garden._freeze_photo(false)
	await SceneShutdown.wait_wallclock(self, 1.2)
	await _draw_frames(8)
	var after: int = garden.pond_reflections.captures
	_check("planar reflection is exercised separately", after > before)
	measurements["multiview"] = {
		"photo_export_exercised": true,
		"reflection_exercised": after > before,
		"reflection_capture_delta": after - before,
		"reflection_cloud_image_verified": false,
		"artifact_free_temporal_history_verified": false,
		"full_multiview_approval": false
	}
	garden.pond_reflections.enabled = false
	garden.pond_reflections.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	garden._freeze_photo(true)
	await _draw_frames(16)


func _finish() -> void:
	var passed: bool = not checks.is_empty() and not checks.values().has(false)
	var msaa: int = root.msaa_3d
	if is_instance_valid(garden):
		garden.cloud_adapter.shutdown()
		garden.soundscape.shutdown()
		await SceneShutdown.wait_wallclock(self, 0.4)
		await SceneShutdown.release_scene(garden)
	await _draw_frames(8)
	var file: FileAccess = FileAccess.open(FOLDER.path_join("result.json"), FileAccess.WRITE)
	file.store_string(
		(
			JSON.stringify(
				{
					"passed": passed,
					"checks": checks,
					"measurements": measurements,
					"images": images,
					"photos": photo_results,
					"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
					"viewport_size": [SIZE.x, SIZE.y],
					"msaa_mode": msaa,
					"taa_during_pixel_checks": false,
					"single_view_baseline_reflections_disabled": true,
					"geometric_snow_thickness": false,
					"performance_gate_run": false,
					"windows_real_device_verified": false,
					"teardown_requested": true,
					"exit_leak_free_requires_external_log_check": true
				},
				"\t"
			)
			+ "\n"
		)
	)
	file.close()
	print("WEATHER_PLUGIN_NATIVE_", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)
