class_name BuildingGallery
extends RefCounted


static func create() -> Dictionary:
	var draft: Dictionary = WorldDocument.new("w07-building-gallery").snapshot()
	for pair: Array in [
		[Vector3(-9, 0, -8), Vector3(3, 2.4, 3), "rect"],
		[Vector3(-9, 0, 7), Vector3(3, 2.4, 3), "round"],
		[Vector3(6, 0, -8), Vector3(12, 7.2, 12), "rect"],
		[Vector3(6, 0, 8), Vector3(12, 7.2, 12), "round"]
	]:
		var home: Dictionary = WorldDocument.allocate_building(draft, pair[0], pair[1], pair[2])
		home["openings"] = [
			{
				"kind": "arch" if pair[2] == "round" else "rect",
				"center": 0.15 if pair[2] == "round" else 0.5,
				"width": 1.2 if pair[2] == "round" else 1.1,
				"height": 2.1 if pair[2] == "round" else 2.05,
				"source": "manual"
			}
		]
		if pair[1].x > 3:
			home["openings"].append_array(
				[
					{
						"kind": "rect",
						"center": 0.5,
						"width": 1.0,
						"height": 1.0,
						"sill": 1.2,
						"facade": 0 if pair[2] == "round" else 1
					},
					{
						"kind": "round",
						"center": 0.75,
						"width": 1.0,
						"height": 1.0,
						"sill": 1.2,
						"facade": 0 if pair[2] == "round" else 2
					}
				]
			)
			if pair[2] == "rect":
				home["openings"].append(
					{
						"kind": "rect",
						"center": 0.5,
						"width": 1.1,
						"height": 2.05,
						"variant": "glass",
						"facade": 3
					}
				)
	return draft
