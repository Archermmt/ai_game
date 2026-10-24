class_name UserPreferences
extends RefCounted
## Local preferences never modify the portable world source.

const ACTIONS: Array[String] = ["undo_edit", "redo_edit", "save_work", "load_work", "reset_camera"]
const LABELS: Array[String] = ["撤销", "重做", "保存", "载入", "重置相机"]
var values: Dictionary = {
	"ui_scale": 1.0,
	"dof": false,
	"reduce_motion": false,
	"bindings": {},
	"ambient_volume": 0.7,
	"effects_volume": 0.65,
	"music_volume": 0.0
}
var defaults: Dictionary = {}


func _init() -> void:
	for action: String in ACTIONS:
		defaults[action] = InputMap.action_get_events(action).duplicate()


func load_file(path: String) -> Error:
	var config: ConfigFile = ConfigFile.new()
	var error: Error = config.load(path)
	if error != OK:
		return error
	var candidate: Variant = config.get_value("preferences", "values", {})
	if not candidate is Dictionary or not valid(candidate) or not effective_valid(candidate):
		return ERR_INVALID_DATA
	values = candidate.duplicate(true)
	for key: String in ["ambient_volume", "effects_volume", "music_volume"]:
		if not values.has(key):
			values[key] = {"ambient_volume": 0.7, "effects_volume": 0.65, "music_volume": 0.0}[key]
	apply_bindings()
	return OK


func save_file(path: String) -> Error:
	if not valid(values) or not effective_valid(values):
		return ERR_INVALID_DATA
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var config: ConfigFile = ConfigFile.new()
	config.set_value("preferences", "values", values)
	var error: Error = config.save(path + ".tmp")
	if error != OK:
		return error
	return DirAccess.rename_absolute(
		ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path)
	)


func rebind(action: String, event: InputEventKey) -> String:
	if (
		action not in ACTIONS
		or event.keycode in [0, KEY_ESCAPE, KEY_META, KEY_CTRL, KEY_SHIFT, KEY_ALT]
	):
		return "请选择有效按键；Esc 保留用于取消"
	for other: String in ACTIONS:
		if other != action:
			for existing: InputEvent in InputMap.action_get_events(other):
				if same_shortcut(existing, event):
					return "快捷键冲突：" + LABELS[ACTIONS.find(other)]
	values["bindings"][action] = {
		"key": event.keycode,
		"ctrl": event.ctrl_pressed,
		"meta": event.meta_pressed,
		"alt": event.alt_pressed,
		"shift": event.shift_pressed
	}
	apply_bindings()
	return ""


func reset() -> void:
	values = {
		"ui_scale": 1.0,
		"dof": false,
		"reduce_motion": false,
		"bindings": {},
		"ambient_volume": 0.7,
		"effects_volume": 0.65,
		"music_volume": 0.0
	}
	apply_bindings()


func apply_bindings() -> void:
	for action: String in ACTIONS:
		InputMap.action_erase_events(action)
		if values["bindings"].has(action):
			InputMap.action_add_event(action, binding_event(values["bindings"][action]))
		else:
			for event: InputEvent in defaults[action]:
				InputMap.action_add_event(action, event)


static func binding_event(binding: Dictionary) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = int(binding["key"])
	event.ctrl_pressed = binding["ctrl"]
	event.meta_pressed = binding["meta"]
	event.alt_pressed = binding["alt"]
	event.shift_pressed = binding["shift"]
	return event


static func valid(candidate: Dictionary) -> bool:
	if (
		not candidate.get("ui_scale") is float
		or not is_finite(candidate["ui_scale"])
		or candidate["ui_scale"] < 1
		or candidate["ui_scale"] > 1.5
	):
		return false
	if (
		not candidate.get("dof") is bool
		or not candidate.get("reduce_motion") is bool
		or not candidate.get("bindings") is Dictionary
	):
		return false
	if candidate.has("garden_focus") and not candidate["garden_focus"] is bool:
		return false
	if (
		candidate.has("seasonal_music_initialized")
		and not candidate["seasonal_music_initialized"] is bool
	):
		return false
	for key: String in ["ambient_volume", "effects_volume", "music_volume", "grass_density"]:
		if candidate.has(key):
			var volume: Variant = candidate[key]
			if not volume is float or not is_finite(volume) or volume < 0 or volume > 1:
				return false
	var used: Array[String] = []
	for action: Variant in candidate["bindings"]:
		var b: Variant = candidate["bindings"][action]
		if (
			action not in ACTIONS
			or not b is Dictionary
			or not b.get("key") is int
			or b["key"] <= 0
			or b["key"] in [KEY_ESCAPE, KEY_META, KEY_CTRL, KEY_SHIFT, KEY_ALT]
		):
			return false
		for modifier: String in ["ctrl", "meta", "alt", "shift"]:
			if not b.get(modifier) is bool:
				return false
		var signature: String = binding_event(b).as_text()
		if signature in used:
			return false
		used.append(signature)
	return true


func effective_valid(candidate: Dictionary) -> bool:
	var used: Array[InputEvent] = []
	for action: String in ACTIONS:
		var events: Array = (
			[binding_event(candidate["bindings"][action])]
			if candidate["bindings"].has(action)
			else defaults[action]
		)
		for event: InputEvent in events:
			for existing: InputEvent in used:
				if same_shortcut(existing, event):
					return false
			used.append(event)
	return true


static func same_shortcut(a: InputEvent, b: InputEvent) -> bool:
	if not a is InputEventKey or not b is InputEventKey:
		return a.is_match(b)
	var a_code: int = a.keycode if a.keycode != 0 else a.physical_keycode
	var b_code: int = b.keycode if b.keycode != 0 else b.physical_keycode
	return (
		a_code == b_code
		and a.ctrl_pressed == b.ctrl_pressed
		and a.meta_pressed == b.meta_pressed
		and a.alt_pressed == b.alt_pressed
		and a.shift_pressed == b.shift_pressed
	)
