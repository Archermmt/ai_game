class_name GardenAssetWrapper
extends Node3D
## Application-owned wrapper. Imported GLB nodes are never edited on disk.

@export var asset_id: String = "PROP-01"
var visual: Node3D


func configure(item: Dictionary, snapshot: Dictionary, wood: Material, stone: Material) -> void:
	name = "Asset_" + String(item["id"])
	set_meta("object_id", item["id"])
	set_meta("asset_id", asset_id)
	visual = (
		HedgeView.create(item, snapshot, wood, stone)
		if item.has("hedge")
		else WeekSixCatalog.create(asset_id, item["id"], wood, stone)
	)
	visual.name = "Visual"
	add_child(visual)
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "PickProxy"
	body.collision_layer = 2
	body.collision_mask = 0
	body.set_meta("object_id", item["id"])
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.name = "SelectionShape"
	var box: BoxShape3D = BoxShape3D.new()
	box.size = AssetFootprints.dimensions(asset_id)
	shape.shape = box
	shape.position.y = box.size.y * 0.5
	if item.has("hedge"):
		var rect: Rect2 = Rect2(Vector2.ZERO, Vector2.ZERO)
		for p: Vector2 in HedgeRules.samples(item):
			rect = rect.expand(p)
		box.size = Vector3(
			rect.size.x + item["hedge"]["width"], 1.0, rect.size.y + item["hedge"]["width"]
		)
		shape.position = Vector3(rect.get_center().x, 0.5, rect.get_center().y)
	body.add_child(shape)
	add_child(body)
	for pair: Array in [
		["GroundAnchor", 0.0],
		["SupportSurface", 0.8 if asset_id == "PROP-05" else 0.58],
		["LampAnchor", 0.28]
	]:
		if pair[0] == "SupportSurface" and asset_id not in ["PROP-01", "PROP-05"]:
			continue
		if pair[0] == "LampAnchor" and asset_id != "PROP-08":
			continue
		var anchor: Marker3D = Marker3D.new()
		anchor.name = pair[0]
		anchor.position.y = pair[1]
		add_child(anchor)
