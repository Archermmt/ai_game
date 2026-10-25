extends GutTest
## Exercise the actual F5 scene while isolating all test IO before inherited ready.

const SCENE_PATH: String = "res://app/living_root.tscn"
const TRIANGLES: Array[int] = [24, 2288, 28, 8]
var garden: Variant
var original: Dictionary
var test_directory: String


func before_all() -> void:
	var packed: PackedScene = load(SCENE_PATH) as PackedScene
	garden = packed.instantiate()
	garden.qa_mode = true
	add_child(garden)
	test_directory = "user://qa_production_landscape/tests/%d" % Time.get_ticks_usec()
	garden.saves.directory = test_directory.path_join("saves")
	garden.hud.photo_directory.text = ProjectSettings.globalize_path(
		test_directory.path_join("photos")
	)
	garden.active_slot = -1
	garden.calendar.speed = 0
	garden.calendar.automatic_weather = false
	var deadline: int = Time.get_ticks_msec() + 120000
	while (
		not bool(garden.get("landscape_ready"))
		and not bool(garden.get("landscape_failed"))
		and Time.get_ticks_msec() < deadline
	):
		await get_tree().process_frame
	assert_true(
		_production_ready(), "The real F5 scene must finish its Terrain3D and four-layer setup"
	)
	await _settle()
	original = garden.document.snapshot()


func before_each() -> void:
	if not _production_ready():
		return
	if garden.photo_active:
		garden.exit_photo()
	garden.active_slot = -1
	garden._freeze_photo(false)
	garden.preferences.values["reduce_motion"] = false
	garden.preferences.values["grass_density"] = 0.45
	garden._apply_preferences()
	assert_true(garden.session.replace_document(original, garden._prepare_views)["ok"])
	await _settle()


func after_all() -> void:
	if is_instance_valid(garden):
		if garden.seasonal_music != null:
			garden.seasonal_music.shutdown()
		if garden.soundscape != null:
			garden.soundscape.shutdown()
		await SceneShutdown.wait_wallclock(get_tree(), 0.4)
		await SceneShutdown.release_scene(garden)
	for i: int in 8:
		await get_tree().process_frame


func _production_ready() -> bool:
	return (
		is_instance_valid(garden)
		and bool(garden.get("landscape_ready"))
		and not bool(garden.get("landscape_failed"))
	)


func _settle(core_only: bool = false) -> void:
	var deadline: int = Time.get_ticks_msec() + 60000
	while _busy(core_only) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	assert_false(_busy(core_only), "Source/core and current landscape views must finish")
	if not core_only and _production_ready():
		assert_eq(garden.meadow.published_signature, MeadowData.signature(garden.document.state))


func _busy(core_only: bool) -> bool:
	if (
		garden.queue.is_busy()
		or garden.stage.is_busy()
		or garden.saves.is_busy()
		or garden._loading
	):
		return true
	return not core_only and (garden.meadow.is_busy() or garden.landscape_terrain.is_busy())


func _commit(candidate: Dictionary, label: String, core_only: bool = false) -> void:
	var revision: int = garden.document.state["revision"]
	garden._submit_async(candidate, label)
	await _settle(core_only)
	assert_eq(garden.document.state["revision"], revision + 1, label)


func _without_revision(source: Dictionary) -> Dictionary:
	var value: Dictionary = source.duplicate(true)
	value.erase("revision")
	return value


func _surface_error(points: Array[Vector2]) -> float:
	var field: TerrainField = TerrainField.new(garden.document.snapshot())
	var maximum: float = 0.0
	for point: Vector2 in points:
		var height: float = garden.landscape_terrain.terrain.data.get_height(
			Vector3(point.x, 0, point.y)
		)
		assert_true(is_finite(height), "Native Terrain3D height must exist at the query")
		maximum = maxf(maximum, absf(height - field.height_at(point)))
	return maximum


