class_name VegetationBrush
extends RefCounted
## Stable per-category lattice, independent density/spacing and manual-first clearance.

const CATEGORIES: Dictionary = {
	"trees": ["NAT-01", "NAT-02", "NAT-03"],
	"plants": ["NAT-04", "NAT-05", "NAT-06", "NAT-07"],
	"rocks": ["NAT-08", "NAT-09"]
}
const SPACING: Dictionary = {"trees": 3.2, "plants": 0.85, "rocks": 1.6}


static func paint(
	draft: Dictionary,
	point: Vector2,
	category: String,
	radius: float,
	density: float,
	visited: Dictionary,
	erase: bool = false
) -> int:
	if (
		not CATEGORIES.has(category)
		or not is_finite(radius)
		or radius < 0.5
		or radius > 6
		or not is_finite(density)
	):
		return 0
	if not erase and density <= 0:
		return 0
	var assets: Array = CATEGORIES[category]
	var changed: int = 0
	if erase:
		for i: int in range(draft["instances"].size() - 1, -1, -1):
			var item: Dictionary = draft["instances"][i]
			if item["source"] != "brush" or item["locked"] or item["asset_id"] not in assets:
				continue
			var distance: float = (
				HedgeRules.distance(item, point)
				if item.has("hedge")
				else point.distance_to(Vector2(item["position"][0], item["position"][2]))
			)
			if distance <= radius:
				draft["instances"].remove_at(i)
				changed += 1
		return changed
	var spacing: float = SPACING[category]
	var lo: Vector2i = Vector2i(((point - Vector2.ONE * radius) / spacing).floor())
	var hi: Vector2i = Vector2i(((point + Vector2.ONE * radius) / spacing).ceil())
	for z: int in range(lo.y, hi.y + 1):
		for x: int in range(lo.x, hi.x + 1):
			var seed_key: String = "%s:foliage:%s:%d:%d" % [draft["world_seed"], category, x, z]
			var rng: RandomNumberGenerator = RandomNumberGenerator.new()
			rng.seed = seed_key.hash()
			var position: Vector2 = (
				(Vector2(x, z) + Vector2(rng.randf_range(0.2, 0.8), rng.randf_range(0.2, 0.8)))
				* spacing
			)
			if point.distance_to(position) > radius or visited.has(seed_key):
				continue
			visited[seed_key] = true
			if rng.randf() > density or not clear(draft, position, category):
				continue
			var id_value: String = seed_key.sha256_text().left(24)
			var exists: bool = false
			for item: Dictionary in draft["instances"]:
				exists = exists or item["id"] == id_value
			if exists or draft["instances"].size() >= 800:
				continue
			draft["instances"].append(
				{
					"id": id_value,
					"position": [position.x, 0.0, position.y],
					"yaw": rng.randf_range(0, TAU),
					"scale":
					(
						rng.randf_range(0.85, 1.15)
						if category == "trees"
						else rng.randf_range(0.75, 1.25)
					),
					"asset_id": assets[rng.randi_range(0, assets.size() - 1)],
					"seed": seed_key.sha256_text(),
					"source": "brush",
					"locked": false,
					"category": category
				}
			)
			changed += 1
	return changed


static func geometry_clear(snapshot: Dictionary, p: Vector2) -> bool:
	if absf(p.x) > 23 or absf(p.y) > 23 or PondShape.distance(snapshot["pool"], p) < 1.8:
		return false
	for home: Dictionary in snapshot["buildings"]:
		if TerrainField.conflicts(p, 0.7, home):
			return false
	if TerrainEdits.entrance_protected(snapshot, p):
		return false
	for path: Dictionary in snapshot["paths"]:
		var points: Array[Vector2] = PathCurve.sample(path)
		for i: int in range(points.size() - 1):
			if (
				p.distance_to(Geometry2D.get_closest_point_to_segment(p, points[i], points[i + 1]))
				< path["width"] * 0.5 + 0.5
			):
				return false
	for collection: String in ["bridges", "stairs"]:
		for item: Dictionary in snapshot.get(collection, []):
			for end: Array in [item["a"], item["b"]]:
				if p.distance_to(Vector2(end[0], end[1])) < item["width"] * 0.5 + 0.5:
					return false
	return true


static func clear(snapshot: Dictionary, p: Vector2, category: String) -> bool:
	if not geometry_clear(snapshot, p):
		return false
	for item: Dictionary in snapshot["instances"]:
		var other: Vector2 = Vector2(item["position"][0], item["position"][2])
		var gap: float = 0.65
		if category == "trees" and item["asset_id"] in CATEGORIES["trees"]:
			gap = 2.6
		if p.distance_to(other) < gap:
			return false
	return true


static func reconcile(snapshot: Dictionary) -> Dictionary:
	var draft: Dictionary = snapshot.duplicate(true)
	for i: int in range(draft["instances"].size() - 1, -1, -1):
		var item: Dictionary = draft["instances"][i]
		if item["source"] != "brush" or item["locked"] or not item.has("category"):
			continue
		var p: Vector2 = Vector2(item["position"][0], item["position"][2])
		if (
			not HedgeRules.clearance(draft, item)
			if item.has("hedge")
			else not geometry_clear(draft, p)
		):
			draft["instances"].remove_at(i)
	return draft
