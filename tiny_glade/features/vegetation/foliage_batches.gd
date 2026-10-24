class_name FoliageBatches
extends RefCounted
## Spatial batches keep source IDs; only unselected automatic foliage is batched.


static func groups(snapshot: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for item: Dictionary in snapshot["instances"]:
		if (
			item.has("hedge")
			or item["source"] != "brush"
			or item["locked"]
			or not String(item["asset_id"]).begins_with("NAT")
		):
			continue
		var p: Array = item["position"]
		var key: String = "%s:%d:%d" % [item["asset_id"], floori(p[0] / 8), floori(p[2] / 8)]
		if not result.has(key):
			result[key] = []
		result[key].append(item)
	return result


static func build(
	items: Array, poses: Dictionary, wood: Material, stone: Material, parts: Array[Dictionary] = []
) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "FoliageCell"
	var location: Array = items[0]["position"]
	root.position = Vector3(floorf(location[0] / 8) * 8 + 4, 0, floorf(location[2] / 8) * 8 + 4)
	if parts.is_empty():
		parts = describe(items[0]["asset_id"], wood, stone)
	for part: Dictionary in parts:
		var transform_value: Transform3D = part["transform"]
		var view: MultiMeshInstance3D = MultiMeshInstance3D.new()
		view.multimesh = MultiMesh.new()
		view.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		view.multimesh.use_custom_data = true
		view.multimesh.mesh = part["mesh"]
		view.multimesh.instance_count = items.size()
		for i: int in range(items.size()):
			var item: Dictionary = items[i]
			var pose: Transform3D = poses[item["id"]]
			pose.origin -= root.position
			view.multimesh.set_instance_transform(i, pose * transform_value)
			view.multimesh.set_instance_custom_data(
				i, Color(float(item["seed"].hash() % 10000) / 10000, 0, 0, 1)
			)
		view.material_override = part["material"]
		view.visibility_range_begin = part["begin"]
		view.visibility_range_end = part["end"]
		view.extra_cull_margin = 0.5
		root.add_child(view)
	root.set_meta("ids", items.map(func(item: Dictionary) -> String: return item["id"]))
	return root


static func describe(asset_id: String, wood: Material, stone: Material) -> Array[Dictionary]:
	var parts: Array[Dictionary] = []
	var batched_materials: Dictionary = {}
	var prototype: Node3D = WeekSixCatalog.create(asset_id, "batch", wood, stone)
	for part: Node in prototype.find_children("*", "MeshInstance3D", true, false):
		var transform_value: Transform3D = Transform3D.IDENTITY
		var cursor: Node3D = part
		while cursor != prototype:
			transform_value = cursor.transform * transform_value
			cursor = cursor.get_parent() as Node3D
		var material: Material = part.material_override
		if material is ShaderMaterial:
			var parameters: Array = []
			for property: Dictionary in material.get_property_list():
				if String(property["name"]).begins_with("shader_parameter/"):
					parameters.append([property["name"], material.get(property["name"])])
			var signature: int = hash([material.shader, parameters])
			if not batched_materials.has(signature):
				var shared: ShaderMaterial = material.duplicate(true)
				shared.set_shader_parameter("batched", true)
				batched_materials[signature] = shared
			material = batched_materials[signature]
		parts.append(
			{
				"mesh": part.mesh,
				"material": material,
				"transform": transform_value,
				"begin": part.visibility_range_begin,
				"end": part.visibility_range_end
			}
		)
	prototype.free()
	return parts
