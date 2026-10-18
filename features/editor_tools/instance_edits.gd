class_name InstanceEdits
extends RefCounted
## Source-only edits. Brush entries are independently seeded, manual entries protected.


static func allocate(draft: Dictionary, point: Vector3, manual: bool = true) -> Dictionary:
	var sequence: int = int(draft["next_id"])
	var key: String = "%s:instance:%d" % [draft["world_seed"], sequence]
	var record: Dictionary = {
		"id": key.sha256_text().left(24),
		"position": [point.x, point.y, point.z],
		"yaw": 0.0,
		"scale": 1.0,
		"asset_id": "grey_prop",
		"seed": key.sha256_text(),
		"source": "manual" if manual else "brush",
		"locked": manual
	}
	draft["next_id"] = sequence + 1
	draft["instances"].append(record)
	return record


static func brush(
	draft: Dictionary, point: Vector2, visited: Dictionary, erase: bool = false
) -> void:
	if erase:
		for index: int in range(draft["instances"].size() - 1, -1, -1):
			var item: Dictionary = draft["instances"][index]
			if item["source"] == "manual" or item["locked"]:
				continue
			if point.distance_to(Vector2(item["position"][0], item["position"][2])) < 1.5:
				draft["instances"].remove_at(index)
		return
	var cell: Vector2i = Vector2i(point.round())
	for z: int in range(cell.y - 1, cell.y + 2):
		for x: int in range(cell.x - 1, cell.x + 2):
			var key: String = "%d:%d" % [x, z]
			if visited.has(key):
				continue
			visited[key] = true
			var rng: RandomNumberGenerator = RandomNumberGenerator.new()
			rng.seed = (str(draft["world_seed"]) + ":brush:" + key).hash()
			var position: Vector2 = (
				Vector2(x, z) + Vector2(rng.randf_range(-0.2, 0.2), rng.randf_range(-0.2, 0.2))
			)
			if absf(position.x) > 23.0 or absf(position.y) > 23.0:
				continue
			var exists: bool = false
			for other: Dictionary in draft["instances"]:
				exists = (
					exists
					or (
						position.distance_to(Vector2(other["position"][0], other["position"][2]))
						< 0.6
					)
				)
			for building: Dictionary in draft["buildings"]:
				exists = exists or TerrainField.conflicts(position, 0.6, building)
			if not draft["pool"].is_empty():
				exists = exists or PondShape.distance(draft["pool"], position) < 1.8
			if exists:
				continue
			var item: Dictionary = allocate(draft, Vector3(position.x, 0, position.y), false)
			item["yaw"] = rng.randf_range(0, TAU)
			item["scale"] = rng.randf_range(0.8, 1.15)


static func transform_selection(
	draft: Dictionary,
	selected: Array[String],
	delta: Vector3,
	yaw: float = 0.0,
	scale_factor: float = 1.0
) -> void:
	for item: Dictionary in draft["instances"]:
		if item["id"] not in selected:
			continue
		if delta.length_squared() > 0.00001:
			item.erase("support_id")
		item["position"][0] += delta.x
		item["position"][2] += delta.z
		item["yaw"] += yaw
		item["scale"] = clampf(float(item["scale"]) * scale_factor, 0.5, 2.0)
		item["source"] = "manual"
		item["locked"] = true


static func duplicate_selection(draft: Dictionary, selected: Array[String]) -> Array[String]:
	var copies: Array[Dictionary] = []
	for item: Dictionary in draft["instances"]:
		if item["id"] in selected:
			copies.append(item.duplicate(true))
	var result: Array[String] = []
	for item: Dictionary in copies:
		var p: Array = item["position"]
		var copy: Dictionary = allocate(draft, Vector3(p[0] + 1, p[1], p[2] + 1))
		copy["yaw"] = item["yaw"]
		copy["scale"] = item["scale"]
		copy["asset_id"] = item["asset_id"]
		for key: String in ["hedge", "lamp_mode", "height_locked", "locked_y"]:
			if item.has(key):
				copy[key] = item[key].duplicate(true) if item[key] is Dictionary else item[key]
		result.append(copy["id"])
	return result


