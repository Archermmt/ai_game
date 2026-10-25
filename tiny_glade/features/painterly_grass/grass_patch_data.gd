class_name PainterlyGrassPatchData
extends RefCounted
## Read-only derived grass. A conservative footprint check protects paths and entrances.

const REGION: Rect2 = Rect2(0, 2, 8, 8)
const MAP_ORIGIN: Vector2 = Vector2(-1, 1)
const MAP_SPAN: float = 10.0
const MAP_RESOLUTION: int = 129


static func height_image(field: TerrainField) -> Image:
	var image: Image = Image.create(MAP_RESOLUTION, MAP_RESOLUTION, false, Image.FORMAT_RF)
	for z: int in MAP_RESOLUTION:
		for x: int in MAP_RESOLUTION:
			var point: Vector2 = MAP_ORIGIN + Vector2(x, z) * MAP_SPAN / (MAP_RESOLUTION - 1)
			image.set_pixel(x, z, Color(field.height_at(point), 0, 0, 1))
	return image


static func sampled_height(image: Image, point: Vector2) -> float:
	var p: Vector2 = (point - MAP_ORIGIN) / MAP_SPAN * (MAP_RESOLUTION - 1)
	var x: int = clampi(floori(p.x), 0, MAP_RESOLUTION - 2)
	var z: int = clampi(floori(p.y), 0, MAP_RESOLUTION - 2)
	return lerpf(
		lerpf(image.get_pixel(x, z).r, image.get_pixel(x + 1, z).r, p.x - x),
		lerpf(image.get_pixel(x, z + 1).r, image.get_pixel(x + 1, z + 1).r, p.x - x),
		p.y - z
	)


static func envelope_clear(
	point: Vector2, radius: float, obstacles: Dictionary, source: Dictionary
) -> bool:
	if not REGION.grow(-radius).has_point(point):
		return false
	if not source["pool"].is_empty() and PondShape.distance(source["pool"], point) < 0.58 + radius:
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
	for item: Dictionary in source["instances"]:
		if item["asset_id"] not in ["NAT-01", "NAT-02", "NAT-03", "NAT-08", "NAT-09"]:
			continue
		var p: Array = item["position"]
		var protected_radius: float = 0.60 if item["asset_id"] in ["NAT-08", "NAT-09"] else 0.30
		if (
			point.distance_to(Vector2(p[0], p[2]))
			< radius + protected_radius * float(item["scale"])
		):
			return false
	return true


static func generate(source: Dictionary, density: float = 0.45) -> Dictionary:
	var field: TerrainField = TerrainField.new(source)
	var obstacles: Dictionary = MeadowData._obstacles(source)
	var meadow: Dictionary = MeadowData.generate(source)
	var groups: Array[Array] = [[], [], []]
	var candidates: int = 0
	var old_visible: int = 0
	var old_selected: int = 0
	for chunk: Array in meadow["chunks"].values():
		for index: int in chunk.size():
			var item: Dictionary = chunk[index]
			var p: Vector3 = item["p"]
			var point: Vector2 = Vector2(p.x, p.z)
			if not REGION.has_point(point):
				continue
			candidates += 1
			old_visible += int(item["rank"] < density)
			old_selected += int(index < floori(chunk.size() * density))
			var kind: int = mini(2, int(float(item["phase"]) * 3.0))
			var mass: float = 0.80 + sin(point.x * 0.65 + cos(point.y * 0.43)) * 0.20
			var edge: float = minf(
				minf(point.x, 8.0 - point.x), minf(point.y - 2.0, 10.0 - point.y)
			)
			if item["rank"] >= density * 0.72 * mass * smoothstep(0, 0.8, edge):
				continue
			var scale_value: float = lerpf(0.75, 1.10, float(item["phase"]))
			var radius: float = (
				(0.55 if kind == 2 else 0.20) * scale_value + (0.02 if kind == 2 else 0.13)
			)
			if not envelope_clear(point, radius, obstacles, source):
				continue
			var pose: Transform3D = Transform3D(
				Basis(Vector3.UP, item["yaw"]).scaled(Vector3.ONE * scale_value),
				Vector3(p.x, field.height_at(point), p.z)
			)
			groups[kind].append({"pose": pose, "phase": item["phase"], "radius": radius})
	return {
		"groups": groups,
		"image": height_image(field),
		"old_candidates": candidates,
		"old_rank_selected": old_visible,
		"old_visible_origins": old_selected
	}
