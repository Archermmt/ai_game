extends GutTest

const DIRECTORY: String = "user://qa_w10_regression"
const PREFS: String = "user://qa_w10_regression/preferences.cfg"


func after_each() -> void:
	for index: int in range(5):
		for suffix: String in ["", ".tmp", ".bak1", ".bak2", ".bak3"]:
			DirAccess.remove_absolute(
				ProjectSettings.globalize_path(SlotStore.path_for(DIRECTORY, index) + suffix)
			)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PREFS))


func test_ten_art_scene_read_write_cycles_preserve_complete_source() -> void:
	var source: Dictionary = ArtLayout.create()
	for index: int in range(10):
		source["environment"]["wind_strength"] = index / 10.0
		source["environment"]["dusk"] = index % 2 == 0
		source = TerrainField.brush(source, Vector2(18, 18), 0.02)
		assert_true(SlotStore.write_slot(DIRECTORY, 0, source, "循环%d" % index)["ok"])
		var loaded: Dictionary = SlotStore.read_slot(DIRECTORY, 0)
		assert_true(loaded["ok"])
		assert_eq_deep(loaded["snapshot"], source)
		assert_eq(loaded["metadata"]["title"], "循环%d" % index)
		source = loaded["snapshot"]


func test_interruption_then_corrupt_primary_restores_latest_valid_backup() -> void:
	var source: Dictionary = ArtLayout.create()
	for index: int in range(3):
		assert_true(SlotStore.write_slot(DIRECTORY, 0, source, str(index))["ok"])
	assert_false(SlotStore.write_slot(DIRECTORY, 0, source, "interrupted", {}, true)["ok"])
	assert_eq(SlotStore.read_slot(DIRECTORY, 0)["metadata"]["title"], "2")
	var path: String = SlotStore.path_for(DIRECTORY, 0)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("truncated")
	file.close()
	var result: Dictionary = SlotStore.read_slot(DIRECTORY, 0)
	assert_true(result["ok"])
	assert_eq(result["recovered_backup"], 1)
	assert_eq(result["metadata"]["title"], "1")
	assert_eq_deep(result["snapshot"], source)
	assert_eq(FileAccess.get_file_as_string(path), "truncated")


func test_legacy_preferences_gain_audio_defaults_without_losing_settings() -> void:
	var preferences: UserPreferences = UserPreferences.new()
	var old: Dictionary = {"ui_scale": 1.5, "dof": false, "reduce_motion": true, "bindings": {}}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRECTORY))
	var config: ConfigFile = ConfigFile.new()
	config.set_value("preferences", "values", old)
	assert_eq(config.save(PREFS), OK)
	assert_eq(preferences.load_file(PREFS), OK)
	assert_eq(preferences.values["ui_scale"], 1.5)
	assert_true(preferences.values["reduce_motion"])
	assert_eq(preferences.values["music_volume"], 0.0)
	assert_eq(preferences.values["ambient_volume"], 0.7)
	preferences.reset()


func test_three_volume_preferences_roundtrip_at_zero_and_full_volume() -> void:
	var preferences: UserPreferences = UserPreferences.new()
	for level: float in [0.0, 0.5, 1.0]:
		for key: String in ["ambient_volume", "effects_volume", "music_volume"]:
			preferences.values[key] = level
		assert_eq(preferences.save_file(PREFS), OK)
		var loaded: UserPreferences = UserPreferences.new()
		assert_eq(loaded.load_file(PREFS), OK)
		assert_eq_deep(loaded.values, preferences.values)
	preferences.reset()


func test_invalid_audio_preference_does_not_replace_valid_file() -> void:
	var preferences: UserPreferences = UserPreferences.new()
	assert_eq(preferences.save_file(PREFS), OK)
	var original: PackedByteArray = FileAccess.get_file_as_bytes(PREFS)
	for value: Variant in [-0.1, 1.1, INF, NAN, "loud", 1]:
		preferences.values["ambient_volume"] = value
		assert_eq(preferences.save_file(PREFS), ERR_INVALID_DATA)
		assert_eq(FileAccess.get_file_as_bytes(PREFS), original)
	preferences.reset()


func test_art_source_audio_and_environment_edits_undo_redo_without_instance_shuffle() -> void:
	var document: WorldDocument = WorldDocument.new()
	var session: EditSession = EditSession.new(document)
	assert_true(session.replace_document(ArtLayout.create())["ok"])
	var instances: Array = document.state["instances"].duplicate(true)
	var buildings: Array = document.state["buildings"].duplicate(true)
	var draft: Dictionary = document.snapshot()
	draft["environment"]["wind_strength"] = 1.0
	draft["environment"]["dusk"] = true
	assert_true(session.commit_snapshot(draft, "wind")["ok"])
	assert_true(session.request_undo()["ok"])
	assert_true(session.request_redo()["ok"])
	assert_eq_deep(document.state["instances"], instances)
	assert_eq_deep(document.state["buildings"], buildings)
	session.dispose()


func test_rejected_invalid_resize_keeps_whole_art_document() -> void:
	var document: WorldDocument = WorldDocument.new()
	var session: EditSession = EditSession.new(document)
	assert_true(session.replace_document(ArtLayout.create())["ok"])
	var before: Dictionary = document.snapshot()
	var draft: Dictionary = before.duplicate(true)
	draft["buildings"][0]["size"][0] = -1
	assert_false(session.reserve_commit(draft, "invalid resize")["ok"])
	assert_eq_deep(document.state, before)
	assert_eq(session.phase, EditSession.Phase.IDLE)
	session.dispose()
