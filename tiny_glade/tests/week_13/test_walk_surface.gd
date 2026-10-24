extends GutTest
## Pure source-derived walking regressions; no generated scene or physics required.


func _surface(source: Dictionary) -> WalkSurface:
	var result: WalkSurface = WalkSurface.new()
	result.configure(source)
	return result


func _point(record: Dictionary, key: String) -> Vector2:
	return Vector2(record[key][0], record[key][1])


func _foot(surface: WalkSurface, point: Vector2) -> Vector3:
	var height: Variant = surface.ground_at(point)
	assert_not_null(height, "Expected safe support at %s" % point)
	return Vector3(point.x, float(height) if height != null else 0.0, point.y)


func _assert_crossing(surface: WalkSurface, a: Vector2, b: Vector2) -> void:
	for i: int in range(33):
		assert_true(surface.can_stand(a.lerp(b, float(i) / 32)), "Blocked centerline sample %d" % i)
	var from: Vector3 = _foot(surface, a)
	var finish: Vector3 = surface.move_grounded(from, b - a)
	assert_lt(Vector2(finish.x, finish.z).distance_to(b), 0.005, "Cross entire walking surface")
	var back: Vector3 = surface.move_grounded(finish, a - b)
	assert_lt(Vector2(back.x, back.z).distance_to(a), 0.005, "Cross in reverse as well")


func _mesh_top(arrays: Array, point: Vector2) -> Variant:
	# Independently query upward mesh triangles, rather than repeat tread/ramp formulas.
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var height: Variant = null
	for i: int in range(0, vertices.size(), 3):
		if normals[i].y < 0.7:
			continue
		var a: Vector3 = vertices[i]
		var b: Vector3 = vertices[i + 1]
		var c: Vector3 = vertices[i + 2]
		var triangle: PackedVector2Array = PackedVector2Array(
			[Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(c.x, c.z)]
		)
		if not Geometry2D.is_point_in_polygon(point, triangle):
			continue
		var normal: Vector3 = (b - a).cross(c - a)
		if absf(normal.y) < 0.00001:
			continue
		var top: float = a.y - (normal.x * (point.x - a.x) + normal.z * (point.y - a.z)) / normal.y
		if height == null or top > float(height):
			height = top
	return height


func test_flat_ground_movement_is_deterministic_and_keeps_source_immutable() -> void:
	var source: Dictionary = WorldDocument.new().snapshot()
	var original: Dictionary = source.duplicate(true)
	var surface: WalkSurface = _surface(source)
	var delta: Vector2 = Vector2(1.2, -0.7)
	var direct: Vector3 = surface.move_grounded(Vector3.ZERO, delta)
	var stepped: Vector3 = Vector3.ZERO
	for i: int in range(20):
		stepped = surface.move_grounded(stepped, delta / 20)
	assert_almost_eq(direct.x, delta.x, 0.0001)
	assert_almost_eq(direct.z, delta.y, 0.0001)
	assert_almost_eq(direct.y, 0.0, 0.0001)
	assert_lt(direct.distance_to(stepped), 0.0001)
	assert_eq(surface.move_grounded(direct, Vector2(INF, 0)), direct)
	assert_eq(surface.move_grounded(direct, Vector2(0, NAN)), direct)
	assert_null(surface.ground_at(Vector2(INF, 0)))
	assert_eq_deep(source, original)


func test_rectangular_and_round_house_footprints_include_body_clearance() -> void:
	var source: Dictionary = WorldDocument.new().snapshot()
	WorldDocument.allocate_building(source, Vector3.ZERO, Vector3(2, 3, 2))
	WorldDocument.allocate_building(source, Vector3(5, 0, 0), Vector3(2, 3, 2), "round")
	var surface: WalkSurface = _surface(source)
	for point: Vector2 in [Vector2.ZERO, Vector2(1.1, 0), Vector2(5, 0), Vector2(6.1, 0)]:
		assert_false(surface.can_stand(point))
	assert_true(surface.can_stand(Vector2(1.3, 0)))
	assert_true(surface.can_stand(Vector2(6.3, 0)))
	# A circular house leaves its diagonal corners clear.
	assert_true(surface.can_stand(Vector2(6, 1)))


