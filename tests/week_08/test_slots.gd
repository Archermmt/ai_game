extends GutTest

const DIRECTORY: String = "user://qa_w08_slots"
var world: Dictionary


func before_each() -> void:
	_cleanup()
	world = ForestTemplate.create()


func after_each() -> void:
	_cleanup()


func _cleanup() -> void:
	for i: int in range(5):
		for suffix: String in ["", ".tmp", ".bak1", ".bak2", ".bak3"]:
			var path: String = SlotStore.path_for(DIRECTORY, i) + suffix
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _corrupt(suffix: String = "") -> void:
	var path: String = SlotStore.path_for(DIRECTORY, 0) + suffix
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	bytes[-1] ^= 1
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()


func test_five_named_slots_roundtrip_independently() -> void:
	for i: int in range(5):
		world["environment"]["wind_strength"] = i * 0.2
		assert_true(SlotStore.write_slot(DIRECTORY, i, world, "庭园%d" % i)["ok"])
	for i: int in range(5):
		var loaded: Dictionary = SlotStore.read_slot(DIRECTORY, i)
		assert_true(loaded["ok"])
		assert_eq(loaded["metadata"]["title"], "庭园%d" % i)
		assert_almost_eq(loaded["snapshot"]["environment"]["wind_strength"], i * 0.2, 0.00001)


func test_three_backups_are_previous_three_generations() -> void:
	for i: int in range(5):
		assert_true(SlotStore.write_slot(DIRECTORY, 0, world, str(i))["ok"])
	var path: String = SlotStore.path_for(DIRECTORY, 0)
	for i: int in range(1, 4):
		var decoded: Dictionary = SceneSave.decode(
			FileAccess.get_file_as_bytes(path + ".bak%d" % i)
		)
		assert_eq(decoded["metadata"]["title"], str(4 - i))
	assert_false(FileAccess.file_exists(path + ".bak4"))


func test_interrupted_write_keeps_primary_and_ignores_valid_temp() -> void:
	SlotStore.write_slot(DIRECTORY, 0, world, "原作")
	var path: String = SlotStore.path_for(DIRECTORY, 0)
	var before: PackedByteArray = FileAccess.get_file_as_bytes(path)
	assert_false(SlotStore.write_slot(DIRECTORY, 0, world, "中断", {}, true)["ok"])
	assert_eq(FileAccess.get_file_as_bytes(path), before)
	assert_eq(SlotStore.read_slot(DIRECTORY, 0)["metadata"]["title"], "原作")
	assert_true(FileAccess.file_exists(path + ".tmp"))


func test_newest_valid_backup_is_recovered_without_touching_bad_main() -> void:
	SlotStore.write_slot(DIRECTORY, 0, world, "第一份")
	SlotStore.write_slot(DIRECTORY, 0, world, "第二份")
	_corrupt()
	var before: PackedByteArray = FileAccess.get_file_as_bytes(SlotStore.path_for(DIRECTORY, 0))
	var loaded: Dictionary = SlotStore.read_slot(DIRECTORY, 0)
	assert_true(loaded["ok"])
	assert_eq(loaded["recovered_backup"], 1)
	assert_eq(loaded["metadata"]["title"], "第一份")
	assert_false(SlotStore.write_slot(DIRECTORY, 0, world, "覆盖坏档")["ok"])
	assert_eq(FileAccess.get_file_as_bytes(SlotStore.path_for(DIRECTORY, 0)), before)


func test_recovery_skips_corrupt_first_backup() -> void:
	for i: int in range(4):
		SlotStore.write_slot(DIRECTORY, 0, world, str(i))
	_corrupt()
	_corrupt(".bak1")
	var loaded: Dictionary = SlotStore.read_slot(DIRECTORY, 0)
	assert_eq(loaded["recovered_backup"], 2)
	assert_eq(loaded["metadata"]["title"], "1")


func test_all_corrupt_generations_fail() -> void:
	for i: int in range(4):
		SlotStore.write_slot(DIRECTORY, 0, world, str(i))
	for suffix: String in ["", ".bak1", ".bak2", ".bak3"]:
		_corrupt(suffix)
	assert_false(SlotStore.read_slot(DIRECTORY, 0)["ok"])


func test_future_magic_never_falls_back_or_overwrites() -> void:
	SlotStore.write_slot(DIRECTORY, 0, world, "old")
	SlotStore.write_slot(DIRECTORY, 0, world, "new")
	var file: FileAccess = FileAccess.open(SlotStore.path_for(DIRECTORY, 0), FileAccess.WRITE)
	file.store_string("WGLADE99future")
	file.close()
	assert_eq(SlotStore.read_slot(DIRECTORY, 0)["error"], "unsupported_save_format")
	assert_false(SlotStore.write_slot(DIRECTORY, 0, world, "replace")["ok"])
	assert_eq(FileAccess.get_file_as_string(SlotStore.path_for(DIRECTORY, 0)), "WGLADE99future")


func test_invalid_slots_cannot_escape_storage_directory() -> void:
	for index: int in [-1, 5, 999]:
		assert_eq(SlotStore.path_for(DIRECTORY, index), "")
		assert_false(SlotStore.write_slot(DIRECTORY, index, world, "bad")["ok"])
		assert_false(SlotStore.read_slot(DIRECTORY, index)["ok"])


