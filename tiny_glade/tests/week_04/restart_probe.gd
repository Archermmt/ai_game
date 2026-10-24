extends "res://tests/week_03/restart_probe.gd"


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 2:
		quit(1)
		return
	var world: Dictionary = WorldDocument.new("w04-restart").snapshot()
	world["terrain"]["base_profile"] = "forest_slope_v1"
	WorldDocument.allocate_building(world, Vector3.ZERO, Vector3(5, 3, 5))
	PathGeometry.allocate(world, [[0, 0, 8], [0, 0, 2.5]])
	world["paths"][0]["curved"] = true
	world = DoorRules.reconcile(world)["snapshot"]
	FenceGeometry.allocate(world, [[-8, 0, 8], [-8, 0, 12]])
	var item: Dictionary = InstanceEdits.allocate(world, Vector3(8, 0, 8))
	item["asset_id"] = "PROP-02"
	world["environment"]["wind_direction"] = 1.7
	world["environment"]["lamp_probes"] = [{"id": "lamp", "position": [0, 1, 5]}]
	var passed: bool = false
	if args[0] == "write":
		passed = SaveCodec.write_file(args[1], world) == OK
	elif args[0] == "read":
		var result: Dictionary = SaveCodec.read_file(args[1])
		passed = result["ok"] and _same(result["snapshot"], world)
	if passed:
		print("RESTART_PROBE_PASS ", args[0])
	quit(0 if passed else 1)
