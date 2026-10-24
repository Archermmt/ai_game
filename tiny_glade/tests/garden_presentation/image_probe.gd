extends SceneTree


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 2:
		quit(1)
		return
	var directory: String = args[0]
	var grass: Rect2i = Rect2i(1730, 900, 170, 140)
	var result: Dictionary = {
		"grass_wind": _difference(directory, "wind_t0", "wind_t2", grass),
		"reduced_motion": _difference(directory, "reduced_t0", "reduced_t2", grass),
		"focus_background":
		_difference(directory, "ribbon", "focus_off", Rect2i(300, 30, 1300, 220)),
		"focus_house_front":
		_difference(directory, "ribbon", "focus_off", Rect2i(1020, 470, 180, 120))
	}
	var passed: bool = result["grass_wind"]["changed_fraction"] > 0.05
	passed = (
		passed
		and result["reduced_motion"]["mean_abs_rgb"] < result["grass_wind"]["mean_abs_rgb"] * 0.15
	)
	passed = (
		passed
		and (
			result["focus_background"]["mean_abs_rgb"]
			> result["focus_house_front"]["mean_abs_rgb"] * 2
		)
	)
	result["passed"] = passed
	var file: FileAccess = FileAccess.open(args[1], FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "  "))
	file.close()
	print("GARDEN_IMAGE_CHECKS ", result)
	quit(0 if passed else 1)


func _difference(directory: String, first: String, second: String, region: Rect2i) -> Dictionary:
	var a: Image = Image.load_from_file(directory.path_join(first + ".png"))
	var b: Image = Image.load_from_file(directory.path_join(second + ".png"))
	if (
		a == null
		or b == null
		or a.get_size() != Vector2i(1920, 1080)
		or b.get_size() != a.get_size()
	):
		return {"mean_abs_rgb": 0, "changed_fraction": 0}
	var sum: float = 0
	var changed: int = 0
	for y: int in range(region.position.y, region.end.y):
		for x: int in range(region.position.x, region.end.x):
			var ca: Color = a.get_pixel(x, y)
			var cb: Color = b.get_pixel(x, y)
			var delta: Vector3 = Vector3(absf(ca.r - cb.r), absf(ca.g - cb.g), absf(ca.b - cb.b))
			sum += (delta.x + delta.y + delta.z) * 255.0 / 3
			if maxf(delta.x, maxf(delta.y, delta.z)) > 8.0 / 255:
				changed += 1
	return {
		"mean_abs_rgb": sum / region.get_area(),
		"changed_fraction": float(changed) / region.get_area()
	}
