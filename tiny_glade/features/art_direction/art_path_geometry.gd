class_name ArtPathGeometry
extends RefCounted
## One worn soil bed across crossings, with flagstones laid in the direction of travel.

const TrailSoil = preload("res://features/art_direction/trail_soil.gd")
const STONE_CORNERS: Array[Vector2] = [
	Vector2(-1, -0.51),
	Vector2(-0.69, -1),
	Vector2(0.55, -1),
	Vector2(1, -0.67),
	Vector2(1, 0.57),
	Vector2(0.70, 1),
	Vector2(-0.63, 1),
	Vector2(-1, 0.65)
]


static func arrays(source: Dictionary) -> Array:
	var field: TerrainField = TerrainField.new(source)
	var builder: BuildingGeometry = BuildingGeometry.new()
	var paths: Array = source["paths"].duplicate()
	paths.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["id"] < b["id"])
	var routes: Array[Dictionary] = []
	var soil: Dictionary = {}
	for path: Dictionary in paths:
		var segments: Array = PathGeometry._segments(path, source, field)
		routes.append({"path": path, "segments": segments})
		TrailSoil.include(soil, segments, path["width"])
	TrailSoil.draw(builder, soil, field, blocked.bind(source))
	var occupied: Dictionary = {}
	for landing: Dictionary in _landings(source, field):
		# Deck endpoints and doorways receive a dressed, transverse stone only
		# where a path actually meets the approach. Reserve these stones first.
		for route: Dictionary in routes:
			var width: float = route.path.width
			if not _beside_route(landing.p, route.segments, width * 0.50):
				continue
			var extent: Vector2 = Vector2(0.24, minf(minf(width, landing.width) * 0.48, 0.60))
			# A corner of the bank may cut across a bridge approach. Fit the slab
			# to the remaining dry width without changing the authored shoreline.
			for fraction: float in [1.0, 0.82, 0.64]:
				if _lay(
					builder,
					occupied,
					source,
					field,
					landing.p,
					landing.dir,
					extent * Vector2(1, fraction),
					landing.seed,
					true,
					landing.get("rise", 0.0)
				):
					break
			break
	for route: Dictionary in routes:
		_paving(builder, occupied, source, field, route.path)
	return MeshParts.arrays(builder)


static func _beside_route(point: Vector2, segments: Array, radius: float) -> bool:
	for segment: Array in segments:
		if segment[0].distance_squared_to(segment[1]) < 0.000001:
			continue
		var nearest: Vector2 = Geometry2D.get_closest_point_to_segment(
			point, segment[0], segment[1]
		)
		if nearest.distance_squared_to(point) <= radius * radius:
			return true
	return false


static func _landings(source: Dictionary, field: TerrainField) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for collection: String in ["bridges", "stairs"]:
		for structure: Dictionary in source.get(collection, []):
			if not GardenStructures.status(source, structure).is_empty():
				continue
			var a: Vector2 = Vector2(structure.a[0], structure.a[1])
			var b: Vector2 = Vector2(structure.b[0], structure.b[1])
			for end: int in 2:
				var endpoint: Vector2 = a if end == 0 else b
				var heading: Vector2 = (a - b).normalized() if end == 0 else (b - a).normalized()
				result.append(
					{
						"p": endpoint + heading * 0.26,
						"dir": heading,
						"width": structure.width,
						"seed": str(structure.id) + str(end)
					}
				)
	for home: Dictionary in source["buildings"]:
		for opening: Dictionary in home["openings"]:
			if opening.height < 1.8 or opening.get("sill", 0.0) > 0.1:
				continue
			var facade: int = opening.get("facade", 0)
			var u: float = opening.center * DoorRules._length(home, facade)
			var rounded: bool = home.shape == "round"
			var local: Vector3 = BuildingGeometry._point(
				u, facade, home.size[0], home.size[2], rounded
			)
			var out: Vector3 = BuildingGeometry._normal(
				u, facade, home.size[0], home.size[2], rounded
			)
			var heading: Vector2 = Vector2(out.x, out.z)
			var point: Vector2 = (
				Vector2(home.position[0] + local.x, home.position[2] + local.z) + heading * 0.46
			)
			if absf(field.height_at(point) - float(home.position[1])) <= 0.45:
				result.append(
					{
						"p": point,
						"dir": heading,
						"width": opening.width,
						"rise": float(home.position[1]) - field.height_at(point),
						"seed": str(home.id) + str(facade) + str(u)
					}
				)
	return result


