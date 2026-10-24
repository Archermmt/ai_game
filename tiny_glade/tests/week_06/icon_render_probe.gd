extends SceneTree

var _frames: int = 0


func _initialize() -> void:
	get_root().size = Vector2i(1280, 800)
	var canvas: Control = Control.new()
	canvas.theme = GardenTheme.create()
	get_root().add_child(canvas)
	var background: ColorRect = ColorRect.new()
	background.color = GardenTheme.CREAM
	background.size = Vector2(1280, 800)
	canvas.add_child(background)
	var title: Label = Label.new()
	title.text = "工具图标 / 64 与 128 像素 · 编辑反馈"
	title.position = Vector2(24, 12)
	title.add_theme_font_size_override("font_size", 22)
	canvas.add_child(title)
	var manifest: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://assets/ui/manifest.json")
	)
	for size: int in [64, 128]:
		for i: int in range(manifest["tools"].size()):
			var name: String = manifest["tools"][i]
			var x: float = 24 + (i % 4) * (size + 20) + (430 if size == 128 else 0)
			var y: float = 70 + (i / 4) * (size + 28)
			var icon: TextureRect = TextureRect.new()
			var raster: Image = Image.new()
			raster.load_svg_from_string(
				FileAccess.get_file_as_string("res://assets/ui/" + name + ".svg"), float(size) / 128
			)
			icon.texture = ImageTexture.create_from_image(raster)
			icon.position = Vector2(x, y)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_SCALE
			icon.size = Vector2.ONE * size
			canvas.add_child(icon)
			var label: Label = Label.new()
			label.position = Vector2(x, y + size)
			label.text = name
			label.add_theme_font_size_override("font_size", 10)
			canvas.add_child(label)
	for i: int in range(4):
		var icon: TextureRect = TextureRect.new()
		icon.texture = load("res://assets/ui/" + manifest["feedback"][i] + ".svg")
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.size = Vector2(64, 64)
		icon.position = Vector2(24 + i * 90, 620)
		canvas.add_child(icon)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 60:
		RenderingServer.force_draw(false)
		get_root().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
		return true
	return false
