extends SceneTree

const LAYOUT = preload("res://levels/forest_slope/art_layout.gd")


func _initialize() -> void:
	var source: Dictionary = LAYOUT.create()
	var error: String = WorldDocument.validate(source)
	print("ART_LAYOUT ", error, " instances=", source["instances"].size())
	for kind: String in ["bridges", "stairs"]:
		for item: Dictionary in source[kind]:
			print(kind, " ", GardenStructures.status(source, item))
	quit(0 if error.is_empty() else 1)
