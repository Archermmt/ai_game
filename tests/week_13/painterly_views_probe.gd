extends "res://tests/ux_02/native_probe.gd"

var checks: Dictionary = {}


func _climate(month: int, hour: float, weather: String) -> void:
	playground.calendar.month = month
	playground.calendar.minute_of_day = hour * 60
	playground.calendar.weather = weather
	playground.atmosphere.blend.advance(0, playground.calendar.sample())
	playground.atmosphere.blend.advance(18, playground.calendar.sample())
	playground.atmosphere.elapsed = 0
	playground.atmosphere.phase = Vector3.ZERO
	playground.atmosphere.update(0, playground.calendar.sample())
	playground.pond_reflections.request_update()


func _ground_view(name_value: String, foot: Vector2, target: Vector3) -> void:
	var ground: Variant = playground.walk_controller.surface.find_spawn(foot)
	assert(ground != null)
	var camera: Camera3D = playground.camera_rig.camera
	camera.fov = 65
	camera.near = 0.06
	camera.global_position = ground + Vector3.UP * 1.65
	camera.look_at(target)
	playground.pond_reflections.request_update()
	await _frame(name_value)


func _run() -> void:
	folder = OS.get_cmdline_user_args()[-1]
	DirAccess.make_dir_recursive_absolute(folder)
	playground = load("res://app/living_root.tscn").instantiate()
	playground.qa_mode = true
	root.add_child(playground)
	await _settle()
	var source: Dictionary = playground.document.snapshot()
	var history: int = playground.session.history_count()
	playground.calendar.speed = 0
	playground.calendar.automatic_weather = false
	_climate(5, 11.5, "clear")
	playground._freeze_photo(true)
	for material: ShaderMaterial in playground.wind_materials:
		material.set_shader_parameter("sample_time", 0.0)
	playground.water_material.set_shader_parameter("sample_time", 0.0)
	playground.hud.hide()
	await _frame("overview_default_focus")
	var camera: Camera3D = playground.camera_rig.camera
	camera.attributes = null
	await _frame("overview_sharp")
	playground.camera_rig.target = Vector3(0, 1.2, 0)
	playground.camera_rig.distance = 16
	playground.camera_rig.pitch = 0.50
	playground.camera_rig.yaw = 0.70
	playground.camera_rig.refresh()
	await _frame("cottage_detail")
	playground.walk_controller.surface.configure(source)
	await _ground_view("pond_walk", Vector2(-2, 11), Vector3(-5.3, 0.7, 5.7))
	await _ground_view("forest_walk", Vector2(-10, 8), Vector3(-16, 3, -8))
	await _ground_view("grass_detail", Vector2(7, 10), Vector3(7, 0.1, 3))
	_climate(7, 14, "clear")
	await _ground_view("summer_sky", Vector2(-2, 11), Vector3(-12, 10, -8))
	_climate(10, 16, "cloudy")
	playground.camera_rig.reset_view()
	await _frame("autumn_overview")
	_climate(1, 11, "snow")
	await _frame("winter_overview")
	_climate(7, 18.3, "clear")
	await _ground_view("sunset_walk", Vector2(-2, 11), Vector3(-12, 6, -8))
	_climate(7, 21, "clear")
	await _ground_view("night_walk", Vector2(-2, 11), Vector3(-12, 9, -8))
	checks["source_unchanged"] = source == playground.document.state
	checks["history_unchanged"] = history == playground.session.history_count()
	checks["viewport_fhd"] = root.get_texture().get_image().get_size() == Vector2i(1920, 1080)
	var file: FileAccess = FileAccess.open(folder.path_join("report.json"), FileAccess.WRITE)
	file.store_string(
		JSON.stringify({"checks": checks, "passed": not checks.values().has(false)}, "\t")
	)
	file.close()
	playground.soundscape.shutdown()
	await SceneShutdown.wait_wallclock(self, 0.4)
	await SceneShutdown.release_scene(playground)
	for i: int in range(8):
		await process_frame
	quit(0 if not checks.values().has(false) else 1)
