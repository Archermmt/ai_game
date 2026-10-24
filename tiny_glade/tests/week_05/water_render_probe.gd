extends SceneTree


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 3:
		quit(1)
		return
	var visible_image: Image = Image.load_from_file(args[0])
	var hidden_image: Image = Image.load_from_file(args[1])
	if (
		visible_image == null
		or hidden_image == null
		or visible_image.get_size() != hidden_image.get_size()
	):
		quit(1)
		return
	var changed: int = 0
	for y: int in range(visible_image.get_height()):
		for x: int in range(visible_image.get_width()):
			if visible_image.get_pixel(x, y) != hidden_image.get_pixel(x, y):
				changed += 1
	var stream: FileAccess = FileAccess.open(args[2], FileAccess.WRITE)
	stream.store_string(
		JSON.stringify({"visible_water_changed_pixels": changed, "passed": changed > 500})
	)
	stream.close()
	print("W05_WATER_PIXELS ", changed)
	quit(0 if changed > 500 else 1)
