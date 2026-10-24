class_name SupportGeometry
extends RefCounted
## W03 groundwork: perimeter source samples for terrain-fitting foundations.


static func perimeter(spec: Dictionary, field: TerrainField) -> Array:
	var points: Array = []
	var p: Array = spec["position"]
	var size: Array = spec["size"]
	var segments: int = 64
	for index: int in range(segments):
		var angle: float = TAU * float(index) / float(segments)
		var direction: Vector2 = Vector2(sin(angle), cos(angle))
		if spec["shape"] == "rect":
			direction /= maxf(absf(direction.x), absf(direction.y))
		var point: Vector2 = Vector2(p[0], p[2]) + direction * Vector2(size[0], size[2]) * 0.5
		points.append([point.x, minf(field.height_at(point), p[1]), point.y])
	return points
