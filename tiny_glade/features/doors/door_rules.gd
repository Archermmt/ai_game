class_name DoorRules
extends RefCounted
## One candidate contains roads and their openings. Manual contents always win.


static func wall_point(building: Dictionary, point: Vector2) -> Dictionary:
	var p: Array = building["position"]
	var size: Array = building["size"]
	var local: Vector2 = point - Vector2(p[0], p[2])
	if building["shape"] == "round":
		var angle: float = fposmod(atan2(local.x, local.y), TAU)
		var at: Vector2 = (
			Vector2(sin(angle), cos(angle)) * float(size[0]) * 0.5 + Vector2(p[0], p[2])
		)
		return {
			"facade": 0,
			"center": angle / TAU,
			"point": at,
			"distance": at.distance_to(point),
			"request": point
		}
	var best: Dictionary = {"distance": INF}
	for facade: int in range(4):
		var length: float = size[0 if facade % 2 == 0 else 2]
		var a3: Vector3 = BuildingGeometry._point(0, facade, size[0], size[2], false)
		var b3: Vector3 = BuildingGeometry._point(length, facade, size[0], size[2], false)
		var a: Vector2 = Vector2(a3.x, a3.z) + Vector2(p[0], p[2])
		var b: Vector2 = Vector2(b3.x, b3.z) + Vector2(p[0], p[2])
		var at: Vector2 = Geometry2D.get_closest_point_to_segment(point, a, b)
		var distance: float = at.distance_to(point)
		if distance < best["distance"]:
			best = {
				"distance": distance,
				"request": point,
				"facade": facade,
				"center": a.distance_to(at) / length,
				"point": at
			}
	return best


static func manual_opening(
	draft: Dictionary, building_id: String, point: Vector2, variant: int
) -> bool:
	for building: Dictionary in draft["buildings"]:
		if building["id"] != building_id:
			continue
		var place: Dictionary = wall_point(building, point)
		var window: bool = variant >= 3
		var key: String = "%s:manual-opening:%d" % [draft["world_seed"], draft["next_id"]]
		draft["next_id"] += 1
		building["openings"].append(
			{
				"kind": "round" if variant == 4 else ("arch" if variant == 1 else "rect"),
				"width": 0.9 if window else 1.1,
				"height": 0.9 if window else 2.05,
				"sill": 1.0 if window else 0.0,
				"facade": place["facade"],
				"center": place["center"],
				"source": "manual",
				"locked": false,
				"variant": "glass" if variant == 2 else "plank",
				"attachment_id": key.sha256_text().left(24)
			}
		)
		snap_manual(building, building["openings"].size() - 1, draft["buildings"])
		return true
	return false


static func snap_manual(building: Dictionary, index: int, world: Array) -> bool:
	var opening: Dictionary = building["openings"][index]
	var center: float = opening["center"]
	var length: float = _length(building, opening.get("facade", 0))
	for offset: float in [0.0, 0.15, -0.15, 0.3, -0.3, 0.45, -0.45, 0.6, -0.6]:
		opening["center"] = center + offset / length
		var proxy: Dictionary = building.duplicate(true)
		proxy["openings"] = proxy["openings"].filter(
			func(item: Dictionary) -> bool:
				return item.get("source", "manual") != "auto_path" or item.get("locked", false)
		)
		if (
			WorldDocument._valid_openings(proxy)
			and BuildingContact.validate(proxy, world).is_empty()
		):
			return true
	opening["center"] = center
	return false


static func lock(opening: Dictionary) -> void:
	opening["locked"] = not opening.get("locked", false)
	opening["source"] = "manual"
	opening.erase("source_path")
	opening.erase("source_paths")


static func reconcile(snapshot: Dictionary) -> Dictionary:
	var draft: Dictionary = snapshot.duplicate(true)
	var field: TerrainField = TerrainField.new(draft)
	var paths: Array = draft["paths"].duplicate(true)
	paths.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["id"] < b["id"])
	var notices: Array[String] = []
	for building: Dictionary in draft["buildings"]:
		var automatic: Array[Dictionary] = []
		var retained: Array = []
		for opening: Dictionary in building["openings"]:
			if opening.get("source", "manual") == "auto_path" and not opening.get("locked", false):
				automatic.append(opening.duplicate(true))
			else:
				var manual: Dictionary = opening.duplicate(true)
				manual["source"] = "manual"
				manual.erase("source_path")
				manual.erase("source_paths")
				retained.append(manual)
		building["openings"] = retained
		for path: Dictionary in paths:
			var points: Array[Vector2] = PathCurve.sample(path)
			var requests: Array[Vector2] = [points[0], points.back()]
			for index: int in range(points.size() - 1):
				requests.append_array(_crossings(building, points[index], points[index + 1]))
			for request: Vector2 in requests:
				var place: Dictionary = wall_point(building, request)
				if place["distance"] > 0.60001:
					continue
				if absf(field.height_at(request) - float(building["position"][1])) > 0.45001:
					notices.append("入口高差超过 0.45m；请调整地形；0.15–0.9m 高差可预览短阶")
					continue
				_connect(building, draft["buildings"], place, path["id"], automatic, notices)
	return {"snapshot": draft, "notices": notices}


