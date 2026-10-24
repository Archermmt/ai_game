extends SceneTree


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 2 or args[0] not in ["write", "read"]:
		quit(1)
		return
	var directory: String = args[1] + "_art_slots"
	var passed: bool = true
	for index: int in range(2):
		var source: Dictionary = ArtLayout.create() if index == 0 else ArtLayout.empty()
		source["environment"]["aged"] = true
		source["environment"]["dusk"] = true
		if args[0] == "write":
			passed = passed and SlotStore.write_slot(directory, index, source, "ART-01")["ok"]
		else:
			var loaded: Dictionary = SlotStore.read_slot(directory, index)
			passed = passed and loaded["ok"] and loaded["snapshot"] == source
			passed = passed and loaded["metadata"]["title"] == "ART-01"
	print("ART_RESTART ", args[0], " ", passed)
	quit(0 if passed else 1)
