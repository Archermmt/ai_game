extends GutTest


func _straight() -> Dictionary:
	var source: Dictionary = WorldDocument.new("walkway-check").snapshot()
	PathGeometry.allocate(source, [[-3, 0, 0], [3, 0, 0]], 0.9)
	return source


func _landing_center(arrays: Array, near: Vector2) -> float:
	var distance: float = INF
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	for i: int in vertices.size():
		if colors[i].is_equal_approx(Color("d0c5a9")):
			distance = minf(distance, near.distance_to(Vector2(vertices[i].x, vertices[i].z)))
	return distance


func test_soil_survives_between_stones_and_duplicate_strokes_do_not_stack_it() -> void:
	var source: Dictionary = _straight()
	var initial: Dictionary = source.duplicate(true)
	var a: Array = ArtPathGeometry.arrays(source)
	assert_eq_deep(initial, source)
	assert_eq_deep(a, ArtPathGeometry.arrays(source))
	var soil_vertices: int = 0
	var stone_vertices: int = 0
	for v: Vector3 in a[Mesh.ARRAY_VERTEX]:
		if is_equal_approx(v.y, 0.014):
			soil_vertices += 1
		elif v.y > 0.03:
			stone_vertices += 1
	assert_gt(soil_vertices, 0)
	assert_gt(stone_vertices, 0)
	PathGeometry.allocate(source, [[3, 0, 0], [-3, 0, 0]], 0.9)
	var second_soil: int = 0
	for v: Vector3 in ArtPathGeometry.arrays(source)[Mesh.ARRAY_VERTEX]:
		if is_equal_approx(v.y, 0.014):
			second_soil += 1
	assert_eq(second_soil, soil_vertices, "Overlapping paths share one ground surface")


func test_stones_rotate_with_a_rotated_path_and_preserve_seeded_shape() -> void:
	var source: Dictionary = _straight()
	var a: Array = ArtPathGeometry.arrays(source)
	source.paths[0].points = [[0, 0, -3], [0, 0, 3]]
	var b: Array = ArtPathGeometry.arrays(source)
	var stones: PackedVector3Array = []
	for point: Vector3 in a[Mesh.ARRAY_VERTEX]:
		if point.y > 0.03:
			stones.append(Vector3(-point.z, point.y, point.x))
	var index: int = 0
	var error: float = 0
	for point: Vector3 in b[Mesh.ARRAY_VERTEX]:
		if point.y > 0.03:
			if index < stones.size():
				error = maxf(error, point.distance_to(stones[index]))
			index += 1
	assert_gt(index, 0)
	assert_eq(index, stones.size())
	assert_lt(error, 0.0001)


func test_moving_a_ground_door_moves_its_landing_along_the_adjoining_path() -> void:
	var source: Dictionary = WorldDocument.new("door-walkway").snapshot()
	var home: Dictionary = WorldDocument.allocate_building(source, Vector3.ZERO, Vector3(4, 3, 4))
	home.openings = [
		{
			"kind": "rect",
			"facade": 0,
			"center": 0.25,
			"width": 0.95,
			"height": 1.98,
			"sill": 0.0,
			"source": "manual"
		}
	]
	PathGeometry.allocate(source, [[-2.4, 0, 2.45], [2.4, 0, 2.45]], 1.0)
	var a: Array = ArtPathGeometry.arrays(source)
	assert_lt(_landing_center(a, Vector2(-1, 2.46)), 0.015)
	home.openings[0].center = 0.75
	var b: Array = ArtPathGeometry.arrays(source)
	assert_gt(_landing_center(b, Vector2(-1, 2.46)), 1.0)
	assert_lt(_landing_center(b, Vector2(1, 2.46)), 0.015)
	source.paths.clear()
	assert_true(ArtPathGeometry.arrays(source)[Mesh.ARRAY_VERTEX].is_empty())


