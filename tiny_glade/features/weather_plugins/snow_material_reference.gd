class_name SnowMaterialReference
extends Node3D
## Unmodified puchik material on reference shapes. This does not generate snow geometry.

const DIRECTORY: String = "res://addons/puchik_snow/"
const UPSTREAM_COMMIT: String = "515900a4aee952cdc4487bed98cc69758c899a32"
const SNOW_SHADER: Shader = preload("res://addons/puchik_snow/shaders/basic_snow.gdshader")

var material: ShaderMaterial
var samples: Array[MeshInstance3D] = []
var snow_cover: float = 0.9
var normal_strength: float = 0.65
var ready_for_preview: bool = false


func _ready() -> void:
	_build_reference()


func configure(cover: float = 0.9, powder_normal_strength: float = 0.65) -> void:
	snow_cover = clampf(cover, 0.0, 1.0)
	normal_strength = clampf(powder_normal_strength, 0.0, 2.0)
	_apply_parameters()


func set_snow_cover(value: float) -> void:
	configure(value, normal_strength)


func set_normal_strength(value: float) -> void:
	configure(snow_cover, value)


func reference_state() -> Dictionary:
	return {
		"ready": ready_for_preview,
		"upstream_commit": UPSTREAM_COMMIT,
		"shader_path": DIRECTORY + "shaders/basic_snow.gdshader",
		"shader_modified": false,
		"snow_cover": snow_cover,
		"normal_strength": normal_strength,
		"samples": samples.size(),
		"geometric_snow_thickness": false
	}


func _build_reference() -> void:
	if ready_for_preview:
		return
	material = ShaderMaterial.new()
	material.shader = SNOW_SHADER
	var textures: Dictionary = {
		"texture_albedo": "textures/rocks/rocks_ground_02_col_1k.jpg",
		"texture_normal": "textures/rocks/rocks_ground_02_nor_gl_1k.jpg",
		"texture_albedo_snow": "textures/snow/snow_02_diff_2k.jpg",
		"texture_normal_snow": "textures/snow/snow_02_nor_gl_1k.jpg"
	}
	for parameter: String in textures:
		var texture: Texture2D = load(DIRECTORY + str(textures[parameter])) as Texture2D
		if texture == null:
			push_error("缺少已固定版本的雪材质样本纹理：" + str(textures[parameter]))
			return
		material.set_shader_parameter(parameter, texture)
	material.set_shader_parameter("albedo", Color("a7a29b"))
	material.set_shader_parameter("albedo_snow", Color("f3f5f2"))
	material.set_shader_parameter("normal_scale", 0.7)
	material.set_shader_parameter("roughness", 0.93)
	material.set_shader_parameter("roughness_snow", 0.86)
	material.set_shader_parameter("specular", 0.25)
	material.set_shader_parameter("metallic", 0.0)
	material.set_shader_parameter("uv1_scale", Vector3(2.5, 2.5, 2.5))
	material.set_shader_parameter("uv1_offset", Vector3.ZERO)
	material.set_shader_parameter("uv2_scale", Vector3.ONE)
	material.set_shader_parameter("uv2_offset", Vector3.ZERO)
	_apply_parameters()
	var ground: PlaneMesh = PlaneMesh.new()
	ground.size = Vector2(5.8, 4.8)
	_add_sample(ground, "SnowGroundReference", Vector3.ZERO)
	var boulder: SphereMesh = SphereMesh.new()
	boulder.radius = 1.0
	boulder.height = 1.6
	boulder.radial_segments = 48
	boulder.rings = 24
	_add_sample(boulder, "SnowBoulderReference", Vector3(-1.4, 0.8, 0.0))
	var slope: BoxMesh = BoxMesh.new()
	slope.size = Vector3(2.5, 0.18, 2.7)
	var ramp: MeshInstance3D = _add_sample(slope, "SnowSlopeReference", Vector3(1.5, 0.68, -0.1))
	ramp.rotation_degrees = Vector3(-25, 15, 0)
	ready_for_preview = true


func _apply_parameters() -> void:
	if material == null:
		return
	# Use only the upstream public material parameters; leave its source byte-identical.
	material.set_shader_parameter("snow_threshold", lerpf(1.1, 0.3, snow_cover))
	material.set_shader_parameter("snow_blend_range", 0.08)
	material.set_shader_parameter("normal_scale_snow", normal_strength)


func _add_sample(mesh: PrimitiveMesh, node_name: String, point: Vector3) -> MeshInstance3D:
	var sample: MeshInstance3D = MeshInstance3D.new()
	sample.name = node_name
	sample.mesh = mesh
	sample.material_override = material
	sample.position = point
	add_child(sample)
	samples.append(sample)
	return sample
