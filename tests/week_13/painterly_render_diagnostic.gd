extends "res://tests/week_13/painterly_views_probe.gd"


func _shot(label: String) -> void:
	for i: int in range(25):
		await process_frame
	await _frame(label)


func _run() -> void:
	folder = OS.get_cmdline_user_args()[-1]
	DirAccess.make_dir_recursive_absolute(folder)
	playground = load("res://app/living_root.tscn").instantiate()
	playground.qa_mode = true
	root.add_child(playground)
	await _settle()
	playground.calendar.speed = 0
	playground.calendar.automatic_weather = false
	_climate(5, 11.5, "clear")
	playground._freeze_photo(true)
	for material: ShaderMaterial in playground.wind_materials:
		material.set_shader_parameter("sample_time", 0.0)
	playground.hud.hide()
	var camera: Camera3D = playground.camera_rig.camera
	camera.attributes = null
	camera.fov = 65
	camera.near = 0.06
	camera.global_position = Vector3(-2, 1.9, 11)
	camera.look_at(Vector3(-5.3, 0.7, 5.7))
	var environment: Environment = playground.world_environment.environment
	playground.sun.shadow_bias = 0.02
	playground.sun.shadow_normal_bias = 1.0
	await _shot("default_stable")
	root.use_taa = false
	await _shot("no_taa")
	environment.ssao_enabled = false
	await _shot("no_taa_no_ssao")
	root.use_taa = true
	await _shot("taa_no_ssao")
	environment.ssao_enabled = true
	playground.sun.shadow_enabled = false
	await _shot("no_sun_shadows")
	playground.sun.shadow_enabled = true
	playground.sun.shadow_bias = 0.10
	playground.sun.shadow_normal_bias = 2.0
	await _shot("increased_shadow_bias")
	var residuals: Dictionary = {}
	var images: Dictionary = {}
	for label: String in [
		"default_stable",
		"no_taa",
		"no_taa_no_ssao",
		"taa_no_ssao",
		"no_sun_shadows",
		"increased_shadow_bias"
	]:
		var image: Image = Image.load_from_file(folder.path_join(label + ".png"))
		images[label] = image
		var total: float = 0
		for y: int in range(361, 649):
			for x: int in range(1610, 1830):
				var a: float = image.get_pixel(x, y - 1).get_luminance()
				var b: float = image.get_pixel(x, y).get_luminance()
				var c: float = image.get_pixel(x, y + 1).get_luminance()
				total += absf(a + c - 2 * b)
		residuals[label] = total / (288 * 220)
	var shadow_difference: float = 0
	for y: int in range(0, 1080, 8):
		for x: int in range(0, 1920, 8):
			shadow_difference += absf(
				(
					images["increased_shadow_bias"].get_pixel(x, y).get_luminance()
					- images["no_sun_shadows"].get_pixel(x, y).get_luminance()
				)
			)
	shadow_difference /= 135 * 240
	var passed: bool = (
		residuals["increased_shadow_bias"] < residuals["default_stable"] * 0.85
		and shadow_difference > 0.01
	)
	var output: FileAccess = FileAccess.open(folder.path_join("report.json"), FileAccess.WRITE)
	output.store_string(
		JSON.stringify(
			{
				"wall_high_frequency_residuals": residuals,
				"shadow_difference": shadow_difference,
				"passed": passed
			},
			"\t"
		)
	)
	output.close()
	playground.soundscape.shutdown()
	await SceneShutdown.wait_wallclock(self, 0.4)
	await SceneShutdown.release_scene(playground)
	for i: int in range(8):
		await process_frame
	quit(0 if passed else 1)
