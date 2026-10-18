class_name TerrainChunks
extends RefCounted
## Exact source signature per chunk, including the normal-sampling halo.


static func signature(snapshot: Dictionary, origin: Vector2) -> String:
	var spacing: float = snapshot["terrain"].get("spacing", 0.5)
	var bounds: Rect2 = Rect2(origin, Vector2(8, 8)).grow(spacing * 2)
	var entries: Array = []
	for entry: Array in snapshot["terrain"]["height_deltas"]:
		var p: Vector2 = Vector2(entry[0], entry[1]) * spacing - Vector2.ONE * 32
		if (
			p.x >= bounds.position.x
			and p.y >= bounds.position.y
			and p.x <= bounds.end.x
			and p.y <= bounds.end.y
		):
			entries.append(entry)
	var pool: Dictionary = snapshot["pool"]
	if not pool.is_empty():
		var c: Vector2 = Vector2(pool["center"][0], pool["center"][1])
		if not bounds.grow(float(pool["radius"]) + 0.75).has_point(c):
			pool = {}
	return JSON.stringify(
		[
			spacing,
			snapshot["terrain"].get("base_profile", "flat"),
			snapshot["world_seed"],
			entries,
			pool
		]
	)
