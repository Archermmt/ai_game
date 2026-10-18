class_name FenceGeometry
extends RefCounted
## Grounded continuous fence: shared corner posts, inset sealed rails, path gaps.


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
						KitProfiles.POST,
						Color("89643e")
					)
				if step == count:
					continue
				var q: Vector2 = a.lerp(b, float(step + 1) / count)
				if _road_gap(snapshot, q) or _road_gap(snapshot, (p + q) * 0.5):
					continue
				for height: float in [0.3, 0.65]:
					var direction: Vector2 = (q - p).normalized()
					var start: Vector2 = p + direction * 0.055
					var end: Vector2 = q - direction * 0.055
					var first: Vector3 = Vector3(start.x, field.height_at(p) + height, start.y)
					var last: Vector3 = Vector3(end.x, field.height_at(q) + height, end.y)
					var local: BuildingGeometry = BuildingGeometry.new()
					MeshParts.box(
						local,
						Vector3.ZERO,
						Vector3(KitProfiles.RAIL.y, KitProfiles.RAIL.z, first.distance_to(last)),
						Color("89643e")
					)
					var frame: Basis = Basis.looking_at(last - first)
					for v: int in range(local._vertices.size()):
						builder._vertices.append((first + last) * 0.5 + frame * local._vertices[v])
						builder._normals.append(frame * local._normals[v])
						builder._colors.append(local._colors[v])
						builder._uvs.append(local._uvs[v])
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
		if fence["closed"] and fence["points"].size() < 3:
			return "invalid_fence_points"
		for p: Variant in fence["points"]:
			if not p is Array or p.size() != 3:
				return "invalid_fence_points"
			for n: Variant in p:
				if not WorldDocument._number(n):
					return "invalid_fence_points"
			if absf(float(p[0])) > 23.5 or absf(float(p[2])) > 23.5:
				return "fence_outside_bounds"
		for i: int in range(fence["points"].size() - 1):
			var a: Array = fence["points"][i]
			var b: Array = fence["points"][i + 1]
			if Vector2(a[0] - b[0], a[2] - b[2]).length() < 0.2:
				return "invalid_fence_points"
		if fence["closed"]:
			var a: Array = fence["points"][0]
			var b: Array = fence["points"].back()
			if Vector2(a[0] - b[0], a[2] - b[2]).length() < 0.2:
				return "invalid_fence_points"
	return ""
