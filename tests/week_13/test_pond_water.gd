extends GutTest

var world: Node3D
var viewport: SubViewport


func before_all() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.own_world_3d = true
	add_child(viewport)
	world = load("res://app/living_root.tscn").instantiate()
	world.qa_mode = true
	viewport.add_child(world)
	world.calendar.speed = 0
	await _settle()


func _settle() -> void:
	var deadline: int = Time.get_ticks_msec() + 15000
	while (
		(world.queue.is_busy() or world.stage.is_busy() or world.meadow.is_busy())
		and Time.get_ticks_msec() < deadline
	):
		await get_tree().process_frame


func after_all() -> void:
	world.soundscape.shutdown()
	await SceneShutdown.wait_wallclock(get_tree(), 0.4)
	await SceneShutdown.release_scene(world)
	viewport.queue_free()
	await get_tree().process_frame


func test_planar_water_has_a_single_bounded_camera_and_no_feedback_or_probe() -> void:
	var fx: PondReflections = world.pond_reflections
	assert_eq(fx.viewport.size, Vector2i(480, 270))
	assert_eq(fx.camera.cull_mask & world.water_view.layers, 0)
	assert_false(fx.camera.environment.ssao_enabled)
	assert_false(fx.camera.environment.glow_enabled)
	assert_true(fx.find_children("*", "ReflectionProbe", true, false).is_empty())
	assert_eq(
		world.water_material.shader.resource_path,
		"res://features/pond_water/reflective_pond.gdshader"
	)
	assert_same(
		world.water_material.get_shader_parameter("reflection_texture"), fx.viewport.get_texture()
	)


func test_reflected_camera_preserves_source_and_has_a_valid_mirrored_pose() -> void:
	var source: Dictionary = world.document.snapshot()
	var fx: PondReflections = world.pond_reflections
	fx.age = 1
	fx.request_update()
	fx.tick(0, world.calendar.sample())
	assert_gt(fx.captures, 0)
	assert_almost_eq(
		fx.camera.global_position.y,
		2 * world.document.state["pool"]["water_y"] - world.camera_rig.camera.global_position.y,
		0.0001
	)
	assert_almost_eq(fx.camera.global_basis.determinant(), 1.0, 0.0001)
	assert_eq(world.document.state, source)
	assert_lte(fx.camera.far, 70.0)


func test_reflection_updates_are_throttled_and_weather_controls_ripples() -> void:
	var fx: PondReflections = world.pond_reflections
	fx.age = 0
	fx.pending = true
	var count: int = fx.captures
	for i: int in range(100):
		fx.tick(0.001, world.calendar.sample())
	assert_eq(fx.captures, count)
	fx.tick(0.03, world.calendar.sample())
	assert_eq(fx.captures, count + 1)
	for i: int in range(100):
		fx.tick(0.001, world.calendar.sample())
	assert_eq(fx.captures, count + 1)
	var rain: Dictionary = world.calendar.sample()
	rain["weather"] = "storm"
	fx.tick(0.03, rain)
	assert_eq(world.water_material.get_shader_parameter("rain_amount"), 1.0)
	fx.tick(0.01, world.calendar.sample())
	assert_eq(world.water_material.get_shader_parameter("rain_amount"), 0.0)


func test_empty_layout_disables_capture_and_a_new_pond_reuses_the_capture_node() -> void:
	var fx: PondReflections = world.pond_reflections
	world._layout_kind = "empty"
	world._apply_layout()
	await _settle()
	fx.tick(1, world.calendar.sample())
	assert_false(world.water_view.visible)
	assert_eq(fx.viewport.render_target_update_mode, SubViewport.UPDATE_DISABLED)
	assert_false(world.water_material.get_shader_parameter("reflection_enabled"))
	world._layout_kind = "demo"
	world._apply_layout()
	await _settle()
	fx.tick(1, world.calendar.sample())
	assert_same(world.pond_reflections, fx)
	assert_true(world.water_view.visible)
	assert_true(world.water_material.get_shader_parameter("reflection_enabled"))
