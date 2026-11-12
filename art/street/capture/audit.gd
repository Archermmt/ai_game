extends SceneTree
## Produce inventory from the meshes actually referenced by the main scene.
func _initialize() -> void:
	var street: Node = load("res://street/street.tscn").instantiate()
	root.add_child(street)
	var modules := {}
	var sources := {"Landscape":"street/layout/layout.gd", "Station":"street/railway/railway.gd",
		"Houses":"street/buildings/source/build_houses.py", "Orchard":"street/vegetation/vegetation.gd"}
	for module_name in sources:
		var module := street.get_node(NodePath(module_name))
		var total := 0
		var copies := 0
		var materials := {}
		var cache := {}
		for node in module.find_children("*", "", true, false):
			var mesh: Mesh
			var count := 1
			if node is MultiMeshInstance3D:
				mesh = node.multimesh.mesh
				count = node.multimesh.instance_count
			elif node is MeshInstance3D:
				mesh = node.mesh
			else:
				continue
			if not mesh:
				continue
			if not cache.has(mesh):
				cache[mesh] = mesh.get_faces().size() / 3
			for i in mesh.get_surface_count():
				var material: Material = node.material_override
				if not material and node is MeshInstance3D:
					material = node.get_active_material(i)
				if not material:
					material = mesh.surface_get_material(i)
				if material:
					materials[material.get_instance_id()] = true
			copies += count
			total += count * cache[mesh]
		modules[module_name] = {"source":sources[module_name], "scene_instances_of_meshes":copies, "triangles_including_instances":total, "distinct_bound_materials":materials.size()}
	var f := FileAccess.open("res://docs/street/asset_manifest.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(modules,"  ")+"\n")
	print(modules)
	street.free()
	quit()
