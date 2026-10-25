extends GutTest

var garden: PainterlyGrassGarden
var original: Dictionary


func before_all() -> void:
	garden = preload("res://app/painterly_grass_garden.tscn").instantiate()
	garden.preview_directory = "user://qa_painterly_grass/tests/g3_%d" % Time.get_ticks_usec()
	assert_true(garden.qa_mode)
	add_child(garden)
	var deadline: int = Time.get_ticks_msec() + 60000
	while not garden.garden_ready and not garden.garden_failed and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	assert_true(garden.garden_ready)
	garden.calendar.speed = 0
	original = garden.document.snapshot()


func before_each() -> void:
	garden.set_grass_variant(true)
	if garden.photo_active:
		garden.exit_photo()
	garden._freeze_photo(false)
	garden.preferences.values["reduce_motion"] = false
	garden._apply_preferences()
	assert_true(garden.session.replace_document(original, garden._prepare_views)["ok"])
	await _settle()


func after_all() -> void:
	garden.seasonal_music.shutdown()
	garden.soundscape.shutdown()
	await SceneShutdown.wait_wallclock(get_tree(), 0.4)
	await SceneShutdown.release_scene(garden)
	for i: int in 8:
		await get_tree().process_frame


func _settle() -> void:
	var deadline: int = Time.get_ticks_msec() + 30000
	while (
		(
			garden.queue.is_busy()
			or garden.stage.is_busy()
			or garden.meadow.is_busy()
			or garden.saves.is_busy()
			or garden._loading
		)
		and Time.get_ticks_msec() < deadline
	):
		await get_tree().process_frame
	assert_false(
		(
			garden.queue.is_busy()
			or garden.stage.is_busy()
			or garden.meadow.is_busy()
			or garden.saves.is_busy()
			or garden._loading
		)
	)
	assert_eq(
		garden.grass_renderer.published_signature, MeadowData.signature(garden.document.state)
	)


func _commit(candidate: Dictionary, label: String) -> void:
	var revision: int = garden.document.state["revision"]
	garden._submit_async(candidate, label)
	await _settle()
	assert_eq(garden.document.state["revision"], revision + 1, label)


func _without_revision(snapshot: Dictionary) -> Dictionary:
	var copy: Dictionary = snapshot.duplicate(true)
	copy.erase("revision")
	return copy


func test_f6_is_editable_and_uses_exclusive_persistent_preview_storage() -> void:
	assert_false(garden.photo_active)
	assert_true(garden.hud.visible)
	assert_eq(garden.saves.directory, garden.preview_directory.path_join("saves"))
	assert_true(garden.hud.photo_directory.text.contains("qa_painterly_grass/tests/"))
	garden.preferences.values["grass_density"] = 0.37
	garden._persist_preferences()
	var readback: UserPreferences = UserPreferences.new()
	assert_eq(readback.load_file(garden.preview_directory.path_join("preferences.cfg")), OK)
	assert_almost_eq(readback.values["grass_density"], 0.37, 0.001)
	assert_eq(garden.document.state["instances"], original["instances"])


func test_density_zero_latest_request_empty_blocks_and_one_are_supported() -> void:
	var renderer: PainterlyGardenGrassRenderer = garden.grass_renderer
	renderer.set_density(0)
	assert_eq(renderer.visible_count(), 0)
	var latest: Dictionary = TerrainField.brush(
		garden.document.snapshot(), Vector2(16, 16), 0.03, 2
	)
	assert_true(
		garden.session.commit_snapshot(latest, "zero density edit", garden._prepare_views)["ok"]
	)
	renderer.set_density(1)
	await _settle()
	assert_eq(renderer.visible_count(), renderer.total)
	assert_gt(renderer.total, 5000)
	renderer.set_density(0.45)
	assert_gt(renderer.visible_count(), 0)
	assert_lt(renderer.visible_count(), renderer.total)
	assert_true(PainterlyGardenGrassData.clear(Vector2(20, 20), 0.5, {}, {}))
	assert_false(PainterlyGardenGrassData.clear(Vector2(23.8, 20), 0.5, {}, {}))