func test_large_moves_cannot_tunnel_through_houses_and_can_slide_along_walls() -> void:
	var source: Dictionary = WorldDocument.new().snapshot()
	WorldDocument.allocate_building(source, Vector3.ZERO, Vector3(2, 3, 2))
	var surface: WalkSurface = _surface(source)
	var stopped: Vector3 = surface.move_grounded(Vector3(-3, 0, 0), Vector2(6, 0))
	assert_gt(stopped.x, -3.0)
	assert_lte(stopped.x, -1.219)
	assert_true(surface.can_stand(Vector2(stopped.x, stopped.z)))
	var slide: Vector3 = surface.move_grounded(Vector3(-1.3, 0, -0.8), Vector2(1, 1.2))
	assert_lte(slide.x, -1.219)
	assert_gt(slide.z, 0.3)
	assert_true(surface.can_stand(Vector2(slide.x, slide.z)))


func test_pond_is_not_swimmable_and_spawn_search_finds_dry_safe_ground() -> void:
	var source: Dictionary = TerrainField.pond(WorldDocument.new().snapshot(), Vector2.ZERO, 2.3)
	var original: Dictionary = source.duplicate(true)
	var surface: WalkSurface = _surface(source)
	assert_null(surface.ground_at(Vector2.ZERO))
	var spawn: Variant = surface.find_spawn(Vector2.ZERO)
	assert_not_null(spawn)
	if spawn != null:
		var point: Vector2 = Vector2(spawn.x, spawn.z)
		assert_gt(PondShape.distance(source["pool"], point), 0.03)
		assert_true(surface.can_stand(point))
		assert_almost_eq(spawn.y, float(surface.ground_at(point)), 0.0001)
		assert_eq(surface.find_spawn(Vector2.ZERO), spawn)
	assert_eq_deep(source, original)


func test_valid_bridge_supports_full_crossing_but_not_water_beside_rails() -> void:
	var source: Dictionary = TerrainField.pond(WorldDocument.new().snapshot(), Vector2.ZERO, 2.3)
	var a: Vector2 = Vector2(0, -2.7)
	var b: Vector2 = Vector2(0, 2.7)
	var bridge: Dictionary = GardenStructures.allocate(source, "bridge", a, b, 1.2)
	assert_eq(GardenStructures.status(source, bridge), "")
	var surface: WalkSurface = _surface(source)
	_assert_crossing(surface, a, b)
	assert_gt(float(surface.ground_at(Vector2.ZERO)), float(source["pool"]["water_y"]))
	assert_false(surface.can_stand(Vector2(0.4, 0)), "Capsule may not cross the bridge rail")
	assert_false(surface.can_stand(Vector2(1, 0)), "Water beside bridge remains forbidden")


func test_default_demo_bridge_is_crossable_and_matches_generated_deck_top() -> void:
	var source: Dictionary = TerrainRelief.apply(ArtLayout.create())
	var original: Dictionary = source.duplicate(true)
	var bridge: Dictionary = source["bridges"][0]
	assert_eq(GardenStructures.status(source, bridge), "")
	var surface: WalkSurface = _surface(source)
	var a: Vector2 = _point(bridge, "a")
	var b: Vector2 = _point(bridge, "b")
	_assert_crossing(surface, a, b)
	var arrays: Array = GardenStructures.build(source)["bridge"][0]
	var boards: int = ceili(a.distance_to(b) / 0.23)
	for i: int in range(boards):
		var point: Vector2 = a.lerp(b, (float(i) + 0.5) / boards)
		var mesh_top: Variant = _mesh_top(arrays, point)
		var support: Variant = surface.ground_at(point)
		assert_not_null(mesh_top)
		assert_not_null(support)
		if mesh_top != null and support != null:
			assert_almost_eq(float(support), float(mesh_top), 0.005)
	assert_eq_deep(source, original)


func test_default_demo_exterior_stairs_are_crossable_and_follow_actual_treads() -> void:
	var source: Dictionary = TerrainRelief.apply(ArtLayout.create())
	var stair: Dictionary = source["stairs"][0]
	assert_eq(GardenStructures.status(source, stair), "")
	var surface: WalkSurface = _surface(source)
	var a: Vector2 = _point(stair, "a")
	var b: Vector2 = _point(stair, "b")
	# The top head is 8 cm from the wall. Keep the 22 cm body outside the house.
	assert_false(surface.can_stand(a), "Closed house interiors cannot be entered")
	_assert_crossing(surface, a.lerp(b, 0.2), b)
	var arrays: Array = GardenStructures.build(source)["stair"][0]
	for t: float in [0.22, 0.38, 0.54, 0.70, 0.86]:
		var point: Vector2 = a.lerp(b, t)
		var mesh_top: Variant = _mesh_top(arrays, point)
		var support: Variant = surface.ground_at(point)
		assert_not_null(mesh_top)
		assert_not_null(support)
		if mesh_top != null and support != null:
			assert_almost_eq(float(support), float(mesh_top), 0.0001)


