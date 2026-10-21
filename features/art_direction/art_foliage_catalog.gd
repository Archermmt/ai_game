class_name ArtFoliageCatalog
extends RefCounted
## Art-pass P0 visuals. Source IDs, transforms and transactions remain the caller's.
## One painted atlas contains foliage, flowers, bark, fruit, stone and moss.

const ATLAS: Texture2D = preload("res://assets/nature/art_pass_01/painted_forest_atlas.png")
const PACKS: Dictionary = {
	"NAT-01": preload("res://assets/nature/art_pass_01/tree_broadleaf.glb"),
	"NAT-02": preload("res://assets/nature/art_pass_01/tree_conifer.glb"),
	"NAT-03": preload("res://assets/nature/art_pass_01/tree_fruit.glb"),
	"NAT-04": preload("res://assets/nature/art_pass_01/fern.glb"),
	"NAT-05": preload("res://assets/nature/art_pass_01/wildflower.glb"),
	"NAT-06": preload("res://assets/nature/art_pass_01/shrub.glb"),
	"NAT-08": preload("res://assets/nature/art_pass_01/moss_rock.glb"),
	"NAT-09": preload("res://assets/nature/art_pass_01/flat_rock.glb"),
}
const LODS: Dictionary = {
	"NAT-01": preload("res://assets/nature/art_pass_01/tree_broadleaf_lod1.glb"),
	"NAT-02": preload("res://assets/nature/art_pass_01/tree_conifer_lod1.glb"),
	"NAT-03": preload("res://assets/nature/art_pass_01/tree_fruit_lod1.glb"),
}

static var _shader: Shader = preload("res://features/vegetation/vegetation.gdshader")


static func configure(shader: Shader) -> void:
	_shader = shader


static func supports(asset_id: String) -> bool:
	return PACKS.has(asset_id) or asset_id == "NAT-07"


static func create(asset_id: String, key: String, _wood: Material, _stone: Material) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "PaintedNature"
	root.set_meta("object_id", key)
	root.set_meta("asset_id", asset_id)
	if asset_id == "NAT-07":
		# A hedge remains an arrangement of NAT-06; it has no new source family.
		for index: int in range(3):
			var shrub: Node3D = create("NAT-06", "%s:%d" % [key, index], _wood, _stone)
			shrub.position.x = (float(index) - 1.0) * 0.38
			shrub.scale = Vector3(0.68, 0.80, 0.80)
			root.add_child(shrub)
		_align_lod_bounds(root)
		return root
	if not PACKS.has(asset_id):
		return root
	var paint: ShaderMaterial = ShaderMaterial.new()
	paint.shader = _shader
	paint.set_shader_parameter("atlas", ATLAS)
	paint.set_shader_parameter("phase", float(posmod(key.hash(), 10000)) * 0.01)
	paint.set_shader_parameter("amplitude", 0.13 if LODS.has(asset_id) else 0.065)
	# Variation is deliberately subtle; hue comes from the painted atlas itself.
	var tint: float = 0.97 + float(posmod(key.hash(), 7)) * 0.005
	paint.set_shader_parameter("foliage_tint", Color(tint, tint, tint, 1.0))
	var high: Node3D = (PACKS[asset_id] as PackedScene).instantiate() as Node3D
	root.add_child(high)
	_paint(high, paint, 0.0, 37.0 if LODS.has(asset_id) else 0.0)
	if LODS.has(asset_id):
		var low: Node3D = (LODS[asset_id] as PackedScene).instantiate() as Node3D
		root.add_child(low)
		_paint(low, paint, 37.0, 0.0)
	_align_lod_bounds(root)
	return root


static func _paint(root: Node, paint: ShaderMaterial, begin: float, end: float) -> void:
	if root is MeshInstance3D:
		var mesh: MeshInstance3D = root as MeshInstance3D
		mesh.material_override = paint
		mesh.visibility_range_begin = begin
		mesh.visibility_range_end = end
		mesh.extra_cull_margin = 0.35
	for child: Node in root.get_children():
		_paint(child, paint, begin, end)


static func _align_lod_bounds(root: Node3D) -> void:
	var transforms: Dictionary = {}
	var bounds: AABB
	var first: bool = true
	for node: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var relative: Transform3D = Transform3D.IDENTITY
		var cursor: Node3D = node
		while cursor != root:
			relative = cursor.transform * relative
			cursor = cursor.get_parent() as Node3D
		transforms[node] = relative
		var part_bounds: AABB = relative * node.mesh.get_aabb()
		bounds = part_bounds if first else bounds.merge(part_bounds)
		first = false
	# Godot measures each GeometryInstance's visibility range from its AABB centre.
	# A common tree envelope switches trunk, inner crown and leaves together.
	root.set_meta("pick_bounds", bounds)
	for node: MeshInstance3D in transforms:
		node.custom_aabb = transforms[node].affine_inverse() * bounds.grow(0.35)
