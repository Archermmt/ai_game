extends GutTest

var garden: ProductionLandscapePlayground


func before_all() -> void:
	garden = load("res://app/living_root.tscn").instantiate() as ProductionLandscapePlayground
	garden.qa_mode = true
	add_child(garden)
	garden.saves.directory = "user://qa_weather_adoption/tests"
	garden.active_slot = -1
	garden.calendar.speed = 0
	var deadline: int = Time.get_ticks_msec() + 120000
	while (
		(not garden.landscape_ready or garden.queue.is_busy() or garden.stage.is_busy())
		and Time.get_ticks_msec() < deadline
	):
		await get_tree().process_frame
	assert_true(garden.landscape_ready)


func after_all() -> void:
	garden.seasonal_music.shutdown()
	garden.soundscape.shutdown()
	await SceneShutdown.wait_wallclock(get_tree(), 0.4)
	await SceneShutdown.release_scene(garden)


func test_headless_preserves_camera_and_uses_safe_sky_fallback() -> void:
	assert_not_null(garden.cloud_adapter)
	assert_false(garden.cloud_adapter.ready_for_clouds)
	assert_null(garden.camera_rig.camera.compositor)
	assert_null(garden.world_environment.compositor)
	assert_true(garden._cloud_views.is_empty())
	assert_true(garden.atmosphere.sky.material.get_shader_parameter("painted_clouds_enabled"))
	assert_null(BlanketShaders.select)


func test_terrain_snow_assets_preserve_authoritative_heightfield() -> void:
	# Headless cannot reflect native shader uniforms; the Metal probe checks bindings and pixels.
	assert_eq(ProductionTerrainRenderer.SNOW_DEPTH, 0.14)
	assert_true(
		ProductionTerrainRenderer.SNOW_ALBEDO.resource_path.begins_with("res://addons/puchik_snow/")
	)
	assert_true(
		ProductionTerrainRenderer.SNOW_NORMAL.resource_path.begins_with("res://addons/puchik_snow/")
	)
	assert_eq(garden.landscape_terrain.source_snapshot["terrain"], garden.document.state["terrain"])


func test_roof_envelopes_exist_for_rect_round_and_flat_without_changing_source_meshes() -> void:
	for shape: String in ["rect", "round", "flat"]:
		var home: Dictionary = garden.document.state["buildings"][0].duplicate(true)
		if shape == "round":
			home["shape"] = "round"
		elif shape == "flat":
			home["roof_rise"] = 0.0
		var shell: ArrayMesh = BuildingGeometry.build(home)
		var node: Node3D = CottageArt.decorate(home, shell, {"buildings": [home]})
		var roof: MeshInstance3D = node.get_node("HandLaidTiles")
		var before: Array = roof.mesh.surface_get_arrays(0).duplicate(true)
		var source: ArrayMesh = BlanketSnowRenderer.source_mesh(
			roof.mesh, Transform3D.IDENTITY, true
		)
		assert_eq(source.get_surface_count(), 1, shape)
		assert_eq(roof.mesh.surface_get_arrays(0), before, "Blanket cannot rewrite source roof")
		if source.get_surface_count() > 0:
			var normals: PackedVector3Array = source.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
			for normal: Vector3 in normals:
				assert_gt(normal.y, 0.1, "No snow volume is generated on roof underside")
		node.free()


func test_leaf_sprays_and_deciduous_crowns_are_not_solid_snow_sheets() -> void:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = preload("res://features/art_direction/materials/painted_foliage.gdshader")
	material.set_shader_parameter("season_deciduous", true)
	assert_eq(BlanketSnowRenderer._kind("foliage_painted_crownMesh", "", material), "")
	assert_eq(BlanketSnowRenderer._kind("bark_branching_trunkMesh", "", material), "nature")
	material.set_shader_parameter("season_deciduous", false)
	assert_eq(
		BlanketSnowRenderer._kind("foliage_full_pine_branch_padsMesh", "", material), "nature"
	)
	assert_eq(BlanketSnowRenderer._kind("foliage_drooping_pine_spraysMesh", "", material), "")
	assert_eq(BlanketSnowRenderer._kind("stone_closed_worn_bodyMesh", "", null), "nature")
	assert_eq(BlanketSnowRenderer._kind("anything", "HandLaidTiles", null), "roof")


