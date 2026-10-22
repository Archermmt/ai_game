class_name BuildingIndex
extends RefCounted
## Per-evaluation broad phase; exact existing footprint tests remain authoritative.

const CELL_SIZE: float = 8.0
var cells: Dictionary = {}


func _init(buildings: Array) -> void:
	for home: Dictionary in buildings:
		var center: Vector2 = Vector2(home["position"][0], home["position"][2])
		var half: Vector2 = Vector2(home["size"][0], home["size"][2]) * 0.5
		if home["shape"] == "round":
			half.y = half.x
		var low: Vector2i = Vector2i(((center - half) / CELL_SIZE).floor())
		var high: Vector2i = Vector2i(((center + half) / CELL_SIZE).floor())
		for z: int in range(low.y, high.y + 1):
			for x: int in range(low.x, high.x + 1):
				var key: Vector2i = Vector2i(x, z)
				if not cells.has(key):
					cells[key] = []
				cells[key].append(home)


func conflicts(point: Vector2, radius: float) -> bool:
	var low: Vector2i = Vector2i(((point - Vector2.ONE * radius) / CELL_SIZE).floor())
	var high: Vector2i = Vector2i(((point + Vector2.ONE * radius) / CELL_SIZE).floor())
	for z: int in range(low.y, high.y + 1):
		for x: int in range(low.x, high.x + 1):
			for home: Dictionary in cells.get(Vector2i(x, z), []):
				if TerrainField.conflicts(point, radius, home):
					return true
	return false
