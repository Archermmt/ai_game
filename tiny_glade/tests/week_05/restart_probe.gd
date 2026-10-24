extends "res://tests/week_03/restart_probe.gd"


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 2:
		quit(1)
		return
	var world: Dictionary = PondShape.draw(
		WorldDocument.new("w05-restart").snapshot(), [[-3, -2], [3, -2], [3, 2], [-3, 2]]
	)
	GardenStructures.allocate(world, "bridge", Vector2(0, -2.5), Vector2(0, 2.5))
	FenceGeometry.allocate(world, [[8, 0, 8], [12, 0, 8], [12, 0, 12]])
	world["fences"][0]["closed"] = true
	var parent: Dictionary = InstanceEdits.allocate(world, Vector3(8, 0, -8))
	parent["asset_id"] = "PROP-05"
	var child: Dictionary = InstanceEdits.allocate(world, Vector3(8, 0, -8))
	child["asset_id"] = "PROP-06"
	child["support_id"] = parent["id"]
	var passed: bool = false
	if args[0] == "write":
		passed = SaveCodec.write_file(args[1], world) == OK
	elif args[0] == "read":
		var result: Dictionary = SaveCodec.read_file(args[1])
		passed = result["ok"] and _same(result["snapshot"], world)
	if passed:
		print("RESTART_PROBE_PASS ", args[0])
	quit(0 if passed else 1)
