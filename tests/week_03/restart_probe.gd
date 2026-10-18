extends SceneTree


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 2:
		quit(1)
		return
	var world: Dictionary = WorldDocument.new("w03-restart").snapshot()
	var building: Dictionary = WorldDocument.allocate_building(
		world, Vector3.ZERO, Vector3(5, 3, 5)
	)
	building["openings"] = [{"kind": "arch", "center": 0.5, "width": 1.1, "height": 2.05}]
	BuildingEdits.remove(world, [building["id"]])
	WorldDocument.allocate_building(world, Vector3(8, 0, 0), Vector3(4, 6, 4), "round")
	PathGeometry.allocate(world, [[-8, 0, 5], [0, 0, 8], [8, 0, 5]], 1.8)
	var tree: Dictionary = InstanceEdits.allocate(world, Vector3(-10, 0, -8))
	tree["asset_id"] = "NAT-03"
	var passed: bool = false
	if args[0] == "write":
		passed = SaveCodec.write_file(args[1], world) == OK
	elif args[0] == "read":
		var result: Dictionary = SaveCodec.read_file(args[1])
		passed = result["ok"]
		if passed:
			for key: String in world:
				if not _same(result["snapshot"][key], world[key]):
					push_error("Restart field mismatch: " + key)
					passed = false
	if passed:
		print("RESTART_PROBE_PASS ", args[0])
	quit(0 if passed else 1)


func _same(a: Variant, b: Variant) -> bool:
	# JSON stores untyped numbers; compare every source field with numeric equivalence.
	if (a is int or a is float) and (b is int or b is float):
		return float(a) == float(b)
	if a is Array and b is Array:
		return (
			a.size() == b.size()
			and range(a.size()).all(func(i: int) -> bool: return _same(a[i], b[i]))
		)
	if a is Dictionary and b is Dictionary:
		return (
			a.size() == b.size()
			and a.keys().all(func(key: String) -> bool: return b.has(key) and _same(a[key], b[key]))
		)
	return a == b
