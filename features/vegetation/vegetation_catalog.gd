class_name VegetationCatalog
extends RefCounted
## A view index is transient; source identity never depends on child order.

const NAMES: Dictionary = {
	"NAT-01": "tree_broadleaf", "NAT-02": "tree_conifer", "NAT-03": "tree_fruit"
}
const ATLAS: Texture2D = preload("res://assets/materials/textures/vegetation_atlas.png")

const PACKS: Dictionary = {
	"tree_broadleaf": preload("res://assets/nature/week_03/tree_broadleaf.glb"),
	"tree_conifer": preload("res://assets/nature/week_03/tree_conifer.glb"),
	"tree_fruit": preload("res://assets/nature/week_03/tree_fruit.glb"),
	"tree_broadleaf_lod1": preload("res://assets/nature/week_03/tree_broadleaf_lod1.glb"),
	"tree_conifer_lod1": preload("res://assets/nature/week_03/tree_conifer_lod1.glb"),
	"tree_fruit_lod1": preload("res://assets/nature/week_03/tree_fruit_lod1.glb")
}


static func instantiate_asset(asset_id: String, key: String, lod: int = 0) -> Node3D:
	var filename: String = NAMES.get(asset_id, "tree_broadleaf")
	if lod > 0:
		filename += "_lod1"
	var packed: PackedScene = PACKS[filename]
	var root: Node3D = packed.instantiate() as Node3D
	root.set_meta("object_id", key)
	apply_material(root, key)
	return root


static func apply_material(root: Node, key: String) -> void:
	if root is MeshInstance3D:
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = preload("res://features/vegetation/vegetation.gdshader")
		material.set_shader_parameter("atlas", ATLAS)
		material.set_shader_parameter("phase", float(key.hash() % 10000) * 0.01)
		root.material_override = material
	for child: Node in root.get_children():
		apply_material(child, key)
