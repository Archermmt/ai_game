class_name GardenStructures
extends RefCounted
## Saved bridge/stair endpoints; invalidated structures remain visible and editable.


static func allocate(
	draft: Dictionary, kind: String, a: Vector2, b: Vector2, width: float = 1.2
) -> Dictionary:
	var key: String = "%s:%s:%d" % [draft["world_seed"], kind, draft["next_id"]]
	draft["next_id"] += 1
	var collection: String = "bridges" if kind == "bridge" else "stairs"
	if not draft.has(collection):
		draft[collection] = []
	var item: Dictionary = {
		"id": key.sha256_text().left(24),
		"kind": kind,
		"a": [a.x, a.y],
		"b": [b.x, b.y],
		"width": width,
		"heights": [endpoint_height(draft, a, kind), endpoint_height(draft, b, kind)]
	}
	draft[collection].append(item)
	return item


static func status(snapshot: Dictionary, item: Dictionary) -> String:
	var a: Vector2 = Vector2(item["a"][0], item["a"][1])
	var b: Vector2 = Vector2(item["b"][0], item["b"][1])
	var length: float = a.distance_to(b)
	var field: TerrainField = TerrainField.new(snapshot)
	var ha: float = endpoint_height(snapshot, a, item["kind"])
	var hb: float = endpoint_height(snapshot, b, item["kind"])
	for home: Dictionary in snapshot["buildings"]:
		for i: int in range(17):
			if TerrainField.conflicts(
				a.lerp(b, float(i) / 16),
				0.01 if item["kind"] == "stair" else item["width"] * 0.5,
				home
			):
				return "structure_building_collision"
	if item["kind"] == "stair":
		if absf(ha - hb) < 0.1499 or absf(ha - hb) > 0.9001:
			return "stair_height_0_15_to_0_9"
		if length < 0.6 or length > 3.0:
			return "stair_length"
		if field.is_protected(a) or field.is_protected(b):
			return "stair_pool_conflict"
	else:
		if length < 1.5 or length > 6.0:
			return "bridge_length_1_5_to_6"
		if absf(ha - hb) > 0.50001:
			return "bridge_height_0_5"
		if snapshot["pool"].is_empty():
			return "bridge_missing_pond"
		if (
			PondShape.distance(snapshot["pool"], a) < 0.05
			or PondShape.distance(snapshot["pool"], b) < 0.05
		):
			return "bridge_adjust_heads"
		var wet: bool = false
		for i: int in range(1, 33):
			wet = wet or PondShape.distance(snapshot["pool"], a.lerp(b, float(i) / 33)) < -0.15
		if not wet:
			return "bridge_adjust_heads"
	return ""


static func transition_error(before: Dictionary, after: Dictionary) -> String:
	for collection: String in ["bridges", "stairs"]:
		for item: Dictionary in after.get(collection, []):
			if item not in before.get(collection, []):
				var issue: String = status(after, item)
				if not issue.is_empty():
					return issue
	return ""


static func validate(snapshot: Dictionary, ids: Dictionary) -> String:
	for collection: String in ["bridges", "stairs"]:
		var entries: Variant = snapshot.get(collection, [])
		if not entries is Array or entries.size() > 100:
			return "invalid_structures"
		for item: Variant in entries:
			if not item is Dictionary or not item.get("id") is String or ids.has(item["id"]):
				return "invalid_structure_id"
			ids[item["id"]] = true
			if item.get("kind") != ("bridge" if collection == "bridges" else "stair"):
				return "invalid_structure_kind"
			for key: String in ["a", "b", "heights"]:
				if not item.get(key) is Array or item[key].size() != 2:
					return "invalid_structure_points"
				for number: Variant in item[key]:
					if not WorldDocument._number(number):
						return "invalid_structure_points"
			for p: Array in [item["a"], item["b"]]:
				if absf(p[0]) > 23.5 or absf(p[1]) > 23.5:
					return "structure_outside_bounds"
			if (
				not WorldDocument._number(item.get("width"))
				or item["width"] < 0.8
				or item["width"] > 2.0
			):
				return "structure_width"
			if status(snapshot, item) == "structure_building_collision":
				return "structure_building_collision"
	return ""


