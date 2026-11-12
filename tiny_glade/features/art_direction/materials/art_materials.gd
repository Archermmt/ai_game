class_name ArtMaterials
extends RefCounted
## Original painted studies. A separate opt-in layer preserves historical fixtures.

const TEXTURE_ROOT: String = "res://assets/materials/art_pass_01/"
const WOODLAND_ROOT: String = "res://assets/materials/woodland_cabin/"


static func create(woodland: bool = false) -> Dictionary:
	var architecture: ShaderMaterial = _shader(
		preload("res://features/art_direction/materials/painted_architecture.gdshader")
	)
	var roof: ShaderMaterial = _shader(
		preload("res://features/art_direction/materials/painted_roof.gdshader")
	)
	var terrain: ShaderMaterial = _shader(
		preload("res://features/art_direction/materials/painted_meadow.gdshader")
	)
	terrain.set_shader_parameter(
		"grass_map", preload("res://assets/materials/woodland_ground/grass_wash.png")
	)
	terrain.set_shader_parameter(
		"soil_map", preload("res://assets/materials/woodland_ground/leaf_mould.png")
	)
	terrain.set_shader_parameter("snow_map", ProductionTerrainRenderer.SNOW_ALBEDO)
	var foliage: ShaderMaterial = _shader(
		(
			WoodlandNature.SHADER
			if woodland
			else preload("res://features/art_direction/materials/painted_foliage.gdshader")
		)
	)
	if not woodland:
		foliage.set_shader_parameter(
			"atlas", load("res://assets/nature/art_pass_01/painted_forest_atlas.png")
		)
	var water: ShaderMaterial = _shader(
		preload("res://features/art_direction/materials/painted_water.gdshader")
	)
	var joinery: ShaderMaterial = _shader(
		preload("res://features/art_direction/materials/cottage_joinery.gdshader")
	)
	var masonry: ShaderMaterial = joinery.duplicate() as ShaderMaterial
	masonry.set_shader_parameter("wood", false)
	var window: ShaderMaterial = _shader(
		preload("res://features/art_direction/materials/painted_window.gdshader")
	)
	return {
		"architecture": architecture,
		"joinery": joinery,
		"masonry": masonry,
		"smoke": _shader(preload("res://features/art_direction/materials/cottage_smoke.gdshader")),
		"roof": roof,
		"terrain": terrain,
		"foliage": foliage,
		"water": water,
		"wood":
		_opaque(
			WOODLAND_ROOT + "weathered_oak.png" if woodland else TEXTURE_ROOT + "honey_timber.png",
			0.94,
			0.65,
			false
		),
		"stone":
		_opaque(
			WOODLAND_ROOT + "fieldstone.png" if woodland else TEXTURE_ROOT + "moss_stone.png",
			0.97,
			0.5
		),
		"window": window
	}


static func sync_cottage_palette(materials: Dictionary, env: Dictionary) -> void:
	var selection: Dictionary = env.get("palette", {})
	var rose: bool = selection.get("plaster", GardenPalette.DEFAULTS["plaster"]) == "plaster_rose"
	var slate: bool = selection.get("roof", GardenPalette.DEFAULTS["roof"]) == "roof_smoke"
	materials["architecture"].set_shader_parameter(
		"plaster_tint", Color("bd8474") if rose else Color("d5bea0")
	)
	materials["roof"].set_shader_parameter(
		"roof_tint", Color("536675") if slate else Color("ab7159")
	)
	materials["roof"].set_shader_parameter("aged", env.get("aged", false))
	for pair: Array in [["joinery", "wood"], ["masonry", "stone"]]:
		var paint: ShaderMaterial = materials[pair[0]]
		paint.set_shader_parameter("tint", GardenPalette.tint(env, pair[1]))
		paint.set_shader_parameter("aged", env.get("aged", false))


static func _shader(shader: Shader) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	return material


static func _opaque(
	texture_path: String, roughness: float, scale_value: float, triplanar: bool = true
) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_texture = load(texture_path) as Texture2D
	material.roughness = roughness
	material.metallic_specular = 0.18
	material.uv1_triplanar = triplanar
	material.uv1_world_triplanar = triplanar
	material.uv1_scale = Vector3.ONE * scale_value
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material
