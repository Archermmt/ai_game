extends SceneTree
## Known W03 1280x800 angle-135 capture: inspect the sun-facing pond interior.


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 2:
		quit(2)
		return
	var image: Image = Image.load_from_file(args[0])
	if image == null or image.get_size() != Vector2i(1280, 800):
		quit(2)
		return
	var highlights: int = 0
	var samples: int = 0
	for y: int in range(535, 565, 3):
		for x: int in range(440, 490, 3):
			var color: Color = image.get_pixel(x, y)
			if color.r > 0.94 and color.g > 0.94 and color.b > 0.94:
				highlights += 1
			samples += 1
	var passed: bool = highlights < samples / 10
	var file: FileAccess = FileAccess.open(args[1], FileAccess.WRITE)
	file.store_string(
		JSON.stringify(
			{"passed": passed, "samples": samples, "blown_highlight_samples": highlights}, "  "
		)
	)
	file.close()
	print("WATER_HIGHLIGHT_PROBE ", highlights, "/", samples)
	quit(0 if passed else 1)
