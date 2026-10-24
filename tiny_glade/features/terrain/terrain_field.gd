class_name TerrainField
extends RefCounted
## W02 bounded height-field query. Player heights and pond derivation stay separate.

var spacing: float = 0.5
var heights: Dictionary = {}
var pool: Dictionary = {}
var forest_profile: bool = false
var rolling_profile: bool = false
var forest_phase: float = 0.0
var pool_contour: PackedVector2Array = PackedVector2Array()
var pool_bounds: Rect2


func _init(snapshot: Dictionary) -> void:
	spacing = float(snapshot["terrain"].get("spacing", 0.5))
	forest_profile = snapshot["terrain"].get("base_profile", "flat") == "forest_slope_v1"
	rolling_profile = snapshot["terrain"].get("base_profile", "flat") == "rolling_hills_v2"
	forest_phase = float(str(snapshot["world_seed"]).hash() % 10000) * 0.001
	for entry: Array in snapshot["terrain"]["height_deltas"]:
		heights[Vector2i(int(entry[0]), int(entry[1]))] = float(entry[2])
	pool = snapshot.get("pool", {}).duplicate(true)
	if pool.has("outline"):
		pool_contour = PondShape.contour(pool)
		pool_bounds = Rect2(pool_contour[0], Vector2.ZERO)
		for point: Vector2 in pool_contour:
			pool_bounds = pool_bounds.expand(point)


func player_height(point: Vector2) -> float:
	var grid: Vector2 = (point + Vector2.ONE * 32.0) / spacing
	var cell: Vector2i = Vector2i(floori(grid.x), floori(grid.y))
	var fraction: Vector2 = grid - Vector2(cell)
	var a: float = lerpf(
		heights.get(cell, 0.0), heights.get(cell + Vector2i.RIGHT, 0.0), fraction.x
	)
	var b: float = lerpf(
		heights.get(cell + Vector2i.DOWN, 0.0), heights.get(cell + Vector2i.ONE, 0.0), fraction.x
	)
	return base_height(point) + lerpf(a, b, fraction.y)


func base_height(point: Vector2) -> float:
	if rolling_profile:
		return (
			-0.15
			+ 0.06 * sin(point.x * 0.1 + forest_phase) * cos(point.y * 0.13)
			+ point.x * 0.002
			+ TerrainRelief.height(point, forest_phase)
			+ 0.15
		)
	if not forest_profile:
		return 0.0
	return -0.15 + 0.06 * sin(point.x * 0.1 + forest_phase) * cos(point.y * 0.13) + point.x * 0.002


func height_at(point: Vector2) -> float:
	var original: float = player_height(point)
	if pool.is_empty():
		return original
	if not pool_contour.is_empty() and not pool_bounds.grow(0.75).has_point(point):
		return original
	var distance: float = (
		PondShape.polygon_distance(pool_contour, point)
		if not pool_contour.is_empty()
		else PondShape.distance(pool, point)
	)
	var water: float = float(pool["water_y"])
	if distance <= -0.35:
		return water - 0.45
	if distance <= 0:
		return lerpf(water - 0.45, water + 0.1, smoothstep(-0.35, 0, distance))
	return lerpf(water + 0.1, original, smoothstep(0, 0.75, distance))


func normal_at(point: Vector2) -> Vector3:
	return (
		Vector3(
			height_at(point - Vector2(spacing, 0)) - height_at(point + Vector2(spacing, 0)),
			2.0 * spacing,
			height_at(point - Vector2(0, spacing)) - height_at(point + Vector2(0, spacing))
		)
		. normalized()
	)


func is_protected(point: Vector2) -> bool:
	if pool.is_empty():
		return false
	return PondShape.distance(pool, point) <= 0.75


