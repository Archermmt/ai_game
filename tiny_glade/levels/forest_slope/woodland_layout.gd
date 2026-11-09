class_name WoodlandLayout
extends RefCounted
## Editable starter planting. All positions are document records, including the forest edge.

const VIEWS: Array[Dictionary] = [
	{
		"id": "recommended_day",
		"target": [0.9, 2.35, 0.4],
		"distance": 29.5,
		"yaw": -0.68,
		"pitch": 0.59
	},
	{
		"id": "recommended_garden",
		"target": [1.15, 1.65, 1.05],
		"distance": 15.0,
		"yaw": -0.57,
		"pitch": 0.37
	},
]


static func empty() -> Dictionary:
	var source: Dictionary = _clearing()
	# Keep the same outer trees and their IDs, leaving the blank building area open.
	source["instances"] = source["instances"].filter(
		func(tree: Dictionary) -> bool:
			return maxf(absf(tree["position"][0]), absf(tree["position"][2])) >= 15.0
	)
	return source


static func _clearing() -> Dictionary:
	var source: Dictionary = WorldDocument.new("woodland-clearing").snapshot()
	source["terrain"]["base_profile"] = "rolling_hills_v2"
	source["environment"]["palette"] = GardenPalette.DEFAULTS.duplicate()
	source["environment"]["palette"]["roof"] = "roof_smoke"
	source["environment"]["palette"]["plaster"] = "plaster_rose"
	source["environment"]["wind_strength"] = 0.28
	source["camera_bookmarks"] = VIEWS.duplicate(true)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 150516
	# Stagger tree crowns in depth. Spaces between the three rows let the cool
	# forest floor show through. Leave a sunlit clearing around the door and pool.
	for row: int in range(3):
		for col: int in range(9):
			var x: float = -19.0 + 4.75 * col + rng.randf_range(-1.2, 1.2)
			var z: float = -7.0 - row * 6.2 + rng.randf_range(-1.35, 1.35)
			if row == 0 and col in [1, 5]:
				continue
			var species: String = "NAT-02" if (col + row * 2) % 5 == 0 else "NAT-01"
			_place(source, species, Vector2(x, z), rng.randf_range(0.94, 1.42))
	for tree: Array in [
		[-13, -2, 1.35],
		[-17, 4, 1.5],
		[-12, 7, 1.23],
		[-13.2, 9.7, 0.91],
		[13.8, -2.5, 1.32],
		[15, 4, 1.42],
		[12.8, 10.4, 0.91],
		[-2.45, 17.35, 1.03],
		[-21, 14, 1.3],
		[18, 17, 1.35],
		[-17, 20, 1.52],
		[18.4, -2.0, 1.4],
		[21.3, 2.8, 1.28],
		[22.2, -5.4, 1.51],
	]:
		_place(source, "NAT-01", Vector2(tree[0], tree[1]), tree[2])
	return source


static func create() -> Dictionary:
	var source: Dictionary = _clearing()
	var house: Dictionary = WorldDocument.allocate_building(
		source, Vector3(-0.55, 0.35, -0.6), Vector3(4.8, 2.85, 4.5)
	)
	house["roof_rise"] = 2.25
	house["openings"] = [
		_opening("rect", 0, 0.65, 1.02, 1.99, 0),
		_opening("rect", 0, 0.22, 0.88, 0.95, 1.03),
		_opening("rect", 3, 0.54, 1.05, 0.98, 1.08),
		_opening("round", 2, 0.52, 0.76, 0.76, 1.15),
	]
	# Keep examples of both building shapes in the playable garden. Distant
	# garden sheds sit beyond the first frame; the cottage owns the clearing.
	var shed: Dictionary = WorldDocument.allocate_building(
		source, Vector3(-18.0, 1.65, -1.2), Vector3(3.1, 2.4, 3.2)
	)
	shed["openings"] = [_opening("rect", 0, 0.55, 1, 1.91, 0)]
	var round_shed: Dictionary = WorldDocument.allocate_building(
		source, Vector3(21.0, 1.25, 16.2), Vector3(3.5, 2.55, 3.5), "round"
	)
	round_shed["openings"] = [_opening("arch", 0, 0.18, 1, 2, 0)]
	source = PondShape.draw(
		source, [[3.25, 4.0], [5.2, 2.3], [8.55, 2.65], [9.2, 5.05], [7.75, 7.2], [4.65, 7.05]]
	)
	GardenStructures.allocate(source, "bridge", Vector2(8.15, 1.95), Vector2(8.4, 7.05), 0.92)
	GardenStructures.allocate(source, "stair", Vector2(0.17, 1.76), Vector2(0.17, 3.22), 1.22)
	for points: Array in [
		[[0.17, 0, 3.22], [0.6, 0, 4.25], [1.72, 0, 5.85], [3.3, 0, 7.75], [4.9, 0, 9.05]],
		[[4.9, 0, 9.05], [6.5, 0, 8.85], [7.9, 0, 8.2], [8.4, 0, 7.05]],
	]:
		PathGeometry.allocate(source, points, 0.91)
		source["paths"].back()["curved"] = true
	FenceGeometry.allocate(source, [[-8.3, 0, -2.7], [-8, 0, -0.2], [-7.2, 0, 1.5]])
	var bench: Dictionary = _place(source, "PROP-01", Vector2(-3.55, 2.5))
	var tea: Dictionary = _place(source, "PROP-07", Vector2(-3.55, 2.5))
	tea["support_id"] = bench["id"]
	for entry: Array in [
		["PROP-02", 2.1, 8.3],
		["PROP-03", -1.65, 2.28],
		["PROP-04", -5.65, -0.8],
		["PROP-05", -3.8, -2.4],
		["PROP-06", -2.7, 2.36],
		["PROP-08", 1.28, 2.26],
		["NAT-09", 3.0, -2.0],
		["NAT-08", 11.9, 7.0],
	]:
		_place(source, entry[0], Vector2(entry[1], entry[2]))
	for bed: Vector2 in [
		Vector2(-5, 4.2), Vector2(0, 6.7), Vector2(2.4, -3.9), Vector2(9, 9.4), Vector2(-7, -4.4)
	]:
		VegetationBrush.paint(source, bed, "plants", 1.95, 0.49, {})
	return source


static func _place(
	source: Dictionary, asset: String, point: Vector2, size: float = 1.0
) -> Dictionary:
	var item: Dictionary = InstanceEdits.allocate(source, Vector3(point.x, 0, point.y))
	item["asset_id"] = asset
	item["scale"] = size
	item["yaw"] = float(posmod(String(item["seed"]).hash(), 6283)) / 1000.0
	return item


static func _opening(
	kind: String, facade: int, center: float, width: float, height: float, sill: float
) -> Dictionary:
	return {
		"kind": kind,
		"facade": facade,
		"center": center,
		"width": width,
		"height": height,
		"sill": sill,
		"source": "manual"
	}
