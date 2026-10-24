class_name PathCurve
extends RefCounted
## Bounded Catmull-Rom source control points, sampled without SceneTree resources.


static func sample(path: Dictionary) -> Array[Vector2]:
	var points: Array = path["points"]
	var result: Array[Vector2] = []
	for i: int in range(points.size() - 1):
		var a: Vector2 = _point(points[maxi(0, i - 1)])
		var b: Vector2 = _point(points[i])
		var c: Vector2 = _point(points[i + 1])
		var d: Vector2 = _point(points[mini(points.size() - 1, i + 2)])
		var steps: int = clampi(ceili(b.distance_to(c) / 0.25), 1, 80)
		for step: int in range(steps):
			var t: float = float(step) / steps
			var p: Vector2 = b.lerp(c, t)
			if path.get("curved", false):
				p = (
					0.5
					* (
						(2 * b)
						+ (-a + c) * t
						+ (2 * a - 5 * b + 4 * c - d) * t * t
						+ (-a + 3 * b - 3 * c + d) * t * t * t
					)
				)
			result.append(p.clamp(Vector2(-24, -24), Vector2(24, 24)))
	result.append(_point(points.back()))
	return result


static func _point(p: Array) -> Vector2:
	return Vector2(p[0], p[2])


static func dirty_bounds(path: Dictionary) -> Rect2:
	var points: Array[Vector2] = sample(path)
	var bounds: Rect2 = Rect2(points[0], Vector2.ZERO)
	for p: Vector2 in points:
		bounds = bounds.expand(p)
	return bounds.grow(float(path["width"]) * 0.5 + 0.5)
