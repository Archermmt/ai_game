extends GutTest


func _spec(shape: String = "rect", kind: String = "arch") -> Dictionary:
	var draft: Dictionary = WorldDocument.new().snapshot()
	var result: Dictionary = WorldDocument.allocate_building(
		draft, Vector3.ZERO, Vector3(4, 3, 4), shape
	)
	result["openings"] = [
		{
			"kind": kind,
			"center": 0.25 if shape == "round" else 0.5,
			"width": 1.1,
			"height": 1.0 if kind == "round" else 2.0,
			"sill": 0.8 if kind == "round" else 0.0,
		}
	]
	return result


func test_real_holes_in_flat_and_curved_walls_for_all_profiles() -> void:
	for shape: String in ["rect", "round"]:
		for kind: String in ["rect", "arch", "round"]:
			var mesh: ArrayMesh = BuildingGeometry.build(_spec(shape, kind))
			var normal: Vector3 = Vector3.RIGHT if shape == "round" else Vector3.BACK
			var center: Vector3 = normal * 2.0 + Vector3.UP * 1.3
			var distance: float = _nearest(mesh, center + normal * 4.0, -normal)
			assert_gt(distance, 4.25, "%s / %s must not fill the opening" % [shape, kind])


func test_solid_wall_next_to_hole_still_exists() -> void:
	var mesh: ArrayMesh = BuildingGeometry.build(_spec())
	assert_almost_eq(_nearest(mesh, Vector3(1.6, 1, 6), Vector3.FORWARD), 4.0, 0.02)


func test_opening_profiles_keep_standard_dimensions_and_sills() -> void:
	var arch: Dictionary = _spec()["openings"][0]
	assert_almost_eq(BuildingGeometry.opening_interval(arch, 2.0, 4.0).y, 2.0, 0.001)
	assert_eq(BuildingGeometry.opening_interval(arch, 0.1, 4.0), Vector2(-1, -1))
	var circle: Dictionary = _spec("rect", "round")["openings"][0]
	var bounds: Vector2 = BuildingGeometry.opening_interval(circle, 2.0, 4.0)
	assert_almost_eq(bounds.x, 0.8, 0.001)
	assert_almost_eq(bounds.y, 1.8, 0.001)


func test_mesh_has_finite_normals_and_clockwise_triangles() -> void:
	var mesh: ArrayMesh = BuildingGeometry.build(_spec("round"))
	var arrays: Array = mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	assert_gt(points.size(), 100)
	assert_eq(points.size() % 3, 0)
	assert_eq(normals.size(), points.size())
	var valid: bool = true
	for index: int in range(0, points.size(), 3):
		var cross: Vector3 = (points[index + 1] - points[index]).cross(
			points[index + 2] - points[index]
		)
		valid = valid and cross.dot(normals[index]) <= 0.0001 and points[index].is_finite()
	assert_true(valid, "all surface triangles have consistent front-face winding")


func test_minimum_and_maximum_size_profiles_generate_bounded_meshes() -> void:
	for width: float in [3.0, 12.0]:
		for shape: String in ["rect", "round"]:
			var spec: Dictionary = _spec(shape)
			spec["size"] = [width, 7.2, width]
			var mesh: ArrayMesh = BuildingGeometry.build(spec)
			assert_lt(mesh.surface_get_array_len(0), 50000)
			assert_almost_eq(mesh.get_aabb().size.x, width + 0.7, 0.05)


func _nearest(mesh: ArrayMesh, origin: Vector3, direction: Vector3) -> float:
	var points: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var distance: float = INF
	for index: int in range(0, points.size(), 3):
		var hit: Variant = Geometry3D.ray_intersects_triangle(
			origin, direction, points[index], points[index + 1], points[index + 2]
		)
		if hit is Vector3:
			distance = minf(distance, origin.distance_to(hit))
	return distance
