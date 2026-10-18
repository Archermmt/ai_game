class_name PlacementRules
extends RefCounted
## Week-one bounded placement: axis-aligned rectangles and independent circles.


static func overlaps(a: Dictionary, b: Dictionary) -> bool:
	var pa: Array = a["position"]
	var pb: Array = b["position"]
	var sa: Array = a["size"]
	var sb: Array = b["size"]
	var ca: Vector2 = Vector2(pa[0], pa[2])
	var cb: Vector2 = Vector2(pb[0], pb[2])
	var ra: float = float(sa[0]) * 0.5
	var rb: float = float(sb[0]) * 0.5
	if a["shape"] == "round" and b["shape"] == "round":
		return ca.distance_to(cb) < ra + rb - 0.001
	if a["shape"] == "rect" and b["shape"] == "rect":
		return (
			absf(ca.x - cb.x) < (float(sa[0]) + float(sb[0])) * 0.5 - 0.001
			and absf(ca.y - cb.y) < (float(sa[2]) + float(sb[2])) * 0.5 - 0.001
		)
	if a["shape"] == "round":
		return _circle_rect(ca, ra, cb, Vector2(sb[0], sb[2]) * 0.5)
	return _circle_rect(cb, rb, ca, Vector2(sa[0], sa[2]) * 0.5)


static func _circle_rect(circle: Vector2, radius: float, center: Vector2, half: Vector2) -> bool:
	var closest: Vector2 = circle.clamp(center - half, center + half)
	return circle.distance_to(closest) < radius - 0.001
