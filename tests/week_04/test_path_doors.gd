extends GutTest


func _world(shape: String = "rect") -> Dictionary:
	var draft: Dictionary = WorldDocument.new("w04-doors").snapshot()
	WorldDocument.allocate_building(draft, Vector3.ZERO, Vector3(5, 3, 5), shape)
	return draft


func _road(world: Dictionary, end: Vector2 = Vector2(0, 2.5)) -> void:
	PathGeometry.allocate(world, [[end.x, 0, 8], [end.x, 0, end.y]], 1.2)


func test_path_endpoint_generates_real_arch_and_valid_back_reference() -> void:
	var world: Dictionary = _world()
	_road(world)
	var linked: Dictionary = DoorRules.reconcile(world)["snapshot"]
	assert_eq(WorldDocument.validate(linked), "")
	assert_eq(linked["buildings"][0]["openings"].size(), 1)
	var door: Dictionary = linked["buildings"][0]["openings"][0]
	assert_eq(door["kind"], "arch")
	assert_eq(door["source_paths"], [linked["paths"][0]["id"]])
	assert_eq(door["width"], 1.1)


func test_endpoint_distance_and_height_thresholds() -> void:
	for distance: float in [0.59, 0.61]:
		var world: Dictionary = _world()
		_road(world, Vector2(0, 2.5 + distance))
		var linked: Dictionary = DoorRules.reconcile(world)["snapshot"]
		assert_eq(linked["buildings"][0]["openings"].size(), 1 if distance < 0.6 else 0)
	var high: Dictionary = _world()
	high["buildings"][0]["position"][1] = 0.46
	_road(high)
	var result: Dictionary = DoorRules.reconcile(high)
	assert_true(result["snapshot"]["buildings"][0]["openings"].is_empty())
	assert_false(result["notices"].is_empty())


func test_multiple_paths_reuse_door_and_last_path_removal_removes_it() -> void:
	var world: Dictionary = _world()
	_road(world, Vector2(-0.2, 2.5))
	_road(world, Vector2(0.4, 2.5))
	world = DoorRules.reconcile(world)["snapshot"]
	assert_eq(world["buildings"][0]["openings"].size(), 1)
	assert_eq(world["buildings"][0]["openings"][0]["source_paths"].size(), 2)
	world["paths"].pop_back()
	world = DoorRules.reconcile(world)["snapshot"]
	assert_eq(world["buildings"][0]["openings"].size(), 1)
	world["paths"].clear()
	world = DoorRules.reconcile(world)["snapshot"]
	assert_true(world["buildings"][0]["openings"].is_empty())


func test_lock_converts_auto_door_to_manual_and_survives_road_deletion() -> void:
	var world: Dictionary = _world()
	_road(world)
	world = DoorRules.reconcile(world)["snapshot"]
	var key: String = world["buildings"][0]["openings"][0]["attachment_id"]
	DoorRules.lock(world["buildings"][0]["openings"][0])
	world["paths"].clear()
	world = DoorRules.reconcile(world)["snapshot"]
	assert_eq(WorldDocument.validate(world), "")
	assert_eq(world["buildings"][0]["openings"][0]["attachment_id"], key)
	assert_eq(world["buildings"][0]["openings"][0]["source"], "manual")


func test_hand_door_has_priority_without_being_replaced() -> void:
	var world: Dictionary = _world()
	DoorRules.manual_opening(world, world["buildings"][0]["id"], Vector2(0, 2.5), 2)
	var before: Dictionary = world["buildings"][0]["openings"][0].duplicate(true)
	_road(world)
	world = DoorRules.reconcile(world)["snapshot"]
	assert_eq(world["buildings"][0]["openings"].size(), 1)
	assert_eq(world["buildings"][0]["openings"][0]["attachment_id"], before["attachment_id"])
	assert_eq(world["buildings"][0]["openings"][0]["variant"], "glass")


func test_manual_window_conflict_never_swallows_window() -> void:
	var world: Dictionary = _world()
	world["buildings"][0]["openings"] = [
		{
			"kind": "rect",
			"center": 0.5,
			"width": 2.4,
			"height": 0.9,
			"sill": 1.0,
			"source": "manual"
		}
	]
	_road(world)
	var linked: Dictionary = DoorRules.reconcile(world)
	assert_eq(linked["snapshot"]["buildings"][0]["openings"].size(), 1)
	assert_false(linked["notices"].is_empty())
	assert_eq(linked["snapshot"]["buildings"][0]["openings"][0]["sill"], 1.0)


func test_crossing_house_creates_exterior_entries_and_hides_interior_road() -> void:
	var world: Dictionary = _world()
	PathGeometry.allocate(world, [[0, 0, -8], [0, 0, 8]])
	world = DoorRules.reconcile(world)["snapshot"]
	assert_eq(world["buildings"][0]["openings"].size(), 2)
	var arrays: Array = PathGeometry.arrays(world)
	var inside: bool = false
	for p: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
		inside = inside or (absf(p.x) < 2.4 and absf(p.z) < 2.4)
	assert_false(inside)


