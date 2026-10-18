class_name RiskEdits
extends RefCounted
## SP-04 narrow road→door transaction probe, not the later full road editing tool.


static func road_to_door(
	snapshot: Dictionary, building_id: String, start: Vector3, end: Vector3
) -> Dictionary:
	var draft: Dictionary = snapshot.duplicate(true)
	for building: Dictionary in draft["buildings"]:
		if building["id"] != building_id or building["shape"] != "rect":
			continue
		var p: Array = building["position"]
		var size: Array = building["size"]
		var wall_z: float = float(p[2]) + float(size[2]) * 0.5
		if absf(end.z - wall_z) > 0.6 or absf(end.y - float(p[1])) > 0.45:
			return {"ok": false, "error": "road_door_distance"}
		var key: String = "%s:road:%d" % [draft["world_seed"], draft["next_id"]]
		var path_id: String = key.sha256_text().left(24)
		draft["next_id"] += 1
		draft["paths"].append(
			{
				"id": path_id,
				"seed": key.sha256_text(),
				"points": [[start.x, start.y, start.z], [end.x, end.y, end.z]],
				"width": 1.2
			}
		)
		building["openings"].append(
			{
				"kind": "arch",
				"center": (end.x - float(p[0])) / float(size[0]) + 0.5,
				"width": 1.1,
				"height": 2.05,
				"source": "auto_path",
				"source_path": path_id
			}
		)
		var error: String = WorldDocument.validate(draft)
		return (
			{"ok": true, "snapshot": draft} if error.is_empty() else {"ok": false, "error": error}
		)
	return {"ok": false, "error": "no_probe_building"}


static func validate_paths(snapshot: Dictionary, existing: Dictionary) -> String:
	var ids: Dictionary = existing
	var path_ids: Dictionary = {}
	for path: Variant in snapshot["paths"]:
		if not path is Dictionary or not path.get("id") is String or ids.has(path["id"]):
			return "invalid_path_id"
		ids[path["id"]] = true
		path_ids[path["id"]] = true
		if (
			not path.get("points") is Array
			or path["points"].size() < 2
			or path["points"].size() > 256
		):
			return "invalid_path_points"
		for point: Variant in path["points"]:
			if not point is Array or point.size() != 3:
				return "invalid_path_points"
			for number: Variant in point:
				if not (number is float or number is int) or not is_finite(float(number)):
					return "invalid_path_points"
			if absf(float(point[0])) > 24 or absf(float(point[2])) > 24:
				return "path_outside_bounds"
		var width: Variant = path.get("width")
		if not (width is float or width is int) or width < 0.5 or width > 3:
			return "invalid_path_width"
	for building: Dictionary in snapshot["buildings"]:
		for opening: Dictionary in building["openings"]:
			if opening.has("source_path") and not path_ids.has(opening["source_path"]):
				return "invalid_opening_path_reference"
	return ""
