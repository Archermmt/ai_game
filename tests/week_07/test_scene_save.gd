extends GutTest


func test_template_and_empty_share_terrain_periphery_and_two_views() -> void:
	var filled: Dictionary = ForestTemplate.create()
	var empty: Dictionary = ForestTemplate.empty()
	assert_eq(WorldDocument.validate(filled), "")
	assert_eq(WorldDocument.validate(empty), "")
	assert_eq(filled["terrain"], empty["terrain"])
	assert_eq(filled["camera_bookmarks"], empty["camera_bookmarks"])
	assert_eq(empty["camera_bookmarks"].size(), 2)
	for i: int in range(empty["instances"].size()):
		assert_eq(filled["instances"][i], empty["instances"][i])
	assert_true(empty["buildings"].is_empty())
	assert_true(empty["pool"].is_empty())


func test_template_has_editable_required_objects_and_valid_structures() -> void:
	var world: Dictionary = ForestTemplate.create()
	var assets: Array = []
	for item: Dictionary in world["instances"]:
		assets.append(item["asset_id"])
	for id_value: String in AssetRegistry.WRAPPERS:
		assert_has(assets, id_value)
	assert_eq(world["buildings"].size(), 2)
	for collection: String in ["bridges", "stairs"]:
		assert_eq(GardenStructures.status(world, world[collection][0]), "")


func test_new_container_roundtrip_keeps_hedges_palette_and_composition() -> void:
	var world: Dictionary = ForestTemplate.create()
	var bytes: PackedByteArray = SceneSave.encode(world, "我的庭园")
	assert_eq(bytes.slice(0, 8).get_string_from_utf8(), "WGLADE02")
	var result: Dictionary = SceneSave.decode(bytes)
	assert_true(result["ok"])
	assert_eq_deep(result["snapshot"], world)
	assert_eq(result["metadata"]["title"], "我的庭园")


func test_container_compresses_height_deltas_together_with_source_metadata() -> void:
	var world: Dictionary = ForestTemplate.create()
	world = TerrainField.brush(world, Vector2(15, -15), 0.35)
	var bytes: PackedByteArray = SceneSave.encode(world)
	var result: Dictionary = SceneSave.decode(bytes)
	assert_true(result["ok"])
	assert_eq_deep(result["snapshot"]["terrain"], world["terrain"])
	assert_lt(bytes.size(), bytes.decode_u32(8))


func test_legacy_week_six_container_still_loads() -> void:
	var world: Dictionary = WorldDocument.new().snapshot()
	var result: Dictionary = SceneSave.decode(SaveCodec.encode(world))
	assert_true(result["ok"])
	assert_eq_deep(result["snapshot"], world)


func test_corruption_and_size_header_fail_before_decode() -> void:
	var bytes: PackedByteArray = SceneSave.encode(ForestTemplate.create())
	bytes[-1] ^= 1
	assert_false(SceneSave.decode(bytes)["ok"])
	bytes = SceneSave.encode(ForestTemplate.create())
	bytes.encode_u32(8, SceneSave.LIMIT + 1)
	assert_false(SceneSave.decode(bytes)["ok"])
	assert_false(SceneSave.decode(PackedByteArray([1, 2, 3]))["ok"])


func test_future_dto_and_invalid_reference_do_not_load() -> void:
	var dto: Dictionary = SnapshotDto.pack(ForestTemplate.create(), "test")
	dto["format_version"] = 99
	assert_eq(SnapshotDto.unpack(dto)["error"], "unsupported_save_format")
	dto["format_version"] = 2
	dto["source"]["instances"].back()["support_id"] = "missing-parent"
	assert_false(SnapshotDto.unpack(dto)["ok"])


func test_disposable_generated_cache_is_never_authoritative() -> void:
	var dto: Dictionary = SnapshotDto.pack(ForestTemplate.create(), "test")
	dto["source"]["generated_cache"] = {"garbage": "irrelevant"}
	var result: Dictionary = SnapshotDto.unpack(dto)
	assert_true(result["ok"])
	assert_false(result["snapshot"].has("generated_cache"))


func test_unknown_container_is_preserved_on_write_and_read() -> void:
	var path: String = "user://test_w07_future.wgs"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer("WGLADE99future".to_utf8_buffer())
	file.close()
	var before: PackedByteArray = FileAccess.get_file_as_bytes(path)
	assert_eq(SceneSave.write_file(path, ForestTemplate.create()), ERR_FILE_UNRECOGNIZED)
	assert_eq(FileAccess.get_file_as_bytes(path), before)
	assert_eq(SceneSave.read_file(path)["error"], "unsupported_save_format")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_locked_parent_support_height_and_copy_lamp_parameters_are_preserved() -> void:
	var world: Dictionary = WorldDocument.new().snapshot()
	var box: Dictionary = InstanceEdits.allocate(world, Vector3.ZERO)
	box["asset_id"] = "PROP-05"
	box["height_locked"] = true
	box["locked_y"] = 2.0
	box["position"][1] = 0.2
	var lamp: Dictionary = InstanceEdits.allocate(world, Vector3.ZERO)
	lamp["asset_id"] = "PROP-08"
	lamp["support_id"] = box["id"]
	lamp["lamp_mode"] = "on"
	assert_almost_eq(InstanceEdits.support_height(world, lamp), 2.8, 0.001)
	InstanceEdits.duplicate_selection(world, [lamp["id"]])
	assert_eq(world["instances"].back()["lamp_mode"], "on")
	assert_false(world["instances"].back().has("support_id"))


func test_json_envelope_preserves_integer_types_and_rejects_invalid_integer_metadata() -> void:
	var source: Dictionary = {"values": [7, 9223372036854775807, 1.23456789012345]}
	var decoded: Dictionary = ExactFloatJson.restore(
		JSON.parse_string(ExactFloatJson.encode(source))
	)
	assert_eq_deep(decoded["snapshot"], source)
	for value: String in ["1.5", "9223372036854775808", "0001"]:
		var envelope: Dictionary = JSON.parse_string(ExactFloatJson.encode(source))
		envelope["integer_paths"] = [[["values", 0], value]]
		assert_false(ExactFloatJson.restore(envelope)["ok"])
