class_name LandscapeSampleSurfaceModifier
extends "res://addons/proton_scatter/src/modifiers/base_modifier.gd"
## Projects plugin-generated candidates against the current authoritative surface.
## This avoids physics-cache latency while a Terrain3D region is being rebuilt.

var sample_surface: Callable
var root_offset_m: float = 0.0
var normal_alignment: float = 0.75
var max_slope_degrees: float = 55.0
var uniform_scale_min: float = 1.0


func _init() -> void:
	display_name = "Project On Current Landscape"
	category = "Edit"
	can_restrict_height = false


func _process_transforms(transforms: TransformList, domain: Domain, _seed: int) -> void:
	var projected: Array[Transform3D] = []
	var to_world: Transform3D = domain.get_global_transform()
	var to_local: Transform3D = to_world.affine_inverse()
	var minimum_up: float = cos(deg_to_rad(max_slope_degrees))
	for candidate: Transform3D in transforms.list:
		var world_position: Vector3 = to_world * candidate.origin
		var sample: Dictionary = sample_surface.call(Vector2(world_position.x, world_position.z))
		if not bool(sample.get("allowed", true)) or not sample.has("height"):
			continue
		var height: float = float(sample["height"])
		var normal: Vector3 = sample.get("normal", Vector3.UP)
		if not is_finite(height) or not normal.is_finite() or normal.is_zero_approx():
			continue
		normal = normal.normalized()
		if normal.y < minimum_up:
			continue
		var world_basis: Basis = to_world.basis * candidate.basis
		var aligned_up: Vector3 = Vector3.UP.slerp(normal, normal_alignment).normalized()
		var tilt: Basis = Basis(Quaternion(world_basis.y.normalized(), aligned_up))
		candidate.basis = to_local.basis * tilt * world_basis * uniform_scale_min
		world_position.y = height + root_offset_m
		candidate.origin = to_local * world_position
		projected.append(candidate)
	transforms.list = projected