func test_f5_uses_editable_production_scene_and_four_real_valley_models() -> void:
	assert_true(_production_ready())
	if not _production_ready():
		return
	assert_true(str(garden.get_script().resource_path).contains("production"))
	assert_true(garden.hud.visible and not garden.photo_active)
	assert_true(garden.saves.directory.begins_with("user://qa_production_landscape/tests/"))
	assert_eq(garden.meadow.meshes.size(), 4)
	assert_gt(garden.meadow.visible_count(), 0)
	for kind: int in 4:
		var mesh: Mesh = garden.meadow.meshes[kind]
		assert_eq(mesh.get_surface_count(), 1)
		var arrays: Array = mesh.surface_get_arrays(0)
		assert_eq((arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3, TRIANGLES[kind])
	var texture: Texture2D = garden.meadow.material.get_shader_parameter("coverage")
	assert_eq(texture.get_size(), Vector2(4096, 4096))
	assert_eq(garden.document.state.keys(), original.keys())
	assert_eq(garden.document.state["instances"], original["instances"])


func test_native_terrain_matches_authoritative_heightfield_and_pond_after_brush() -> void:
	if not _production_ready():
		assert_true(false, "Production landscape is required")
		return
	var points: Array[Vector2] = [
		Vector2.ZERO, Vector2(16, 16), Vector2(-20, -20), Vector2(20, -20), Vector2(-20, 20)
	]
	var pool: Dictionary = garden.document.state["pool"]
	if not pool.is_empty():
		points.append(Vector2(pool["center"][0], pool["center"][1]).snapped(Vector2.ONE * 0.25))
	assert_lt(_surface_error(points), 0.02)
	assert_eq(garden.landscape_terrain.terrain.transform, Transform3D.IDENTITY)
	await _commit(
		TerrainField.brush(garden.document.snapshot(), Vector2(16, 16), 0.4, 3),
		"Raise current terrain"
	)
	assert_lt(_surface_error(points), 0.02)
	assert_gt(
		TerrainField.new(garden.document.snapshot()).height_at(Vector2(16, 16)),
		TerrainField.new(original).height_at(Vector2(16, 16)) + 0.3
	)


func test_local_edit_reuses_distant_grass_and_undo_redo_restore_current_views() -> void:
	if not _production_ready():
		assert_true(false, "Production landscape is required")
		return
	var key: Vector2i = Vector2i(-3, -3)
	var retained: Array = garden.meadow.groups[key].duplicate()
	var versions: Dictionary = garden.meadow._published_versions.duplicate(true)
	await _commit(
		TerrainField.brush(garden.document.snapshot(), Vector2(16, 16), 0.2, 2), "Local slope"
	)
	assert_eq(garden.meadow.groups[key], retained)
	assert_gt(garden.meadow.reused_chunks, 0)
	assert_lt(garden.meadow.rebuilt_chunks, 36)
	garden._on_action(&"undo")
	await _settle()
	assert_eq(_without_revision(garden.document.snapshot()), _without_revision(original))
	assert_eq(garden.meadow._published_versions, versions)
	garden._on_action(&"redo")
	await _settle()
	assert_lt(_surface_error([Vector2(16, 16)]), 0.02)


func test_source_burial_offsets_and_protected_roots_survive_render_publication() -> void:
	if not _production_ready():
		assert_true(false, "Production landscape is required")
		return
	var source: Dictionary = garden.document.snapshot()
	var obstacles: Dictionary = MeadowData._obstacles(source)
	var field: TerrainField = TerrainField.new(source)
	var checked: int = 0
	var invalid: int = 0
	var maximum: float = 0.0
	var layer_counts: Array[int] = [0, 0, 0, 0]
	for key: Vector2i in garden.meadow.published_chunks:
		var kinds: Array = garden.meadow.published_chunks[key]
		assert_eq(kinds.size(), 4)
		for kind: int in 4:
			var items: Array = kinds[kind]
			layer_counts[kind] += items.size()
			for index: int in range(0, items.size(), 17):
				var item: Dictionary = items[index]
				var pose: Transform3D = item["pose"]
				var point: Vector2 = Vector2(pose.origin.x, pose.origin.z)
				invalid += int(
					not pose.is_finite() or not MeadowData.clear(point, obstacles, source["pool"])
				)
				maximum = maxf(
					maximum,
					absf(pose.origin.y - field.height_at(point) - float(item["ground_offset"]))
				)
				checked += 1
	for amount: int in layer_counts:
		assert_gt(amount, 0, "All four independent layers must have instances")
	assert_gt(checked, 40)
	assert_eq(invalid, 0, "Plants must stay out of buildings, roads and pond protection")
	assert_lt(maximum, 0.02)


func test_fifty_mixed_commits_undo_and_redo_keep_latest_source_and_meshes() -> void:
	if not _production_ready():
		assert_true(false, "Production landscape is required")
		return
	var initial: Dictionary = _without_revision(garden.document.snapshot())
	var initial_versions: Dictionary = garden.meadow._published_versions.duplicate(true)
	for index: int in 50:
		var candidate: Dictionary = garden.document.snapshot()
		match index % 5:
			0:
				candidate = TerrainField.brush(candidate, Vector2(16, 16), 0.01, 2)
			1:
				candidate["buildings"][0]["size"][1] += 0.01
			2:
				candidate["paths"][0]["width"] += 0.005
			3:
				candidate["instances"][0]["position"][0] += 0.005
			4:
				candidate["bridges"][0]["width"] += 0.005
		await _commit(candidate, "Production edit %d" % index, true)
	await _settle()
	assert_eq(garden.session.history_count(), 50)
	var final: Dictionary = _without_revision(garden.document.snapshot())
	var final_versions: Dictionary = garden.meadow._published_versions.duplicate(true)
	for index: int in 50:
		garden._on_action(&"undo")
		await _settle(true)
	await _settle()
	assert_eq(_without_revision(garden.document.snapshot()), initial)
	assert_eq(garden.meadow._published_versions, initial_versions)
	for index: int in 50:
		garden._on_action(&"redo")
		await _settle(true)
	await _settle()
	assert_eq(_without_revision(garden.document.snapshot()), final)
	assert_eq(garden.meadow._published_versions, final_versions)
	assert_lt(_surface_error([Vector2(16, 16), Vector2.ZERO]), 0.02)


func test_isolated_save_load_regenerates_the_same_terrain_and_grass() -> void:
	if not _production_ready():
		assert_true(false, "Production landscape is required")
		return
	var source: Dictionary = _without_revision(garden.document.snapshot())
	var versions: Dictionary = garden.meadow._published_versions.duplicate(true)
	garden._start_save(0, "Production landscape regression")
	await _settle()
	var saved: Dictionary = SlotStore.read_slot(garden.saves.directory, 0)
	assert_true(saved["ok"])
	assert_eq(_without_revision(saved["snapshot"]), source)
	await _commit(
		TerrainField.brush(garden.document.snapshot(), Vector2(16, 16), 0.2, 2), "Edit after save"
	)
	garden._start_load(0)
	await _settle()
	assert_eq(_without_revision(garden.document.snapshot()), source)
	assert_eq(garden.meadow._published_versions, versions)
	assert_lt(_surface_error([Vector2.ZERO, Vector2(16, 16)]), 0.02)


func test_density_seasons_freeze_and_reduced_motion_do_not_edit_world_source() -> void:
	if not _production_ready():
		assert_true(false, "Production landscape is required")
		return
	var source: Dictionary = garden.document.snapshot()
	var history: int = garden.session._history.get_version()
	var versions: Dictionary = garden.meadow._published_versions.duplicate(true)
	garden.meadow.set_density(0)
	assert_eq(garden.meadow.visible_count(), 0)
	garden.meadow.set_density(1)
	await _settle()
	assert_eq(garden.meadow.visible_count(), garden.meadow.total)
	for month: int in [4, 7, 10, 1]:
		garden.calendar.month = month
		garden.calendar.weather = "clear"
		garden.atmosphere.blend.advance(0, garden.calendar.sample())
		garden.atmosphere.blend.advance(18, garden.calendar.sample())
		garden.atmosphere.update(0, garden.calendar.sample())
	garden._freeze_photo(true)
	assert_true(garden.meadow.material.get_shader_parameter("freeze_time"))
	garden._freeze_photo(false)
	assert_false(garden.meadow.material.get_shader_parameter("freeze_time"))
	garden.preferences.values["reduce_motion"] = true
	garden._apply_preferences()
	assert_true(garden.meadow.material.get_shader_parameter("reduce_motion"))
	assert_eq(garden.document.snapshot(), source)
	assert_eq(garden.session._history.get_version(), history)
	assert_eq(garden.meadow._published_versions, versions)
	for batch: MultiMeshInstance3D in garden.meadow.batches:
		assert_eq(batch.layers & PondReflections.REFLECTION_LAYER, 0)


func test_cancelled_brush_and_pending_zero_density_requests_never_publish_old_source() -> void:
	if not _production_ready():
		assert_true(false, "Production landscape is required")
		return
	var source: Dictionary = garden.document.snapshot()
	var history: int = garden.session._history.get_version()
	var original_height: float = TerrainField.new(source).height_at(Vector2(16, 16))
	garden.tools.mode = "raise"
	garden._last_point = Vector3(16, original_height, 16)
	assert_true(garden.session.begin_gesture())
	assert_true(garden.session.update_gesture(TerrainField.brush(source, Vector2(16, 16), 0.4, 2)))
	garden._preview_tool()
	await _settle()
	await get_tree().process_frame
	assert_eq(garden.document.snapshot(), source)
	assert_eq(garden.session._history.get_version(), history)
	assert_eq(
		garden.landscape_terrain.source_snapshot["terrain"], garden.session.preview["terrain"]
	)
	var preview_height: float = garden.landscape_terrain.terrain.data.get_height(Vector3(16, 0, 16))
	assert_almost_eq(preview_height, original_height + 0.4, 0.02)
	assert_true(garden.landscape_terrain.visible, "The current preview must use the native surface")
	garden._cancel_edit()
	await _settle()
	assert_eq(garden.document.snapshot(), source)
	assert_eq(garden.session._history.get_version(), history)
	assert_eq(garden.landscape_terrain.source_snapshot["terrain"], source["terrain"])
	assert_almost_eq(
		garden.landscape_terrain.terrain.data.get_height(Vector3(16, 0, 16)), original_height, 0.02
	)
	garden.tools.mode = "inspect"
	garden.meadow.set_density(0)
	await _commit(
		TerrainField.brush(source, Vector2(16, 16), 0.03, 2), "Edit while grass hidden", true
	)
	garden.meadow.set_density(0.45)
	await _settle()
	assert_gt(garden.meadow.visible_count(), 0)
	assert_eq(garden.meadow.published_signature, MeadowData.signature(garden.document.state))
	assert_lt(_surface_error([Vector2(16, 16)]), 0.02)
