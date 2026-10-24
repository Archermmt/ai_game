class_name WalkSurface
extends RefCounted
## Read-only, source-derived ground and horizontal capsule clearance for photography.
## Buildings store an absolute fixed floor; instance Y is a support-relative offset.

const BODY_RADIUS: float = 0.22
const BODY_HEIGHT: float = 1.75
const MAX_STEP: float = 0.4
const WORLD_LIMIT: float = 23.5
const MIN_SLOPE_NORMAL_Y: float = 0.70710678
const SUBSTEP: float = 0.10
const CELL_SIZE: float = 2.0
const FOOT_OFFSETS: Array[Vector2] = [
	Vector2.ZERO,
	Vector2.LEFT,
	Vector2.RIGHT,
	Vector2.UP,
	Vector2.DOWN,
	Vector2(-0.7071, -0.7071),
	Vector2(0.7071, -0.7071),
	Vector2(-0.7071, 0.7071),
	Vector2(0.7071, 0.7071)
]

var field: TerrainField
var structures: Array[Dictionary] = []
var obstacles: Dictionary = {}


func configure(snapshot: Dictionary) -> void:
	field = TerrainField.new(snapshot)
	structures.clear()
	obstacles.clear()
	for home: Dictionary in snapshot.get("buildings", []):
		var center: Vector2 = Vector2(home["position"][0], home["position"][2])
		var half: Vector2 = Vector2(home["size"][0], home["size"][2]) * 0.5
		if home["shape"] == "round":
			_circle(center, half.x, -INF, float(home["position"][1]) + float(home["size"][1]) + 4)
		else:
			_rect(center, half, 0, -INF, float(home["position"][1]) + float(home["size"][1]) + 4)
	for item: Dictionary in snapshot.get("instances", []):
		_instance(snapshot, item)
	for collection: String in ["bridges", "stairs"]:
		for item: Dictionary in snapshot.get(collection, []):
			# Invalid retained structures are editable scenery, not safe walking surfaces.
			if not GardenStructures.status(snapshot, item).is_empty():
				continue
			var a: Vector2 = Vector2(item["a"][0], item["a"][1])
			var b: Vector2 = Vector2(item["b"][0], item["b"][1])
			var ha: float = GardenStructures.endpoint_height(snapshot, a, item["kind"])
			var hb: float = GardenStructures.endpoint_height(snapshot, b, item["kind"])
			structures.append(
				{
					"a": a,
					"b": b,
					"length": a.distance_to(b),
					"ha": ha,
					"hb": hb,
					"kind": item["kind"],
					"width": float(item["width"]),
					"deck": maxf(maxf(ha, hb), float(snapshot["pool"].get("water_y", -99)) + 0.18)
				}
			)
	for fence: Dictionary in snapshot.get("fences", []):
		_fence(snapshot, fence)


func ground_at(point: Vector2) -> Variant:
	if field == null or not is_finite(point.x) or not is_finite(point.y):
		return null
	var center: Variant = _support_at(point)
	if center == null or _solid_at(point, float(center)):
		return null
	var on_structure: bool = _structure_at(point) != null
	if not on_structure and field.normal_at(point).y < MIN_SLOPE_NORMAL_Y:
		return null
	for offset: Vector2 in FOOT_OFFSETS:
		var support: Variant = _support_at(point + offset * BODY_RADIUS)
		if support == null:
			return null
		# Structures have discrete treads; the center follows the exact generated top.
		if not on_structure and absf(float(support) - float(center)) > BODY_RADIUS * 1.2:
			return null
	return center


func can_stand(point: Vector2) -> bool:
	return ground_at(point) != null


func find_spawn(preferred: Vector2) -> Variant:
	if not is_finite(preferred.x) or not is_finite(preferred.y):
		preferred = Vector2.ZERO
	preferred = preferred.clamp(Vector2.ONE * -23, Vector2.ONE * 23)
	var height: Variant = ground_at(preferred)
	if height != null:
		return Vector3(preferred.x, float(height), preferred.y)
	for ring: int in range(1, 49):
		var radius: float = float(ring) * 0.5
		var samples: int = maxi(16, ceili(TAU * radius / 0.5))
		for i: int in range(samples):
			var point: Vector2 = preferred + Vector2.from_angle(float(i) * TAU / samples) * radius
			height = ground_at(point)
			if height != null:
				return Vector3(point.x, float(height), point.y)
	return null


