extends GutTest


func test_environment_keeps_soft_contacts_and_limits_bloom() -> void:
	var environment: Environment = Environment.new()
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	ArtEnvironment.configure(environment, sun)
	assert_true(environment.ssao_enabled)
	assert_lte(environment.ssao_intensity, 1.0)
	assert_lte(environment.glow_intensity, 0.10)
	assert_between(environment.tonemap_exposure, 0.90, 1.0)
	assert_gte(sun.light_angular_distance, 2.0)
	sun.free()


func test_sky_ridges_and_daylight_follow_seasons_without_changing_the_weather_source() -> void:
	var environment: Environment = Environment.new()
	var sky: PaintedSky = PaintedSky.new()
	sky.configure(environment)
	var blend: WeatherBlend = WeatherBlend.new()
	var source: Dictionary = {"weather": "clear", "season": "summer"}
	var before: Dictionary = source.duplicate(true)
	var visual: Dictionary = blend.advance(0, source)
	sky.sync(0, 1.0, 12, true, visual, "summer")
	var summer: Vector3 = sky.material.get_shader_parameter("ridge_tint")
	var noon: Vector3 = sky.material.get_shader_parameter("sun_direction")
	sky.sync(0, 0.0, 0, false, visual, "winter")
	var winter: Vector3 = sky.material.get_shader_parameter("ridge_tint")
	assert_ne(summer, winter)
	assert_true(noon.is_normalized())
	assert_gt(noon.y, 0.0)
	assert_lt(sky.material.get_shader_parameter("sun_direction").y, 0.0)
	assert_eq(environment.sky.radiance_size, Sky.RADIANCE_SIZE_32)
	assert_eq(source, before)


func test_default_focus_and_local_lightning_keep_view_contracts() -> void:
	var world: Node3D = load("res://app/living_root.tscn").instantiate()
	world.qa_mode = true
	add_child(world)
	assert_true(world.atmosphere.flash is OmniLight3D)
	assert_false(world.atmosphere.flash.shadow_enabled)
	assert_gte(world.atmosphere.flash.omni_range, 80.0)
	assert_eq(world.find_children("*", "DirectionalLight3D", true, false).size(), 1)
	var attributes: CameraAttributesPractical = world.camera_rig.camera.attributes
	assert_not_null(attributes)
	if attributes != null:
		assert_lte(attributes.dof_blur_amount, 0.06)
		assert_false(attributes.dof_blur_near_enabled)
		assert_gt(attributes.dof_blur_far_distance, world.camera_rig.distance + 5)
	world.soundscape.shutdown()
	await SceneShutdown.wait_wallclock(get_tree(), 0.4)
	await SceneShutdown.release_scene(world)