func test_local_terrain_edit_reuses_far_chunk_nodes_and_keeps_distribution() -> void:
	var renderer: PainterlyGardenGrassRenderer = garden.grass_renderer
	var distant: Vector2i = Vector2i(-3, -3)
	var retained: Array = renderer.groups[distant].duplicate()
	var previous: Array = renderer._published_versions[distant].duplicate()
	await _commit(
		TerrainField.brush(garden.document.snapshot(), Vector2(16, 16), 0.1, 2), "raise slope"
	)
	assert_eq(renderer.groups[distant], retained)
	assert_eq(renderer._published_versions[distant], previous)
	assert_gt(renderer.reused_chunks, 0)
	assert_lt(renderer.rebuilt_chunks, 36)


func test_building_path_tree_pool_and_bridge_changes_preserve_unaffected_chunks() -> void:
	var renderer: PainterlyGardenGrassRenderer = garden.grass_renderer
	var distant: Vector2i = Vector2i(-3, -3)
	var baseline: Array = renderer._published_versions[distant].duplicate()
	for kind: int in 5:
		var candidate: Dictionary = garden.document.snapshot()
		match kind:
			0:
				candidate["buildings"][2]["position"][0] -= 0.02
				candidate["buildings"][2]["size"][0] += 0.02
				candidate["buildings"][2]["size"][2] += 0.02
			1:
				candidate["paths"][0]["width"] += 0.02
			2:
				candidate["instances"][0]["position"][0] += 0.03
			3:
				candidate["pool"]["outline"][0][0] += 0.01
			4:
				candidate["bridges"][0]["width"] += 0.01
		await _commit(candidate, "clearance edit %d" % kind)
		assert_eq(renderer._published_versions[distant], baseline)
		assert_gt(renderer.reused_chunks, 0)


func test_brush_erase_preserves_manual_locked_ids_and_source_schema() -> void:
	var candidate: Dictionary = garden.document.snapshot()
	var preserved: Array = candidate["instances"].filter(
		func(i: Dictionary) -> bool: return i["source"] == "manual" or i["locked"]
	)
	assert_gt(VegetationBrush.paint(candidate, Vector2(16, 16), "plants", 2, 1, {}), 0)
	await _commit(candidate, "paint vegetation")
	candidate = garden.document.snapshot()
	assert_gt(VegetationBrush.paint(candidate, Vector2(16, 16), "plants", 2, 1, {}, true), 0)
	await _commit(candidate, "erase vegetation")
	for item: Dictionary in preserved:
		assert_true(garden.document.state["instances"].has(item))
	assert_eq(garden.document.state["schema_version"], original["schema_version"])
	assert_eq(garden.document.state.keys(), original.keys())


func test_latest_worker_variant_switch_and_cancel_never_publish_stale_data() -> void:
	var source: Dictionary = garden.document.snapshot()
	var version: int = garden.session._history.get_version()
	for i: int in 6:
		garden.set_grass_variant(i % 2 == 0)
	garden.set_grass_variant(true)
	await _commit(
		TerrainField.brush(source, Vector2(16, 16), 0.04, 2), "latest geometry during variant load"
	)
	source = garden.document.snapshot()
	version = garden.session._history.get_version()
	assert_true(garden.session.begin_gesture())
	assert_true(garden.session.update_gesture(TerrainField.brush(source, Vector2(16, 16), 0.3, 2)))
	garden._cancel_edit()
	await _settle()
	assert_eq(garden.document.snapshot(), source)
	assert_eq(garden.session._history.get_version(), version)
	assert_true(garden.grass_renderer.use_new_grass)
	for view: MultiMeshInstance3D in garden.meadow.batches:
		assert_same(view.material_override, garden.meadow.material)


func test_fifty_mixed_edits_undo_redo_restore_source_and_derived_versions() -> void:
	var initial: Dictionary = _without_revision(garden.document.snapshot())
	var initial_versions: Dictionary = garden.grass_renderer._published_versions.duplicate(true)
	for i: int in 50:
		var candidate: Dictionary = garden.document.snapshot()
		match i % 5:
			0:
				candidate = TerrainField.brush(candidate, Vector2(16, 16), 0.01, 2)
			1:
				candidate["buildings"][0]["size"][1] += 0.01
			2:
				candidate["buildings"][2]["size"][0] += 0.01
				candidate["buildings"][2]["size"][2] += 0.01
			3:
				candidate["paths"][0]["width"] += 0.005
			4:
				candidate["instances"][0]["position"][0] += 0.01
		await _commit(candidate, "mixed edit %d" % i)
	assert_eq(garden.session.history_count(), 50)
	var final: Dictionary = _without_revision(garden.document.snapshot())
	var final_versions: Dictionary = garden.grass_renderer._published_versions.duplicate(true)
	for i: int in 50:
		garden._on_action(&"undo")
		await _settle()
	assert_eq(_without_revision(garden.document.snapshot()), initial)
	assert_eq(garden.grass_renderer._published_versions, initial_versions)
	for i: int in 50:
		garden._on_action(&"redo")
		await _settle()
	assert_eq(_without_revision(garden.document.snapshot()), final)
	assert_eq(garden.grass_renderer._published_versions, final_versions)


