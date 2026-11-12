@tool
extends Node3D

const LEAF_LIGHT := preload("res://examples/cabin/leaf_light.gdshader")
const COTTAGE_PARTS := [&"TimberHouse", &"SlateCourses", &"WindowDeckAndChimney",
	&"MasonryFlue", &"DormerWindows", &"WestDeck", &"Doorstone"]

func _ready() -> void:
	var forest := ShaderMaterial.new()
	forest.shader = LEAF_LIGHT
	var foreground := forest.duplicate() as ShaderMaterial
	foreground.set_shader_parameter("transmission",0.25)
	foreground.set_shader_parameter("pigment_energy",0.90)
	foreground.set_shader_parameter("pigment_tint",Vector3(.87,.85,.76))
	var west := foreground.duplicate() as ShaderMaterial
	west.set_shader_parameter("pigment_tint",Vector3(1.02,1.20,.87))
	var spruce := forest.duplicate() as ShaderMaterial
	spruce.set_shader_parameter("pigment_tint",Vector3(.82,.73,.68))
	for element in find_children("*Canopy", "MeshInstance3D", true, false):
		var canopy := element as MeshInstance3D
		canopy.material_override = forest
		if canopy.name.begins_with("Near"):
			canopy.material_override = west if canopy.position.x < 0.0 else foreground
		elif canopy.name.begins_with("Spruce"):
			canopy.material_override = spruce
	var pond_branch := find_child("PoolEdgeFoliage",true,false) as MeshInstance3D
	if pond_branch:
		pond_branch.material_override = foreground
	# Retain both boot silhouettes in the shadow map at the wide art camera.
	for person in ["Wanderer","Herbalist"]:
		var figure := find_child(person,true,false) as MeshInstance3D
		if figure:
			figure.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
			figure.lod_bias = 64.0
	var floor_mesh := find_child("SunlitForestFloor",true,false) as MeshInstance3D
	if floor_mesh:
		floor_mesh.lod_bias = 64.0
	for part_name in COTTAGE_PARTS:
		var part := find_child(String(part_name),true,false) as MeshInstance3D
		if part:
			part.set_layer_mask_value(2,true)
