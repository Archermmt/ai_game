@tool
extends EditorScenePostImport

func _post_import(scene: Node) -> Object:
	for part in scene.find_children("*", "MeshInstance3D", true, false):
		for i in part.mesh.get_surface_count():
			var material := part.mesh.surface_get_material(i) as StandardMaterial3D
			if material:
				material.vertex_color_use_as_albedo = true
				material.vertex_color_is_srgb = false
				material.metallic_specular = 0.08
			if material and material.resource_name in ["stone","lumen"]:
				var stylized := ShaderMaterial.new()
				stylized.shader = preload("res://examples/lava/glowing_sap.gdshader") if material.resource_name == "lumen" else preload("res://examples/lava/strata.gdshader")
				part.mesh.surface_set_material(i, stylized)
	return scene
