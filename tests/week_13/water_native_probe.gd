extends "res://tests/ux_02/native_probe.gd"

var checks: Dictionary = {}
var measurements: Dictionary = {}


func _difference(a: Image, b: Image, mask: Image) -> float:
	var total: float = 0
	var count: int = 0
	for y: int in range(0, a.get_height(), 3):
		for x: int in range(0, a.get_width(), 3):
			var mark: Color = mask.get_pixel(x, y)
			if mark.r > 0.7 and mark.b > 0.6 and mark.g < 0.2:
				var p: Color = a.get_pixel(x, y)
				var q: Color = b.get_pixel(x, y)
				total += absf(p.r - q.r) + absf(p.g - q.g) + absf(p.b - q.b)
				count += 1
	assert(count > 1000)
	measurements["water_samples"] = count
	return total / (count * 3)


func _run() -> void:
	folder = OS.get_cmdline_user_args()[-1]
	DirAccess.make_dir_recursive_absolute(folder)
	playground = load("res://app/living_root.tscn").instantiate()
	playground.qa_mode = true
	root.add_child(playground)
	await _settle()
	root.use_taa = false
	var source: Dictionary = playground.document.snapshot()
	playground.calendar.month = 7
	playground.calendar.weather = "clear"
	playground.calendar.minute_of_day = 720
	playground.calendar.speed = 0
	playground.calendar.automatic_weather = false
	playground._freeze_photo(true)
	for material: ShaderMaterial in playground.wind_materials:
		material.set_shader_parameter("sample_time", 0.0)
	var water: ShaderMaterial = playground.water_material
	water.set_shader_parameter("sample_time", 0.0)
	playground.atmosphere.blend.advance(0, playground.calendar.sample())
	playground.atmosphere.blend.advance(WeatherBlend.DURATION, playground.calendar.sample())
	playground.atmosphere.update(0, playground.calendar.sample())
	playground.hud.hide()
	var pool: Dictionary = playground.document.state["pool"]
	playground.camera_rig.target = Vector3(pool["center"][0], pool["water_y"], pool["center"][1])
	playground.camera_rig.distance = 17
	playground.camera_rig.pitch = 0.60
	playground.camera_rig.yaw = 0.65
	playground.camera_rig.refresh()
	await SceneShutdown.wait_wallclock(self, 0.5)
	await _frame("pond_near")
	var initial: Image = root.get_texture().get_image()
	var fx: PondReflections = playground.pond_reflections
	checks["bounded_capture"] = fx.viewport.size == Vector2i(480, 270)
	checks["capture_has_geometry"] = fx.captures > 0
	var mask_material: ShaderMaterial = ShaderMaterial.new()
	var mask_shader: Shader = Shader.new()
	mask_shader.code = (
		"shader_type spatial; render_mode unshaded; " + "void fragment(){ALBEDO=vec3(1,0,1); }"
	)
	mask_material.shader = mask_shader
	playground.water_view.material_override = mask_material
	await _frame("water_mask")
	var mask: Image = root.get_texture().get_image()
	playground.water_view.material_override = water
	fx.enabled = false
	await _frame("reflection_disabled")
	var off: Image = root.get_texture().get_image()
	measurements["reflection_difference"] = _difference(initial, off, mask)
	checks["reflection_changes_water_pixels"] = measurements["reflection_difference"] > 0.005
	fx.enabled = true
	water.set_shader_parameter("sample_time", 4.0)
	await _frame("ripple_phase_b")
	measurements["ripple_difference"] = _difference(initial, root.get_texture().get_image(), mask)
	checks["visible_ripple_motion"] = measurements["ripple_difference"] > 0.002
	water.set_shader_parameter("reduce_motion", true)
	await _frame("reduced_motion_a")
	var reduced: Image = root.get_texture().get_image()
	water.set_shader_parameter("sample_time", 8.0)
	await _frame("reduced_motion_b")
	measurements["reduced_motion_difference"] = _difference(
		reduced, root.get_texture().get_image(), mask
	)
	checks["reduced_motion_stable"] = measurements["reduced_motion_difference"] < 0.001
	water.set_shader_parameter("reduce_motion", false)
	water.set_shader_parameter("sample_time", 0.0)
	var sentinel: MeshInstance3D = MeshInstance3D.new()
	var cube: BoxMesh = BoxMesh.new()
	cube.size = Vector3(2, 4, 2)
	sentinel.mesh = cube
	sentinel.position = Vector3(-8, pool["water_y"] + 2.5, 1.5)
	var paint: StandardMaterial3D = StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.albedo_color = Color.RED
	sentinel.material_override = paint
	playground.world_view.add_child(sentinel)
	fx.request_update()
	await SceneShutdown.wait_wallclock(self, 0.3)
	await _frame("red_object_reflection")
	var red: Image = root.get_texture().get_image()
	paint.albedo_color = Color.BLUE
	fx.request_update()
	await SceneShutdown.wait_wallclock(self, 0.3)
	await _frame("blue_object_reflection")
	measurements["geometry_reflection_difference"] = _difference(
		red, root.get_texture().get_image(), mask
	)
	checks["actual_geometry_reflects"] = measurements["geometry_reflection_difference"] > 0.001
	sentinel.queue_free()
	fx.request_update()
	playground.calendar.weather = "storm"
	playground.atmosphere.blend.advance(0, playground.calendar.sample())
	playground.atmosphere.blend.advance(18, playground.calendar.sample())
	playground.atmosphere.update(0, playground.calendar.sample())
	await SceneShutdown.wait_wallclock(self, 0.3)
	await _frame("rain_water")
	checks["rain_strengthens_ripples"] = water.get_shader_parameter("rain_amount") == 1.0
	playground.calendar.weather = "clear"
	playground.calendar.minute_of_day = 0
	fx.request_update()
	await SceneShutdown.wait_wallclock(self, 0.3)
	await _frame("night_water")
	playground.calendar.minute_of_day = 720
	playground.camera_rig.reset_view()
	fx.request_update()
	await SceneShutdown.wait_wallclock(self, 0.3)
	await _frame("pond_full")
	checks["source_unchanged"] = playground.document.state == source
	checks["no_reflection_probe"] = fx.find_children("*", "ReflectionProbe", true, false).is_empty()
	var passed: bool = not checks.values().has(false)
	var file: FileAccess = FileAccess.open(folder.path_join("water_report.json"), FileAccess.WRITE)
	file.store_string(
		JSON.stringify({"checks": checks, "measurements": measurements, "passed": passed}, "\t")
	)
	file.close()
	playground.soundscape.shutdown()
	await SceneShutdown.wait_wallclock(self, 0.4)
	await SceneShutdown.release_scene(playground)
	for i: int in range(12):
		await process_frame
	quit(0 if passed else 1)
