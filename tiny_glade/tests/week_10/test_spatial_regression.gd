extends GutTest


func test_cached_field_matches_exact_signed_distance_everywhere_on_art_pond() -> void:
	var source: Dictionary = ArtLayout.create()
	var field: TerrainField = TerrainField.new(source)
	for z: int in range(-24, 25):
		for x: int in range(-24, 25):
			var point: Vector2 = Vector2(x, z) + Vector2(0.13, 0.27)
			var original: float = field.player_height(point)
			var distance: float = PondShape.distance(source["pool"], point)
			var water: float = source["pool"]["water_y"]
			var expected: float = lerpf(water + 0.1, original, smoothstep(0, 0.75, distance))
			if distance <= -0.35:
				expected = water - 0.45
			elif distance <= 0:
				expected = lerpf(water - 0.45, water + 0.1, smoothstep(-0.35, 0, distance))
			assert_almost_eq(field.height_at(point), expected, 0.000001)


func test_building_and_shore_conflicts_reject_whole_transactions_both_directions() -> void:
	var source: Dictionary = PondShape.draw(
		WorldDocument.new().snapshot(), [[-3, -2], [3, -2], [3, 2], [-3, 2]]
	)
	WorldDocument.allocate_building(source, Vector3(5.76, 0, 0), Vector3(3, 3, 3))
	var document: WorldDocument = WorldDocument.new()
	var session: EditSession = EditSession.new(document)
	assert_true(session.replace_document(source)["ok"])
	var before: Dictionary = document.snapshot()
	var home: Dictionary = before.duplicate(true)
	home["buildings"][0]["position"][0] = 5.6
	var shore: Dictionary = PondShape.draw(before, [[-3, -2], [3.2, -2], [3.2, 2], [-3, 2]])
	for candidate: Dictionary in [home, shore]:
		var result: Dictionary = session.reserve_commit(candidate, "conflict")
		assert_false(result["ok"])
		assert_eq(result["error"], "pool_building_safety")
		assert_eq_deep(document.state, before)
		assert_eq(session.history_count(), 0)
	session.dispose()


func test_all_terrain_modes_preserve_art_pond_and_shore_heights() -> void:
	var source: Dictionary = ArtLayout.create()
	var point: Array = source["pool"]["outline"][0]
	var bank: Vector2 = Vector2(point[0], point[1])
	var height: float = TerrainField.new(source).height_at(bank)
	for mode: String in ["raise", "lower", "smooth", "restore"]:
		var edited: Dictionary = TerrainEdits.stroke(source, bank, mode, 2)
		assert_eq_deep(edited["pool"], source["pool"])
		assert_eq(TerrainField.new(edited).height_at(bank), height)


func test_locked_window_conflict_rejects_resize_without_changing_art_source() -> void:
	var source: Dictionary = ArtLayout.create()
	var home: Dictionary = source["buildings"][0]
	home["openings"] = [
		{
			"kind": "rect",
			"center": 0.5,
			"width": 3.4,
			"height": 1.2,
			"sill": 0.8,
			"source": "manual",
			"locked": true
		}
	]
	var document: WorldDocument = WorldDocument.new()
	var session: EditSession = EditSession.new(document)
	assert_true(session.replace_document(source)["ok"])
	var before: Dictionary = document.snapshot()
	var draft: Dictionary = before.duplicate(true)
	BuildingEdits.resize(draft, [home["id"]], Vector3(3, 3, 3))
	assert_false(session.reserve_commit(draft, "locked window")["ok"])
	assert_eq_deep(document.state, before)
	assert_eq(session.history_count(), 0)
	session.dispose()
