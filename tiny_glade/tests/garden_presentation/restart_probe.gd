extends SceneTree


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 2 or args[0] not in ["write", "read"]:
		quit(1)
		return
	var passed: bool = true
	var source: Dictionary = ArtLayout.create()
	var preferences: UserPreferences = UserPreferences.new()
	var directory: String = args[1] + "_garden"
	if args[0] == "write":
		preferences.values.merge({"grass_density": 0.25, "garden_focus": false})
		passed = SlotStore.write_slot(directory, 0, source, "Garden UI")["ok"]
		passed = passed and preferences.save_file(directory.path_join("preferences.cfg")) == OK
	else:
		var loaded: Dictionary = SlotStore.read_slot(directory, 0)
		passed = loaded["ok"] and loaded["snapshot"] == source
		passed = passed and not loaded["snapshot"].has("grass_density")
		passed = passed and preferences.load_file(directory.path_join("preferences.cfg")) == OK
		passed = (
			passed
			and preferences.values["grass_density"] == 0.25
			and not preferences.values["garden_focus"]
		)
	preferences.reset()
	print("GARDEN_RESTART ", args[0], " ", passed)
	quit(0 if passed else 1)
