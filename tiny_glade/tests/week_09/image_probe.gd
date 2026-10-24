extends SceneTree


func _initialize() -> void:
	var directory: String = OS.get_cmdline_user_args()[0]
	var passed: bool = true
	for dimensions: Vector2i in PhotoExport.SIZES + [Vector2i(512, 288)]:
		var path: String = directory.path_join("photo_%dx%d.png" % [dimensions.x, dimensions.y])
		var image: Image = Image.load_from_file(path)
		passed = passed and image != null and not image.is_empty()
		if image != null:
			passed = passed and image.get_size() == dimensions
			var colors: Dictionary = {}
			for y: int in range(0, dimensions.y, 20):
				for x: int in range(0, dimensions.x, 20):
					colors[image.get_pixel(x, y).to_html()] = true
			passed = passed and colors.size() > 50
	print("PNG_DECODE_PASS" if passed else "PNG_DECODE_FAIL")
	quit(0 if passed else 1)
