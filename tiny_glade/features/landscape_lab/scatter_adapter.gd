class_name LandscapeScatterAdapter
extends RefCounted
## Uses ProtonScatter's public modifiers for deterministic candidate generation.
## Generated output is a disposable rendering cache, never WorldDocument state.

const ScatterNode := preload("res://addons/proton_scatter/src/scatter.gd")
const ScatterShape := preload("res://addons/proton_scatter/src/scatter_shape.gd")
const BoxShape := preload("res://addons/proton_scatter/src/shapes/box_shape.gd")
const TransformList := preload("res://addons/proton_scatter/src/common/transform_list.gd")
const CreateRandom := preload("res://addons/proton_scatter/src/modifiers/create_inside_random.gd")
const Randomize := preload("res://addons/proton_scatter/src/modifiers/randomize_transforms.gd")
const SurfaceProjection := preload("res://features/landscape_lab/sample_surface_modifier.gd")

var last_candidate_count: int = 0
var last_accepted_count: int = 0


## region uses world X/Z coordinates. The callable receives Vector2(world_x, world_z)
## and returns {height:float, normal:Vector3, allowed:bool}. Output is world space.
## options: scale_min, scale_max, normal_alignment, max_slope_degrees, root_offset_m.
func generate(
	parent: Node3D,
	region: Rect2,
	amount: int,
	scatter_seed: int,
	sample_surface: Callable,
	options: Dictionary = {}
) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	last_candidate_count = 0
	last_accepted_count = 0
	if not parent.is_inside_tree() or not sample_surface.is_valid() or amount <= 0:
		return result
	var scatter: ProtonScatter = ScatterNode.new()
	scatter.name = "LandscapeScatterGenerator"
	scatter.force_rebuild_on_load = false
	scatter.enable_updates_in_game = false
	scatter.global_seed = scatter_seed
	scatter.dbg_disable_thread = true
	# Only public modifiers are evaluated here; rendering is owned by the lab.
	var shape_node: ProtonScatterShape = ScatterShape.new()
	shape_node.name = "ScatterDomain"
	var box: ProtonScatterBoxShape = BoxShape.new()
	box.size = Vector3(region.size.x, 2.0, region.size.y)
	shape_node.shape = box
	shape_node.position = Vector3(region.get_center().x, 0.0, region.get_center().y)
	scatter.add_child(shape_node)
	parent.add_child(scatter)
	scatter.global_transform = Transform3D.IDENTITY
	scatter.domain.discover_shapes(scatter)
	var transforms: TransformList = TransformList.new()
	var create := CreateRandom.new()
	create.amount = amount
	create.restrict_height = true
	await create.process_transforms(transforms, scatter.domain, scatter_seed)
	last_candidate_count = transforms.size()
	var vary := Randomize.new()
	vary.rotation = Vector3(0.0, 180.0, 0.0)
	var minimum_scale: float = maxf(0.001, float(options.get("scale_min", 0.8)))
	var maximum_scale: float = maxf(minimum_scale, float(options.get("scale_max", 1.2)))
	vary.scale = Vector3.ONE * (maximum_scale / minimum_scale - 1.0)
	await vary.process_transforms(transforms, scatter.domain, scatter_seed + 7919)
	var projection: LandscapeSampleSurfaceModifier = SurfaceProjection.new()
	projection.sample_surface = sample_surface
	projection.root_offset_m = float(options.get("root_offset_m", 0.0))
	projection.normal_alignment = clampf(float(options.get("normal_alignment", 0.75)), 0.0, 1.0)
	projection.max_slope_degrees = float(options.get("max_slope_degrees", 55.0))
	projection.uniform_scale_min = minimum_scale
	await projection.process_transforms(transforms, scatter.domain, scatter_seed)
	result.assign(transforms.list)
	last_accepted_count = result.size()
	scatter.free()
	return result