static func support_height(
	snapshot: Dictionary, item: Dictionary, depth: int = 0, ground_field: TerrainField = null
) -> float:
	if item.get("height_locked", false):
		return float(item["locked_y"]) - float(item["position"][1])
	var p: Array = item["position"]
	var field: TerrainField = ground_field if ground_field != null else TerrainField.new(snapshot)
	if depth > 8 or not item.has("support_id"):
		return field.height_at(Vector2(p[0], p[2]))
	for parent: Dictionary in snapshot["instances"]:
		if parent["id"] == item.get("support_id", ""):
			return (
				support_height(snapshot, parent, depth + 1, field)
				+ float(parent["position"][1])
				+ float(parent["scale"]) * (0.8 if parent["asset_id"] == "PROP-05" else 0.58)
			)
	return field.height_at(Vector2(p[0], p[2]))


static func support_error(snapshot: Dictionary, item: Dictionary) -> String:
	if not item.has("support_id"):
		return ""
	var seen: Array = [item["id"]]
	var cursor: Dictionary = item
	for depth: int in range(9):
		if not cursor.has("support_id"):
			return ""
		var found: bool = false
		for parent: Dictionary in snapshot["instances"]:
			if parent["id"] != cursor["support_id"]:
				continue
			if parent["id"] in seen or parent["asset_id"] not in ["PROP-05", "PROP-01"]:
				return "invalid_support"
			var extent: float = 0.3 * float(parent["scale"])
			if (
				absf(cursor["position"][0] - parent["position"][0]) > extent
				or absf(cursor["position"][2] - parent["position"][2]) > extent
			):
				return "support_outside_surface"
			seen.append(parent["id"])
			cursor = parent
			found = true
			break
		if not found:
			return "missing_support"
	return "support_stack_limit"


static func validate(snapshot: Dictionary, existing_ids: Dictionary) -> String:
	var ids: Dictionary = existing_ids
	if snapshot["instances"].size() > 800:
		return "prototype_instance_limit"
	for item: Variant in snapshot["instances"]:
		if not item is Dictionary:
			return "invalid_instance"
		if not item.get("id") is String or ids.has(item["id"]):
			return "duplicate_instance_id"
		ids[item["id"]] = true
		if not item.get("position") is Array or item["position"].size() != 3:
			return "invalid_instance_transform"
		for value: Variant in item["position"] + [item.get("yaw"), item.get("scale")]:
			if not (value is float or value is int) or not is_finite(float(value)):
				return "invalid_instance_transform"
		if (
			absf(float(item["position"][0])) > 23.5
			or absf(float(item["position"][2])) > 23.5
			or item["scale"] < 0.5
			or item["scale"] > 2.0
		):
			return "instance_outside_bounds"
		if (
			item.get("source") not in ["manual", "brush"]
			or not item.get("locked") is bool
			or not item.get("seed") is String
			or (
				item.get("asset_id")
				not in [
					"grey_prop",
					"NAT-01",
					"NAT-02",
					"NAT-03",
					"NAT-04",
					"NAT-05",
					"NAT-06",
					"NAT-07",
					"NAT-08",
					"NAT-09",
					"PROP-01",
					"PROP-02",
					"PROP-03",
					"PROP-04",
					"PROP-05",
					"PROP-06",
					"PROP-07",
					"PROP-08"
				]
			)
		):
			return "invalid_instance_source"
		if (
			item.has("height_locked")
			and (
				not item["height_locked"] is bool or not WorldDocument._number(item.get("locked_y"))
			)
		):
			return "invalid_height_lock"
		if (
			item.has("lamp_mode")
			and (item["asset_id"] != "PROP-08" or item["lamp_mode"] not in ["on", "off", "auto"])
		):
			return "invalid_lamp_mode"
		if item.has("hedge"):
			var hedge_issue: String = HedgeRules.shape_error(item)
			if not hedge_issue.is_empty():
				return hedge_issue
			if not HedgeRules.clearance(snapshot, item):
				return "hedge_clearance"
		var support_issue: String = support_error(snapshot, item)
		if not support_issue.is_empty():
			return support_issue
		for building: Dictionary in snapshot["buildings"]:
			if TerrainField.conflicts(
				Vector2(item["position"][0], item["position"][2]),
				0.46 * float(item["scale"]),
				building
			):
				return "instance_building_collision"
	return ""
