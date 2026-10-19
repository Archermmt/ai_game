class_name GardenPalette
extends RefCounted
## Frozen UI-04 IDs. Tint choices reuse existing materials and original painted textures.

const CARDS: Array[Dictionary] = [
	{
		"id": "plaster_cream",
		"group": "plaster",
		"label": "奶油灰泥",
		"tint": "ffffff",
		"texture": "plaster"
	},
	{
		"id": "plaster_rose",
		"group": "plaster",
		"label": "暖粉灰泥",
		"tint": "edc7b4",
		"texture": "plaster"
	},
	{"id": "wood_honey", "group": "wood", "label": "蜂蜜木", "tint": "ffffff", "texture": "wood"},
	{"id": "wood_walnut", "group": "wood", "label": "胡桃木", "tint": "aa8060", "texture": "wood"},
	{"id": "wood_sage", "group": "wood", "label": "鼠尾草木", "tint": "b5c5aa", "texture": "wood"},
	{
		"id": "roof_terracotta",
		"group": "roof",
		"label": "赤陶瓦",
		"tint": "ffffff",
		"texture": "terracotta"
	},
	{
		"id": "roof_smoke",
		"group": "roof",
		"label": "烟灰瓦",
		"tint": "9eaba7",
		"texture": "terracotta"
	},
	{"id": "stone_grey", "group": "stone", "label": "暖灰石", "tint": "ffffff", "texture": "stone"},
	{"id": "stone_moss", "group": "stone", "label": "苔青石", "tint": "b7c5a4", "texture": "stone"},
	{"id": "stone_sand", "group": "stone", "label": "浅砂石", "tint": "dfc89f", "texture": "stone"},
	{
		"id": "foliage_spring",
		"group": "foliage",
		"label": "春叶",
		"tint": "ffffff",
		"texture": "vegetation_atlas"
	},
	{
		"id": "foliage_deep",
		"group": "foliage",
		"label": "深林",
		"tint": "a3b79a",
		"texture": "vegetation_atlas"
	}
]
const DEFAULTS: Dictionary = {
	"plaster": "plaster_cream",
	"wood": "wood_honey",
	"roof": "roof_terracotta",
	"stone": "stone_grey",
	"foliage": "foliage_spring"
}


static func valid(selection: Variant) -> bool:
	if not selection is Dictionary:
		return false
	for group: String in selection:
		var found: bool = false
		for card: Dictionary in CARDS:
			found = found or (card["group"] == group and card["id"] == selection[group])
		if not found:
			return false
	return true


static func tint(environment: Dictionary, group: String) -> Color:
	var id_value: String = environment.get("palette", {}).get(group, DEFAULTS[group])
	for card: Dictionary in CARDS:
		if card["id"] == id_value:
			return Color(card["tint"])
	return Color.WHITE


static func apply(root: Node3D, snapshot: Dictionary, update_foliage: bool = true) -> void:
	var env: Dictionary = snapshot["environment"]
	root.architecture_material.set_shader_parameter("plaster_tint", tint(env, "plaster"))
	root.architecture_material.set_shader_parameter("roof_tint", tint(env, "roof"))
	root.wood_material.albedo_color *= tint(env, "wood")
	root.stone_material.albedo_color *= tint(env, "stone")
	if not update_foliage:
		return
	for paint: ShaderMaterial in root.wind_materials:
		if paint.shader == preload("res://features/vegetation/vegetation.gdshader"):
			paint.set_shader_parameter("foliage_tint", tint(env, "foliage"))