func test_curved_wall_entry_uses_arc_coordinates() -> void:
	var world: Dictionary = _world("round")
	PathGeometry.allocate(world, [[8, 0, 0], [2.5, 0, 0]])
	world = DoorRules.reconcile(world)["snapshot"]
	assert_eq(WorldDocument.validate(world), "")
	assert_eq(world["buildings"][0]["openings"].size(), 1)
	assert_almost_eq(world["buildings"][0]["openings"][0]["center"], 0.25, 0.001)


func test_reconciliation_is_idempotent_and_independent_of_path_order() -> void:
	var world: Dictionary = _world()
	_road(world, Vector2(-0.2, 2.5))
	_road(world, Vector2(0.4, 2.5))
	var a: Dictionary = DoorRules.reconcile(world)["snapshot"]
	assert_eq_deep(DoorRules.reconcile(a)["snapshot"], a)
	world["paths"].reverse()
	var b: Dictionary = DoorRules.reconcile(world)["snapshot"]
	assert_eq_deep(a["buildings"], b["buildings"])


func test_one_transaction_undo_restores_path_and_opening_together() -> void:
	var doc: WorldDocument = WorldDocument.new()
	doc.state = _world()
	var session: EditSession = EditSession.new(doc)
	var candidate: Dictionary = doc.snapshot()
	_road(candidate)
	candidate = DoorRules.reconcile(candidate)["snapshot"]
	assert_true(session.commit_snapshot(candidate, "road+door")["ok"])
	assert_eq(session.history_count(), 1)
	assert_true(session.request_undo()["ok"])
	assert_true(doc.state["paths"].is_empty())
	assert_true(doc.state["buildings"][0]["openings"].is_empty())
	assert_true(session.request_redo()["ok"])
	assert_eq(doc.state["buildings"][0]["openings"].size(), 1)
	session.dispose()


func test_curve_sampling_passes_controls_and_stays_in_plot() -> void:
	var path: Dictionary = {
		"points": [[-4, 0, 0], [0, 0, 4], [4, 0, 0]], "curved": true, "width": 1.5
	}
	var points: Array[Vector2] = PathCurve.sample(path)
	assert_eq(points[0], Vector2(-4, 0))
	assert_eq(points.back(), Vector2(4, 0))
	assert_has(points, Vector2(0, 4))
	assert_gt(points.size(), 20)
	assert_true(PathCurve.dirty_bounds(path).has_point(Vector2(0, 4)))


func test_path_seed_changes_stones_but_keeps_distant_path_geometry() -> void:
	var world: Dictionary = _world()
	world["buildings"].clear()
	_road(world)
	PathGeometry.allocate(world, [[12, 0, 8], [12, 0, 3]])
	var a: Array = PathGeometry.arrays(world)
	world["paths"][0]["seed"] = "another-seed"
	var b: Array = PathGeometry.arrays(world)
	assert_ne(a[Mesh.ARRAY_VERTEX], b[Mesh.ARRAY_VERTEX])
	assert_ne(a[Mesh.ARRAY_COLOR], b[Mesh.ARRAY_COLOR])
	var far_a: Array = []
	var far_b: Array = []
	for p: Vector3 in a[Mesh.ARRAY_VERTEX]:
		if p.x > 10:
			far_a.append(p)
	for p: Vector3 in b[Mesh.ARRAY_VERTEX]:
		if p.x > 10:
			far_b.append(p)
	assert_eq(far_a, far_b)
	assert_eq(b, PathGeometry.arrays(world))


func test_all_three_doors_and_two_windows_create_valid_fixed_size_source() -> void:
	for variant: int in range(5):
		var world: Dictionary = _world()
		assert_true(
			DoorRules.manual_opening(world, world["buildings"][0]["id"], Vector2(0, 2.5), variant)
		)
		assert_eq(WorldDocument.validate(world), "")
		var opening: Dictionary = world["buildings"][0]["openings"][0]
		assert_almost_eq(opening["width"], 0.9 if variant >= 3 else 1.1, 0.0001)
		assert_eq(opening["source"], "manual")


func test_near_limit_endpoint_cannot_snap_sideways_beyond_distance_limit() -> void:
	var world: Dictionary = _world()
	world["buildings"][0]["openings"] = [
		{"kind": "rect", "center": 0.58, "width": 0.9, "height": 0.9, "sill": 1.0}
	]
	_road(world, Vector2(0, 3.09))
	world = DoorRules.reconcile(world)["snapshot"]
	assert_eq(world["buildings"][0]["openings"].size(), 1)


func test_manual_window_near_corner_snaps_to_nearest_legal_wall_region() -> void:
	var world: Dictionary = _world()
	assert_true(DoorRules.manual_opening(world, world["buildings"][0]["id"], Vector2(2.5, 2.5), 3))
	assert_eq(WorldDocument.validate(world), "")
	var opening: Dictionary = world["buildings"][0]["openings"][0]
	assert_lt(opening["center"], 1.0)
	assert_almost_eq(opening["width"], 0.9, 0.0001)
