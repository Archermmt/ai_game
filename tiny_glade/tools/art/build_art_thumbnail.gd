extends SceneTree
## Derive UI-06 only from the actual native art scene capture.


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 2:
		quit(1)
		return
	var image: Image = Image.load_from_file(args[0])
	if image == null or image.get_size() != Vector2i(1920, 1080):
		quit(1)
		return
	image.resize(512, 288, Image.INTERPOLATE_LANCZOS)
	DirAccess.make_dir_recursive_absolute(args[1].get_base_dir())
	quit(0 if image.save_png(args[1]) == OK else 1)