func test_real_bridge_and_stair_get_approach_slabs_while_decks_and_water_stay_clear() -> void:
	var source: Dictionary = WoodlandLayout.create()
	var arrays: Array = ArtPathGeometry.arrays(source)
	for collection: String in ["bridges", "stairs"]:
		var item: Dictionary = source[collection][0]
		var a: Vector2 = Vector2(item.a[0], item.a[1])
		var b: Vector2 = Vector2(item.b[0], item.b[1])
		assert_lt(_landing_center(arrays, b + (b - a).normalized() * 0.26), 0.015, collection)
	var violations: int = 0
	for point: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
		if ArtPathGeometry.blocked(Vector2(point.x, point.z), source):
			violations += 1
	assert_eq(violations, 0)


func test_raised_door_approach_shares_the_rise_between_walkway_and_threshold() -> void:
	var source: Dictionary = WorldDocument.new("door-on-low-foundation").snapshot()
	var home: Dictionary = WorldDocument.allocate_building(
		source, Vector3(0, 0.4, 0), Vector3(4, 3, 4)
	)
	home.openings = [
		{
			"kind": "rect",
			"facade": 0,
			"center": 0.5,
			"width": 0.95,
			"height": 1.98,
			"sill": 0.0,
			"source": "manual"
		}
	]
	PathGeometry.allocate(source, [[0, 0, 2.25], [0, 0, 6.0]], 1.0)
	var arrays: Array = ArtPathGeometry.arrays(source)
	var highest: float = -INF
	for i: int in arrays[Mesh.ARRAY_VERTEX].size():
		var point: Vector3 = arrays[Mesh.ARRAY_VERTEX][i]
		var color: Color = arrays[Mesh.ARRAY_COLOR][i]
		if color.is_equal_approx(Color("d0c5a9")):
			highest = maxf(highest, point.y)
	assert_gt(highest, 0.16)
	assert_lt(highest, 0.26)
	var feathered: int = 0
	for color: Color in arrays[Mesh.ARRAY_COLOR]:
		if color.a > 0.05 and color.a < 0.95:
			feathered += 1
	assert_gt(feathered, 10, "Worn soil has a graded coverage band over the turf")


func test_walking_steps_onto_the_published_door_stone_then_back_to_terrain() -> void:
	var source: Dictionary = WorldDocument.new("walk-up-one-tread").snapshot()
	var home: Dictionary = WorldDocument.allocate_building(
		source, Vector3(0, 0.4, 0), Vector3(4, 3, 4)
	)
	home.openings = [
		{
			"kind": "rect",
			"facade": 0,
			"center": 0.5,
			"width": 1.0,
			"height": 2.0,
			"sill": 0.0,
			"source": "manual"
		}
	]
	PathGeometry.allocate(source, [[0, 0, 2.25], [0, 0, 6]], 1.0)
	var mesh: ArrayMesh = BuildingGeometry.mesh_from_arrays(ArtPathGeometry.arrays(source))
	var surface: WalkSurface = WalkSurface.new()
	surface.configure(source, mesh)
	var from: Vector3 = Vector3(0, 0, 3.4)
	var at_stone: Vector3 = surface.move_grounded(from, Vector2(0, -0.94))
	var peak: float = -INF
	for vertex: Vector3 in mesh.get_faces():
		peak = maxf(peak, vertex.y)
	assert_almost_eq(at_stone.z, 2.46, 0.001)
	assert_almost_eq(at_stone.y, peak, 0.002, "Feet meet the drawn crown of the raised slab")
	assert_eq(surface.ground_at(Vector2(0.72, 2.46)), 0.0, "Ground beside the slab stays level")
	var back: Vector3 = surface.move_grounded(at_stone, Vector2(0, 0.94))
	assert_lt(back.distance_to(from), 0.001)
	surface.configure(source)
	assert_eq(
		surface.ground_at(Vector2(0, 2.46)), 0.0, "Dropping an old published mesh clears its tread"
	)