func test_trees_large_props_and_support_relative_instance_offsets() -> void:
	var source: Dictionary = TerrainField.brush(WorldDocument.new().snapshot(), Vector2.ZERO, 1, 4)
	var tree: Dictionary = InstanceEdits.allocate(source, Vector3.ZERO)
	tree["asset_id"] = "NAT-01"
	var bench: Dictionary = InstanceEdits.allocate(source, Vector3(5, 0, 0))
	bench["asset_id"] = "PROP-01"
	bench["yaw"] = PI * 0.5
	var grass: Dictionary = InstanceEdits.allocate(source, Vector3(8, 0, 0))
	grass["asset_id"] = "NAT-04"
	var floating: Dictionary = InstanceEdits.allocate(source, Vector3(11, 2.5, 0))
	floating["asset_id"] = "PROP-05"
	var surface: WalkSurface = _surface(source)
	assert_false(surface.can_stand(Vector2.ZERO), "Tree stays grounded on raised terrain")
	assert_false(surface.can_stand(Vector2(5, 0.8)), "Rotated bench long axis blocks passage")
	assert_true(surface.can_stand(Vector2(5.8, 0)))
	assert_true(surface.can_stand(Vector2(8, 0)), "Small meadow plants remain traversable")
	assert_true(surface.can_stand(Vector2(11, 0)), "Overhead object does not block ground")


func test_fences_block_movement_and_generated_path_gates_stay_open() -> void:
	var source: Dictionary = WorldDocument.new().snapshot()
	FenceGeometry.allocate(source, [[0, 0, -3], [0, 0, 3]])
	var surface: WalkSurface = _surface(source)
	assert_false(surface.can_stand(Vector2.ZERO))
	var stopped: Vector3 = surface.move_grounded(Vector3(-2, 0, 0), Vector2(4, 0))
	assert_lt(stopped.x, 0.0)
	PathGeometry.allocate(source, [[-2, 0, 0], [2, 0, 0]], 1.2)
	surface.configure(source)
	_assert_crossing(surface, Vector2(-2, 0), Vector2(2, 0))


func test_steep_terrain_bounds_and_invalid_retained_bridges_are_not_traversable() -> void:
	var source: Dictionary = WorldDocument.new().snapshot()
	# A raised plateau with a 1.5 m rise over one 0.5 m cell exceeds a 45 degree slope.
	for z: int in range(60, 69):
		for x: int in range(64, 73):
			source["terrain"]["height_deltas"].append([x, z, 1.5])
	var surface: WalkSurface = _surface(source)
	assert_false(surface.can_stand(Vector2(-0.25, 0)))
	assert_true(surface.can_stand(Vector2(1, 0)))
	var stopped: Vector3 = surface.move_grounded(Vector3(-2, 0, 0), Vector2(4, 0))
	assert_lt(stopped.x, 0.0)
	var boundary: Vector3 = surface.move_grounded(Vector3(22, 0, 10), Vector2(1000, 0))
	assert_gt(boundary.x, 22.0)
	assert_lte(boundary.x, WalkSurface.WORLD_LIMIT - WalkSurface.BODY_RADIUS + 0.0001)
	assert_null(surface.ground_at(Vector2(WalkSurface.WORLD_LIMIT, 10)))
	assert_null(surface.ground_at(Vector2(1000, 0)))
	source = TerrainField.pond(WorldDocument.new().snapshot(), Vector2.ZERO, 2.3)
	var invalid: Dictionary = GardenStructures.allocate(
		source, "bridge", Vector2(0, -1.5), Vector2(0, 1.5), 1.2
	)
	assert_false(GardenStructures.status(source, invalid).is_empty())
	surface.configure(source)
	assert_null(surface.ground_at(Vector2.ZERO), "Retained invalid bridge supplies no safe deck")
