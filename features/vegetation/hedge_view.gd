class_name HedgeView
extends RefCounted
## Repeated shared shrub mesh and UVs; a closed volume at each end and every corner.


static func create(
	item: Dictionary, snapshot: Dictionary, wood: Material, stone: Material
) -> Node3D:
	var layout: Dictionary = plan(item, snapshot)
	var root: Node3D = FoliageBatches.build(layout["items"], layout["poses"], wood, stone)
	root.name = "HedgeVolume"
	root.set_meta("object_id", item["id"])
	root.set_meta("asset_id", "NAT-07")
	return root


static func plan(item: Dictionary, snapshot: Dictionary) -> Dictionary:
	var field: TerrainField = TerrainField.new(snapshot)
	var base_height: float = field.height_at(Vector2(item["position"][0], item["position"][2]))
	var items: Array = []
	var poses: Dictionary = {}
	for p: Vector2 in HedgeRules.samples(item):
		var key: String = "%s:%.4f:%.4f" % [item["seed"], p.x, p.y]
		var world: Vector2 = HedgeRules.world_point(item, p)
		var height: float = (field.height_at(world) - base_height) / item["scale"]
		if item.get("height_locked", false):
			height = 0
		var size: Vector3 = Vector3(item["hedge"]["width"], 0.85, item["hedge"]["width"])
		var basis_value: Basis = (
			Basis(Vector3.UP, float(posmod(key.hash(), 1000)) * TAU / 1000).scaled(size)
		)
		poses[key] = Transform3D(basis_value, Vector3(p.x, height, p.y))
		items.append({"id": key, "seed": key, "asset_id": "NAT-06", "position": [p.x, 0, p.y]})
	return {"items": items, "poses": poses}
