extends "res://tests/week_03/restart_probe.gd"


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 2:
		quit(1)
		return
	var world: Dictionary = ForestTemplate.create()
	world["environment"]["palette"]["wood"] = "wood_walnut"
	var passed: bool = false
	if args[0] == "write":
		passed = SceneSave.write_file(args[1], world, "W07 restart") == OK
	elif args[0] == "read":
		var result: Dictionary = SceneSave.read_file(args[1])
		passed = result["ok"] and _same(result["snapshot"], world)
	if passed:
		print("RESTART_PROBE_PASS ", args[0])
	quit(0 if passed else 1)
