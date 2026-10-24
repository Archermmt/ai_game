extends GutTest


func _world() -> Dictionary:
	var draft: Dictionary = WorldDocument.new("w03-path").snapshot()
	PathGeometry.allocate(draft, [[-5, 0, 0], [5, 0, 0]], 1.5)
	return draft


func test_path_projection_samples_actual_terrain_and_is_repeatable() -> void:
	var world: Dictionary = TerrainField.brush(_world(), Vector2.ZERO, 0.4, 4)
	var a: Array = PathGeometry.arrays(world)
	assert_eq(a, PathGeometry.arrays(world))
	var field: TerrainField = TerrainField.new(world)
	var valid: bool = true
	for p: Vector3 in a[Mesh.ARRAY_VERTEX]:
		valid = valid and absf(p.y - field.height_at(Vector2(p.x, p.z)) - 0.025) < 0.001
	assert_true(valid)
	assert_gt(a[Mesh.ARRAY_VERTEX].size(), 0)


func test_intersection_union_has_no_duplicate_triangles() -> void:
	var world: Dictionary = _world()
	PathGeometry.allocate(world, [[0, 0, -5], [0, 0, 5]], 1.5)
	var arrays: Array = PathGeometry.arrays(world)
	var seen: Dictionary = {}
	var duplicate: bool = false
	for i: int in range(0, arrays[Mesh.ARRAY_VERTEX].size(), 3):
		var key: String = str(arrays[Mesh.ARRAY_VERTEX].slice(i, i + 3))
		duplicate = duplicate or seen.has(key)
		seen[key] = true
	assert_false(duplicate)
	assert_eq(WorldDocument.validate(world), "")


func test_path_hides_inside_building_and_stops_at_water() -> void:
	var world: Dictionary = _world()
	WorldDocument.allocate_building(world, Vector3.ZERO, Vector3(3, 3, 3))
	world = TerrainField.pond(world, Vector2(8, 0), 2)
	PathGeometry.allocate(world, [[4, 0, 0], [12, 0, 0]])
	var arrays: Array = PathGeometry.arrays(world)
	var valid: bool = true
	for i: int in range(0, arrays[Mesh.ARRAY_VERTEX].size(), 3):
		var center: Vector3 = (
			(
				arrays[Mesh.ARRAY_VERTEX][i]
				+ arrays[Mesh.ARRAY_VERTEX][i + 1]
				+ arrays[Mesh.ARRAY_VERTEX][i + 2]
			)
			/ 3.0
		)
		valid = valid and not (absf(center.x) < 1.5 and absf(center.z) < 1.5)
		valid = valid and Vector2(center.x - 8, center.z).length() > 2.0
	assert_true(valid)


func test_width_and_bounds_are_validated_before_mesh_generation() -> void:
	var world: Dictionary = _world()
	world["paths"][0]["width"] = 4.0
	assert_false(WorldRebuild.evaluate(world)["ok"])
	world["paths"][0]["width"] = 1.0
	world["paths"][0]["points"][0][0] = 30.0
	assert_false(WorldRebuild.evaluate(world)["ok"])


func test_source_order_and_unrelated_instance_do_not_reseed_path() -> void:
	var world: Dictionary = _world()
	var a: Array = PathGeometry.arrays(world)
	InstanceEdits.allocate(world, Vector3(12, 0, 12))
	assert_eq(a, PathGeometry.arrays(world))


func test_world_rebuild_prepares_path_before_publication() -> void:
	var result: Dictionary = WorldRebuild.materialize(WorldRebuild.evaluate(_world()))
	assert_true(result["ok"])
	assert_not_null(result["path_mesh"])