static func build(snapshot: Dictionary) -> Dictionary:
	var result: Dictionary = {"bridge": [], "stair": [], "issues": []}
	for collection: String in ["bridges", "stairs"]:
		for item: Dictionary in snapshot.get(collection, []):
			var issue: String = status(snapshot, item)
			if not issue.is_empty():
				result["issues"].append({"id": item["id"], "error": issue})
			var builder: BuildingGeometry = BuildingGeometry.new()
			var a: Vector2 = Vector2(item["a"][0], item["a"][1])
			var b: Vector2 = Vector2(item["b"][0], item["b"][1])
			var field: TerrainField = TerrainField.new(snapshot)
			var ha: float = (
				endpoint_height(snapshot, a, item["kind"])
				if issue.is_empty()
				else item["heights"][0]
			)
			var hb: float = (
				endpoint_height(snapshot, b, item["kind"])
				if issue.is_empty()
				else item["heights"][1]
			)
			var length: float = a.distance_to(b)
			var angle: float = -atan2(b.y - a.y, b.x - a.x)
			var tint: Color = Color("bd7653") if not issue.is_empty() else Color("aa8055")
			if item["kind"] == "bridge":
				var deck: float = maxf(
					maxf(ha, hb), float(snapshot["pool"].get("water_y", -99)) + 0.18
				)
				var count: int = maxi(1, ceili(length / 0.23))
				for i: int in range(count):
					var t0: float = float(i) / count
					var t1: float = float(i + 1) / count
					var h0: float = deck_height(ha, hb, deck, length, t0)
					var h1: float = deck_height(ha, hb, deck, length, t1)
					var p: Vector2 = a.lerp(b, (t0 + t1) * 0.5)
					beam(
						builder,
						Vector3(p.x, (h0 + h1) * 0.5, p.y),
						Vector3(
							Vector2(length / count, h1 - h0).length() - 0.008, 0.12, item["width"]
						),
						angle,
						tint,
						atan2(h1 - h0, length / count)
					)
				for side: float in [-1.0, 1.0]:
					var normal: Vector2 = (
						(b - a).normalized().orthogonal() * side * item["width"] * 0.4
					)
					for i: int in range(5):
						var p: Vector2 = a.lerp(b, float(i) / 4) + normal
						var ground: float = field.height_at(p)
						beam(
							builder,
							Vector3(p.x, (ground + deck + 0.65) * 0.5, p.y),
							Vector3(0.1, maxf(0.1, deck + 0.65 - ground), 0.1),
							angle,
							tint
						)
					var midpoint: Vector2 = (a + b) * 0.5 + normal
					beam(
						builder,
						Vector3(midpoint.x, deck + 0.58, midpoint.y),
						Vector3(length, 0.07, 0.08),
						angle,
						tint
					)
			else:
				if ha > hb:
					var swap: Vector2 = a
					a = b
					b = swap
					var hswap: float = ha
					ha = hb
					hb = hswap
				var count: int = maxi(1, ceili(absf(hb - ha) / KitProfiles.TREAD_RISE))
				for i: int in range(count):
					var p: Vector2 = a.lerp(b, (float(i) + 0.5) / count)
					var top: float = lerpf(ha, hb, float(i + 1) / count)
					beam(
						builder,
						Vector3(p.x, (ha - 0.08 + top) * 0.5, p.y),
						Vector3(length / count + 0.015, top - ha + 0.08, item["width"]),
						angle,
						Color("92988b") if issue.is_empty() else tint
					)
			result[item["kind"]].append(MeshParts.arrays(builder))
	return result


static func beam(
	builder: BuildingGeometry,
	center: Vector3,
	size: Vector3,
	angle: float,
	tint: Color,
	pitch: float = 0.0
) -> void:
	var start: int = builder._vertices.size()
	MeshParts.box(builder, Vector3.ZERO, size, tint)
	var rotation: Basis = Basis(Vector3.UP, angle) * Basis(Vector3.BACK, pitch)
	for i: int in range(start, builder._vertices.size()):
		builder._vertices[i] = center + rotation * builder._vertices[i]
		builder._normals[i] = rotation * builder._normals[i]


static func deck_height(ha: float, hb: float, deck: float, length: float, t: float) -> float:
	var ramp: float = minf(0.5, length * 0.25) / maxf(length, 0.001)
	if t < ramp:
		return lerpf(ha - 0.03, deck, t / ramp)
	if t > 1.0 - ramp:
		return lerpf(deck, hb - 0.03, (t - 1.0 + ramp) / ramp)
	return deck


static func endpoint_height(snapshot: Dictionary, p: Vector2, kind: String) -> float:
	if kind == "stair":
		for home: Dictionary in snapshot["buildings"]:
			var place: Dictionary = DoorRules.wall_point(home, p)
			if place["distance"] > 0.4 or TerrainField.conflicts(p, 0.001, home):
				continue
			for opening: Dictionary in home["openings"]:
				if (
					opening["height"] >= 1.8
					and opening.get("facade", 0) == place["facade"]
					and (
						(
							absf(opening["center"] - place["center"])
							* DoorRules._length(home, place["facade"])
						)
						< opening["width"] * 0.5
					)
				):
					return home["position"][1]
	return TerrainField.new(snapshot).height_at(p)
