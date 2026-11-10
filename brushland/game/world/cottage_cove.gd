extends RefCounted

# Everything in this composition is a regular, editable world cell or object.
static func create(data: IslandData) -> void:
	data.clear_world()
	var middle := Vector2(31, 32)
	for z in range(26, 38):
		for x in range(24, 39):
			var unit := (Vector2(x, z) - middle) / Vector2(6.1, 3.9)
			var angle := unit.angle()
			var edge := 1.0 + 0.10 * sin(3.0 * angle + 0.4) + 0.06 * cos(5.0 * angle)
			if unit.length() <= edge:
				var stone := x >= 35 and z >= 32
				data.tiles[data.key(Vector2i(x, z))] = {
					"h": 1, "surface": "rock" if stone else "grass",
					"road": false, "flower": false
				}
	# The front door looks over the lake. The dock meets the path on the west.
	var landing := Vector2i(25, 33)
	data.paint([landing, Vector2i(26, 33)], "grass")
	for x in range(22, 25):
		data.paint([Vector2i(x, 32), Vector2i(x, 33)], "water")
	for x in range(25, 31):
		data.paint([Vector2i(x, 33)], "road")
	data.paint([Vector2i(30, 34), Vector2i(31, 34), Vector2i(32, 34)], "road")
	BuildingRules.place(data, Vector2i(30, 31), "house")
	BuildingRules.place(data, Vector2i(31, 29), "tree")
	BuildingRules.place(data, landing, "dock", 1, 2)
	BuildingRules.place(data, Vector2i(32, 35), "bench", 2)
	data.paint([Vector2i(28, 30), Vector2i(28, 31), Vector2i(29, 32),
		Vector2i(35, 30), Vector2i(34, 33), Vector2i(34, 34),
		Vector2i(29, 34), Vector2i(31, 35), Vector2i(33, 35)], "flower")
	data.history.clear()
	data.future.clear()
	data.revision += 1