static func brush(
	snapshot: Dictionary, point: Vector2, amount: float, radius: float = 2.0
) -> Dictionary:
	var result: Dictionary = snapshot.duplicate(true)
	var field: TerrainField = TerrainField.new(snapshot)
	var changes: Dictionary = field.heights.duplicate()
	var low: Vector2i = Vector2i(
		((point - Vector2.ONE * radius + Vector2.ONE * 32) / field.spacing).floor()
	)
	var high: Vector2i = Vector2i(
		((point + Vector2.ONE * radius + Vector2.ONE * 32) / field.spacing).ceil()
	)
	for z: int in range(low.y, high.y + 1):
		for x: int in range(low.x, high.x + 1):
			var position: Vector2 = Vector2(x, z) * field.spacing - Vector2.ONE * 32
			var distance: float = point.distance_to(position)
			if (
				absf(position.x) > 24
				or absf(position.y) > 24
				or distance > radius
				or field.is_protected(position)
			):
				continue
			var key: Vector2i = Vector2i(x, z)
			changes[key] = snappedf(
				float(changes.get(key, 0.0)) + amount * (1.0 - smoothstep(0.0, radius, distance)),
				0.0001
			)
	var keys: Array = changes.keys()
	keys.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x)
	)
	result["terrain"]["height_deltas"] = []
	for key: Vector2i in keys:
		if absf(changes[key]) > 0.00001:
			result["terrain"]["height_deltas"].append([key.x, key.y, changes[key]])
	return result


static func pond(snapshot: Dictionary, center: Vector2, radius: float) -> Dictionary:
	var result: Dictionary = snapshot.duplicate(true)
	var field: TerrainField = TerrainField.new(snapshot)
	var water: float = field.player_height(center) - 0.15
	if not snapshot["pool"].is_empty():
		water = float(snapshot["pool"]["water_y"])
	result["pool"] = {"center": [center.x, center.y], "radius": radius, "water_y": water}
	return result


static func validate(snapshot: Dictionary) -> String:
	var terrain: Dictionary = snapshot["terrain"]
	var step: Variant = terrain.get("spacing", 0.5)
	if not (step is float or step is int) or step not in [0.25, 0.5]:
		return "invalid_spacing"
	if terrain.get("base_profile", "flat") not in ["flat", "forest_slope_v1", "rolling_hills_v2"]:
		return "invalid_base_profile"
	var occupied: Dictionary = {}
	for entry: Array in terrain["height_deltas"]:
		var key: Vector2i = Vector2i(int(entry[0]), int(entry[1]))
		if (
			occupied.has(key)
			or key.x < 0
			or key.y < 0
			or key.x > int(64 / step)
			or key.y > int(64 / step)
		):
			return "invalid_height_index"
		if absf(float(entry[2])) > 8.0:
			return "height_out_of_range"
		occupied[key] = true
	var pond_data: Variant = snapshot.get("pool")
	if not pond_data is Dictionary:
		return "invalid_pool"
	if not pond_data.is_empty():
		var format_error: String = _pool_format(pond_data)
		if not format_error.is_empty():
			return format_error
	var field: TerrainField = TerrainField.new(snapshot)
	if not field.pool.is_empty():
		var pool_error: String = field._validate_pool(snapshot)
		if not pool_error.is_empty():
			return pool_error
	for building: Dictionary in snapshot["buildings"]:
		var p: Array = building["position"]
		var size: Array = building["size"]
		for z: float in _samples(
			float(p[2]) - float(size[2]) * 0.5, float(p[2]) + float(size[2]) * 0.5, field.spacing
		):
			for x: float in _samples(
				float(p[0]) - float(size[0]) * 0.5,
				float(p[0]) + float(size[0]) * 0.5,
				field.spacing
			):
				if (
					building["shape"] == "round"
					and Vector2(x - p[0], z - p[2]).length() > float(size[0]) * 0.5
				):
					continue
				var support: float = float(p[1]) - field.height_at(Vector2(x, z))
				if support > 3.00001:
					return "foundation_exceeds_3m"
				if support < -0.05:
					return "terrain_above_fixed_floor"
	return ""


