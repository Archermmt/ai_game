@tool
extends EditorScenePostImport
## The painterly palette is stored in the glTF linear COLOR_0 vertex stream.

func _post_import(scene: Node) -> Object:
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = node.mesh
		for surface in mesh.get_surface_count():
			var material := mesh.surface_get_material(surface) as StandardMaterial3D
			if material != null:
				material.vertex_color_use_as_albedo = true
				material.vertex_color_is_srgb = false
				material.metallic_specular = 0.10
	return scene
