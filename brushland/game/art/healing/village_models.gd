extends RefCounted
## Independently placeable pieces of the supplied sunset cottage study.
const COTTAGE = preload("res://game/art/healing/models/cottage.glb")
const OAK = preload("res://game/art/healing/models/autumn_oak.glb")
const FOXGLOVES = preload("res://game/art/healing/models/foxgloves.glb")
const GROVE = preload("res://game/art/healing/models/grove_oak.glb")
const PAINT = preload("res://game/art/healing/paint.gdshader")
const CANOPY = preload("res://game/art/healing/canopy.gdshader")
const ROOF_TINTS = [Color("ce8865"), Color("78989d"), Color("a2a37b")]
const COAST_ROOF = Color("8ca2a2")
const TRIM = Color("977553")
static var pigments: Dictionary = {}
static var foliage_materials: Dictionary = {}
static var foliage_fill: float = 1.0

static func tree(parent: Node3D, pos: Vector3, seed_value: int, wild: bool = false, focal: bool = false) -> void:
	var oak: Node3D = OAK.instantiate() if focal else GROVE.instantiate()
	oak.position = pos
	oak.rotation.y = 0.06 if focal else posmod(seed_value, 11) * 0.41
	var size_factor = 0.60 + 0.055 * posmod(seed_value, 3) if wild else 0.96 + 0.02 * posmod(seed_value, 4)
	oak.scale = Vector3.ONE * size_factor
	parent.add_child(oak)
	oak.find_child("OakWood", true, false).material_override = paint(Color.WHITE)
	var leaves: MeshInstance3D = oak.find_child("AutumnLeaves", true, false)
	var tint = Color("d6ddad") if wild else Color.WHITE
	if not foliage_materials.has(tint):
		var material = ShaderMaterial.new()
		material.shader = CANOPY
		material.set_shader_parameter("leaf_tint", tint)
		material.set_shader_parameter("fill_strength", foliage_fill)
		foliage_materials[tint] = material
	leaves.material_override = foliage_materials[tint]
	leaves.add_to_group("island_leaf_nodes")

static func flowers(parent: Node3D, pos: Vector3, seed_value: int = 0) -> void:
	var plant: Node3D = FOXGLOVES.instantiate()
	plant.position = pos
	plant.rotation.y = posmod(seed_value, 8) * 0.80
	plant.scale = Vector3.ONE * (0.92 + posmod(seed_value, 4) * 0.08)
	parent.add_child(plant)
	plant.find_child("Foxgloves", true, false).material_override = paint(Color.WHITE)

static func cottage(kit, variant: String, color_index: int, tea: bool = false) -> Node3D:
	var root = Node3D.new()
	root.name = "TeaPavilion" if tea else "Cottage"
	var shell: Node3D = COTTAGE.instantiate()
	root.add_child(shell)
	var tiles: MeshInstance3D = shell.find_child("RoofTiles", true, false)
	var roof_color = ROOF_TINTS[posmod(color_index, ROOF_TINTS.size())]
	if variant == "coast" and color_index == 0:
		roof_color = COAST_ROOF
	tiles.material_override = paint(roof_color)
	shell.find_child("TimberAndPlaster", true, false).material_override = paint(Color.WHITE)
	if tea:
		shell.position.z = -0.34
		shell.scale = Vector3(0.88, 0.76, 0.71)
		canvas(kit, root, 0.02, 1.10, 0.76, Color("cfac74"))
		kit.table(root, Vector3(0.17, 0.0, 0.66))
		for x in [-0.40, 0.72]:
			kit.cylinder(root, Vector3(x, 0.17, 0.60), 0.13, 0.34, TRIM)
	elif variant == "coast":
		canvas(kit, root, 0.35, 1.05, 0.47, Color("a3b9b4"))
	elif variant == "garden":
		canvas(kit, root, 0.40, 1.12, 0.60, Color("c88e93"))
		for x in [-0.61, 0.44]:
			var z = 0.72 if x < 0.0 else 0.29
			kit.box(root, Vector3(x, 0.54, z), Vector3(0.42, 0.13, 0.16), TRIM)
			for j in range(2):
				var sprig = Node3D.new()
				sprig.scale = Vector3.ONE * 0.65
				sprig.position = Vector3(x - 0.1 + j * 0.20, 0.60, z)
				root.add_child(sprig)
				flowers(sprig, Vector3.ZERO, j)
	return root

static func canvas(kit, parent: Node3D, center_x: float, height: float, front: float, stripe: Color) -> void:
	# A shallow striped awning leaves the doorway and resident route visible.
	var fabric_width = 1.54 if parent.name == "TeaPavilion" else 0.92
	for i in range(7):
		var x = center_x + (i - 3) * fabric_width / 7.0
		var shade = Color("efe1bc") if i % 2 == 0 else stripe
		var fabric = kit.box(parent, Vector3(x, height, front - 0.13),
				Vector3(fabric_width / 7.0, 0.038, 0.55), shade)
		fabric.rotation.x = 0.19
		kit.box(parent, Vector3(x, height - 0.105, front + 0.133),
				Vector3(fabric_width / 7.0, 0.105, 0.038), shade)
	for side in [-1, 1]:
		kit.beam(parent, Vector3(center_x + side * fabric_width * 0.47, 0.02, front + 0.13),
				Vector3(center_x + side * fabric_width * 0.47, height - 0.05, front + 0.13), 0.043, TRIM)

static func paint(color: Color) -> ShaderMaterial:
	if not pigments.has(color):
		var mat = ShaderMaterial.new()
		mat.shader = PAINT
		mat.set_shader_parameter("pigment_tint", color)
		mat.set_meta("static_batch_safe", true)
		pigments[color] = mat
	return pigments[color]

static func set_dusk(dusk: bool) -> void:
	foliage_fill = 0.57 if dusk else 1.0
	for mat in foliage_materials.values():
		mat.set_shader_parameter("fill_strength", foliage_fill)
