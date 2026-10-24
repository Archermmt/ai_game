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


static func generate_cached(source: Dictionary, cache: Dictionary) -> Dictionary:
	# This cache belongs to the single meadow worker. Published arrays remain immutable.
	var started: int = Time.get_ticks_usec()
	var geometry: String = distribution_key(source)
	var chunks: Dictionary = {}
	var signatures: Dictionary = {}
	var count: int = 0
	var updated: int = 0
	var distribution_epoch: int = cache.get("distribution_epoch", 0)
	if cache.get("geometry", "") != geometry:
		distribution_epoch += 1
		var fresh: Dictionary = generate(source)
		chunks = fresh["chunks"]
		count = fresh["count"]
		updated = chunks.size()
		for key: Vector2i in chunks:
			signatures[key] = TerrainChunks.signature(source, Vector2(key) * CELL_SIZE)
	else:
		var field: TerrainField = TerrainField.new(source)
		for key: Vector2i in cache["chunks"]:
			var signature: String = TerrainChunks.signature(source, Vector2(key) * CELL_SIZE)
			signatures[key] = signature
			var items: Array = cache["chunks"][key]
			count += items.size()
			if signature == cache["signatures"][key]:
				chunks[key] = items
				continue
			updated += 1
			var next: Array = []
			for item: Dictionary in items:
				var copy: Dictionary = item.duplicate()
				var p: Vector3 = item["p"]
				p.y = field.height_at(Vector2(p.x, p.z)) - 0.015
				copy["p"] = p
				next.append(copy)
			chunks[key] = next
	var buffers: Dictionary = {}
	var versions: Dictionary = {}
	for key: Vector2i in chunks:
		var version: Array = [distribution_epoch, signatures[key]]
		versions[key] = version
		buffers[key] = (
			cache["buffers"][key]
			if cache.get("versions", {}).get(key, []) == version
			else chunk_buffer(chunks[key], key)
		)
	cache["distribution_epoch"] = distribution_epoch
	cache["buffers"] = buffers
	cache["versions"] = versions
	cache["geometry"] = geometry
	cache["chunks"] = chunks
	cache["signatures"] = signatures
	return {
		"chunks": chunks,
		"count": count,
		"updated_chunks": updated,
		"buffers": buffers,
		"versions": versions,
		"worker_ms": (Time.get_ticks_usec() - started) / 1000.0
	}


static func distribution_key(source: Dictionary) -> String:
	# Match _obstacles' actual 2D inputs. Roofs, wall height, windows and prop yaw/Y
	# do not change clearance; terrain heights remain tracked per chunk separately.
	var homes: Array = []
	for home: Dictionary in source["buildings"]:
		var entrances: Array = []
		for opening: Dictionary in home["openings"]:
			if opening["height"] >= 1.8 and opening.get("sill", 0) <= 0.1:
				entrances.append([opening.get("facade", 0), opening["center"], opening["width"]])
		homes.append(
			[
				home["shape"],
				[home["position"][0], home["position"][2]],
				[home["size"][0], home["size"][2]],
				entrances
			]
		)
	var props: Array = []
	for item: Dictionary in source["instances"]:
		if String(item["asset_id"]).begins_with("PROP-"):
			props.append(
				[item["asset_id"], [item["position"][0], item["position"][2]], item["scale"]]
			)
	return DirtyGraph.key(
		[
			source["world_seed"],
			source["pool"],
			homes,
			source["paths"],
			source.get("bridges", []),
			source.get("stairs", []),
			props
		]
	)


static func chunk_buffer(items: Array, key: Vector2i) -> PackedFloat32Array:
	# RenderingServer's row-major Transform3D (12 floats), then custom Color (4).
	# Build on the worker; publish once instead of making two server calls per blade.
	var buffer: PackedFloat32Array = PackedFloat32Array()
	buffer.resize(items.size() * 16)
	var origin: Vector3 = Vector3(key.x * 8 + 4, 0, key.y * 8 + 4)
	for i: int in range(items.size()):
		var item: Dictionary = items[i]
		var pose: Transform3D = Transform3D(
			Basis(Vector3.UP, item["yaw"]).scaled(Vector3.ONE * item["scale"]), item["p"] - origin
		)
		var offset: int = i * 16
		for axis: int in range(3):
			buffer[offset + axis * 4] = pose.basis.x[axis]
			buffer[offset + axis * 4 + 1] = pose.basis.y[axis]
			buffer[offset + axis * 4 + 2] = pose.basis.z[axis]
			buffer[offset + axis * 4 + 3] = pose.origin[axis]
		buffer[offset + 12] = item["phase"]
		buffer[offset + 13] = item["rank"]
		buffer[offset + 14] = 0
		buffer[offset + 15] = 1
	return buffer


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
	# Three curved blades share the existing nine-triangle presentation budget.
	# Distribution, density ranks and worker buffers are intentionally independent.
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	var heights: Array[float] = [0.252, 0.408, 0.324]
	var widths: Array[float] = [0.019, 0.025, 0.016]
	for i: int in range(3):
		var angle: float = i * 2.399963 + 0.31
		var side: Vector3 = Vector3(cos(angle), 0, sin(angle)) * widths[i]
		var forward: Vector3 = Vector3(sin(angle), 0, -cos(angle))
		var base: Vector3 = forward * (0.012 + i * 0.009)
		var tip: Vector3 = base + Vector3.UP * heights[i] + forward * (0.10 + i * 0.021)
		var mid: Vector3 = base + Vector3.UP * heights[i] * 0.57 + forward * 0.026
		for point: Vector3 in [
			base - side * 0.42,
			mid - side,
			mid + side,
			base - side * 0.42,
			mid + side,
			base + side * 0.42,
			mid - side,
			tip,
			mid + side
		]:
			vertices.append(point)
			normals.append(Vector3.UP)
			colors.append(Color(point.y / 0.408, float(i) * 0.5, 0, 1))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
