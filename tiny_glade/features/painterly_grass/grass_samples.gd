class_name PainterlyGrassSamples
extends RefCounted
## Local-only imported geometry. No world source or user preferences are accessed.

const ROOT: String = "res://assets/painterly_grass/local/"
const IDS: Array[String] = ["grass_card_a", "grass_card_b", "grass_floor"]
const PAINT_SHADER: Shader = preload("res://features/painterly_grass/grass_sample.gdshader")
const OLD_SHADER: Shader = preload("res://features/garden_presentation/meadow.gdshader")


static func paths() -> Array[String]:
	return [
		ROOT + "grass_card_a.glb",
		ROOT + "grass_card_b.glb",
		ROOT + "grass_floor.glb",
		ROOT + "grass_coverage.png"
	]


static func mesh_from(scene: PackedScene) -> Mesh:
	var source: Node = scene.instantiate()
	var found: Array[Node] = source.find_children("*", "MeshInstance3D", true, false)
	var mesh: Mesh = null
	if not found.is_empty():
		mesh = (found[0] as MeshInstance3D).mesh
	source.free()
	return mesh


static func material(texture: Texture2D) -> ShaderMaterial:
	var result: ShaderMaterial = ShaderMaterial.new()
	result.shader = PAINT_SHADER
	result.set_shader_parameter("coverage", texture)
	return result


static func batch(
	mesh: Mesh, paint: Material, kind: int, single: bool = false
) -> MultiMeshInstance3D:
	var view: MultiMeshInstance3D = MultiMeshInstance3D.new()
	view.name = "GrassSample"
	view.multimesh = MultiMesh.new()
	view.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	view.multimesh.use_custom_data = true
	view.multimesh.mesh = mesh
	var count: int = 1 if single else (64 if kind == 0 else (25 if kind == 3 else 49))
	view.multimesh.instance_count = count
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 251025 + kind
	for i: int in count:
		var angle: float = rng.randf_range(0, TAU)
		var radius: float = sqrt(rng.randf()) * 0.95
		var position: Vector3 = Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		var pose: Transform3D = Transform3D(Basis(Vector3.UP, rng.randf_range(0, TAU)), position)
		pose.basis = pose.basis.scaled(Vector3.ONE * rng.randf_range(0.85, 1.15))
		if single:
			pose = Transform3D.IDENTITY.scaled(Vector3.ONE * 1.7)
		view.multimesh.set_instance_transform(i, pose)
		view.multimesh.set_instance_custom_data(
			i, Color(rng.randf(), 0.08 if kind == 3 else 1.0, 0, 1)
		)
	view.material_override = paint
	view.extra_cull_margin = 0.25
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return view
