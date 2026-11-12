@tool
extends EditorScenePostImport

## The GLB uses CORNER vertex colours as its shared palette.
func _post_import(scene: Node) -> Object:
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = node.mesh
		if str(node.name).begins_with("01 "):
			var sand := ShaderMaterial.new()
			sand.shader = preload("res://examples/desert/sand.gdshader")
			mesh.surface_set_material(0, sand)
			continue
		for surface in mesh.get_surface_count():
			var material := mesh.surface_get_material(surface) as StandardMaterial3D
			if material:
				material.vertex_color_use_as_albedo = true
				material.vertex_color_is_srgb = false
				material.metallic_specular = 0.10
	return scene
