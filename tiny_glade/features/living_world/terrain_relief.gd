class_name TerrainRelief
extends RefCounted
## Stable analytic hills, evaluated by the existing background terrain generation.


static func height(point: Vector2, phase: float) -> float:
	var mask: float = smoothstep(7.5, 15.0, point.distance_to(Vector2(0, 1)))
	mask *= smoothstep(7.5, 12.0, point.distance_to(Vector2(-5, 4)))
	var edge: float = 1.0 - smoothstep(26.0, 32.0, maxf(absf(point.x), absf(point.y)))
	var hills: float = 1.1 + 1.5 * sin(point.x * 0.16 + phase) * cos(point.y * 0.13 - phase * 0.7)
	hills += 0.6 * sin(point.x * 0.32 + point.y * 0.21 + phase * 0.6)
	hills -= 1.2 * exp(-point.distance_squared_to(Vector2(-12, 9)) / 32.0)
	hills -= 1.0 * exp(-point.distance_squared_to(Vector2(13, -9)) / 24.0)
	hills += 1.6 * exp(-point.distance_squared_to(Vector2(14, 5)) / 20.0)
	hills += 1.1 * exp(-point.distance_squared_to(Vector2(-11, -6)) / 14.0)
	hills -= 1.0 * exp(-point.distance_squared_to(Vector2(11, 13)) / 14.0)
	return -0.15 + mask * edge * hills


static func apply(source: Dictionary) -> Dictionary:
	var result: Dictionary = source.duplicate(true)
	result["terrain"]["base_profile"] = "rolling_hills_v2"
	# Instance position.y is a support-relative offset. The existing pose generator
	# grounds it against the new field; rewriting it would apply terrain twice.
	return result
