class_name MeadowData
extends RefCounted
## Stable stratified cells. Derived presentation only; no IDs or random state enter saves.

const STEP: float = 0.24
const CELL_SIZE: float = 8.0


static func signature(source: Dictionary) -> int:
	return hash(
		[
			source["world_seed"],
			source["terrain"],
			source["pool"],
			source["buildings"],
			source["paths"],
			source.get("bridges", []),
			source.get("stairs", []),
			source["instances"]
		]
	)


static func generate(source: Dictionary) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	var field: TerrainField = TerrainField.new(source)
	var obstacles: Dictionary = _obstacles(source)
	var chunks: Dictionary = {}
	var count: int = 0
	for z: int in range(-100, 100):
		for x: int in range(-100, 100):
			var rng: RandomNumberGenerator = RandomNumberGenerator.new()
			rng.seed = (str(source["world_seed"]) + ":meadow:%d:%d" % [x, z]).hash()
			var p: Vector2 = (
				Vector2(x + rng.randf_range(0.12, 0.88), z + rng.randf_range(0.12, 0.88)) * STEP
			)
			if not clear(p, obstacles, source["pool"]):
				continue
			var chunk: Vector2i = Vector2i(floori(p.x / CELL_SIZE), floori(p.y / CELL_SIZE))
			if not chunks.has(chunk):
				chunks[chunk] = []
			chunks[chunk].append(
				{
					"p": Vector3(p.x, field.height_at(p) - 0.015, p.y),
					"yaw": rng.randf_range(0, TAU),
					"scale": rng.randf_range(0.65, 1.4),
					"rank": rng.randf(),
					"phase": rng.randf()
				}
			)
			count += 1
	for chunk: Vector2i in chunks:
		chunks[chunk].sort_custom(
			func(a: Dictionary, b: Dictionary) -> bool: return a["rank"] < b["rank"]
		)
	return {
		"chunks": chunks, "count": count, "worker_ms": (Time.get_ticks_usec() - started) / 1000.0
	}


static func clear(p: Vector2, obstacles: Dictionary, pool: Dictionary) -> bool:
	if not pool.is_empty() and PondShape.distance(pool, p) < 0.58:
		return false
	var cell: Vector2i = Vector2i(floori(p.x / CELL_SIZE), floori(p.y / CELL_SIZE))
	for item: Dictionary in obstacles.get(cell, []):
		match item["kind"]:
			"rect":
				if item["bounds"].has_point(p):
					return false
			"circle":
				if p.distance_squared_to(item["center"]) < item["radius"] * item["radius"]:
					return false
			"segment":
				if (
					p.distance_to(Geometry2D.get_closest_point_to_segment(p, item["a"], item["b"]))
					< item["radius"]
				):
					return false
	return true


static func _insert(index: Dictionary, bounds: Rect2, item: Dictionary) -> void:
	var lo: Vector2i = Vector2i((bounds.position / CELL_SIZE).floor())
	var hi: Vector2i = Vector2i((bounds.end / CELL_SIZE).floor())
	for z: int in range(lo.y, hi.y + 1):
		for x: int in range(lo.x, hi.x + 1):
			var key: Vector2i = Vector2i(x, z)
			if not index.has(key):
				index[key] = []
			index[key].append(item)


static func _obstacles(source: Dictionary) -> Dictionary:
	var index: Dictionary = {}
	for home: Dictionary in source["buildings"]:
		var p: Vector2 = Vector2(home["position"][0], home["position"][2])
		var size: Vector2 = Vector2(home["size"][0], home["size"][2])
		var bounds: Rect2 = Rect2(p - size * 0.5, size).grow(0.16)
		var item: Dictionary = {"kind": "rect", "bounds": bounds}
		if home["shape"] == "round":
			item = {"kind": "circle", "center": p, "radius": size.x * 0.5 + 0.16}
		_insert(index, bounds, item)
		for opening: Dictionary in home["openings"]:
			if opening["height"] < 1.8 or opening.get("sill", 0) > 0.1:
				continue
			var facade: int = opening.get("facade", 0)
			var point: Vector3 = BuildingGeometry._point(
				opening["center"] * DoorRules._length(home, facade),
				facade,
				size.x,
				size.y,
				home["shape"] == "round"
			)
			var center: Vector2 = p + Vector2(point.x, point.z)
			var radius: float = opening["width"] * 0.5 + 0.6
			_insert(
				index,
				Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2),
				{"kind": "circle", "center": center, "radius": radius}
			)
	for path: Dictionary in source["paths"]:
		var points: Array[Vector2] = PathCurve.sample(path)
		for i: int in range(points.size() - 1):
			_segment(index, points[i], points[i + 1], path["width"] * 0.5 + 0.18)
	for collection: String in ["bridges", "stairs"]:
		for item: Dictionary in source.get(collection, []):
			_segment(
				index,
				Vector2(item["a"][0], item["a"][1]),
				Vector2(item["b"][0], item["b"][1]),
				item["width"] * 0.5 + 0.2
			)
	for item: Dictionary in source["instances"]:
		if not String(item["asset_id"]).begins_with("PROP-"):
			continue
		var center: Vector2 = Vector2(item["position"][0], item["position"][2])
		var radius: float = 0.45 * float(item["scale"])
		_insert(
			index,
			Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2),
			{"kind": "circle", "center": center, "radius": radius}
		)
	return index


static func _segment(index: Dictionary, a: Vector2, b: Vector2, radius: float) -> void:
	_insert(
		index,
		Rect2(a.min(b), (b - a).abs()).grow(radius),
		{"kind": "segment", "a": a, "b": b, "radius": radius}
	)


static func blade_mesh() -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	for i: int in range(3):
		var angle: float = i * PI / 3
		var side: Vector3 = Vector3(cos(angle), 0, sin(angle)) * 0.035
		var bend: Vector3 = Vector3(sin(angle), 0, -cos(angle)) * 0.11
		var tip: Vector3 = Vector3(0, 0.38 + i * 0.035, 0) + bend
		var mid: Vector3 = tip * 0.55
		for point: Vector3 in [
			-side,
			mid - side * 0.55,
			mid + side * 0.55,
			-side,
			mid + side * 0.55,
			side,
			mid - side * 0.55,
			tip,
			mid + side * 0.55
		]:
			vertices.append(point)
			normals.append(Vector3.UP)
			colors.append(Color(point.y / 0.46, 0, 0, 1))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