func test_isolated_save_load_regenerates_identical_grass_and_legacy_source() -> void:
	var saved: Dictionary = _without_revision(garden.document.snapshot())
	var versions: Dictionary = garden.grass_renderer._published_versions.duplicate(true)
	garden._start_save(0, "G3 regression")
	await _settle()
	var slot: Dictionary = SlotStore.read_slot(garden.saves.directory, 0)
	assert_true(slot["ok"])
	assert_eq(_without_revision(slot["snapshot"]), saved)
	await _commit(
		TerrainField.brush(garden.document.snapshot(), Vector2(16, 16), 0.03, 2),
		"modify after save"
	)
	garden._start_load(0)
	await _settle()
	assert_eq(_without_revision(garden.document.snapshot()), saved)
	assert_eq(garden.grass_renderer._published_versions, versions)


func test_seasons_weather_freeze_reduce_motion_and_reflection_layers_share_interfaces() -> void:
	var renderer: PainterlyGardenGrassRenderer = garden.grass_renderer
	var versions: Dictionary = renderer._published_versions.duplicate(true)
	for month: int in [4, 7, 10, 1]:
		for weather: String in ["clear", "cloudy"]:
			garden.calendar.month = month
			garden.calendar.weather = weather
			garden.atmosphere.blend.advance(0, garden.calendar.sample())
			garden.atmosphere.blend.advance(18, garden.calendar.sample())
			garden.atmosphere.update(0, garden.calendar.sample())
			assert_eq(renderer._published_versions, versions)
	garden._freeze_photo(true)
	assert_true(renderer.material.get_shader_parameter("freeze_time"))
	assert_true(renderer.old_material.get_shader_parameter("freeze_time"))
	garden._freeze_photo(false)
	assert_false(renderer.material.get_shader_parameter("freeze_time"))
	garden.preferences.values["reduce_motion"] = true
	garden._sync_wind(garden.document.state)
	assert_true(renderer.material.get_shader_parameter("reduce_motion"))
	for view: MultiMeshInstance3D in renderer.batches:
		assert_eq(view.layers & PondReflections.REFLECTION_LAYER, 0)


func test_empty_chunk_publication_clears_old_views_and_can_recover() -> void:
	var renderer: PainterlyGardenGrassRenderer = garden.grass_renderer
	renderer._deliver(
		renderer._token,
		{
			"chunks": {},
			"buffers": {},
			"versions": {},
			"images": {},
			"count": 0,
			"worker_ms": 0,
			"new_grass": true,
			"signature": MeadowData.signature(garden.document.state)
		}
	)
	await _settle()
	assert_eq(renderer.batches.size(), 0)
	assert_eq(renderer.groups.size(), 0)
	assert_eq(renderer.visible_count(), 0)
	renderer.request(garden.document.snapshot(), true)
	await _settle()
	assert_gt(renderer.visible_count(), 0)