static func _connect(
	building: Dictionary,
	world: Array,
	place: Dictionary,
	path_id: String,
	old: Array[Dictionary],
	notices: Array[String]
) -> void:
	var length: float = _length(building, place["facade"])
	for opening: Dictionary in building["openings"]:
		if opening.get("facade", 0) != place["facade"] or opening["height"] < 1.8:
			continue
		if _distance(opening["center"], place["center"], building) * length < 1.2:
			if opening.get("source", "") == "auto_path" and path_id not in opening["source_paths"]:
				opening["source_paths"].append(path_id)
			return
	for offset: float in [0.0, 0.2, -0.2, 0.4, -0.4]:
		var center: float = float(place["center"]) + offset / length
		var proposed: Dictionary = {
			"kind": "arch",
			"center": center,
			"width": 1.1,
			"height": 2.05,
			"facade": place["facade"],
			"source": "auto_path"
		}
		for previous: Dictionary in old:
			if (
				previous.get("facade", 0) == place["facade"]
				and _distance(previous["center"], center, building) * length < 0.6
			):
				proposed = previous.duplicate(true)
				break
		proposed["source_paths"] = [path_id]
		proposed["source_path"] = path_id
		if not proposed.has("attachment_id"):
			proposed["attachment_id"] = (
				(
					str(building["id"])
					+ ":door:"
					+ str(place["facade"])
					+ ":"
					+ str(snappedf(center, 0.001))
				)
				. sha256_text()
				. left(24)
			)
		var location: Vector3 = BuildingGeometry._point(
			float(proposed["center"]) * length,
			place["facade"],
			building["size"][0],
			building["size"][2],
			building["shape"] == "round"
		)
		var request: Vector2 = place.get("request", place["point"])
		if (
			request.distance_to(
				Vector2(location.x + building["position"][0], location.z + building["position"][2])
			)
			> 0.60001
		):
			continue
		building["openings"].append(proposed)
		if (
			WorldDocument._valid_openings(building)
			and BuildingContact.validate(building, world).is_empty()
		):
			return
		building["openings"].pop_back()
	notices.append("入口附近没有合法墙段；保留手放门窗")


static func _length(building: Dictionary, facade: int) -> float:
	return (
		PI * float(building["size"][0])
		if building["shape"] == "round"
		else float(building["size"][0 if facade % 2 == 0 else 2])
	)


static func _distance(a: float, b: float, building: Dictionary) -> float:
	var d: float = absf(a - b)
	return minf(d, 1.0 - d) if building["shape"] == "round" else d


static func _crossings(building: Dictionary, a: Vector2, b: Vector2) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var p: Array = building["position"]
	var size: Array = building["size"]
	var origin: Vector2 = Vector2(p[0], p[2])
	if building["shape"] == "round":
		var d: Vector2 = b - a
		var rel: Vector2 = a - origin
		var aa: float = d.length_squared()
		var bb: float = 2 * rel.dot(d)
		var cc: float = rel.length_squared() - pow(float(size[0]) * 0.5, 2)
		var disc: float = bb * bb - 4 * aa * cc
		if aa > 0.000001 and disc >= 0:
			for t: float in [(-bb - sqrt(disc)) / (2 * aa), (-bb + sqrt(disc)) / (2 * aa)]:
				if t >= 0 and t <= 1:
					result.append(a + d * t)
	else:
		for facade: int in range(4):
			var u: Vector3 = BuildingGeometry._point(0, facade, size[0], size[2], false)
			var v: Vector3 = BuildingGeometry._point(
				_length(building, facade), facade, size[0], size[2], false
			)
			var hit: Variant = Geometry2D.segment_intersects_segment(
				a, b, Vector2(u.x, u.z) + origin, Vector2(v.x, v.z) + origin
			)
			if hit is Vector2:
				result.append(hit)
	return result
