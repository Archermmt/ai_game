class_name PathGeometry
extends RefCounted
## W03 path groundwork: sampled brush polyline, source IDs, ground projection.


static func allocate(draft: Dictionary, points: Array, width: float = 1.2) -> String:
	var key: String = "%s:path:%d" % [draft["world_seed"], draft["next_id"]]
	draft["next_id"] += 1
	var id_value: String = key.sha256_text().left(24)
	draft["paths"].append(
		{
			"id": id_value,
			"seed": key.sha256_text(),
			"points": points.duplicate(true),
			"width": width
		}
	)
	return id_value


static func arrays(snapshot: Dictionary) -> Array:
	var field: TerrainField = TerrainField.new(snapshot)
	var builder: BuildingGeometry = BuildingGeometry.new()
	# A shared world-space lattice avoids stacked overlapping surfaces at crossings.
	var cells: Dictionary = {}
	var paths: Array = snapshot["paths"].duplicate()
	paths.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["id"] < b["id"])
	for path: Dictionary in paths:
		var segments: Array = _segments(path, snapshot, field)
		for segment: Array in segments:
			var a: Vector2 = segment[0]
			var b: Vector2 = segment[1]
			var radius: float = path["width"] * 0.5
			var lo: Vector2i = Vector2i(((a.min(b) - Vector2.ONE * radius) * 4).floor())
			var hi: Vector2i = Vector2i(((a.max(b) + Vector2.ONE * radius) * 4).ceil())
			for z: int in range(lo.y, hi.y + 1):
				for x: int in range(lo.x, hi.x + 1):
					var cell: Vector2i = Vector2i(x, z)
					var center: Vector2 = (Vector2(cell) + Vector2.ONE * 0.5) * 0.25
					var nearest: Vector2 = Geometry2D.get_closest_point_to_segment(center, a, b)
					if center.distance_to(nearest) <= radius and not _blocked(center, snapshot):
						if not cells.has(cell):
							cells[cell] = path.get("seed", path["id"])
	var keys: Array = cells.keys()
	keys.sort()
	for cell: Vector2i in keys:
		var p: Vector2 = Vector2(cell) * 0.25
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = (str(cells[cell]) + ":stone:" + str(cell)).hash()
		var corners: Array[Vector3] = []
		for offset: Vector2 in [
			Vector2.ZERO, Vector2(0.25, 0), Vector2(0.25, 0.25), Vector2(0, 0.25)
		]:
			var v: Vector2 = p + offset
			v.x += rng.randf_range(0.01, 0.035) * (1.0 if offset.x == 0.0 else -1.0)
			v.y += rng.randf_range(0.01, 0.035) * (1.0 if offset.y == 0.0 else -1.0)
			corners.append(Vector3(v.x, field.height_at(v) + 0.025, v.y))
		builder._quad(
			corners[0],
			corners[1],
			corners[2],
			corners[3],
			Vector3.UP,
			Color("b0ac91").darkened(rng.randf_range(0.0, 0.06))
		)
	var result: Array = []
	result.resize(Mesh.ARRAY_MAX)
	result[Mesh.ARRAY_VERTEX] = builder._vertices
	result[Mesh.ARRAY_NORMAL] = builder._normals
	result[Mesh.ARRAY_COLOR] = builder._colors
	result[Mesh.ARRAY_TEX_UV] = builder._uvs
	return result


static func _segments(path: Dictionary, snapshot: Dictionary, field: TerrainField) -> Array:
	var samples: Array[Vector2] = PathCurve.sample(path)
	var segments: Array = []
	for i: int in range(samples.size() - 1):
		segments.append([samples[i], samples[i + 1]])
	for home: Dictionary in snapshot["buildings"]:
		for opening: Dictionary in home["openings"]:
			if opening["height"] < 1.8:
				continue
			var length: float = DoorRules._length(home, opening.get("facade", 0))
			var local: Vector3 = BuildingGeometry._point(
				opening["center"] * length,
				opening.get("facade", 0),
				home["size"][0],
				home["size"][2],
				home["shape"] == "round"
			)
			var entry: Vector2 = Vector2(
				local.x + home["position"][0], local.z + home["position"][2]
			)
			var nearest: Vector2 = samples[0]
			for i: int in range(samples.size() - 1):
				var p: Vector2 = Geometry2D.get_closest_point_to_segment(
					entry, samples[i], samples[i + 1]
				)
				if entry.distance_to(p) < entry.distance_to(nearest):
					nearest = p
			if (
				nearest.distance_to(entry) <= 1.2
				and DoorRules.wall_point(home, nearest)["distance"] <= 0.6
				and absf(field.height_at(nearest) - float(home["position"][1])) <= 0.45
			):
				segments.append([nearest, entry])
	return segments


static func _blocked(point: Vector2, snapshot: Dictionary) -> bool:
	for building: Dictionary in snapshot["buildings"]:
		if TerrainField.conflicts(point, 0.18, building):
			return true
	if not snapshot["pool"].is_empty():
		if PondShape.distance(snapshot["pool"], point) < 0.3:
			return true
	return absf(point.x) > 23.7 or absf(point.y) > 23.7
