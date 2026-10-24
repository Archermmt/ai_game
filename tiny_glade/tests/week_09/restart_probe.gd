extends "res://tests/week_03/restart_probe.gd"


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 2:
		quit(1)
		return
	var directory: String = args[1] + "_slots"
	var preferences: UserPreferences = UserPreferences.new()
	var passed: bool = true
	if args[0] == "write":
		for i: int in range(5):
			var world: Dictionary = _world(i)
			var result: Dictionary = SlotStore.write_slot(
				directory,
				i,
				world,
				"重启%d" % i,
				{"camera": world["camera_bookmarks"][1], "thumbnail": _thumbnail(i)}
			)
			passed = passed and result["ok"]
		preferences.values["ui_scale"] = 1.5
		preferences.values["reduce_motion"] = true
		preferences.rebind("save_work", _shortcut())
		passed = passed and preferences.save_file(args[1] + ".cfg") == OK
	else:
		for i: int in range(5):
			var loaded: Dictionary = SlotStore.read_slot(directory, i)
			var world: Dictionary = _world(i)
			passed = passed and loaded["ok"] and _same(loaded["snapshot"], world)
			passed = passed and loaded["metadata"]["title"] == "重启%d" % i
			passed = passed and loaded["metadata"]["presentation"]["thumbnail"] == _thumbnail(i)
		passed = passed and preferences.load_file(args[1] + ".cfg") == OK
		passed = (
			passed and preferences.values["ui_scale"] == 1.5 and preferences.values["reduce_motion"]
		)
		passed = passed and InputMap.action_get_events("save_work")[0].is_match(_shortcut())
	preferences.reset()
	if passed:
		print("RESTART_PROBE_PASS ", args[0])
	quit(0 if passed else 1)


func _world(index: int) -> Dictionary:
	var world: Dictionary = TerrainField.brush(
		ForestTemplate.create(), Vector2(16, -16), float(index) * 0.03
	)
	world["environment"]["wind_strength"] = float(index) / 5
	world["environment"]["dusk"] = index % 2 == 0
	world["environment"]["aged"] = true
	var bookmark: Dictionary = world["camera_bookmarks"][0].duplicate(true)
	bookmark["id"] = "custom_photo"
	bookmark["yaw"] = 2.6
	world["camera_bookmarks"].append(bookmark)
	world["environment"]["palette"]["wood"] = "wood_walnut"
	return world


func _thumbnail(index: int) -> String:
	var image: Image = Image.create(16, 10, false, Image.FORMAT_RGB8)
	image.fill(Color(float(index) / 5, 0.5, 0.2))
	return Marshalls.raw_to_base64(image.save_png_to_buffer())


func _shortcut() -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = KEY_K
	event.alt_pressed = true
	return event
