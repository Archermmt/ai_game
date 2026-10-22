class_name SurfaceEditData
extends RefCounted
## Identity-based surface edits. The session remains the sole publisher.


static func resolve(source: Dictionary, target: Dictionary) -> Dictionary:
	var family: String = target.get("family", "")
	if family in ["house", "prop"]:
		return DirectEditData.find(source, target["id"], family == "house")
	if family == "opening":
		var home: Dictionary = DirectEditData.find(source, target["parent"], true)
		for index: int in range(home.get("openings", []).size()):
			var item: Dictionary = home["openings"][index]
			if (
				(
					target.has("attachment_id")
					and item.get("attachment_id", "") == target["attachment_id"]
				)
				or (not target.has("attachment_id") and index == target.get("index", -1))
			):
				return item
	else:
		for item: Dictionary in source.get("bridges" if family == "bridge" else "stairs", []):
			if item["id"] == target.get("id"):
				return item
	return {}


static func opening_origin(home: Dictionary, opening: Dictionary) -> Vector3:
	var size: Array = home["size"]
	var point: Vector3 = BuildingGeometry._point(
		opening["center"] * DoorRules._length(home, opening.get("facade", 0)),
		opening.get("facade", 0),
		size[0],
		size[2],
		home["shape"] == "round"
	)
	return (
		point
		+ Vector3(
			home["position"][0],
			home["position"][1] + opening.get("sill", 0) + opening["height"] * 0.5,
			home["position"][2]
		)
	)


static func origin(source: Dictionary, target: Dictionary) -> Vector3:
	var item: Dictionary = resolve(source, target)
	if item.is_empty():
		return Vector3.ZERO
	if target["family"] == "opening":
		return opening_origin(DirectEditData.find(source, target["parent"], true), item)
	if target["family"] in ["bridge", "stair"]:
		var a: Vector2 = Vector2(item["a"][0], item["a"][1])
		var b: Vector2 = Vector2(item["b"][0], item["b"][1])
		var y: float = maxf(item["heights"][0], item["heights"][1])
		return Vector3((a.x + b.x) * 0.5, y + 0.2, (a.y + b.y) * 0.5)
	var p: Array = item["position"]
	return Vector3(
		p[0],
		(
			p[1]
			+ (
				InstanceEdits.support_height(source, item, 0, TerrainField.new(source))
				if target["family"] == "prop"
				else 0
			)
		),
		p[2]
	)


static func transform(
	source: Dictionary, target: Dictionary, kind: String, amount: Vector3
) -> Dictionary:
	var draft: Dictionary = source.duplicate(true)
	var item: Dictionary = resolve(draft, target)
	if amount.length_squared() < 0.000000000001:
		return draft
	if item.is_empty():
		return draft
	match target["family"]:
		"house":
			item["roof_rise"] = clampf(RoofProfile.rise(item) + amount.x, 0, 6)
			if item["roof_rise"] < 0.12:
				item["roof_rise"] = 0.0
		"opening":
			var home: Dictionary = DirectEditData.find(draft, target["parent"], true)
			var window: bool = item.get("sill", 0) > 0.1 or item["height"] < 1.8
			if kind == "move":
				var p: Vector3 = opening_origin(home, item) + amount
				var place: Dictionary = DoorRules.wall_point(home, Vector2(p.x, p.z))
				item["center"] = place["center"]
				item["facade"] = place["facade"]
				if window:
					item["sill"] = maxf(0.15, float(item.get("sill", 0)) + amount.y)
			elif kind == "width":
				item["width"] = clampf(float(item["width"]) + amount.x, 0.35, 3)
			elif kind == "height":
				item["height"] = clampf(
					float(item["height"]) + amount.x, 0.35 if window else 1.8, 3.5
				)
			if draft == source:
				return draft
			item["source"] = "manual"
			item.erase("source_path")
			item.erase("source_paths")
			if not item.has("attachment_id"):
				item["attachment_id"] = (
					(str(draft["world_seed"]) + ":hover-opening:" + str(draft["next_id"]))
					. sha256_text()
					. left(24)
				)
				draft["next_id"] += 1
		"bridge", "stair":
			if kind == "width":
				item["width"] = clampf(float(item["width"]) + amount.x, 0.8, 2)
			else:
				for key: String in ["a", "b"]:
					if kind == "move" or kind == "end_" + key:
						item[key] = [item[key][0] + amount.x, item[key][1] + amount.z]
			for index: int in range(2):
				var p: Array = item["a" if index == 0 else "b"]
				item["heights"][index] = GardenStructures.endpoint_height(
					draft, Vector2(p[0], p[1]), item["kind"]
				)
	return DoorRules.reconcile(draft)["snapshot"]


static func issue(before: Dictionary, draft: Dictionary) -> String:
	var error: String = WorldDocument.validate(draft)
	return error if not error.is_empty() else GardenStructures.transition_error(before, draft)
