extends GutTest
## Integration boundary: upstream seeded candidates -> current surface -> cache.

const ADAPTER := preload("res://features/landscape_lab/scatter_adapter.gd")
const REGION := Rect2(-8.0, -6.0, 16.0, 12.0)
var host: Node3D


func before_each() -> void:
	host = Node3D.new()
	add_child(host)


func after_each() -> void:
	host.free()


func test_upstream_seed_repeats_and_new_seed_changes_candidates() -> void:
	var adapter: LandscapeScatterAdapter = ADAPTER.new()
	var first: Array[Transform3D] = await adapter.generate(host, REGION, 64, 1701, _surface)
	var repeated: Array[Transform3D] = await adapter.generate(host, REGION, 64, 1701, _surface)
	var changed: Array[Transform3D] = await adapter.generate(host, REGION, 64, 1702, _surface)
	assert_eq(first.size(), 64, "Real plugin candidates must exist")
	assert_eq(first, repeated, "Seed and settings must reproduce the entire cache")
	assert_ne(first, changed)
	assert_eq(adapter.last_candidate_count, 64)
	assert_eq(adapter.last_accepted_count, 64)
	assert_eq(host.get_child_count(), 0, "Disposable plugin generator must be released")


func test_current_surface_and_root_offset_are_preserved() -> void:
	var adapter: LandscapeScatterAdapter = ADAPTER.new()
	var poses: Array[Transform3D] = await adapter.generate(
		host, REGION, 32, 2501, _surface, {"root_offset_m": -0.12, "normal_alignment": 1.0}
	)
	var normal: Vector3 = Vector3(-0.2, 1.0, 0.1).normalized()
	for pose: Transform3D in poses:
		var ground: float = _surface(Vector2(pose.origin.x, pose.origin.z))["height"]
		assert_almost_eq(pose.origin.y, ground - 0.12, 0.00001)
		assert_gt(pose.basis.y.normalized().dot(normal), 0.9999)
		assert_between(pose.basis.get_scale().x, 0.7999, 1.2001)


func test_protected_roots_and_steep_slopes_are_rejected() -> void:
	var adapter: LandscapeScatterAdapter = ADAPTER.new()
	var poses: Array[Transform3D] = await adapter.generate(host, REGION, 64, 3101, _blocked)
	assert_gt(poses.size(), 0)
	assert_lt(poses.size(), 64)
	for pose: Transform3D in poses:
		assert_lt(pose.origin.x, 0.0)
	var steep: Array[Transform3D] = await adapter.generate(host, REGION, 64, 3101, _steep)
	assert_eq(steep.size(), 0)
	assert_eq(host.get_child_count(), 0)


func test_world_space_output_is_independent_of_render_parent_pose() -> void:
	var adapter: LandscapeScatterAdapter = ADAPTER.new()
	var identity: Array[Transform3D] = await adapter.generate(host, REGION, 32, 4001, _surface)
	host.transform = Transform3D(Basis(Vector3.UP, 0.7), Vector3(9.0, 3.0, -7.0))
	var moved: Array[Transform3D] = await adapter.generate(host, REGION, 32, 4001, _surface)
	assert_eq(identity.size(), moved.size())
	for index: int in identity.size():
		assert_true(identity[index].is_equal_approx(moved[index]))
	assert_eq(host.get_child_count(), 0)


func _surface(point: Vector2) -> Dictionary:
	return {
		"height": 0.2 * point.x - 0.1 * point.y,
		"normal": Vector3(-0.2, 1.0, 0.1).normalized(),
		"allowed": true
	}


func _blocked(point: Vector2) -> Dictionary:
	var result: Dictionary = _surface(point)
	result["allowed"] = point.x < 0.0
	return result


func _steep(point: Vector2) -> Dictionary:
	return {"height": point.x, "normal": Vector3.RIGHT, "allowed": true}
