extends "res://tests/week_03/restart_probe.gd"


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 2:
		quit(1)
		return
	var world: Dictionary = WorldDocument.new("w06-restart").snapshot()
	VegetationBrush.paint(world, Vector2(10, 10), "plants", 3, 1, {})
	var bench: Dictionary = InstanceEdits.allocate(world, Vector3.ZERO)
	bench["asset_id"] = "PROP-01"
	var tea: Dictionary = InstanceEdits.allocate(world, Vector3.ZERO)
	tea["asset_id"] = "PROP-07"
	tea["support_id"] = bench["id"]
	var lamp: Dictionary = InstanceEdits.allocate(world, Vector3(3, 0, 3))
	lamp["asset_id"] = "PROP-08"
	lamp["lamp_mode"] = "on"
	lamp["height_locked"] = true
	lamp["locked_y"] = 0.73
	var passed: bool = false
	if args[0] == "write":
		passed = SaveCodec.write_file(args[1], world) == OK
	elif args[0] == "read":
		var result: Dictionary = SaveCodec.read_file(args[1])
		passed = result["ok"] and _same(result["snapshot"], world)

	if passed:
		print("RESTART_PROBE_PASS ", args[0])
	quit(0 if passed else 1)
