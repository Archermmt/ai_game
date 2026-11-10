extends GutTest


func test_contacts_are_reproducible_arrays_and_do_not_enter_saved_state() -> void:
	var source: Dictionary = WoodlandLayout.create()
	var before: PackedByteArray = SaveCodec.encode(source)
	var a: Dictionary = WoodlandContacts.generate(source)
	var b: Dictionary = WoodlandContacts.generate(source)
	assert_eq_deep(a, b)
	assert_eq(SaveCodec.encode(source), before)
	assert_gt(a["patches"].size(), 100)
	assert_lte(a["patches"].size(), WoodlandContacts.LIMIT)
	var kinds: Dictionary = {}
	for patch: Dictionary in a["patches"]:
		kinds[patch["kind"]] = true
	assert_eq(kinds.size(), 4, "Wall, roots, path verge and pond bank all have transitions")
	var view: MeshInstance3D = WoodlandContacts.view(a)
	assert_eq(view.mesh.get_surface_count(), 1)
	assert_eq(view.material_override.shader, WoodlandContacts.SHADER)
	view.free()


func test_contacts_leave_entrances_paths_bridges_and_manual_props_clear() -> void:
	var source: Dictionary = WoodlandLayout.create()
	var obstacles: Dictionary = MeadowData._obstacles(source)
	var data: Dictionary = WoodlandContacts.generate(source)
	var blocked: int = 0
	for patch: Dictionary in data["patches"]:
		var p: Vector3 = patch["p"]
		if not WoodlandContacts.allowed(source, obstacles, Vector2(p.x, p.z)):
			blocked += 1
	assert_eq(blocked, 0)
	# Check an actual doorway and bridge centre, not only accepted samples.
	var home: Dictionary = source["buildings"][0]
	var opening: Dictionary = home["openings"][0]
	var door: Vector3 = BuildingGeometry._point(
		opening["center"] * home["size"][0], 0, home["size"][0], home["size"][2], false
	)
	var point: Vector2 = Vector2(home["position"][0] + door.x, home["position"][2] + door.z + 0.4)
	assert_false(WoodlandContacts.allowed(source, obstacles, point))
	var bridge: Dictionary = source["bridges"][0]
	point = Vector2(bridge["a"][0] + bridge["b"][0], bridge["a"][1] + bridge["b"][1]) * 0.5
	assert_false(WoodlandContacts.allowed(source, obstacles, point))


func test_terrain_and_object_edits_invalidate_contacts_but_weather_and_camera_do_not() -> void:
	var source: Dictionary = WoodlandLayout.create()
	var original: String = WoodlandContacts.signature(source)
	for key: String in ["buildings", "instances", "paths", "pool", "terrain", "bridges", "stairs"]:
		var changed: Dictionary = source.duplicate(true)
		if key == "terrain":
			changed[key]["height_deltas"].append([64, 64, 0.15])
		elif key == "pool":
			changed[key] = {}
		else:
			changed[key].clear()
		assert_ne(WoodlandContacts.signature(changed), original, key)
	var presentation: Dictionary = source.duplicate(true)
	presentation["environment"]["wind_strength"] = 0.8
	presentation["camera_bookmarks"] = []
	presentation["revision"] += 1
	assert_eq(WoodlandContacts.signature(presentation), original)


func test_removing_objects_removes_their_transitions_and_restore_is_exact() -> void:
	var source: Dictionary = WoodlandLayout.create()
	var original: Dictionary = WoodlandContacts.generate(source)
	var changed: Dictionary = source.duplicate(true)
	changed["buildings"] = []
	changed["pool"] = {}
	changed["paths"] = []
	changed["instances"] = []
	assert_true(WoodlandContacts.generate(changed)["patches"].is_empty())
	assert_eq_deep(WoodlandContacts.generate(source), original)
	var empty_view: MeshInstance3D = WoodlandContacts.view(WoodlandContacts.generate(changed))
	assert_null(empty_view.mesh)
	empty_view.free()


func test_contacts_follow_ground_after_slope_edits_and_keep_finite_vertices() -> void:
	var source: Dictionary = WoodlandLayout.create()
	source["terrain"]["height_deltas"] = [[64, 64, 0.3], [65, 64, 0.18]]
	var field: TerrainField = TerrainField.new(source)
	var data: Dictionary = WoodlandContacts.generate(source)
	var maximum_error: float = 0
	for patch: Dictionary in data["patches"]:
		var p: Vector3 = patch["p"]
		maximum_error = maxf(maximum_error, absf(p.y - field.height_at(Vector2(p.x, p.z)) - 0.008))
	assert_lt(maximum_error, 0.0001)
	var invalid: int = 0
	for vertex: Vector3 in data["arrays"][Mesh.ARRAY_VERTEX]:
		if not vertex.is_finite():
			invalid += 1
	assert_eq(invalid, 0)


func test_meadow_swathes_are_bounded_coherent_and_not_uniform() -> void:
	var minimum: float = 1
	var maximum: float = 0
	var discontinuity: float = 0
	for x: int in range(-20, 21):
		var p: Vector2 = Vector2(x, 2.5)
		var value: float = ProductionGrassData.meadow_drift(p)
		minimum = minf(minimum, value)
		maximum = maxf(maximum, value)
		discontinuity = maxf(
			discontinuity, absf(value - ProductionGrassData.meadow_drift(p + Vector2(0.05, 0)))
		)
	assert_gte(minimum, 0.0)
	assert_lte(maximum, 1.0)
	assert_gt(maximum - minimum, 0.5)
	assert_lt(discontinuity, 0.02)


func test_moist_bank_mask_tracks_actual_pond_and_does_not_change_heightfield() -> void:
	var source: Dictionary = WoodlandLayout.create()
	var before: Dictionary = source.duplicate(true)
	var maps: Dictionary = ProductionTerrainRenderer.build_maps(source)
	var field: TerrainField = TerrainField.new(source)
	# Polygon pool.center is its first authored shore point, not its centroid.
	var center: Vector2 = Vector2.ZERO
	var contour: PackedVector2Array = PondShape.contour(source["pool"])
	for point: Vector2 in contour:
		center += point / contour.size()
	assert_lt(PondShape.distance(source["pool"], center), -0.5)
	var pixel: Vector2i = Vector2i((center + Vector2.ONE * 32) * 4)
	assert_gt(maps["bank"].get_pixel(pixel.x, pixel.y).r, 0.9)
	assert_eq(maps["bank"].get_pixel(8, 8).r, 0.0)
	assert_almost_eq(
		maps["height"].get_pixel(pixel.x, pixel.y).r,
		field.height_at(Vector2(pixel) * 0.25 - Vector2.ONE * 32),
		0.0001
	)
	assert_eq_deep(source, before)
	source["pool"] = {}
	var empty_maps: Dictionary = ProductionTerrainRenderer.build_maps(source)
	assert_eq(empty_maps["bank"].get_pixel(pixel.x, pixel.y).r, 0.0)