func move_grounded(from: Vector3, delta: Vector2) -> Vector3:
	if not is_finite(delta.x) or not is_finite(delta.y) or not from.is_finite():
		return from
	var current: Vector3 = from
	if not can_stand(Vector2(from.x, from.z)):
		return from
	# Defensive bound for an interrupted/long frame; no unbounded sweep loop.
	if delta.length() > 8:
		delta = delta.normalized() * 8
	var count: int = maxi(1, ceili(delta.length() / SUBSTEP))
	var step: Vector2 = delta / count
	for i: int in range(count):
		var moved: Vector3 = _try_step(current, step)
		if moved == current:
			# Preserve tangential movement along walls, while each substep stays safe.
			moved = _try_step(current, Vector2(step.x, 0))
			moved = _try_step(moved, Vector2(0, step.y))
		current = moved
	return current


func _try_step(from: Vector3, delta: Vector2) -> Vector3:
	var point: Vector2 = Vector2(from.x, from.z) + delta
	var height: Variant = ground_at(point)
	if height == null or absf(float(height) - from.y) > MAX_STEP:
		return from
	return Vector3(point.x, float(height), point.y)


func _support_at(point: Vector2) -> Variant:
	if absf(point.x) > WORLD_LIMIT or absf(point.y) > WORLD_LIMIT:
		return null
	var structure: Variant = _structure_at(point)
	if structure != null:
		return structure
	if not field.pool.is_empty() and PondShape.distance(field.pool, point) < 0.03:
		return null
	return field.height_at(point)


func _structure_at(point: Vector2) -> Variant:
	var best: Variant = null
	for item: Dictionary in structures:
		var a: Vector2 = item["a"]
		var b: Vector2 = item["b"]
		var t: float = (point - a).dot(b - a) / (b - a).length_squared()
		if t < 0 or t > 1:
			continue
		var half_width: float = float(item["width"]) * (0.4 if item["kind"] == "bridge" else 0.5)
		if point.distance_to(a.lerp(b, t)) > half_width - 0.04:
			continue
		var height: float
		if item["kind"] == "bridge":
			# Beam centers use deck_height; their 0.12m thickness adds 0.06m to the top.
			height = (
				GardenStructures.deck_height(
					item["ha"], item["hb"], item["deck"], item["length"], t
				)
				+ 0.06
			)
		else:
			var low: float = minf(item["ha"], item["hb"])
			var high: float = maxf(item["ha"], item["hb"])
			var count: int = maxi(1, ceili((high - low) / KitProfiles.TREAD_RISE))
			var up: float = t if item["hb"] >= item["ha"] else 1.0 - t
			var tread: int = mini(count, floori(up * count) + 1)
			height = lerpf(low, high, float(tread) / count)
		if best == null or height > float(best):
			best = height
	return best


func _solid_at(point: Vector2, feet: float) -> bool:
	var key: Vector2i = Vector2i(floori(point.x / CELL_SIZE), floori(point.y / CELL_SIZE))
	for item: Dictionary in obstacles.get(key, []):
		if item["low"] >= feet + BODY_HEIGHT or item["high"] <= feet + 0.05:
			continue
		var distance: float
		if item["kind"] == "circle":
			distance = point.distance_to(item["center"]) - float(item["radius"])
		elif item["kind"] == "segment":
			distance = (
				point.distance_to(
					Geometry2D.get_closest_point_to_segment(point, item["a"], item["b"])
				)
				- float(item["radius"])
			)
		else:
			var local: Vector2 = (point - item["center"]).rotated(float(item["yaw"]))
			var half: Vector2 = item["half"]
			distance = local.distance_to(local.clamp(-half, half))
		if distance < BODY_RADIUS - 0.00001:
			return true
	return false


func _insert(bounds: Rect2, item: Dictionary) -> void:
	var low: Vector2i = Vector2i((bounds.position / CELL_SIZE).floor())
	var high: Vector2i = Vector2i((bounds.end / CELL_SIZE).floor())
	for z: int in range(low.y, high.y + 1):
		for x: int in range(low.x, high.x + 1):
			var key: Vector2i = Vector2i(x, z)
			if not obstacles.has(key):
				obstacles[key] = []
			obstacles[key].append(item)


