extends "res://app/week_three_boot.gd"
## Repeatable T019 min/max parameter inspection scene; not a second save format.


func _setup_initial_buildings() -> void:
	var draft: Dictionary = WorldDocument.new("w03-parameter-gallery").snapshot()
	for entry: Array in [
		["rect", Vector3(-10, 0, -10), Vector3(12, 7.2, 12)],
		["round", Vector3(10, 0, -10), Vector3(12, 2.4, 12)],
		["rect", Vector3(-8, 0, 8), Vector3(3, 2.4, 3)],
		["round", Vector3(8, 0, 8), Vector3(3, 7.2, 3)],
	]:
		var home: Dictionary = WorldDocument.allocate_building(draft, entry[1], entry[2], entry[0])
		home["openings"] = [{"kind": "arch", "center": 0.5, "width": 1.1, "height": 2.05}]
	session.replace_document(draft, _prepare_views)
	camera_rig.distance = 52.0
	camera_rig.target = Vector3(0, 2, 0)
	camera_rig.refresh()
