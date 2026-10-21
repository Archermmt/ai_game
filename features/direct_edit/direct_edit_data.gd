class_name DirectEditData
extends RefCounted
## Pure candidate transformations. Publication still uses the existing validated session.


static func find(source: Dictionary, id_value: String, house: bool) -> Dictionary:
	for item: Dictionary in source["buildings" if house else "instances"]:
		if item["id"] == id_value:
			return item
	return {}


static func clone(source: Dictionary, id_value: String, house: bool) -> Dictionary:
	var draft: Dictionary = source.duplicate(true)
	var original: Dictionary = find(source, id_value, house)
	if original.is_empty():
		return {"source": draft, "id": ""}
	var p: Array = original["position"]
	var item: Dictionary
	if house:
		var s: Array = original["size"]
		item = WorldDocument.allocate_building(
			draft, Vector3(p[0], p[1], p[2]), Vector3(s[0], s[1], s[2]), original["shape"]
		)
		item["openings"] = []
		for opening: Dictionary in original["openings"]:
			if opening.get("source", "manual") == "auto_path":
				continue
			var copy: Dictionary = opening.duplicate(true)
			copy.erase("attachment_id")
			item["openings"].append(copy)
	else:
		item = InstanceEdits.allocate(draft, Vector3(p[0], p[1], p[2]))
		for key: String in [
			"asset_id", "yaw", "scale", "hedge", "lamp_mode", "height_locked", "locked_y"
		]:
			if original.has(key):
				item[key] = (
					original[key].duplicate(true) if original[key] is Dictionary else original[key]
				)
	return {"source": draft, "id": item["id"]}


static func transform(
	source: Dictionary, id_value: String, house: bool, kind: String, amount: Vector3
) -> Dictionary:
	var draft: Dictionary = source.duplicate(true)
	var item: Dictionary = find(draft, id_value, house)
	if item.is_empty():
		return draft
	if house:
		if kind in ["move", "copy"]:
			var p: Array = item["position"]
			var field: TerrainField = TerrainField.new(source)
			var from: Vector2 = Vector2(p[0], p[2])
			var to: Vector2 = from + Vector2(amount.x, amount.z)
			item["position"] = [to.x, p[1] + field.height_at(to) - field.height_at(from), to.y]
		else:
			var axis: int = {"width": 0, "height": 1, "depth": 2}.get(kind, 0)
			var limits: Vector2 = Vector2(2.4, 7.2) if axis == 1 else Vector2(3, 12)
			item["size"][axis] = clampf(float(item["size"][axis]) + amount.x, limits.x, limits.y)
			if item["shape"] == "round":
				item["size"][2] = item["size"][0]
	else:
		var ids: Array[String] = [id_value]
		InstanceEdits.transform_selection(
			draft,
			ids,
			amount if kind in ["move", "copy"] else Vector3.ZERO,
			amount.x if kind == "rotate" else 0.0,
			exp(clampf(amount.x, -2, 2)) if kind == "scale" else 1.0
		)
	return DoorRules.reconcile(draft)["snapshot"]


static func wall_hit(home: Dictionary, origin: Vector3, direction: Vector3) -> Variant:
	var p: Array = home["position"]
	var s: Array = home["size"]
	if home["shape"] != "round":
		return (
			AABB(Vector3(p[0] - s[0] / 2.0, p[1], p[2] - s[2] / 2.0), Vector3(s[0], s[1], s[2]))
			. intersects_ray(origin, direction)
		)
	var offset: Vector2 = Vector2(origin.x - p[0], origin.z - p[2])
	var ray: Vector2 = Vector2(direction.x, direction.z)
	var a: float = ray.length_squared()
	var b: float = 2 * offset.dot(ray)
	var c: float = offset.length_squared() - pow(s[0] / 2.0, 2)
	var discriminant: float = b * b - 4 * a * c
	if a < 0.000001 or discriminant < 0:
		return null
	for t: float in [(-b - sqrt(discriminant)) / (2 * a), (-b + sqrt(discriminant)) / (2 * a)]:
		var point: Vector3 = origin + direction * t
		if t >= 0 and point.y >= p[1] and point.y <= p[1] + s[1]:
			return point
	return null
