class_name BuildingEdits
extends RefCounted
## Atomic source edits. Detached manual openings retain their identity and world pose.


static func resize(draft: Dictionary, ids: Array[String], size: Vector3) -> void:
	for building: Dictionary in draft["buildings"]:
		if building["id"] in ids:
			building["size"] = [size.x, size.y, size.x if building["shape"] == "round" else size.z]


static func remove(draft: Dictionary, ids: Array[String]) -> void:
	for building: Dictionary in draft["buildings"]:
		if building["id"] not in ids:
			continue
		for index: int in range(building["openings"].size()):
			var opening: Dictionary = building["openings"][index]
			if opening.get("source", "manual") == "auto_path" and not opening.get("locked", false):
				continue
			var width: float = building["size"][0]
			var depth: float = building["size"][2]
			var facade: int = opening.get("facade", 0)
			var rounded: bool = building["shape"] == "round"
			var length: float = PI * width if rounded else (width if facade % 2 == 0 else depth)
			var u: float = opening["center"] * length
			var p: Array = building["position"]
			var point: Vector3 = BuildingGeometry._point(u, facade, width, depth, rounded)
			point += Vector3(p[0], p[1] + opening.get("sill", 0.0), p[2])
			var normal: Vector3 = BuildingGeometry._normal(u, facade, width, depth, rounded)
			var key: String = "%s:opening:%d" % [building["id"], index]
			draft["attachments"].append(
				{
					"id": opening.get("attachment_id", key.sha256_text().left(24)),
					"parent_id": "",
					"former_parent_id": building["id"],
					"former_shape": building["shape"],
					"former_size": building["size"].duplicate(),
					"position": [point.x, point.y, point.z],
					"yaw": atan2(normal.x, normal.z),
					"opening": opening.duplicate(true)
				}
			)
	for index: int in range(draft["buildings"].size() - 1, -1, -1):
		if draft["buildings"][index]["id"] in ids:
			draft["buildings"].remove_at(index)


static func reattach(
	draft: Dictionary, attachment_id: String, parent_id: String, facade: int = 0
) -> bool:
	for index: int in range(draft["attachments"].size()):
		var attachment: Dictionary = draft["attachments"][index]
		if attachment["id"] != attachment_id:
			continue
		for building: Dictionary in draft["buildings"]:
			if building["id"] != parent_id:
				continue
			var opening: Dictionary = attachment["opening"].duplicate(true)
			opening["attachment_id"] = attachment_id
			opening["source"] = "manual"
			opening.erase("source_path")
			opening.erase("source_paths")
			opening["facade"] = 0 if building["shape"] == "round" else facade
			building["openings"].append(opening)
			draft["attachments"].remove_at(index)
			return true
	return false


static func validate_attachments(snapshot: Dictionary, ids: Dictionary) -> String:
	for item: Variant in snapshot["attachments"]:
		if not item is Dictionary or not item.get("id") is String or ids.has(item["id"]):
			return "invalid_attachment_id"
		ids[item["id"]] = true
		if item.get("parent_id") != "" or not item.get("former_parent_id") is String:
			return "invalid_attachment_parent"
		if not item.get("position") is Array or item["position"].size() != 3:
			return "invalid_attachment_pose"
		for value: Variant in item["position"] + [item.get("yaw")]:
			if not WorldDocument._number(value):
				return "invalid_attachment_pose"
		if not item.get("opening") is Dictionary:
			return "invalid_detached_opening"
		var proxy: Dictionary = {
			"shape": item.get("former_shape", "rect"),
			"size": item.get("former_size", [12.0, 7.2, 12.0]),
			"openings": [item["opening"]]
		}
		if (
			proxy["shape"] not in ["rect", "round"]
			or not proxy["size"] is Array
			or proxy["size"].size() != 3
		):
			return "invalid_detached_opening"
		for value: Variant in proxy["size"]:
			if not WorldDocument._number(value) or value <= 0:
				return "invalid_detached_opening"
		if not WorldDocument._valid_openings(proxy):
			return "invalid_detached_opening"
	for building: Dictionary in snapshot["buildings"]:
		for opening: Dictionary in building["openings"]:
			if opening.has("attachment_id"):
				var key: Variant = opening["attachment_id"]
				if not key is String or ids.has(key):
					return "duplicate_attachment_id"
				ids[key] = true
	return ""
