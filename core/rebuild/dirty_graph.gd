class_name DirtyGraph
extends RefCounted
## Pure spatial dependencies. Exact source signatures, including height interpolation halo.


static func key(value: Variant) -> String:
	return JSON.stringify(value, "", true, true)


static func bounds(record: Dictionary) -> Rect2:
	if record.has("hedge"):
		return HedgeRules.bounds(record)
	if record.has("points"):
		var first: Array = record["points"][0]
		var result: Rect2 = Rect2(Vector2(first[0], first[2]), Vector2.ZERO)
		for p: Array in record["points"]:
			result = result.expand(Vector2(p[0], p[2]))
		return result.grow(float(record.get("width", 0.2)) + 1.5)
	if record.has("a"):
		var a: Vector2 = Vector2(record["a"][0], record["a"][1])
		var b: Vector2 = Vector2(record["b"][0], record["b"][1])
		return Rect2(a.min(b), (b - a).abs()).grow(float(record["width"]) + 0.5)
	var p: Vector2 = Vector2(record["position"][0], record["position"][2])
	var size: Vector2 = Vector2.ONE * 2
	if record.has("size"):
		size = Vector2(record["size"][0], record["size"][2])
	return Rect2(p - size * 0.5, size).grow(0.6)


static func field_key(snapshot: Dictionary, region: Rect2) -> String:
	var halo: Rect2 = region.grow(float(snapshot["terrain"].get("spacing", 0.5)) * 2)
	var entries: Array = []
	for entry: Array in snapshot["terrain"]["height_deltas"]:
		var p: Vector2 = (
			Vector2(entry[0], entry[1]) * float(snapshot["terrain"].get("spacing", 0.5))
			- Vector2.ONE * 32
		)
		if (
			p.x >= halo.position.x
			and p.y >= halo.position.y
			and p.x <= halo.end.x
			and p.y <= halo.end.y
		):
			entries.append(entry)
	var pool: Dictionary = snapshot["pool"]
	if not pool.is_empty():
		var c: Vector2 = Vector2(pool["center"][0], pool["center"][1])
		if not halo.grow(float(pool["radius"]) + 0.75).has_point(c):
			pool = {}
	return key(
		[
			snapshot["world_seed"],
			snapshot["terrain"].get("base_profile", "flat"),
			snapshot["terrain"].get("spacing", 0.5),
			entries,
			pool
		]
	)


static func nearby(records: Array, region: Rect2) -> Array:
	var result: Array = []
	for record: Dictionary in records:
		if bounds(record).intersects(region, true):
			result.append(record)
	return result


static func union(records: Array) -> Rect2:
	var result: Rect2 = Rect2()
	for record: Dictionary in records:
		var region: Rect2 = bounds(record)
		result = region if result.size == Vector2.ZERO else result.merge(region)
	return result


static func changed(before: Dictionary, after: Dictionary) -> Dictionary:
	var regions: Array[Rect2] = []
	var ids: Array[String] = []
	for collection: String in ["buildings", "paths", "fences", "bridges", "stairs", "instances"]:
		for record: Dictionary in before.get(collection, []) + after.get(collection, []):
			if record not in before.get(collection, []) or record not in after.get(collection, []):
				if record["id"] not in ids:
					ids.append(record["id"])
				regions.append(bounds(record))
	for record: Array in (
		before.get("terrain", {}).get("height_deltas", [])
		+ after.get("terrain", {}).get("height_deltas", [])
	):
		if (
			record not in before.get("terrain", {}).get("height_deltas", [])
			or record not in after.get("terrain", {}).get("height_deltas", [])
		):
			var p: Vector2 = (
				Vector2(record[0], record[1]) * float(after["terrain"].get("spacing", 0.5))
				- Vector2.ONE * 32
			)
			regions.append(Rect2(p - Vector2.ONE, Vector2.ONE * 2))
	if before.get("pool", {}) != after.get("pool", {}):
		for pool: Dictionary in [before.get("pool", {}), after.get("pool", {})]:
			var polygon: PackedVector2Array = PondShape.contour(pool)
			if not polygon.is_empty():
				var region: Rect2 = Rect2(polygon[0], Vector2.ZERO)
				for p: Vector2 in polygon:
					region = region.expand(p)
				regions.append(region.grow(0.75))
	return {"ids": ids, "regions": regions}
