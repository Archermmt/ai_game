extends RefCounted

static func height_at(x: float, z: float) -> float:
	var across := smoothstep(9.0, 11.15, absf(x))
	var depth := smoothstep(0.0, 6.4, -z)
	return 0.55 * across * depth * smoothstep(-8.0,-6.3,z)
