class_name ArtViewPlan
extends ViewPlan
## Only presentation changes; publication, caching and source identity stay inherited.


func prepare(data: Dictionary, stage: ResourceStage = null) -> Dictionary:
	if data.get("ok", false) and data.has("art_path_arrays"):
		data["path_arrays"] = data["art_path_arrays"]
	return super.prepare(data, stage)


func _foliage(items: Array, poses: Dictionary) -> Node3D:
	var asset: String = items[0]["asset_id"]
	if not ArtFoliageCatalog.supports(asset):
		return super._foliage(items, poses)
	if not foliage_parts.has(asset):
		foliage_parts[asset] = describe(asset, owner_root.wood_material, owner_root.stone_material)
	return build_batch(
		items, poses, owner_root.wood_material, owner_root.stone_material, foliage_parts[asset]
	)


static func describe(asset: String, wood: Material, stone: Material) -> Array[Dictionary]:
	var prototype: Node3D = ArtFoliageCatalog.create(asset, "art_batch", wood, stone)
	var result: Array[Dictionary] = []
	var shared: Dictionary = {}
	for node: Node in prototype.find_children("*", "MeshInstance3D", true, false):
		var transform_value: Transform3D = Transform3D.IDENTITY
		var cursor: Node3D = node
		while cursor != prototype:
			transform_value = cursor.transform * transform_value
			cursor = cursor.get_parent() as Node3D
		var material: Material = node.material_override
		if material is ShaderMaterial:
			var id_value: int = material.get_instance_id()
			if not shared.has(id_value):
				var paint: ShaderMaterial = material.duplicate()
				paint.set_shader_parameter("batched", true)
				shared[id_value] = paint
			material = shared[id_value]
		result.append(
			{
				"mesh": node.mesh,
				"material": material,
				"transform": transform_value,
				"begin": node.visibility_range_begin,
				"end": node.visibility_range_end
			}
		)
	prototype.free()
	return result


static func build_batch(
	items: Array, poses: Dictionary, wood: Material, stone: Material, parts: Array[Dictionary]
) -> Node3D:
	var root: Node3D = FoliageBatches.build(items, poses, wood, stone, parts)
	var envelope: AABB
	var first: bool = true
	for part: Dictionary in parts:
		var part_bounds: AABB = part["transform"] * part["mesh"].get_aabb()
		envelope = part_bounds if first else envelope.merge(part_bounds)
		first = false
	var bounds: AABB
	first = true
	for item: Dictionary in items:
		var pose: Transform3D = poses[item["id"]]
		pose.origin -= root.position
		var instance_bounds: AABB = pose * envelope
		bounds = instance_bounds if first else bounds.merge(instance_bounds)
		first = false
	for view: MultiMeshInstance3D in root.get_children():
		view.custom_aabb = bounds.grow(0.5)
	return root
