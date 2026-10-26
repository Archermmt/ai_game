extends GutTest
## Exercise the isolated preview, its inherited edits, and both actual renderers.

const SCENE: PackedScene = preload("res://app/grass_capacity.tscn")
var garden: Variant
var source: Dictionary


func before_all() -> void:
	garden = SCENE.instantiate()
	add_child(garden)
	await _ready_landscape(garden)
	source = garden.document.snapshot()


func after_all() -> void:
	await _release(garden)


func _ready_landscape(world: Variant) -> void:
	var deadline: int = Time.get_ticks_msec() + 120000
	while (
		not world.landscape_ready
		and not world.landscape_failed
		and Time.get_ticks_msec() < deadline
	):
		await get_tree().process_frame
	assert_true(world.landscape_ready and not world.landscape_failed)


func _release(world: Variant) -> void:
	world.soundscape.shutdown()
	await SceneShutdown.wait_wallclock(get_tree(), 0.4)
	await SceneShutdown.release_scene(world)


func test_capacity_preview_is_isolated_before_ready_and_uses_real_stress_source() -> void:
	assert_true(garden.qa_mode)
	assert_eq(garden.saves.directory, "user://qa_painterly_grass/g4/saves")
	assert_eq(garden.active_slot, -1)
	assert_true(garden.hud.photo_directory.text.contains("qa_painterly_grass/g4/photos"))
	assert_eq(source["buildings"].size(), 24)
	assert_eq(source["instances"].size(), 1000)
	assert_true(garden.meadow is ProductionGrassRenderer)
	assert_true(garden.landscape_terrain.data_ready)
	assert_gt(garden.meadow.visible_count(), 0)


func test_density_and_weather_controls_are_presentation_only() -> void:
	var history: int = garden.session.history_count()
	var versions: Dictionary = garden.meadow._published_versions.duplicate(true)
	for density: float in [0, 1, 0.45]:
		garden.set_capacity_density(density)
		assert_eq(garden.meadow.density, density)
		assert_eq(garden.meadow.visible_count() == 0, density == 0)
	for index: int in 4:
		garden.set_capacity_weather(index)
		assert_eq(garden.calendar.weather, ["clear", "storm", "blizzard", "duststorm"][index])
		assert_eq(garden.calendar.sample()["season"], "winter" if index == 2 else "summer")
	assert_eq(garden.document.snapshot(), source)
	assert_eq(garden.session.history_count(), history)
	assert_eq(garden.meadow._published_versions, versions)
	garden.set_capacity_weather(0)


func test_legacy_comparison_keeps_identical_source_and_native_terrain() -> void:
	var legacy: Variant = SCENE.instantiate()
	legacy.legacy_comparison = true
	add_child(legacy)
	await _ready_landscape(legacy)
	assert_false(legacy.meadow is ProductionGrassRenderer)
	assert_true(legacy.meadow is MeadowRenderer)
	assert_eq(legacy.document.snapshot(), source)
	assert_eq(
		legacy.landscape_terrain.published_signature, garden.landscape_terrain.published_signature
	)
	assert_true(legacy.landscape_terrain.data_ready)
	assert_eq(legacy.meadow.density, garden.meadow.density)
	assert_gt(legacy.meadow.visible_count(), 0)
	await _release(legacy)
