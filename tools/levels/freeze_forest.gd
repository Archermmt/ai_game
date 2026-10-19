extends SceneTree
## Explicit authoring command; normal gameplay never overwrites the shipped layouts.


func _initialize() -> void:
	var script: Script = load("res://levels/forest_slope/forest_layout.gd")
	for mode: String in ["filled", "empty"]:
		var layout: Resource = script.new()
		var source: Dictionary = (
			ForestTemplate.create() if mode == "filled" else ForestTemplate.empty()
		)
		layout.source_json = ExactFloatJson.encode(source)
		if not WorldDocument.validate(source).is_empty():
			quit(1)
			return
		if ResourceSaver.save(layout, "res://levels/forest_slope/scn_01_%s.tres" % mode) != OK:
			quit(1)
			return
	print("SCN-01 frozen: editable source, same terrain and periphery")
	quit()