static func _paving(
	builder: BuildingGeometry,
	occupied: Dictionary,
	source: Dictionary,
	field: TerrainField,
	path: Dictionary
) -> void:
	var samples: Array[Vector2] = PathCurve.sample(path)
	var width: float = path.width
	var lanes: int = clampi(roundi(width / 0.78), 1, 4)
	var lane_width: float = width / lanes
	for lane: int in lanes:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = (str(path.get("seed", path.id)) + ":paving:" + str(lane)).hash()
		var length_walked: float = 0.0
		var next_stone: float = 0.22 + 0.27 * (lane % 2)
		var index: int = 0
		for i: int in range(samples.size() - 1):
			var start: Vector2 = samples[i]
			var segment: Vector2 = samples[i + 1] - start
			var span: float = segment.length()
			if span < 0.0001:
				continue
			var dir: Vector2 = segment / span
			while next_stone < length_walked + span:
				var side: float = (
					lane_width * (lane + 0.5 + rng.randf_range(-0.095, 0.095)) - width * 0.5
				)
				var center: Vector2 = (
					start + dir * (next_stone - length_walked) + dir.orthogonal() * side
				)
				var extent: Vector2 = Vector2(
					rng.randf_range(0.23, 0.35), lane_width * rng.randf_range(0.22, 0.34)
				)
				_lay(
					builder,
					occupied,
					source,
					field,
					center,
					dir.rotated(rng.randf_range(-0.15, 0.15)),
					extent,
					"%s:%d:%d" % [path.id, lane, index],
					false
				)
				next_stone += extent.x + rng.randf_range(0.35, 0.46)
				index += 1
			length_walked += span


static func blocked(point: Vector2, source: Dictionary) -> bool:
	if PathGeometry._blocked(point, source):
		return true
	for collection: String in ["stairs", "bridges"]:
		for structure: Dictionary in source.get(collection, []):
			var a: Vector2 = Vector2(structure.a[0], structure.a[1])
			var ab: Vector2 = Vector2(structure.b[0], structure.b[1]) - a
			var axis: Vector2 = ab.normalized()
			var along: float = (point - a).dot(axis)
			if (
				along > 0.0
				and along < ab.length()
				and absf((point - a).dot(axis.orthogonal())) < float(structure.width) * 0.5
			):
				return true
	return false


static func _lay(
	builder: BuildingGeometry,
	occupied: Dictionary,
	source: Dictionary,
	field: TerrainField,
	center: Vector2,
	dir: Vector2,
	extent: Vector2,
	key: String,
	landing: bool,
	entry_rise: float = 0.0
) -> bool:
	if blocked(center, source):
		return false
	var cell: Vector2i = Vector2i((center / 1.8).floor())
	# A spatial lookup also deduplicates adjoining path strokes and crossings.
	var right: Vector2 = dir.orthogonal()
	var poly: PackedVector2Array = []
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = key.hash()
	for corner: Vector2 in STONE_CORNERS:
		var p: Vector2 = (
			center
			+ (dir * corner.x * extent.x + right * corner.y * extent.y) * rng.randf_range(0.84, 1.0)
		)
		if blocked(p, source):
			return false
		poly.append(p)
	for x: int in range(cell.x - 1, cell.x + 2):
		for y: int in range(cell.y - 1, cell.y + 2):
			for existing: PackedVector2Array in occupied.get(Vector2i(x, y), []):
				if not Geometry2D.intersect_polygons(existing, poly).is_empty():
					return false
	if not occupied.has(cell):
		occupied[cell] = []
	occupied[cell].append(poly)
	var tint: Color = Color("c7b99b").lerp(Color("aab4a3"), rng.randf())
	if landing:
		tint = Color("d0c5a9")
	var top: float = maxf(rng.randf_range(0.041, 0.060), clampf(entry_rise * 0.55, 0.0, 0.25))
	var crown: Vector3 = _at(center, field, top + 0.006)
	for i: int in poly.size():
		var j: int = (i + 1) % poly.size()
		var a: Vector3 = _at(poly[i], field, 0.004)
		var b: Vector3 = _at(poly[j], field, 0.004)
		var c: Vector3 = _at(center.lerp(poly[j], 0.89), field, top)
		var d: Vector3 = _at(center.lerp(poly[i], 0.89), field, top)
		builder._triangle(crown, c, d, Vector3.UP, tint)
		builder._quad(d, c, b, a, (a + b) * 0.5 - crown, tint.darkened(0.08))
	return true


static func _at(p: Vector2, field: TerrainField, lift: float) -> Vector3:
	return Vector3(p.x, field.height_at(p) + lift, p.y)
