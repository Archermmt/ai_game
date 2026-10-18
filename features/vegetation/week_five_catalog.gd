class_name WeekFiveCatalog
extends RefCounted

const PACKS: Dictionary = {
	"PROP-03": preload("res://assets/week_05/pot.glb"),
	"PROP-04": preload("res://assets/week_05/clothesline.glb"),
	"PROP-05": preload("res://assets/week_05/crate.glb"),
	"PROP-06": preload("res://assets/week_05/watering_can.glb"),
	"PROP-07": preload("res://assets/week_05/tea_set.glb"),
	"PROP-08": preload("res://assets/week_05/lantern.glb")
}


static func create(asset_id: String, key: String, wood: Material, stone: Material) -> Node3D:
	var root: Node3D = PACKS[asset_id].instantiate() as Node3D
	root.set_meta("object_id", key)
	root.set_meta("w05_asset", asset_id)
	WeekFourCatalog._paint(root, key, wood, stone)
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		if String(node.name).begins_with("metal"):
			var paint: StandardMaterial3D = StandardMaterial3D.new()
			paint.albedo_color = Color("718576")
			paint.metallic = 0.12
			paint.roughness = 0.9
			node.material_override = paint
	return root