func test_snow_season_changes_do_not_change_source_or_start_headless_compute() -> void:
	var source: Dictionary = garden.document.snapshot()
	var history: int = garden.session.history_count()
	garden.snow_cover.sync(0.98)
	assert_true(garden.snow_cover.visible)
	assert_false(garden.snow_cover.is_busy())
	assert_eq(garden.snow_cover.baked_count, 0)
	assert_null(BlanketShaders.select)
	garden.snow_cover.sync(0.0)
	assert_false(garden.snow_cover.visible)
	assert_eq(garden.document.snapshot(), source)
	assert_eq(garden.session.history_count(), history)


func test_source_mesh_adapter_handles_nonindexed_and_transformed_geometry() -> void:
	var source: BoxMesh = BoxMesh.new()
	var pose: Transform3D = Transform3D(
		Basis(Vector3.UP, 0.8).scaled(Vector3(2, 1, 3)), Vector3(4, 2, -3)
	)
	var converted: ArrayMesh = BlanketSnowRenderer.source_mesh(source, pose)
	var arrays: Array = converted.surface_get_arrays(0)
	assert_gt((arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size(), 0)
	assert_true(converted.get_aabb().is_equal_approx(pose * source.get_aabb()))
	for normal: Vector3 in arrays[Mesh.ARRAY_NORMAL]:
		assert_almost_eq(normal.length(), 1.0, 0.00001)
	assert_eq(source.get_aabb(), AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE))


func test_winter_eye_height_follows_visible_snow_without_moving_source_feet() -> void:
	assert_true(garden.enter_photo())
	assert_true(garden.start_walk())
	var field: TerrainField = TerrainField.new(garden.document.snapshot())
	garden.walk_controller.feet = Vector3(12, field.height_at(Vector2(12, 12)), 12)
	var before: Vector3 = garden.walk_controller.feet
	garden.calendar.month = 1
	garden.calendar.weather = "clear"
	garden.atmosphere.blend.advance(WeatherBlend.DURATION, garden.calendar.sample())
	for index: int in 3:
		await get_tree().process_frame
	assert_eq(garden.walk_controller.feet, before)
	assert_almost_eq(garden.walk_controller.eye_height, 1.65 + 0.14 * 0.98, 0.0001)
	garden.stop_walk()
	garden.exit_photo()


func test_footprint_projection_tracks_rendered_snow_surface() -> void:
	var source: Dictionary = garden.document.snapshot()
	var field: TerrainField = TerrainField.new(source)
	var prints: SnowFootprints = SnowFootprints.new()
	add_child(prints)
	prints.configure(source)
	prints.surface_offset = ProductionTerrainRenderer.SNOW_DEPTH * 0.98
	for index: int in 6:
		var point: Vector2 = Vector2(12 + float(index) * 0.25, 12)
		prints.update_contact(
			Vector3(point.x, field.height_at(point), point.y), -PI / 2, true, 0.98, 0.1
		)
	var records: Array[Dictionary] = prints.contact_records()
	assert_gt(records.size(), 0)
	for record: Dictionary in records:
		var point: Vector3 = record["point"]
		assert_almost_eq(point.y - field.height_at(Vector2(point.x, point.z)), 0.14 * 0.98, 0.0001)
	prints.shutdown()
	prints.free()


func test_only_buried_ground_paths_receive_prints_while_bridge_decks_stay_excluded() -> void:
	var road: Dictionary = WorldDocument.new().snapshot()
	PathGeometry.allocate(road, [[-3, 0, 0], [3, 0, 0]], 1.2)
	var prints: SnowFootprints = SnowFootprints.new()
	add_child(prints)
	prints.configure(road)
	prints.surface_offset = 0
	assert_null(prints._contact_height(Vector2.ZERO, 0))
	prints.surface_offset = 0.14 * 0.98
	assert_not_null(
		prints._contact_height(Vector2.ZERO, 0), "Buried paving is now a visible snow surface"
	)
	prints.surface_offset = 0.07
	assert_null(
		prints._contact_height(Vector2.ZERO, 0), "Exposed paving must not receive snow impressions"
	)
	var bridge: Dictionary = TerrainField.pond(WorldDocument.new().snapshot(), Vector2.ZERO, 2.3)
	GardenStructures.allocate(bridge, "bridge", Vector2(0, -3), Vector2(0, 3))
	prints.configure(bridge)
	prints.surface_offset = 0.14 * 0.98
	var support: Variant = prints._surface.ground_at(Vector2.ZERO)
	assert_not_null(support)
	assert_null(
		prints._contact_height(Vector2.ZERO, float(support)),
		"A bridge is not the displaced terrain snow surface"
	)
	prints.shutdown()
	prints.free()