func test_height_layers_match_mesh_roots_and_clearance_covers_full_wind() -> void:
	var source: Dictionary = garden.document.snapshot()
	var cache: Dictionary = {}
	var data: Dictionary = PainterlyGardenGrassData.generate(source, cache, true)
	var obstacles: Dictionary = PainterlyGardenGrassData.clearance_index(source)
	var field: TerrainField = TerrainField.new(source)
	var max_error: float = 0
	for key: Vector2i in data["chunks"]:
		var image: Image = data["images"][key]
		for kind: int in 3:
			var points: PackedVector3Array = (
				garden.grass_renderer.meshes[kind].surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			)
			for item: Dictionary in data["chunks"][key][kind]:
				var origin: Vector3 = item["p"]
				var radius: float = (
					(0.55 if kind == 2 else 0.20) * item["scale"] + (0.025 if kind == 2 else 0.16)
				)
				assert_true(
					PainterlyGardenGrassData.clear(
						Vector2(origin.x, origin.z), radius, obstacles, source["pool"]
					)
				)
				var pose: Transform3D = Transform3D(
					Basis(Vector3.UP, item["yaw"]).scaled(Vector3.ONE * item["scale"]), origin
				)
				for point: Vector3 in points:
					if point.y > 0.00001:
						continue
					var p: Vector3 = pose * point
					var local: Vector2 = (
						Vector2(p.x, p.z)
						- Vector2(key) * 8
						+ Vector2.ONE
						+ PainterlyGrassPatchData.MAP_ORIGIN
					)
					max_error = maxf(
						max_error,
						absf(
							(
								PainterlyGrassPatchData.sampled_height(image, local)
								- field.height_at(Vector2(p.x, p.z))
							)
						)
					)
	assert_lt(max_error, 0.02)
	var output: FileAccess = FileAccess.open(
		"res://reports/week_14/g3/root_error.json", FileAccess.WRITE
	)
	output.store_string(JSON.stringify({"max_error_m": max_error, "limit_m": 0.02}))
	output.close()


func test_height_cache_tracks_seed_quarter_spacing_halo_and_brushed_surface() -> void:
	var source: Dictionary = garden.document.snapshot()
	var changed: Dictionary = source.duplicate(true)
	changed["world_seed"] = "g3-other-seed"
	assert_ne(
		PainterlyGardenGrassData.height_key(source, Vector2i.ZERO),
		PainterlyGardenGrassData.height_key(changed, Vector2i.ZERO)
	)
	changed = source.duplicate(true)
	changed["terrain"]["spacing"] = 0.25
	var before: String = PainterlyGardenGrassData.height_key(changed, Vector2i(0, 2))
	# x=8.75 is outside the chunk but inside a wide-card root's terrain-map halo.
	changed["terrain"]["height_deltas"].append([163, 196, 0.3])
	assert_ne(before, PainterlyGardenGrassData.height_key(changed, Vector2i(0, 2)))
	var errors: Array[float] = []
	for profile: String in ["flat", "rolling_hills_v2", "brushed"]:
		var fixture: Dictionary = source.duplicate(true)
		fixture["pool"] = {}
		if profile == "flat":
			fixture["terrain"]["base_profile"] = "flat"
			fixture["terrain"]["height_deltas"] = []
		elif profile == "brushed":
			fixture = TerrainField.brush(fixture, Vector2(19, 19), 0.7, 3)
		var field: TerrainField = TerrainField.new(fixture)
		var image: Image = PainterlyGardenGrassData.height_image(field, Vector2i(2, 2))
		var maximum: float = 0
		for z: int in 41:
			for x: int in 41:
				var p: Vector2 = Vector2(15.1, 15.1) + Vector2(x, z) * 0.24
				var mapped: Vector2 = p - Vector2(15, 15) + PainterlyGrassPatchData.MAP_ORIGIN
				maximum = maxf(
					maximum,
					absf(PainterlyGrassPatchData.sampled_height(image, mapped) - field.height_at(p))
				)
		errors.append(maximum)
		assert_lt(maximum, 0.02)
	for kind: int in 3:
		var points: PackedVector3Array = garden.grass_renderer.meshes[kind].surface_get_arrays(0)[
			Mesh.ARRAY_VERTEX
		]
		var extent: float = 0
		for point: Vector3 in points:
			extent = maxf(extent, Vector2(point.x, point.z).length())
		var wind: float = 0.1 * 1.22 * 1.1 * (0.08 if kind == 2 else 1.0)
		assert_lte(
			extent * 1.1 + wind,
			(0.55 if kind == 2 else 0.20) * 1.1 + (0.025 if kind == 2 else 0.16)
		)
	var output: FileAccess = FileAccess.open(
		"res://reports/week_14/g3/surface_errors.json", FileAccess.WRITE
	)
	output.store_string(
		JSON.stringify(
			{"profiles": ["flat", "rolling", "brushed"], "max_errors_m": errors, "limit_m": 0.02}
		)
	)
	output.close()
