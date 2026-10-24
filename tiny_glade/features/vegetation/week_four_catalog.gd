class_name WeekFourCatalog
extends RefCounted

const NAMES: Dictionary = {
	"NAT-04": "fern",
	"NAT-05": "wildflower",
	"NAT-06": "shrub",
	"NAT-08": "moss_rock",
	"NAT-09": "flat_rock",
	"PROP-01": "bench",
	"PROP-02": "mailbox",
	"PROP-03": "pot",
	"PROP-04": "clothesline"
}
const ATLAS: Texture2D = preload("res://assets/materials/textures/vegetation_atlas.png")

const PACKS: Dictionary = {
	"NAT-04": preload("res://assets/week_04/fern.glb"),
	"NAT-05": preload("res://assets/week_04/wildflower.glb"),
	"NAT-06": preload("res://assets/week_04/shrub.glb"),
	"NAT-08": preload("res://assets/week_04/moss_rock.glb"),
	"NAT-09": preload("res://assets/week_04/flat_rock.glb"),
	"PROP-01": preload("res://assets/week_04/bench.glb"),
	"PROP-02": preload("res://assets/week_04/mailbox.glb"),
	"PROP-03": preload("res://assets/week_04/pot.glb"),
	"PROP-04": preload("res://assets/week_04/clothesline.glb"),
}


static func create(asset_id: String, key: String, wood: Material, stone: Material) -> Node3D:
	var packed: PackedScene = PACKS[asset_id]
	var root: Node3D = packed.instantiate() as Node3D
	root.set_meta("object_id", key)
	_paint(root, key, wood, stone)
	return root


static func _paint(root: Node, key: String, wood: Material, stone: Material) -> void:
	if root is MeshInstance3D:
		var mesh: MeshInstance3D = root as MeshInstance3D
		var label: String = String(mesh.name)
		mesh.material_override = wood
		if label.begins_with("stone") or label.begins_with("soil"):
			mesh.material_override = stone
		elif label.begins_with("leaves") or label.begins_with("flower"):
			VegetationCatalog.apply_material(mesh, key)
			mesh.material_override.set_shader_parameter(
				"amplitude", 0.09 if label.begins_with("flower") else 0.12
			)
		elif label.begins_with("cloth"):
			var paint: ShaderMaterial = ShaderMaterial.new()
			paint.shader = preload("res://features/environment/wind.gdshader")
			paint.set_shader_parameter("base_color", Color("ece2c4"))
			paint.set_shader_parameter("amplitude", 0.55)
			paint.set_shader_parameter("phase", float(key.hash() % 10000) * 0.01)
			mesh.material_override = paint
		elif (
			label.begins_with("moss")
			or label.begins_with("mail_slot")
			or label.begins_with("pot")
			or label.begins_with("mailbox_roof")
		):
			var paint: StandardMaterial3D = StandardMaterial3D.new()
			paint.albedo_color = (
				Color("6b7e48")
				if label.begins_with("moss")
				else (
					Color("ad704e")
					if label.begins_with("pot") or label.begins_with("mailbox_roof")
					else Color("354235")
				)
			)
			paint.roughness = 0.95
			mesh.material_override = paint
	for child: Node in root.get_children():
		_paint(child, key, wood, stone)
