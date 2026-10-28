class_name ProductionGrassData
extends RefCounted
## Immutable worker output. Candidate locations come from pinned ProtonScatter.

const BOUNDS: Rect2 = Rect2(-24, -24, 48, 48)
const RESOLUTION: int = 129
const MAP_SPAN: float = 12.0
const MAP_PADDING: float = 2.0


static func layer(key: Vector2i) -> int:
	return (key.y + 3) * 6 + key.x + 3


static func generate(source: Dictionary, candidates: Array[Array], cache: Dictionary) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	var field: TerrainField = TerrainField.new(source)
	var obstacles: Dictionary = PainterlyGardenGrassData.clearance_index(source)
	var data: Dictionary = {
		"chunks": {}, "buffers": {}, "versions": {}, "images": {}, "masks": {}, "count": 0
	}
	for z: int in range(-3, 3):
		for x: int in range(-3, 3):
			data["chunks"][Vector2i(x, z)] = [[], [], [], []]
	for kind: int in 4:
		for candidate: Dictionary in candidates[kind]:
			var pose: Transform3D = candidate["pose"]
			var point: Vector2 = Vector2(pose.origin.x, pose.origin.z)
			if (
				not BOUNDS.has_point(point)
				or not MeadowData.clear(point, obstacles, source["pool"])
			):
				continue
			var normal: Vector3 = field.normal_at(point)
			if normal.y < 0.54:
				continue
			var scale_factor: float = 1.0
			if not PainterlyGardenGrassData.clear(point, 0.38, obstacles, source["pool"]):
				scale_factor = 0.62
			var up: Vector3 = Vector3.UP.slerp(normal, 0.92).normalized()
			pose.basis = Basis(Quaternion(Vector3.UP, up)) * pose.basis * scale_factor
			pose.origin.y = field.height_at(point) + float(candidate["ground_offset"])
			var key: Vector2i = Vector2i((point / 8.0).floor())
			var item: Dictionary = candidate.duplicate()
			item["pose"] = pose
			item["p"] = pose.origin
			item["kind"] = kind
			item["scale"] = pose.basis.y.length()
			data["chunks"][key][kind].append(item)
	var heights: Dictionary = cache.get("images", {})
	var masks: Dictionary = cache.get("masks", {})
	var height_keys: Dictionary = cache.get("height_keys", {})
	var mask_keys: Dictionary = cache.get("mask_keys", {})
	for key: Vector2i in data["chunks"]:
		var groups: Array = data["chunks"][key]
		var buffers: Array[PackedFloat32Array] = []
		for kind: int in 4:
			groups[kind].sort_custom(
				func(a: Dictionary, b: Dictionary) -> bool: return a["rank"] < b["rank"]
			)
			buffers.append(chunk_buffer(groups[kind], key, kind))
			data["count"] += groups[kind].size()
		var height_signature: String = height_key(source, key)
		var mask_signature: String = mask_key(source, obstacles, key)
		if height_keys.get(key, "") != height_signature:
			heights[key] = height_image(field, key)
			height_keys[key] = height_signature
		if mask_keys.get(key, "") != mask_signature:
			masks[key] = clearance_image(source, obstacles, key)
			mask_keys[key] = mask_signature
		data["buffers"][key] = buffers
		data["versions"][key] = [hash(buffers), height_signature, mask_signature]
		data["images"][key] = heights[key]
		data["masks"][key] = masks[key]
	cache["images"] = heights
	cache["masks"] = masks
	cache["height_keys"] = height_keys
	cache["mask_keys"] = mask_keys
	data["signature"] = MeadowData.signature(source)
	data["worker_ms"] = float(Time.get_ticks_usec() - started) / 1000.0
	return data


static func height_key(source: Dictionary, key: Vector2i) -> String:
	var bounds: Rect2 = Rect2(Vector2(key) * 8, Vector2.ONE * 8).grow(MAP_PADDING + 0.6)
	var spacing: float = source["terrain"].get("spacing", 0.5)
	var entries: Array = []
	for entry: Array in source["terrain"]["height_deltas"]:
		if bounds.has_point(Vector2(entry[0], entry[1]) * spacing - Vector2.ONE * 32):
			entries.append(entry)
	return JSON.stringify(
		[
			source["world_seed"],
			source["terrain"].get("base_profile", "flat"),
			spacing,
			entries,
			_local_pool(source["pool"], bounds)
		]
	)


static func mask_key(source: Dictionary, obstacles: Dictionary, key: Vector2i) -> String:
	var bounds: Rect2 = Rect2(Vector2(key) * 8, Vector2.ONE * 8).grow(MAP_PADDING)
	var items: Array = []
	var lo: Vector2i = Vector2i((bounds.position / 8).floor())
	var hi: Vector2i = Vector2i((bounds.end / 8).floor())
	for z: int in range(lo.y, hi.y + 1):
		for x: int in range(lo.x, hi.x + 1):
			items.append(obstacles.get(Vector2i(x, z), []))
	return JSON.stringify([items, _local_pool(source["pool"], bounds)])


static func _local_pool(pool: Dictionary, bounds: Rect2) -> Dictionary:
	if pool.is_empty():
		return {}
	var center: Vector2 = Vector2(pool["center"][0], pool["center"][1])
	return pool if bounds.grow(float(pool["radius"]) + 0.75).has_point(center) else {}


static func height_image(field: TerrainField, key: Vector2i) -> Image:
	var image: Image = Image.create(RESOLUTION, RESOLUTION, false, Image.FORMAT_RF)
	var origin: Vector2 = Vector2(key) * 8 - Vector2.ONE * MAP_PADDING
	for z: int in RESOLUTION:
		for x: int in RESOLUTION:
			var point: Vector2 = origin + Vector2(x, z) * MAP_SPAN / (RESOLUTION - 1)
			image.set_pixel(x, z, Color(field.height_at(point), 0, 0, 1))
	return image


static func clearance_image(source: Dictionary, obstacles: Dictionary, key: Vector2i) -> Image:
	var image: Image = Image.create(RESOLUTION, RESOLUTION, false, Image.FORMAT_R8)
	var origin: Vector2 = Vector2(key) * 8 - Vector2.ONE * MAP_PADDING
	for z: int in RESOLUTION:
		for x: int in RESOLUTION:
			var point: Vector2 = origin + Vector2(x, z) * MAP_SPAN / (RESOLUTION - 1)
			var allowed: bool = (
				BOUNDS.has_point(point) and MeadowData.clear(point, obstacles, source["pool"])
			)
			image.set_pixel(x, z, Color(1 if allowed else 0, 0, 0, 1))
	return image


static func chunk_buffer(items: Array, key: Vector2i, kind: int) -> PackedFloat32Array:
	var buffer: PackedFloat32Array = PackedFloat32Array()
	buffer.resize(items.size() * 16)
	var origin: Vector3 = Vector3(key.x * 8 + 4, 0, key.y * 8 + 4)
	for index: int in items.size():
		var item: Dictionary = items[index]
		var pose: Transform3D = item["pose"]
		pose.origin -= origin
		var offset: int = index * 16
		for axis: int in 3:
			buffer[offset + axis * 4] = pose.basis.x[axis]
			buffer[offset + axis * 4 + 1] = pose.basis.y[axis]
			buffer[offset + axis * 4 + 2] = pose.basis.z[axis]
			buffer[offset + axis * 4 + 3] = pose.origin[axis]
		buffer[offset + 12] = item["phase"]
		buffer[offset + 13] = 0.08 if kind == 3 else 1.0
		buffer[offset + 14] = layer(key)
		buffer[offset + 15] = item["tint"]
	return buffer
