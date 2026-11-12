@tool
extends Node3D

@export var reflected := false
const MIRROR = preload("res://examples/island/reflection.gdshader")
const LEAVES = preload("res://examples/island/leaves.gdshader")
const PAINT = preload("res://examples/island/paint.gdshader")
const SMOKE = preload("res://examples/island/smoke.gdshader")

func _ready() -> void:
	var leaves_mat := ShaderMaterial.new()
	leaves_mat.shader = LEAVES
	var paint_mat := ShaderMaterial.new()
	paint_mat.shader = PAINT
	var bank_mat := paint_mat.duplicate()
	bank_mat.set_shader_parameter("shoreline", true)
	var reflected_mat := ShaderMaterial.new()
	reflected_mat.shader = MIRROR
	var reflected_leaves := reflected_mat.duplicate()
	reflected_leaves.set_shader_parameter("tree_reflection", true)
	reflected_leaves.set_shader_parameter("canopy", true)
	var reflected_wood := reflected_mat.duplicate()
	reflected_wood.set_shader_parameter("tree_reflection", true)
	var smoke_mat := ShaderMaterial.new()
	smoke_mat.shader = SMOKE
	smoke_mat.render_priority = 4
	if reflected:
		smoke_mat.set_shader_parameter("mirrored", true)
		smoke_mat.set_shader_parameter("opacity", 0.26)
	for child in find_children("*", "MeshInstance3D", true, false):
		var part := child as MeshInstance3D
		if reflected:
			part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			part.material_override = reflected_leaves if part.name == "AutumnOak" else reflected_mat
			if part.name == "OakWood":
				part.material_override = reflected_wood
			if part.name == "ChimneySmoke":
				part.material_override = smoke_mat
			elif part.name == "LilyPads":
				part.hide()
		elif part.name == "ChimneySmoke":
			part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			part.material_override = smoke_mat
		elif part.name == "AutumnOak":
			part.material_override = leaves_mat
		elif part.name == "TurfAndEarth":
			part.material_override = bank_mat
		else:
			part.material_override = paint_mat
