class_name TerrainEdits
extends RefCounted
## Finite player-delta brushes. Base profile and pond derivation remain independent.


static func stroke(
	snapshot: Dictionary, point: Vector2, mode: String, radius: float = 2.0, strength: float = 0.35
) -> Dictionary:
	var draft: Dictionary = snapshot.duplicate(true)
	var field: TerrainField = TerrainField.new(snapshot)
	var changes: Dictionary = field.heights.duplicate()
	var low: Vector2i = Vector2i(
		((point - Vector2.ONE * radius + Vector2.ONE * 32) / field.spacing).floor()
	)
	var high: Vector2i = Vector2i(
		((point + Vector2.ONE * radius + Vector2.ONE * 32) / field.spacing).ceil()
	)
	for z: int in range(low.y, high.y + 1):
		for x: int in range(low.x, high.x + 1):
			var cell: Vector2i = Vector2i(x, z)
			var p: Vector2 = Vector2(cell) * field.spacing - Vector2.ONE * 32
			var distance: float = p.distance_to(point)
			if (
				absf(p.x) >= 24
				or absf(p.y) >= 24
				or distance > radius
				or field.is_protected(p)
				or entrance_protected(snapshot, p)
			):
				continue
			var weight: float = 1 - smoothstep(0, radius, distance)
			var value: float = changes.get(cell, 0.0)
			if mode == "restore":
				value = 0.0
			elif mode == "smooth":
				var mean: float = 0.0
				for dz: int in range(-1, 2):
					for dx: int in range(-1, 2):
						mean += field.player_height(p + Vector2(dx, dz) * field.spacing) / 9.0
				value = lerpf(value, mean - field.base_height(p), weight * 0.6)
			else:
				value += strength * weight * (-1.0 if mode == "lower" else 1.0)
			changes[cell] = snappedf(value, 0.0001)
	var keys: Array = changes.keys()
	keys.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x)
	)
	draft["terrain"]["height_deltas"] = []
	for cell: Vector2i in keys:
		if absf(changes[cell]) > 0.00001:
			draft["terrain"]["height_deltas"].append([cell.x, cell.y, changes[cell]])
	return draft


static func entrance_protected(snapshot: Dictionary, p: Vector2) -> bool:
	for home: Dictionary in snapshot["buildings"]:
		for opening: Dictionary in home["openings"]:
			if opening["height"] < 1.8 or opening.get("sill", 0.0) > 0.1:
				continue
			var length: float = DoorRules._length(home, opening.get("facade", 0))
			var u: float = opening["center"] * length
			var v: Vector3 = BuildingGeometry._point(
				u,
				opening.get("facade", 0),
				home["size"][0],
				home["size"][2],
				home["shape"] == "round"
			)
			v += Vector3(home["position"][0], 0, home["position"][2])
			if p.distance_to(Vector2(v.x, v.z)) < float(opening["width"]) * 0.5 + 0.5:
				return true
	return false