func _circle(center: Vector2, radius: float, low: float, high: float) -> void:
	var extent: Vector2 = Vector2.ONE * (radius + BODY_RADIUS)
	_insert(
		Rect2(center - extent, extent * 2),
		{"kind": "circle", "center": center, "radius": radius, "low": low, "high": high}
	)


func _rect(center: Vector2, half: Vector2, yaw: float, low: float, high: float) -> void:
	var c: float = absf(cos(yaw))
	var s: float = absf(sin(yaw))
	var extent: Vector2 = (
		Vector2(half.x * c + half.y * s, half.x * s + half.y * c) + Vector2.ONE * BODY_RADIUS
	)
	_insert(
		Rect2(center - extent, extent * 2),
		{"kind": "rect", "center": center, "half": half, "yaw": yaw, "low": low, "high": high}
	)


func _segment(a: Vector2, b: Vector2, radius: float, low: float, high: float) -> void:
	_insert(
		Rect2(a.min(b), (b - a).abs()).grow(radius + BODY_RADIUS),
		{"kind": "segment", "a": a, "b": b, "radius": radius, "low": low, "high": high}
	)


func _instance(snapshot: Dictionary, item: Dictionary) -> void:
	var asset: String = item["asset_id"]
	if asset in ["NAT-04", "NAT-05", "PROP-06", "PROP-07", "PROP-08"]:
		return
	var pose: Transform3D = LocalRebuild.pose(snapshot, item, field)
	var center: Vector2 = Vector2(pose.origin.x, pose.origin.z)
	var scale_value: float = float(item["scale"])
	var low: float = pose.origin.y
	if item.has("hedge"):
		var points: Array = item["hedge"]["points"]
		for i: int in range(points.size() - 1):
			_segment(
				HedgeRules.world_point(item, Vector2(points[i][0], points[i][1])),
				HedgeRules.world_point(item, Vector2(points[i + 1][0], points[i + 1][1])),
				float(item["hedge"]["width"]) * scale_value * 0.5,
				low,
				low + 1.5 * scale_value
			)
	elif asset == "PROP-01":
		_rect(center, Vector2(0.95, 0.38) * scale_value, item["yaw"], low, low + 1.1 * scale_value)
	elif asset == "PROP-04":
		for side: float in [-1.0, 1.0]:
			var offset: Vector3 = (
				Basis(Vector3.UP, item["yaw"]) * Vector3(side * 1.1 * scale_value, 0, 0)
			)
			_circle(
				center + Vector2(offset.x, offset.z),
				0.07 * scale_value,
				low,
				low + 2.0 * scale_value
			)
	else:
		var radius: float = (
			{
				"NAT-01": 0.22,
				"NAT-02": 0.18,
				"NAT-03": 0.20,
				"NAT-06": 0.42,
				"NAT-07": 0.45,
				"NAT-08": 0.55,
				"NAT-09": 0.55,
				"PROP-02": 0.24,
				"PROP-03": 0.30,
				"PROP-05": 0.42
			}
			. get(asset, 0.35)
		)
		_circle(
			center,
			radius * scale_value,
			low,
			low + (5.0 if asset in VegetationCatalog.NAMES else 1.2) * scale_value
		)


func _fence(snapshot: Dictionary, fence: Dictionary) -> void:
	var points: Array = fence["points"].duplicate(true)
	if fence.get("closed", false):
		points.append(points[0])
	for i: int in range(points.size() - 1):
		var a: Vector2 = Vector2(points[i][0], points[i][2])
		var b: Vector2 = Vector2(points[i + 1][0], points[i + 1][2])
		var count: int = maxi(1, ceili(a.distance_to(b) / 0.9))
		for j: int in range(count + 1):
			var p: Vector2 = a.lerp(b, float(j) / count)
			if FenceGeometry._road_gap(snapshot, p):
				continue
			var low: float = field.height_at(p)
			_circle(p, 0.055, low, low + 0.95)
			if j == count:
				continue
			var q: Vector2 = a.lerp(b, float(j + 1) / count)
			if (
				not FenceGeometry._road_gap(snapshot, q)
				and not FenceGeometry._road_gap(snapshot, (p + q) * 0.5)
			):
				_segment(
					p, q, 0.04, minf(low, field.height_at(q)), maxf(low, field.height_at(q)) + 0.8
				)
