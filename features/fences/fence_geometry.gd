class_name FenceGeometry
extends RefCounted
## W04 opening slice: saved control points, grounded posts/rails and path gaps.


static func allocate(draft: Dictionary, points: Array) -> void:
	if not draft.has("fences"):
		draft["fences"] = []
	var key: String = "%s:fence:%d" % [draft["world_seed"], draft["next_id"]]
	draft["next_id"] += 1
	draft["fences"].append(
		{"id": key.sha256_text().left(24), "points": points.duplicate(true), "closed": false}
	)


static func build(snapshot: Dictionary) -> Array:
	var builder: BuildingGeometry = BuildingGeometry.new()
	var field: TerrainField = TerrainField.new(snapshot)
	var posts: Dictionary = {}
	for fence: Dictionary in snapshot.get("fences", []):
		var points: Array = fence["points"].duplicate(true)
		if fence.get("closed", false):
			points.append(points[0])
		for i: int in range(points.size() - 1):
			var a: Vector2 = Vector2(points[i][0], points[i][2])
			var b: Vector2 = Vector2(points[i + 1][0], points[i + 1][2])
			var count: int = maxi(1, ceili(a.distance_to(b) / 0.9))
			for step: int in range(count + 1):
				var p: Vector2 = a.lerp(b, float(step) / count)
				if _road_gap(snapshot, p):
					continue
				var key: String = str(p.snapped(Vector2.ONE * 0.01))
				if not posts.has(key):
					posts[key] = true
					MeshParts.box(
						builder,
						Vector3(p.x, field.height_at(p) + 0.45, p.y),
						Vector3(0.11, 0.9, 0.11),
						Color("89643e")
					)
				if step == count:
					continue
				var q: Vector2 = a.lerp(b, float(step + 1) / count)
				if _road_gap(snapshot, q) or _road_gap(snapshot, (p + q) * 0.5):
					continue
				for height: float in [0.3, 0.65]:
					var along: Vector3 = Vector3(
						q.x - p.x, field.height_at(q) - field.height_at(p), q.y - p.y
					)
					var side: Vector3 = Vector3(along.z, 0, -along.x).normalized() * 0.035
					var base: Vector3 = Vector3(p.x, field.height_at(p) + height, p.y)
					builder._quad(
						base - side,
						base + along - side,
						base + along + side,
						base + side,
						Vector3.UP,
						Color("89643e")
					)
					builder._quad(
						base - side,
						base - side + Vector3.UP * 0.07,
						base + along - side + Vector3.UP * 0.07,
						base + along - side,
						-side.normalized(),
						Color("89643e")
					)
					builder._quad(
						base + side,
						base + along + side,
						base + along + side + Vector3.UP * 0.07,
						base + side + Vector3.UP * 0.07,
						side.normalized(),
						Color("89643e")
					)
	return MeshParts.arrays(builder)


static func _road_gap(snapshot: Dictionary, p: Vector2) -> bool:
	for path: Dictionary in snapshot["paths"]:
		var points: Array[Vector2] = PathCurve.sample(path)
		for i: int in range(points.size() - 1):
			if (
				p.distance_to(Geometry2D.get_closest_point_to_segment(p, points[i], points[i + 1]))
				< float(path["width"]) * 0.5 + 0.25
			):
				return true
	return false


static func validate(snapshot: Dictionary, ids: Dictionary) -> String:
	if not snapshot.get("fences", []) is Array or snapshot.get("fences", []).size() > 100:
		return "invalid_fences"
	for fence: Variant in snapshot.get("fences", []):
		if not fence is Dictionary or not fence.get("id") is String or ids.has(fence["id"]):
			return "invalid_fence_id"
		ids[fence["id"]] = true
		if (
			not fence.get("closed") is bool
			or not fence.get("points") is Array
			or fence["points"].size() < 2
			or fence["points"].size() > 128
		):
			return "invalid_fence_points"
		for p: Variant in fence["points"]:
			if not p is Array or p.size() != 3:
				return "invalid_fence_points"
			for n: Variant in p:
				if not WorldDocument._number(n):
					return "invalid_fence_points"
			if absf(float(p[0])) > 23.5 or absf(float(p[2])) > 23.5:
				return "fence_outside_bounds"
	return ""