static func _samples(low: float, high: float, step: float) -> Array[float]:
	var result: Array[float] = [low, high]
	for index: int in range(ceili(low / step), floori(high / step) + 1):
		result.append(float(index) * step)
	return result


static func _pool_format(data: Dictionary) -> String:
	if not data.get("center") is Array or data["center"].size() != 2:
		return "invalid_pool"
	for number: Variant in [
		data["center"][0], data["center"][1], data.get("radius"), data.get("water_y")
	]:
		if not (number is int or number is float) or not is_finite(float(number)):
			return "invalid_pool"
	if data.has("outline"):
		if (
			absf(data["center"][0]) > 22
			or absf(data["center"][1]) > 22
			or data["radius"] < 1
			or data["radius"] > 64
		):
			return "invalid_pool"
		var outline_error: String = PondShape.format_error(data)
		if not outline_error.is_empty():
			return outline_error
		for p: Array in data["outline"]:
			if (
				Vector2(p[0] - data["center"][0], p[1] - data["center"][1]).length()
				> float(data["radius"]) + 0.001
			):
				return "invalid_pool_bounds"
		return ""
	if data["radius"] < 1.0 or data["radius"] > 10.0:
		return "pool_minimum_width"
	if (
		absf(float(data["center"][0])) + float(data["radius"]) > 22.0
		or absf(float(data["center"][1])) + float(data["radius"]) > 22.0
	):
		return "pool_boundary_2m"
	return ""


func _validate_pool(snapshot: Dictionary) -> String:
	var center: Vector2 = Vector2(pool["center"][0], pool["center"][1])
	var radius: float = float(pool["radius"])
	var lowest: float = INF
	var highest: float = -INF
	for z: float in _samples(center.y - radius - 0.75, center.y + radius + 0.75, spacing):
		for x: float in _samples(center.x - radius - 0.75, center.x + radius + 0.75, spacing):
			if (
				(
					PondShape.polygon_distance(pool_contour, Vector2(x, z))
					if not pool_contour.is_empty()
					else PondShape.distance(pool, Vector2(x, z))
				)
				> 0.75
			):
				continue
			var original: float = player_height(Vector2(x, z))
			lowest = minf(lowest, original)
			highest = maxf(highest, original)
	if highest - lowest > 0.60001:
		return "pool_slope_exceeds_0_6m"
	if lowest < float(pool["water_y"]) - 0.00001:
		return "pool_flooding"
	if highest < float(pool["water_y"]) + 0.1:
		return "pool_floating"
	for building: Dictionary in snapshot["buildings"]:
		if _pool_conflicts(1.25, building):
			return "pool_building_safety"
	for instance: Dictionary in snapshot["instances"]:
		if _pool_conflicts(
			1.25, {"position": instance["position"], "size": [0.8, 1, 0.8], "shape": "rect"}
		):
			return "pool_manual_instance_safety"
	return ""


func _pool_conflicts(margin: float, object: Dictionary) -> bool:
	# Reuse this field's contour bounds for the far majority of distant objects.
	if pool.has("outline"):
		var center: Vector2 = Vector2(object["position"][0], object["position"][2])
		var half: Vector2 = Vector2(object["size"][0], object["size"][2]) * 0.5
		if not pool_bounds.grow(margin + 0.00001).intersects(Rect2(center - half, half * 2), true):
			return false
	return PondShape.conflicts(pool, margin, object)


static func conflicts(center: Vector2, radius: float, building: Dictionary) -> bool:
	var location: Vector2 = Vector2(building["position"][0], building["position"][2])
	if building["shape"] == "round":
		return center.distance_to(location) < radius + float(building["size"][0]) * 0.5 - 0.00001
	var half: Vector2 = Vector2(building["size"][0], building["size"][2]) * 0.5
	return center.distance_to(center.clamp(location - half, location + half)) < radius - 0.00001
