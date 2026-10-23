extends GutTest


func test_calendar_rolls_minute_day_month_and_year() -> void:
	var clock: CalendarState = CalendarState.new()
	clock.month = 12
	clock.day = 30
	clock.minute_of_day = 1439.5
	clock.advance(1)
	assert_eq([clock.year, clock.month, clock.day], [2, 1, 1])
	assert_almost_eq(clock.minute_of_day, 0.5, 0.0001)


func test_pause_and_speed_are_independent_from_wall_clock() -> void:
	var clock: CalendarState = CalendarState.new()
	clock.speed = 0
	var before: Dictionary = clock.record()
	clock.advance(100)
	assert_eq(clock.record(), before)
	clock.speed = 60
	clock.advance(2)
	assert_eq(clock.minute_of_day, 750.0)


func test_large_delta_rolls_multiple_years() -> void:
	var clock: CalendarState = CalendarState.new()
	clock.month = 1
	clock.day = 1
	clock.minute_of_day = 0
	clock.advance(1440.0 * 721)
	assert_eq([clock.year, clock.month, clock.day], [3, 1, 2])


func test_seasons_follow_months() -> void:
	var clock: CalendarState = CalendarState.new()
	for pair: Array in [
		[1, "winter"], [4, "spring"], [7, "summer"], [10, "autumn"], [12, "winter"]
	]:
		clock.month = pair[0]
		assert_eq(clock.season(), pair[1])


func test_invalid_clock_data_is_rejected_without_mutation() -> void:
	var clock: CalendarState = CalendarState.new()
	var before: Dictionary = clock.record()
	for pair: Array in [
		["month", 13],
		["day", 0],
		["year", -1],
		["minute_of_day", 1440],
		["speed", -1],
		["weather", "bad"],
		["month", "4"],
		["day", 2.5]
	]:
		var bad: Dictionary = before.duplicate()
		bad[pair[0]] = pair[1]
		assert_false(clock.restore(bad))
		assert_eq(clock.record(), before)


func test_clock_roundtrip_in_save_presentation_and_legacy() -> void:
	var clock: CalendarState = CalendarState.new()
	clock.weather = "snow"
	clock.month = 1
	var source: Dictionary = WorldDocument.new().snapshot()
	var unpacked: Dictionary = SnapshotDto.unpack(
		SnapshotDto.pack(source, "四季", {"calendar": clock.record()})
	)
	assert_true(unpacked["ok"])
	var restored: CalendarState = CalendarState.new()
	assert_true(restored.restore(unpacked["metadata"]["presentation"]["calendar"]))
	assert_eq(restored.record(), clock.record())
	assert_true(SnapshotDto.unpack(SnapshotDto.pack(source, "旧作"))["ok"])
	assert_false(SnapshotDto.valid_presentation({"calendar": {}}))


func test_relief_new_demo_is_valid_and_preserves_source_identity() -> void:
	var before: Dictionary = ArtLayout.create()
	var source: Dictionary = TerrainRelief.apply(before)
	assert_eq(WorldDocument.validate(source), "")
	assert_eq(source["buildings"], before["buildings"])
	assert_ne(source["terrain"], before["terrain"])
	assert_eq(before["terrain"]["base_profile"], "forest_slope_v1")
	assert_eq(source["pool"], before["pool"])
	assert_eq(source["instances"], before["instances"])


func test_relief_has_hills_hollows_and_seed_repeatability() -> void:
	var source: Dictionary = TerrainRelief.apply(ArtLayout.empty())
	var a: TerrainField = TerrainField.new(source)
	var b: TerrainField = TerrainField.new(source.duplicate(true))
	var high: float = -100
	var low: float = 100
	for x: int in range(-24, 25, 2):
		for z: int in range(-24, 25, 2):
			var p: Vector2 = Vector2(x, z)
			assert_eq(a.height_at(p), b.height_at(p))
			high = maxf(high, a.height_at(p))
			low = minf(low, a.height_at(p))
	assert_gt(high - low, 2.0)
	source["world_seed"] = "another-valley"
	var c: TerrainField = TerrainField.new(source)
	assert_ne(a.height_at(Vector2(18, 17)), c.height_at(Vector2(18, 17)))


func test_old_flat_world_still_flat() -> void:
	var field: TerrainField = TerrainField.new(WorldDocument.new().snapshot())
	assert_eq(field.height_at(Vector2(17, 11)), 0.0)


func test_new_ground_contacts_and_cache_keys() -> void:
	var source: Dictionary = TerrainRelief.apply(ArtLayout.empty())
	var field: TerrainField = TerrainField.new(source)
	for item: Dictionary in source["instances"]:
		var p: Array = item["position"]
		var pose: Transform3D = LocalRebuild.pose(source, item, field)
		assert_almost_eq(pose.origin.y, field.height_at(Vector2(p[0], p[2])), 0.00001)
	var old: Dictionary = source.duplicate(true)
	old["terrain"]["base_profile"] = "forest_slope_v1"
	assert_ne(
		TerrainChunks.signature(source, Vector2i(2, 2)),
		TerrainChunks.signature(old, Vector2i(2, 2))
	)


func test_illustration_cache_and_different_tool_silhouettes() -> void:
	var seen: Dictionary = {}
	for key: String in [
		"矩形小屋",
		"圆形小屋",
		"短桥",
		"短阶",
		"围栏",
		"拱门",
		"方窗",
		"阔叶树",
		"野花",
		"复制",
		"删除",
		"更多参数",
		"cloudy",
		"rain",
		"snow"
	]:
		var texture: Texture2D = IllustratedIcons.texture(key)
		assert_same(texture, IllustratedIcons.texture(key))
		assert_eq(texture.get_size(), Vector2(72, 72))
		var hash_value: int = hash(texture.get_image().get_data())
		assert_false(seen.has(hash_value), key)
		seen[hash_value] = true


func test_calendar_upper_bound_remains_savable() -> void:
	var clock: CalendarState = CalendarState.new()
	clock.year = 99999
	clock.month = 12
	clock.day = 30
	clock.minute_of_day = 1439
	clock.advance(100)
	assert_true(CalendarState.valid(clock.record()))
	assert_eq(clock.speed, 0.0)
