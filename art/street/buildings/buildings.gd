@tool
extends Node3D
## Apply the same stylized surfaces to the imported house meshes in the editor and game.

const PLASTER_SHADER := preload("res://street/buildings/house_surface.gdshader")

var surface_materials: Dictionary = {}


func _ready() -> void:
	_apply_surface_colors(self)


func _apply_surface_colors(house: Node3D) -> void:
	for node in house.find_children("*", "MeshInstance3D", true, false):
		var part := node as MeshInstance3D
		for i in part.mesh.get_surface_count():
			var original := part.mesh.surface_get_material(i) as StandardMaterial3D
			if original == null:
				continue
			if not surface_materials.has(original):
				var material := ShaderMaterial.new()
				material.shader = PLASTER_SHADER
				material.set_shader_parameter("swatch", original.albedo_color)
				if original.resource_name.ends_with("_roof_color"):
					material.set_shader_parameter("roof_half_span", part.mesh.get_aabb().end.z)
				surface_materials[original] = material
			part.set_surface_override_material(i, surface_materials[original])
