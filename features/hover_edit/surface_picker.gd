class_name SurfacePicker
extends RefCounted
## Source geometry ray tests; select the nearest visible editable surface, not a ground proxy.


static func pick(source: Dictionary, ray: Vector3, direction: Vector3) -> Dictionary:
	var best: Dictionary = {}
	for home: Dictionary in source["buildings"]:
		var hit: Variant = DirectEditData.wall_hit(home, ray, direction)
		if hit is Vector3:
			var p: Array = home["position"]
			var place: Dictionary = DoorRules.wall_point(home, Vector2(hit.x, hit.z))
			var key: String = (
				"height"
				if hit.y - p[1] > home["size"][1] * 0.7
				else ("width" if place["facade"] % 2 == 0 else "depth")
			)
			if hit.y - p[1] < home["size"][1] * 0.22:
				key = "move"
			if home["shape"] == "round" and key == "depth":
				key = "width"
			var target: Dictionary = {"family": "house", "id": home["id"], "zone": key}
			for index: int in range(home["openings"].size()):
				var opening: Dictionary = home["openings"][index]
				if opening.get("facade", 0) != place["facade"]:
					continue
				var interval: Vector2 = BuildingGeometry.opening_interval(
					opening,
					place["center"] * DoorRules._length(home, place["facade"]),
					DoorRules._length(home, place["facade"])
				)
				if interval.x >= 0 and hit.y - p[1] >= interval.x and hit.y - p[1] <= interval.y:
					target = {
						"family": "opening", "parent": home["id"], "index": index, "zone": "move"
					}
					if opening.has("attachment_id"):
						target["attachment_id"] = opening["attachment_id"]
					break
			best = _near(best, target, hit, ray)
		for triangle: Array in roof_triangles(home):
			var center: Vector3 = (triangle[0] + triangle[1] + triangle[2]) / 3.0
			hit = Geometry3D.ray_intersects_triangle(
				ray,
				direction,
				center + (triangle[0] - center) * 1.002,
				center + (triangle[1] - center) * 1.002,
				center + (triangle[2] - center) * 1.002
			)
			if hit is Vector3:
				best = _near(best, {"family": "house", "id": home["id"], "zone": "roof"}, hit, ray)
	for family: String in ["bridge", "stair"]:
		for item: Dictionary in source.get("bridges" if family == "bridge" else "stairs", []):
			var a: Vector3 = Vector3(
				item["a"][0], maxf(item["heights"][0], item["heights"][1]) + 0.2, item["a"][1]
			)
			var b: Vector3 = Vector3(item["b"][0], a.y, item["b"][1])
			var pose: Transform3D = Transform3D(
				Basis(Vector3.UP, -atan2(b.z - a.z, b.x - a.x)), (a + b) * 0.5
			)
			var local: Transform3D = pose.affine_inverse()
			var bounds: AABB = AABB(
				Vector3(-a.distance_to(b) * 0.5, -0.35, -item["width"] * 0.5),
				Vector3(a.distance_to(b), 0.8, item["width"])
			)
			var hit: Variant = bounds.intersects_ray(local * ray, local.basis * direction)
			if hit is Vector3:
				hit = pose * hit
				var zone: String = (
					"end_a"
					if hit.distance_to(a) < 0.65
					else ("end_b" if hit.distance_to(b) < 0.65 else "move")
				)
				best = _near(best, {"family": family, "id": item["id"], "zone": zone}, hit, ray)
	return best


static func _near(best: Dictionary, target: Dictionary, hit: Vector3, ray: Vector3) -> Dictionary:
	var distance: float = ray.distance_to(hit)
	if distance < best.get("distance", INF):
		target["point"] = hit
		target["distance"] = distance
		return target
	return best


static func roof_triangles(home: Dictionary) -> Array:
	var p: Array = home["position"]
	var s: Array = home["size"]
	var center: Vector3 = Vector3(p[0], p[1] + s[1], p[2])
	var rise: float = RoofProfile.rise(home)
	var result: Array = []
	if home["shape"] == "round":
		var radius: float = s[0] * 0.5 + 0.35
		for index: int in range(64):
			var a: float = index * TAU / 64
			var b: float = (index + 1) * TAU / 64
			result.append(
				[
					center + Vector3(sin(a) * radius, 0, cos(a) * radius),
					center + Vector3(sin(b) * radius, 0, cos(b) * radius),
					center + Vector3.UP * rise
				]
			)
	else:
		var w: float = s[0] * 0.5 + 0.35
		var d: float = s[2] * 0.5 + 0.35
		for side: float in [-1.0, 1.0]:
			var a: Vector3 = center + Vector3(side * w, 0, -d)
			var b: Vector3 = center + Vector3(side * w, 0, d)
			var c: Vector3 = center + Vector3(0, rise, d)
			var e: Vector3 = center + Vector3(0, rise, -d)
			result.append([a, b, c])
			result.append([a, c, e])
	return result
