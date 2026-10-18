extends GutTest

const TEST_PATH: String = "user://tests/week_01/roundtrip.wgs"


func after_each() -> void:
	for suffix: String in ["", ".bak", ".tmp"]:
		var path: String = ProjectSettings.globalize_path(TEST_PATH + suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func test_source_state_roundtrip_preserves_seed_transform_and_heights() -> void:
	var doc: WorldDocument = WorldDocument.new("18446744073709551615")
	var draft: Dictionary = doc.snapshot()
	WorldDocument.allocate_building(draft, Vector3(1.25, 0, -2.5), Vector3(4, 3, 5))
	draft["terrain"]["height_deltas"] = [[1, 2, 0.25], [4, 3, -0.5]]
	var decoded: Dictionary = SaveCodec.decode(SaveCodec.encode(draft))
	assert_true(decoded["ok"])
	assert_eq(decoded["snapshot"]["world_seed"], "18446744073709551615")
	assert_eq(decoded["snapshot"]["buildings"][0]["id"], draft["buildings"][0]["id"])
	assert_eq_deep(decoded["snapshot"]["terrain"], draft["terrain"])
	assert_eq_deep(decoded["snapshot"]["buildings"][0]["position"], [1.25, 0.0, -2.5])


func test_checksum_detects_corruption_and_truncation() -> void:
	var bytes: PackedByteArray = SaveCodec.encode(WorldDocument.new().snapshot())
	bytes[bytes.size() - 1] ^= 0xFF
	assert_eq(SaveCodec.decode(bytes)["error"], "checksum_mismatch")
	assert_false(SaveCodec.decode(bytes.slice(0, 20))["ok"])


func test_malicious_declared_size_is_rejected_before_decompression() -> void:
	var bytes: PackedByteArray = SaveCodec.encode(WorldDocument.new().snapshot())
	bytes.encode_u32(8, 0xFFFFFFFF)
	assert_eq(SaveCodec.decode(bytes)["error"], "invalid_size")


func test_unknown_schema_cannot_overwrite_good_save() -> void:
	var draft: Dictionary = WorldDocument.new().snapshot()
	assert_eq(SaveCodec.write_file(TEST_PATH, draft), OK)
	var original: PackedByteArray = FileAccess.get_file_as_bytes(TEST_PATH)
	draft["schema_version"] = 100
	assert_eq(SaveCodec.write_file(TEST_PATH, draft), ERR_INVALID_DATA)
	assert_eq(FileAccess.get_file_as_bytes(TEST_PATH), original)


func test_interrupted_temp_and_corrupt_primary_recover_complete_backup() -> void:
	var draft: Dictionary = WorldDocument.new("first").snapshot()
	SaveCodec.write_file(TEST_PATH, draft)
	draft["world_seed"] = "second"
	SaveCodec.write_file(TEST_PATH, draft)
	var stream: FileAccess = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	stream.store_string("interrupted-write")
	stream.close()
	var recovered: Dictionary = SaveCodec.read_file(TEST_PATH)
	assert_true(recovered["ok"])
	assert_true(recovered["recovered_backup"])
	assert_eq(recovered["snapshot"]["world_seed"], "first")


func test_missing_save_reports_failure_instead_of_new_world() -> void:
	assert_false(SaveCodec.read_file(TEST_PATH + ".absent")["ok"])
