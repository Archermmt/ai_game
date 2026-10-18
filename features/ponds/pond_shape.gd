class_name PondShape
extends RefCounted
## Signed shoreline distance shared by rendering, brushes and both edit directions.


static func contour(pool: Dictionary) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	if pool.has("outline"):
		for p: Array in pool["outline"]:
			result.append(Vector2(p[0], p[1]))
	elif not pool.is_empty():
		var c: Vector2 = Vector2(pool["center"][0], pool["center"][1])
		for i: int in range(64):
			result.append(c + Vector2(cos(i * TAU / 64), sin(i * TAU / 64)) * pool["radius"])
	return result


static func distance(pool: Dictionary, point: Vector2) -> float:
	if pool.is_empty():
		return INF
	if not pool.has("outline"):
		return (
			point.distance_to(Vector2(pool["center"][0], pool["center"][1])) - float(pool["radius"])
		)
	var polygon: PackedVector2Array = contour(pool)
	var nearest: float = INF
	for i: int in range(polygon.size()):
		nearest = minf(
			nearest,
			point.distance_to(
				Geometry2D.get_closest_point_to_segment(
					point, polygon[i], polygon[(i + 1) % polygon.size()]
				)
			)
		)
	return -nearest if Geometry2D.is_point_in_polygon(point, polygon) else nearest


static func draw(snapshot: Dictionary, points: Array) -> Dictionary:
	var draft: Dictionary = snapshot.duplicate(true)
	if points.size() < 3:
		return draft
	var c: Vector2 = Vector2(points[0][0], points[0][1])
	var water: float = TerrainField.new(snapshot).player_height(c) - 0.15
	if not snapshot["pool"].is_empty():
		water = snapshot["pool"]["water_y"]
	var radius: float = 1.0
	for p: Array in points:
		radius = maxf(radius, c.distance_to(Vector2(p[0], p[1])))
	draft["pool"] = {
		"center": [c.x, c.y], "radius": radius, "water_y": water, "outline": points.duplicate(true)
	}
	return draft


static func format_error(pool: Dictionary) -> String:
	var outline: Variant = pool.get("outline")
	if not outline is Array or outline.size() < 3 or outline.size() > 64:
		return "invalid_pool_outline"
	for p: Variant in outline:
		if (
			not p is Array
			or p.size() != 2
			or not WorldDocument._number(p[0])
			or not WorldDocument._number(p[1])
		):
			return "invalid_pool_outline"
		if absf(float(p[0])) > 22 or absf(float(p[1])) > 22:
			return "pool_boundary_2m"
	var poly: PackedVector2Array = contour(pool)
	var area: float = 0.0
	for i: int in range(poly.size()):
		area += poly[i].cross(poly[(i + 1) % poly.size()])
	if absf(area) < 0.01:
		return "invalid_pool_outline"
	for i: int in range(poly.size()):
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % poly.size()]
		if a.distance_to(b) < 0.1:
			return "invalid_pool_outline"
		for j: int in range(i + 1, poly.size()):
			if j == i + 1 or (i == 0 and j == poly.size() - 1):
				continue
			var c: Vector2 = poly[j]
			var d: Vector2 = poly[(j + 1) % poly.size()]
			if Geometry2D.segment_intersects_segment(a, b, c, d) != null:
				return "pool_self_intersection"
			for pair: Array in [[a, c, d], [b, c, d], [c, a, b], [d, a, b]]:
				if (
					pair[0].distance_to(
						Geometry2D.get_closest_point_to_segment(pair[0], pair[1], pair[2])
					)
					< 1.9999
				):
					return "pool_minimum_width"
	if Geometry2D.offset_polygon(poly, -0.999).is_empty():
		return "pool_minimum_width"
	if Geometry2D.triangulate_polygon(poly).is_empty():
		return "invalid_pool_outline"
	return ""


static func conflicts(pool: Dictionary, margin: float, object: Dictionary) -> bool:
	if not pool.has("outline"):
		return TerrainField.conflicts(
			Vector2(pool["center"][0], pool["center"][1]), pool["radius"] + margin, object
		)
	var c: Vector2 = Vector2(object["position"][0], object["position"][2])
	if object["shape"] == "round":
		return distance(pool, c) < margin + float(object["size"][0]) * 0.5 - 0.00001
	var half: Vector2 = Vector2(object["size"][0], object["size"][2]) * 0.5
	if distance(pool, c) <= 0:
		return true
	var corners: Array[Vector2] = [
		c - half, c + Vector2(half.x, -half.y), c + half, c + Vector2(-half.x, half.y)
	]
	var poly: PackedVector2Array = contour(pool)
	for p: Vector2 in poly:
		if p.distance_to(p.clamp(c - half, c + half)) < margin - 0.00001:
			return true
	for corner: Vector2 in corners:
		if distance(pool, corner) < margin - 0.00001:
			return true
	for i: int in range(poly.size()):
		for j: int in range(4):
			if (
				Geometry2D.segment_intersects_segment(
					poly[i], poly[(i + 1) % poly.size()], corners[j], corners[(j + 1) % 4]
				)
				!= null
			):
				return true
	return false


static func water_arrays(pool: Dictionary) -> Array:
	var builder: BuildingGeometry = BuildingGeometry.new()
	if pool.is_empty():
		return MeshParts.arrays(builder)
	var poly: PackedVector2Array = contour(pool)
	var indices: PackedInt32Array = Geometry2D.triangulate_polygon(poly)
	for i: int in range(0, indices.size(), 3):
		var a: Vector2 = poly[indices[i]]
		var b: Vector2 = poly[indices[i + 1]]
		var c: Vector2 = poly[indices[i + 2]]
		# The common builder enforces Godot's clockwise front faces with upward normals.
		builder._triangle(
			Vector3(a.x, pool["water_y"], a.y),
			Vector3(b.x, pool["water_y"], b.y),
			Vector3(c.x, pool["water_y"], c.y),
			Vector3.UP,
			Color.WHITE
		)
	return MeshParts.arrays(builder)
