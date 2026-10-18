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
				var pond: Dictionary = draft["pool"]
				exists = (
					exists
					or (
						position.distance_to(Vector2(pond["center"][0], pond["center"][1]))
						< float(pond["radius"]) + 1.8
					)
				)
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
		result.append(copy["id"])
	return result


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
					"NAT-08",
					"NAT-09",
					"PROP-01",
					"PROP-02",
					"PROP-03",
					"PROP-04"
				]
			)
		):
			return "invalid_instance_source"
		for building: Dictionary in snapshot["buildings"]:
			if TerrainField.conflicts(
				Vector2(item["position"][0], item["position"][2]),
				0.46 * float(item["scale"]),
				building
			):
				return "instance_building_collision"
	return ""
