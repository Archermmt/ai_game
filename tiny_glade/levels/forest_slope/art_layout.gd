class_name ArtLayout
extends RefCounted
## Art-directed SCN-01. Every core object remains source-owned and editable.


static func empty() -> Dictionary:
	var source: Dictionary = ForestTemplate.empty()
	source["instances"].clear()
	source = TerrainField.brush(source, Vector2(1, -3), 0.4, 8.0)
	source = TerrainField.brush(source, Vector2(1, -3), 0.15, 4.5)
	var trees: Array = [
		[-14, -8, 0],
		[-10, -12, 1],
		[-5, -13, 0],
		[1, -14, 1],
		[8, -12, 0],
		[13, -8, 0],
		[16, -3, 1],
		[17, 4, 0],
		[14, 11, 0],
		[8, 17, 1],
		[-14, 14, 0],
		[-18, 8, 0],
		[-18, 1, 1],
		[-18, -12, 0],
		[14, -16, 1],
		[-21, 17, 0],
		[-8, 21, 0],
		[17, 18, 1],
		[-21, -4, 0],
		[21, -10, 1]
	]
	for i: int in range(trees.size()):
		var tree: Array = trees[i]
		var item: Dictionary = _place(
			source,
			"NAT-02" if tree[2] else "NAT-01",
			Vector2(tree[0], tree[1]),
			0.9 + float(i % 4) * 0.12
		)
		item["yaw"] = float(i) * 1.79
	source["camera_bookmarks"] = [
		{
			"id": "recommended_day",
			"target": [-0.3, 1.7, 2.0],
			"distance": 27.0,
			"yaw": 0.48,
			"pitch": 0.48
		},
		{
			"id": "recommended_garden",
			"target": [1.4, 1.9, 0.6],
			"distance": 18.0,
			"yaw": 0.70,
			"pitch": 0.48
		}
	]
	return source


static func create() -> Dictionary:
	var source: Dictionary = empty()
	var home: Dictionary = WorldDocument.allocate_building(
		source, Vector3(2, 0.75, -1.5), Vector3(5.8, 3.5, 5.4)
	)
	home["openings"] = [
		{
			"kind": "arch",
			"center": 0.37,
			"width": 1.1,
			"height": 2.05,
			"source": "manual",
			"sill": 0.0
		},
		{
			"kind": "rect",
			"center": 0.78,
			"width": 1.0,
			"height": 1.0,
			"sill": 1.15,
			"facade": 0,
			"source": "manual"
		},
		{
			"kind": "round",
			"center": 0.50,
			"width": 0.75,
			"height": 0.75,
			"sill": 2.55,
			"facade": 0,
			"source": "manual"
		},
		{
			"kind": "rect",
			"center": 0.43,
			"width": 1.0,
			"height": 1.0,
			"sill": 1.2,
			"facade": 3,
			"source": "manual"
		}
	]
	var wing: Dictionary = WorldDocument.allocate_building(
		source, Vector3(6.4, 0.65, -0.4), Vector3(3.0, 2.4, 3.2)
	)
	wing["openings"] = [
		{
			"kind": "rect",
			"center": 0.5,
			"width": 1.0,
			"height": 1.0,
			"sill": 0.9,
			"facade": 0,
			"source": "manual"
		},
		{
			"kind": "round",
			"center": 0.5,
			"width": 0.7,
			"height": 0.7,
			"sill": 1.1,
			"facade": 1,
			"source": "manual"
		}
	]
	var shed: Dictionary = WorldDocument.allocate_building(
		source, Vector3(-5.6, 0.45, -2.4), Vector3(3.4, 2.8, 3.4), "round"
	)
	shed["openings"] = [
		{"kind": "arch", "center": 0.10, "width": 1.1, "height": 2.05, "source": "manual"},
		{
			"kind": "round",
			"center": 0.32,
			"width": 0.8,
			"height": 0.8,
			"sill": 1.25,
			"source": "manual"
		}
	]
	source = PondShape.draw(
		source, [[-8.5, 4.2], [-3.2, 3.5], [-1.2, 5.5], [-2.8, 7.7], [-7.6, 7.9], [-9.5, 6.1]]
	)
	GardenStructures.allocate(source, "bridge", Vector2(-3.5, 3.1), Vector2(-3.5, 8.3), 1.25)
	GardenStructures.allocate(source, "stair", Vector2(1.246, 1.28), Vector2(1.246, 3.25), 1.3)
	PathGeometry.allocate(source, [[1, 0, 15], [-0.6, 0, 12], [-3.5, 0, 8.3]], 1.3)
	PathGeometry.allocate(
		source, [[-3.5, 0, 3.1], [-2, 0, 2.4], [0.0, 0, 3.5], [1.25, 0, 3.2]], 1.2
	)
	PathGeometry.allocate(source, [[1.25, 0, 3.2], [4, 0, 3.4], [6.5, 0, 2.7]], 1.05)
	PathGeometry.allocate(source, [[-3.5, 0, 3.1], [-5.4, 0, 1.8], [-4.6, 0, -0.65]], 1.1)
	for path: Dictionary in source["paths"]:
		path["curved"] = true
	FenceGeometry.allocate(source, [[-12, 0, -5], [-12, 0, 1], [-10, 0, 2]])
	FenceGeometry.allocate(source, [[8.8, 0, -4], [8.8, 0, 3.5], [6.7, 0, 5.2]])
	var bench: Dictionary = _place(source, "PROP-01", Vector2(4.7, 3.5))
	for entry: Array in [
		["PROP-02", 0.2, 9.4],
		["PROP-03", -0.5, 2.15],
		["PROP-03", 3.6, 2.3],
		["PROP-04", 9.7, -0.7],
		["PROP-05", 7.9, 2.0],
		["PROP-06", 0.0, 2.8],
		["PROP-08", 2.1, 2.0],
		["PROP-08", -4.3, 10.0]
	]:
		_place(source, entry[0], Vector2(entry[1], entry[2]), 1.0)
	var tea: Dictionary = _place(source, "PROP-07", Vector2(4.7, 3.5))
	tea["support_id"] = bench["id"]
	for entry: Array in [
		["NAT-03", 9.5, 7, 1.05],
		["NAT-01", -11.5, 7.5, 1.1],
		["NAT-01", 10.5, -5.8, 1.05],
		["NAT-03", -9.8, -1.0, 0.9],
		["NAT-08", -9.6, 10.0, 0.95],
		["NAT-08", 5.5, 8.4, 0.85],
		["NAT-09", 7.4, 6.8, 0.9]
	]:
		_place(source, entry[0], Vector2(entry[1], entry[2]), entry[3])
	for center: Vector2 in [
		Vector2(-11, 7),
		Vector2(-7, 11),
		Vector2(-8, 1),
		Vector2(7, 6),
		Vector2(8, 1),
		Vector2(1, 10),
		Vector2(-12, -3),
		Vector2(10, -6),
		Vector2(-2, -6),
		Vector2(3, 7)
	]:
		VegetationBrush.paint(source, center, "plants", 2.7, 0.72, {})
	return source


static func _place(
	source: Dictionary, asset: String, point: Vector2, scale_value: float = 1.0
) -> Dictionary:
	var item: Dictionary = InstanceEdits.allocate(source, Vector3(point.x, 0, point.y))
	item["asset_id"] = asset
	item["scale"] = scale_value
	item["yaw"] = float(item["seed"].hash() % 6283) / 1000
	return item
