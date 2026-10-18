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
	for path: Dictionary in snapshot["paths"]:
		for index: int in range(path["points"].size() - 1):
			var p: Array = path["points"][index]
			var q: Array = path["points"][index + 1]
			var a: Vector2 = Vector2(p[0], p[2])
			var b: Vector2 = Vector2(q[0], q[2])
			var radius: float = path["width"] * 0.5
			var lo: Vector2i = Vector2i(((a.min(b) - Vector2.ONE * radius) * 4).floor())
			var hi: Vector2i = Vector2i(((a.max(b) + Vector2.ONE * radius) * 4).ceil())
			for z: int in range(lo.y, hi.y + 1):
				for x: int in range(lo.x, hi.x + 1):
					var cell: Vector2i = Vector2i(x, z)
					var center: Vector2 = (Vector2(cell) + Vector2.ONE * 0.5) * 0.25
					var nearest: Vector2 = Geometry2D.get_closest_point_to_segment(center, a, b)
					if center.distance_to(nearest) <= radius and not _blocked(center, snapshot):
						cells[cell] = true
	var keys: Array = cells.keys()
	keys.sort()
	for cell: Vector2i in keys:
		var p: Vector2 = Vector2(cell) * 0.25
		var corners: Array[Vector3] = []
		for offset: Vector2 in [
			Vector2.ZERO, Vector2(0.25, 0), Vector2(0.25, 0.25), Vector2(0, 0.25)
		]:
			var v: Vector2 = p + offset
			corners.append(Vector3(v.x, field.height_at(v) + 0.025, v.y))
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = (str(snapshot["world_seed"]) + ":stone:" + str(cell)).hash()
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


static func _blocked(point: Vector2, snapshot: Dictionary) -> bool:
	for building: Dictionary in snapshot["buildings"]:
		if TerrainField.conflicts(point, 0.18, building):
			return true
	if not snapshot["pool"].is_empty():
		var pool: Dictionary = snapshot["pool"]
		if (
			point.distance_to(Vector2(pool["center"][0], pool["center"][1]))
			< float(pool["radius"]) + 0.3
		):
			return true
	return absf(point.x) > 23.7 or absf(point.y) > 23.7
