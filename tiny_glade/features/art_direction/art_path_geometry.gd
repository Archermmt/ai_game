class_name ArtPathGeometry
extends RefCounted
## Broad irregular flagstones; the same authoritative path masks still decide placement.

const PITCH: float = 0.62


static func arrays(snapshot: Dictionary) -> Array:
	var field: TerrainField = TerrainField.new(snapshot)
	var cells: Dictionary = {}
	for path: Dictionary in snapshot["paths"]:
		for segment: Array in PathGeometry._segments(path, snapshot, field):
			var a: Vector2 = segment[0]
			var b: Vector2 = segment[1]
			var radius: float = path["width"] * 0.5
			var lo: Vector2i = Vector2i(
				((a.min(b) - Vector2.ONE * (radius + PITCH)) / PITCH).floor()
			)
			var hi: Vector2i = Vector2i(
				((a.max(b) + Vector2.ONE * (radius + PITCH)) / PITCH).ceil()
			)
			for z: int in range(lo.y, hi.y + 1):
				for x: int in range(lo.x, hi.x + 1):
					var cell: Vector2i = Vector2i(x, z)
					var p: Vector2 = _cell_center(cell)
					if (
						p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)) < radius
						and not PathGeometry._blocked(p, snapshot)
					):
						cells[cell] = true
	var builder: BuildingGeometry = BuildingGeometry.new()
	var keys: Array = cells.keys()
	keys.sort()
	for cell: Vector2i in keys:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = (str(snapshot["world_seed"]) + ":flagstone:" + str(cell)).hash()
		var center: Vector2 = _cell_center(cell)
		center += Vector2(rng.randf_range(-0.08, 0.08), rng.randf_range(-0.08, 0.08))
		if PathGeometry._blocked(center, snapshot):
			continue
		var points: Array[Vector3] = []
		var tops: Array[Vector3] = []
		var height: float = rng.randf_range(0.045, 0.065)
		var turn: float = rng.randf_range(-0.25, 0.25)
		var stretch: Vector2 = Vector2(rng.randf_range(0.82, 1.12), rng.randf_range(0.82, 1.12))
		for i: int in range(8):
			var angle: float = TAU * (float(i) + 0.5) / 8 + turn
			var radius: float = rng.randf_range(0.29, 0.38)
			var p: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius * stretch
			points.append(Vector3(p.x, field.height_at(p) + 0.008, p.y))
			var q: Vector2 = center + (p - center) * 0.88
			tops.append(Vector3(q.x, field.height_at(q) + height, q.y))
		var tint: Color = Color("c1bba0").lightened(rng.randf_range(-0.08, 0.08))
		var c: Vector3 = Vector3(center.x, field.height_at(center) + height, center.y)
		for i: int in range(8):
			var j: int = (i + 1) % 8
			builder._triangle(c, tops[j], tops[i], Vector3.UP, tint)
			var normal: Vector3 = (points[i] - c).normalized()
			builder._quad(tops[i], tops[j], points[j], points[i], normal, tint.darkened(0.10))
	return MeshParts.arrays(builder)


static func _cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5 + 0.5 * posmod(cell.y, 2), 0.5)) * PITCH
