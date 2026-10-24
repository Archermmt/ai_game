class_name ArtMaterials
extends RefCounted
## Original painted studies. A separate opt-in layer preserves historical fixtures.

const TEXTURE_ROOT: String = "res://assets/materials/art_pass_01/"


static func create() -> Dictionary:
	var architecture: ShaderMaterial = _shader(
		preload("res://features/art_direction/materials/painted_architecture.gdshader")
	)
	architecture.set_shader_parameter("plaster_map", load(TEXTURE_ROOT + "plaster.png"))
	architecture.set_shader_parameter("tile_map", load(TEXTURE_ROOT + "terracotta.png"))
	var roof: ShaderMaterial = _shader(
		preload("res://features/art_direction/materials/painted_roof.gdshader")
	)
	roof.set_shader_parameter("tile_map", load(TEXTURE_ROOT + "terracotta.png"))
	var terrain: ShaderMaterial = _shader(
		preload("res://features/art_direction/materials/painted_meadow.gdshader")
	)
	terrain.set_shader_parameter("grass_map", load(TEXTURE_ROOT + "meadow.png"))
	terrain.set_shader_parameter("meadow_macro", load(TEXTURE_ROOT + "meadow_macro.png"))
	terrain.set_shader_parameter("soil_map", load(TEXTURE_ROOT + "warm_soil.png"))
	terrain.set_shader_parameter("wet_map", load(TEXTURE_ROOT + "wet_bank.png"))
	var foliage: ShaderMaterial = _shader(
		preload("res://features/art_direction/materials/painted_foliage.gdshader")
	)
	foliage.set_shader_parameter(
		"atlas", load("res://assets/nature/art_pass_01/painted_forest_atlas.png")
	)
	var water: ShaderMaterial = _shader(
		preload("res://features/art_direction/materials/painted_water.gdshader")
	)
	var window: ShaderMaterial = _shader(
		preload("res://features/art_direction/materials/painted_window.gdshader")
	)
	window.set_shader_parameter("light_mask", load(TEXTURE_ROOT + "window_glow.png"))
	return {
		"architecture": architecture,
		"roof": roof,
		"terrain": terrain,
		"foliage": foliage,
		"water": water,
		"wood": _opaque("honey_timber", 0.94, 0.65, false),
		"stone": _opaque("moss_stone", 0.97, 0.5),
		"window": window
	}


static func _shader(shader: Shader) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	return material


static func _opaque(
	texture_name: String, roughness: float, scale_value: float, triplanar: bool = true
) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_texture = load(TEXTURE_ROOT + texture_name + ".png") as Texture2D
	material.roughness = roughness
	material.metallic_specular = 0.18
	material.uv1_triplanar = triplanar
	material.uv1_world_triplanar = triplanar
	material.uv1_scale = Vector3.ONE * scale_value
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material
