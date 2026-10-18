extends SceneTree
## Invoked in two distinct OS processes by the weekly gate.


func _initialize() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.size() != 2:
		quit(1)
		return
	var success: bool = _perform(arguments[0], arguments[1])
	if success:
		print("RESTART_PROBE_PASS ", arguments[0])
	quit(0 if success else 1)


func _perform(mode: String, path: String) -> bool:
	var expected: Dictionary = WorldDocument.new("18446744073709551615").snapshot()
	var house: Dictionary = WorldDocument.allocate_building(
		expected, Vector3(1.25, 0, -2.5), Vector3(4, 3, 5)
	)
	expected["terrain"]["height_deltas"] = [[1, 2, 0.25], [4, 3, -0.5]]
	expected = TerrainField.pond(expected, Vector2(10, 7), 2.0)
	InstanceEdits.allocate(expected, Vector3(-8, 0, 4))
	expected["environment"]["aged"] = true
	var road: Dictionary = RiskEdits.road_to_door(
		expected, house["id"], Vector3(1.25, 0, 5), Vector3(1.25, 0, 0)
	)
	if not road["ok"]:
		return false
	expected = road["snapshot"]
	if mode == "write":
		return SaveCodec.write_file(path, expected) == OK
	if mode != "read":
		return false
	var result: Dictionary = SaveCodec.read_file(path)
	if not result["ok"]:
		return false
	var loaded: Dictionary = result["snapshot"]
	return (
		loaded["world_seed"] == expected["world_seed"]
		and loaded["buildings"][0]["id"] == house["id"]
		and loaded["terrain"]["height_deltas"] == expected["terrain"]["height_deltas"]
		and loaded["pool"] == expected["pool"]
		and loaded["instances"] == expected["instances"]
		and loaded["environment"] == expected["environment"]
		and loaded["paths"] == expected["paths"]
		and loaded["buildings"][0]["openings"] == expected["buildings"][0]["openings"]
	)