func test_catalog_lists_five_slots_and_recovery_state() -> void:
	SlotStore.write_slot(DIRECTORY, 2, world, "第三槽")
	var catalog: Array[Dictionary] = SlotStore.catalog(DIRECTORY)
	assert_eq(catalog.size(), 5)
	assert_false(catalog[0]["ok"])
	assert_true(catalog[2]["ok"])
	assert_eq(catalog[2]["metadata"]["title"], "第三槽")


func test_invalid_candidate_never_replaces_existing_valid_save() -> void:
	SlotStore.write_slot(DIRECTORY, 0, world, "valid")
	world["instances"].back()["support_id"] = "missing"
	assert_false(SlotStore.write_slot(DIRECTORY, 0, world, "bad")["ok"])
	assert_eq(SlotStore.read_slot(DIRECTORY, 0)["metadata"]["title"], "valid")


func test_thumbnail_camera_environment_and_heights_share_checksum() -> void:
	var image: Image = Image.create(320, 200, false, Image.FORMAT_RGB8)
	image.fill(Color("729572"))
	var presentation: Dictionary = {
		"camera": ForestTemplate.empty()["camera_bookmarks"][1],
		"thumbnail": Marshalls.raw_to_base64(image.save_png_to_buffer())
	}
	world = TerrainField.brush(world, Vector2(15, -15), 0.35)
	world["environment"]["dusk"] = true
	world["environment"]["aged"] = true
	assert_true(SlotStore.write_slot(DIRECTORY, 0, world, "完整作品", presentation)["ok"])
	var loaded: Dictionary = SlotStore.read_slot(DIRECTORY, 0)
	assert_eq_deep(loaded["snapshot"], world)
	assert_eq_deep(loaded["metadata"]["presentation"], presentation)
	_corrupt()
	assert_false(SlotStore.read_slot(DIRECTORY, 0)["ok"])


func test_invalid_camera_or_thumbnail_is_rejected_before_writing() -> void:
	for presentation: Dictionary in [
		{"camera": {}},
		{"thumbnail": "not png"},
		{"camera": {"target": [0, 0, 0], "distance": 80, "yaw": 0, "pitch": 0.6}}
	]:
		assert_false(SlotStore.write_slot(DIRECTORY, 0, world, "bad", presentation)["ok"])
	assert_false(FileAccess.file_exists(SlotStore.path_for(DIRECTORY, 0)))


func test_camera_bookmark_duplicate_and_nonfinite_values_fail_validation() -> void:
	world["camera_bookmarks"].append(world["camera_bookmarks"][0].duplicate(true))
	assert_eq(WorldDocument.validate(world), "invalid_camera_bookmarks")
	world = ForestTemplate.create()
	world["camera_bookmarks"][0]["yaw"] = INF
	assert_false(WorldDocument.validate(world).is_empty())


func test_legacy_dto_without_presentation_still_migrates() -> void:
	var dto: Dictionary = SnapshotDto.pack(world, "W07")
	dto["metadata"].erase("presentation")
	assert_true(SnapshotDto.unpack(dto)["ok"])
	assert_true(SceneSave.decode(SaveCodec.encode(world))["ok"])


func test_pending_attachment_remains_pending_on_roundtrip() -> void:
	var source: Dictionary = ForestTemplate.create()
	BuildingEdits.remove(source, [source["buildings"][0]["id"]])
	assert_gt(source["attachments"].size(), 0)
	assert_eq(WorldDocument.validate(source), "")
	var loaded: Dictionary = SceneSave.decode(SceneSave.encode(source))
	assert_true(loaded["ok"])
	assert_eq_deep(loaded["snapshot"], source)
	for attachment: Dictionary in loaded["snapshot"]["attachments"]:
		assert_eq(attachment["parent_id"], "")


func test_corrupt_magic_recovers_backup_but_does_not_promote_it_over_main() -> void:
	SlotStore.write_slot(DIRECTORY, 0, world, "可恢复")
	SlotStore.write_slot(DIRECTORY, 0, world, "新作")
	var path: String = SlotStore.path_for(DIRECTORY, 0)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("broken header")
	file.close()
	var loaded: Dictionary = SlotStore.read_slot(DIRECTORY, 0)
	assert_true(loaded["ok"])
	assert_eq(loaded["recovered_backup"], 1)
	assert_eq(loaded["metadata"]["title"], "可恢复")
	assert_eq(FileAccess.get_file_as_string(path), "broken header")
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(PackedByteArray([255, 254, 253, 252, 251, 250, 249, 248]))
	file.close()
	assert_true(SlotStore.read_slot(DIRECTORY, 0)["ok"])
	assert_false(SceneSave.decode(PackedByteArray([255, 254]))["ok"])


func test_legacy_single_container_has_usable_metadata_and_can_be_resaved() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRECTORY))
	var path: String = SlotStore.path_for(DIRECTORY, 0)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(SaveCodec.encode(world))
	file.close()
	var loaded: Dictionary = SlotStore.read_slot(DIRECTORY, 0)
	assert_true(loaded["ok"])
	assert_eq(loaded["metadata"]["title"], "旧版作品")
	assert_true(SlotStore.write_slot(DIRECTORY, 0, loaded["snapshot"], "迁移作品")["ok"])
	assert_eq_deep(SlotStore.read_slot(DIRECTORY, 0)["snapshot"], world)
	assert_eq(
		FileAccess.get_file_as_bytes(path + ".bak1").slice(0, 8).get_string_from_utf8(), "WGLADE01"
	)
