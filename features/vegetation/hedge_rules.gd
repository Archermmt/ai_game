class_name HedgeRules
extends RefCounted
## Local XZ polyline in an instance record: transforms, history and saves remain shared.


static func allocate(draft: Dictionary, points: Array, width: float = 0.8) -> Dictionary:
	if points.size() < 2:
		return {}
	var origin: Vector2 = Vector2(points[0][0], points[0][1])
	var item: Dictionary = InstanceEdits.allocate(draft, Vector3(origin.x, 0, origin.y), false)
	item["asset_id"] = "NAT-07"
	item["category"] = "plants"
	item["hedge"] = {"points": [], "width": width}
	for p: Array in points:
		item["hedge"]["points"].append([p[0] - origin.x, p[1] - origin.y])
	return item


static func shape_error(item: Dictionary) -> String:
	var hedge: Variant = item.get("hedge")
	if not hedge is Dictionary or item.get("asset_id") != "NAT-07":
		return "invalid_hedge"
	var width: Variant = hedge.get("width")
	var points: Variant = hedge.get("points")
	if not WorldDocument._number(width) or width < 0.5 or width > 1.6:
		return "invalid_hedge_width"
	if not points is Array or points.size() < 2 or points.size() > 32:
		return "invalid_hedge_points"
	var total: float = 0
	for i: int in range(points.size()):
		var p: Variant = points[i]
		if not p is Array or p.size() != 2:
			return "invalid_hedge_points"
		if not WorldDocument._number(p[0]) or not WorldDocument._number(p[1]):
			return "invalid_hedge_points"
		if i > 0:
			var gap: float = Vector2(p[0] - points[i - 1][0], p[1] - points[i - 1][1]).length()
			if gap < 0.25 or gap > 16:
				return "hedge_segment_limit"
			total += gap
	return "hedge_length_limit" if total > 40 else ""


static func samples(item: Dictionary) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var points: Array = item["hedge"]["points"]
	for i: int in range(points.size() - 1):
		var a: Vector2 = Vector2(points[i][0], points[i][1])
		var b: Vector2 = Vector2(points[i + 1][0], points[i + 1][1])
		var steps: int = maxi(1, ceili(a.distance_to(b) / 0.45))
		for j: int in range(steps):
			result.append(a.lerp(b, float(j) / steps))
	result.append(Vector2(points.back()[0], points.back()[1]))
	return result


static func world_point(item: Dictionary, local: Vector2) -> Vector2:
	var rotated: Vector3 = Basis(Vector3.UP, item["yaw"]) * Vector3(local.x, 0, local.y)
	return (
		Vector2(item["position"][0], item["position"][2])
		+ Vector2(rotated.x, rotated.z) * item["scale"]
	)


static func distance(item: Dictionary, point: Vector2) -> float:
	var points: Array = item["hedge"]["points"]
	var best: float = INF
	for i: int in range(points.size() - 1):
		var a: Vector2 = world_point(item, Vector2(points[i][0], points[i][1]))
		var b: Vector2 = world_point(item, Vector2(points[i + 1][0], points[i + 1][1]))
		best = minf(best, point.distance_to(Geometry2D.get_closest_point_to_segment(point, a, b)))
	return best


static func bounds(item: Dictionary) -> Rect2:
	var points: Array[Vector2] = samples(item)
	var result: Rect2 = Rect2(world_point(item, points[0]), Vector2.ZERO)
	for p: Vector2 in points:
		result = result.expand(world_point(item, p))
	return result.grow(item["hedge"]["width"] * item["scale"] * 0.5 + 0.6)


static func clearance(snapshot: Dictionary, item: Dictionary) -> bool:
	for p: Vector2 in samples(item):
		var world: Vector2 = world_point(item, p)
		var radius: float = item["hedge"]["width"] * item["scale"] * 0.5
		for offset: Vector2 in [
			Vector2.ZERO, Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN
		]:
			if not VegetationBrush.geometry_clear(snapshot, world + offset * radius):
				return false
	return true
