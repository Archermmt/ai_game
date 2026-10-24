extends GutTest

const PATH: String = "user://qa_w08_preferences.cfg"
var preferences: UserPreferences


func before_each() -> void:
	preferences = UserPreferences.new()


func after_each() -> void:
	preferences.reset()
	for suffix: String in ["", ".tmp"]:
		if FileAccess.file_exists(PATH + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH + suffix))


func _key(code: int, modifier: bool = false) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.alt_pressed = modifier
	return event


func test_defaults_have_clear_view_and_full_motion() -> void:
	assert_eq(preferences.values["ui_scale"], 1.0)
	assert_false(preferences.values["dof"])
	assert_false(preferences.values["reduce_motion"])
	assert_true(UserPreferences.valid(preferences.values))


func test_preferences_roundtrip_and_key_mapping_apply() -> void:
	preferences.values["ui_scale"] = 1.5
	preferences.values["dof"] = true
	preferences.values["reduce_motion"] = true
	assert_eq(preferences.rebind("save_work", _key(KEY_K, true)), "")
	assert_eq(preferences.save_file(PATH), OK)
	var loaded: UserPreferences = UserPreferences.new()
	assert_eq(loaded.load_file(PATH), OK)
	assert_eq_deep(loaded.values, preferences.values)
	assert_true(InputMap.action_get_events("save_work")[0].is_match(_key(KEY_K, true)))


func test_duplicate_key_rejected_without_mutating_previous_mapping() -> void:
	assert_eq(preferences.rebind("save_work", _key(KEY_K, true)), "")
	var before: Dictionary = preferences.values.duplicate(true)
	assert_false(preferences.rebind("load_work", _key(KEY_K, true)).is_empty())
	assert_eq_deep(preferences.values, before)


func test_escape_and_modifier_only_rebinding_are_rejected() -> void:
	for code: int in [KEY_ESCAPE, KEY_META, KEY_CTRL, KEY_SHIFT, KEY_ALT, 0]:
		assert_false(preferences.rebind("save_work", _key(code)).is_empty())


func test_reset_restores_original_input_map_and_preferences() -> void:
	var original: String = InputMap.action_get_events("save_work")[0].as_text()
	preferences.rebind("save_work", _key(KEY_K))
	preferences.values["ui_scale"] = 1.5
	preferences.reset()
	assert_eq(InputMap.action_get_events("save_work")[0].as_text(), original)
	assert_eq(preferences.values["ui_scale"], 1.0)


func test_ui_scale_outside_range_is_invalid() -> void:
	for scale_value: float in [0.0, 0.99, 1.51, INF, NAN]:
		var candidate: Dictionary = preferences.values.duplicate(true)
		candidate["ui_scale"] = scale_value
		assert_false(UserPreferences.valid(candidate))


func test_wrong_types_and_unknown_actions_are_invalid() -> void:
	for change: Dictionary in [
		{"dof": "yes"}, {"reduce_motion": 1}, {"bindings": []}, {"ui_scale": "large"}
	]:
		var candidate: Dictionary = preferences.values.duplicate(true)
		candidate.merge(change, true)
		assert_false(UserPreferences.valid(candidate))
	assert_false(preferences.rebind("nonexistent", _key(KEY_K)).is_empty())


func test_bad_config_does_not_mutate_defaults() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("preferences", "values", {"ui_scale": 20})
	config.save(PATH)
	var before: Dictionary = preferences.values.duplicate(true)
	assert_eq(preferences.load_file(PATH), ERR_INVALID_DATA)
	assert_eq_deep(preferences.values, before)


func test_invalid_preferences_never_replace_valid_file() -> void:
	assert_eq(preferences.save_file(PATH), OK)
	var before: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	preferences.values["ui_scale"] = 9.0
	assert_eq(preferences.save_file(PATH), ERR_INVALID_DATA)
	assert_eq(FileAccess.get_file_as_bytes(PATH), before)


func test_reset_keeps_camera_mouse_gestures_and_cancel_binding() -> void:
	var cancel: Array = InputMap.action_get_events("cancel_edit").duplicate()
	var orbit: Array = InputMap.action_get_events("camera_orbit").duplicate()
	preferences.rebind("save_work", _key(KEY_K))
	preferences.reset()
	assert_eq(InputMap.action_get_events("cancel_edit"), cancel)
	assert_eq(InputMap.action_get_events("camera_orbit"), orbit)


func test_conflict_with_physical_default_key_is_detected() -> void:
	assert_false(preferences.rebind("save_work", _key(KEY_F)).is_empty())


func test_config_cannot_override_a_default_with_a_conflicting_binding() -> void:
	var event: InputEventKey = _key(KEY_F)
	var config: ConfigFile = ConfigFile.new()
	var candidate: Dictionary = preferences.values.duplicate(true)
	candidate["bindings"]["save_work"] = {
		"key": event.keycode, "ctrl": false, "meta": false, "shift": false, "alt": false
	}
	config.set_value("preferences", "values", candidate)
	config.save(PATH)
	assert_eq(preferences.load_file(PATH), ERR_INVALID_DATA)
