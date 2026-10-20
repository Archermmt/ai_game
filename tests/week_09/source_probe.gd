extends SceneTree


func _initialize() -> void:
	var source: Dictionary = StressLayout.create()
	print("STRESS_VALIDATE ", WorldDocument.validate(source))
	print(
		"STRESS_COUNTS ",
		source["buildings"].size(),
		" ",
		source["instances"].size(),
		" ",
		source["bridges"].size()
	)
	var file: FileAccess = FileAccess.open("res://reports/week_09_stress.wgs", FileAccess.WRITE)
	file.store_buffer(SceneSave.encode(source, "W09固定压力场景"))
	quit()
