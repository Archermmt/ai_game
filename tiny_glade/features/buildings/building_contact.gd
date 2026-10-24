class_name BuildingContact
extends RefCounted
## Shared local (arc-length, height) ranges; the source objects remain independent.


static func intervals(spec: Dictionary, world: Array, facade: int) -> Array[Rect2]:
	var result: Array[Rect2] = []
	if spec["shape"] != "rect":
		return result
	var p: Array = spec["position"]
	var s: Array = spec["size"]
	for other: Dictionary in world:
		if other["id"] == spec["id"] or other["shape"] != "rect":
			continue
		var q: Array = other["position"]
		var t: Array = other["size"]
		var normal: Vector3 = [Vector3.BACK, Vector3.RIGHT, Vector3.FORWARD, Vector3.LEFT][facade]
		var axis: int = 2 if facade % 2 == 0 else 0
		var across: int = 0 if facade % 2 == 0 else 2
		var sign_value: float = normal[axis]
		if absf((q[axis] - p[axis]) * sign_value - (s[axis] + t[axis]) * 0.5) > 0.001:
			continue
		var low: float = maxf(p[across] - s[across] * 0.5, q[across] - t[across] * 0.5)
		var high: float = minf(p[across] + s[across] * 0.5, q[across] + t[across] * 0.5)
		var y_low: float = maxf(0, float(q[1]) - float(p[1]))
		var y_high: float = minf(float(s[1]), float(q[1]) + float(t[1]) - float(p[1]))
		if high - low <= 0.001 or y_high <= y_low:
			continue
		var start: float = low - (float(p[across]) - float(s[across]) * 0.5)
		if facade == 1 or facade == 2:
			start = float(s[across]) - (high - (float(p[across]) - float(s[across]) * 0.5))
		result.append(Rect2(start, y_low, high - low, y_high - y_low))
	return result


static func validate(spec: Dictionary, world: Array) -> String:
	for facade: int in range(1 if spec["shape"] == "round" else 4):
		var length: float = (
			PI * float(spec["size"][0])
			if spec["shape"] == "round"
			else float(spec["size"][0 if facade % 2 == 0 else 2])
		)
		var ranges: Array[Rect2] = []
		for opening: Dictionary in spec["openings"]:
			if int(opening.get("facade", 0)) != facade:
				continue
			var region: Rect2 = Rect2(
				float(opening["center"]) * length - float(opening["width"]) * 0.5,
				float(opening.get("sill", 0)),
				float(opening["width"]),
				float(opening["height"])
			)
			if (
				region.position.x < 0.15
				or region.end.x > length - 0.15
				or region.end.y > float(spec["size"][1]) - 0.15
			):
				return "opening_margin_0_15m"
			if (
				opening["kind"] == "arch"
				and float(opening["height"]) < float(opening["width"]) * 0.5
			):
				return "invalid_arch_proportion"
			for previous: Rect2 in ranges:
				if region.grow(0.075).intersects(previous.grow(0.075)):
					return "opening_clearance_0_15m"
			for contact: Rect2 in intervals(spec, world, facade):
				if region.grow(0.075).intersects(contact):
					return "opening_on_contact"
			ranges.append(region)
	return ""
