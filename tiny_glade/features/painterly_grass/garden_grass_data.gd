class_name PainterlyGardenGrassData
extends RefCounted
## Worker-owned derived data/cache. No source IDs, nodes or rendering resources are mutated.

const BOUNDS: Rect2 = Rect2(-24, -24, 48, 48)
const RESOLUTION: int = 129


static func layer(key: Vector2i) -> int:
	return (key.y + 3) * 6 + key.x + 3


static func clearance_index(source: Dictionary) -> Dictionary:
	var index: Dictionary = MeadowData._obstacles(source)
	for item: Dictionary in source["instances"]:
		if item["asset_id"] not in ["NAT-01", "NAT-02", "NAT-03", "NAT-08", "NAT-09"]:
			continue
		var p: Array = item["position"]
		var center: Vector2 = Vector2(p[0], p[2])
		var radius: float = (
			(0.60 if item["asset_id"] in ["NAT-08", "NAT-09"] else 0.30) * float(item["scale"])
		)
		MeadowData._insert(
			index,
			Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2),
			{"kind": "circle", "center": center, "radius": radius}
		)
	return index


static func clear(point: Vector2, radius: float, obstacles: Dictionary, pool: Dictionary) -> bool:
	if not BOUNDS.grow(-radius).has_point(point):
		return false
	if not pool.is_empty() and PondShape.distance(pool, point) < 0.58 + radius:
		return false
	var lo: Vector2i = Vector2i(((point - Vector2.ONE * radius) / 8).floor())
	var hi: Vector2i = Vector2i(((point + Vector2.ONE * radius) / 8).floor())
	for z: int in range(lo.y, hi.y + 1):
		for x: int in range(lo.x, hi.x + 1):
			for item: Dictionary in obstacles.get(Vector2i(x, z), []):
				if item["kind"] == "rect" and item["bounds"].grow(radius).has_point(point):
					return false
				if (
					item["kind"] == "circle"
					and point.distance_to(item["center"]) < item["radius"] + radius
				):
					return false
				if (
					item["kind"] == "segment"
					and (
						point.distance_to(
							Geometry2D.get_closest_point_to_segment(point, item["a"], item["b"])
						)
						< item["radius"] + radius
					)
				):
					return false
	return true


static func height_key(source: Dictionary, key: Vector2i) -> String:
	var bounds: Rect2 = Rect2(Vector2(key) * 8, Vector2.ONE * 8).grow(1.5)
	var entries: Array = []
	var spacing: float = source["terrain"].get("spacing", 0.5)
	for entry: Array in source["terrain"]["height_deltas"]:
		if bounds.has_point(Vector2(entry[0], entry[1]) * spacing - Vector2.ONE * 32):
			entries.append(entry)
	var pool: Dictionary = source["pool"]
	if (
		not pool.is_empty()
		and not bounds.grow(pool["radius"] + 0.75).has_point(
			Vector2(pool["center"][0], pool["center"][1])
		)
	):
		pool = {}
	return JSON.stringify(
		[
			source["world_seed"],
			source["terrain"].get("base_profile", "flat"),
			spacing,
			entries,
			pool
		]
	)


static func height_image(field: TerrainField, key: Vector2i) -> Image:
	var image: Image = Image.create(RESOLUTION, RESOLUTION, false, Image.FORMAT_RF)
	var origin: Vector2 = Vector2(key) * 8 - Vector2.ONE
	for z: int in RESOLUTION:
		for x: int in RESOLUTION:
			image.set_pixel(
				x,
				z,
				Color(field.height_at(origin + Vector2(x, z) * 10 / (RESOLUTION - 1)), 0, 0, 1)
			)
	return image


static func generate(source: Dictionary, cache: Dictionary, new_grass: bool) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	var meadow_cache: Dictionary = cache.get("meadow", {})
	var meadow: Dictionary = MeadowData.generate_cached(source, meadow_cache)
	cache["meadow"] = meadow_cache
	var data: Dictionary = {
		"chunks": {},
		"buffers": {},
		"versions": {},
		"images": {},
		"new_grass": new_grass,
		"count": 0
	}
	var field: TerrainField = TerrainField.new(source)
	var obstacles: Dictionary = clearance_index(source) if new_grass else {}
	var images: Dictionary = cache.get("images", {})
	var height_keys: Dictionary = cache.get("height_keys", {})
	for key: Vector2i in meadow["chunks"]:
		var groups: Array[Array] = []
		groups.assign([[], [], []] if new_grass else [[]])
		for item: Dictionary in meadow["chunks"][key]:
			if not new_grass:
				groups[0].append(item)
				continue
			var p: Vector3 = item["p"]
			var point: Vector2 = Vector2(p.x, p.z)
			var mass: float = 0.8 + sin(point.x * 0.65 + cos(point.y * 0.43)) * 0.2
			var rank: float = float(item["rank"]) / (0.72 * mass)
			if rank >= 1:
				continue
			var kind: int = mini(2, int(float(item["phase"]) * 3))
			var scale_value: float = lerpf(0.75, 1.10, item["phase"])
			# Includes full wind at strength=1 and each mesh's horizontal diagonal.
			var radius: float = (
				(0.55 if kind == 2 else 0.20) * scale_value + (0.025 if kind == 2 else 0.16)
			)
			if not clear(point, radius, obstacles, source["pool"]):
				continue
			var derived: Dictionary = item.duplicate()
			derived["p"] = Vector3(p.x, field.height_at(point), p.z)
			derived["scale"] = scale_value
			derived["rank"] = rank
			groups[kind].append(derived)
		var buffers: Array[PackedFloat32Array] = []
		for kind: int in groups.size():
			groups[kind].sort_custom(
				func(a: Dictionary, b: Dictionary) -> bool: return a["rank"] < b["rank"]
			)
			var buffer: PackedFloat32Array = MeadowData.chunk_buffer(groups[kind], key)
			if new_grass:
				for i: int in groups[kind].size():
					buffer[i * 16 + 13] = 0.08 if kind == 2 else 1.0
					buffer[i * 16 + 14] = layer(key)
			buffers.append(buffer)
			data["count"] += groups[kind].size()
		var signature: String = ""
		if new_grass:
			signature = height_key(source, key)
			if height_keys.get(key, "") != signature:
				images[key] = height_image(field, key)
				height_keys[key] = signature
			data["images"][key] = images[key]
		data["chunks"][key] = groups
		data["buffers"][key] = buffers
		data["versions"][key] = [new_grass, hash(buffers), signature]
	cache["images"] = images
	cache["height_keys"] = height_keys
	data["worker_ms"] = float(Time.get_ticks_usec() - started) / 1000
	return data
