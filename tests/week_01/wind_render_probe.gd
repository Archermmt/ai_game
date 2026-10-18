extends SceneTree
## Compare real GPU captures; headless invocation here only reads image files.


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 2:
		quit(2)
		return
	var result: Dictionary = {}
	var passed: bool = true
	for mode: String in ["on", "zero", "still"]:
		var first: Image = Image.load_from_file(args[0].path_join(mode + "_0.png"))
		var second: Image = Image.load_from_file(args[0].path_join(mode + "_1.png"))
		if first == null or second == null or first.get_size() != second.get_size():
			quit(2)
			return
		var a: PackedByteArray = first.get_data()
		var b: PackedByteArray = second.get_data()
		var different: int = 0
		for index: int in a.size():
			if a[index] != b[index]:
				different += 1
		result[mode + "_different_bytes"] = different
		passed = passed and (different > 100 if mode == "on" else different == 0)
	result["passed"] = passed
	var file: FileAccess = FileAccess.open(args[1], FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	print("WIND_RENDER_PROBE ", result)
	quit(0 if passed else 1)
