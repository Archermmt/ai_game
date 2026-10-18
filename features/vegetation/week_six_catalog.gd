class_name WeekSixCatalog
extends RefCounted

const TEA: PackedScene = preload("res://assets/week_06/tea_set.glb")
const LANTERN: PackedScene = preload("res://assets/week_06/lantern.glb")


static func create(asset_id: String, key: String, wood: Material, stone: Material) -> Node3D:
	var root: Node3D
	if VegetationCatalog.NAMES.has(asset_id):
		root = Node3D.new()
		for lod: int in range(2):
			var level: Node3D = VegetationCatalog.instantiate_asset(asset_id, key, lod)
			root.add_child(level)
			for node: Node in level.find_children("*", "MeshInstance3D", true, false):
				node.visibility_range_begin = 34.0 if lod == 1 else 0.0
				node.visibility_range_end = 0.0 if lod == 1 else 34.0
	elif asset_id == "NAT-07":
		# Compact end-capped hedge input for T039; T048 adds stretch/turn editing in W07.
		root = Node3D.new()
		for i: int in range(3):
			var shrub: Node3D = WeekFourCatalog.create("NAT-06", key + str(i), wood, stone)
			shrub.position.x = (float(i) - 1) * 0.35
			shrub.scale = Vector3(0.6, 0.75, 0.8)
			root.add_child(shrub)
	elif asset_id in ["PROP-07", "PROP-08"]:
		root = (TEA if asset_id == "PROP-07" else LANTERN).instantiate() as Node3D
		WeekFourCatalog._paint(root, key, wood, stone)
		for node: Node in root.find_children("*", "MeshInstance3D", true, false):
			if String(node.name).begins_with("metal"):
				var paint: StandardMaterial3D = StandardMaterial3D.new()
				paint.albedo_color = Color("4e6657")
				paint.roughness = 0.9
				node.material_override = paint
			if String(node.name).begins_with("lamp_emission"):
				var paint: StandardMaterial3D = StandardMaterial3D.new()
				paint.albedo_color = Color("766841")
				paint.emission_enabled = true
				paint.emission = Color("f2c878")
				paint.emission_energy_multiplier = 0
				node.material_override = paint
	elif WeekFiveCatalog.PACKS.has(asset_id):
		root = WeekFiveCatalog.create(asset_id, key, wood, stone)
	elif WeekFourCatalog.NAMES.has(asset_id):
		root = WeekFourCatalog.create(asset_id, key, wood, stone)
	else:
		var box: MeshInstance3D = MeshInstance3D.new()
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = Vector3(0.65, 0.8, 0.65)
		box.mesh = mesh
		box.material_override = wood
		root = box
	root.set_meta("object_id", key)
	root.set_meta("asset_id", asset_id)
	return root


static func wind_materials(root: Node) -> Array[ShaderMaterial]:
	var result: Array[ShaderMaterial] = []
	if (
		(root is MeshInstance3D or root is MultiMeshInstance3D)
		and root.material_override is ShaderMaterial
	):
		result.append(root.material_override)
	for child: Node in root.get_children():
		result.append_array(wind_materials(child))
	return result
