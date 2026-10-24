extends GutTest


func _world(shape: String = "rect") -> Dictionary:
	var world: Dictionary = WorldDocument.new("w03-buildings").snapshot()
	var home: Dictionary = WorldDocument.allocate_building(
		world, Vector3.ZERO, Vector3(5, 3, 5), shape
	)
	home["openings"] = [
		{"kind": "arch", "center": 0.5, "width": 1.1, "height": 2.05, "source": "manual"}
	]
	return world


func test_generator_extremes_have_unit_geometric_normals_and_metric_uvs() -> void:
	for shape: String in ["rect", "round"]:
		for width: float in [3.0, 5.0, 12.0]:
			for height: float in [2.4, 7.2]:
				var world: Dictionary = _world(shape)
				world["buildings"][0]["size"] = [width, height, width]
				var arrays: Array = BuildingGeometry.build_arrays(world["buildings"][0])
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
				var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
				var valid: bool = true
				var metric: bool = true
				for i: int in range(0, vertices.size(), 3):
					var ab: Vector3 = vertices[i + 1] - vertices[i]
					var ac: Vector3 = vertices[i + 2] - vertices[i]
					valid = valid and ab.cross(ac).normalized().dot(normals[i]) < -0.999
					var a: Vector2 = uv[i + 1] - uv[i]
					var b: Vector2 = uv[i + 2] - uv[i]
					metric = metric and absf(absf(a.cross(b)) - ab.cross(ac).length()) < 0.002
				assert_true(valid, shape + " geometric normals")
				assert_true(metric, shape + " UV area in square metres")
				assert_lt(vertices.size() / 3, 10000)


func test_roofs_have_closed_fascia_and_undersides() -> void:
	for shape: String in ["rect", "round"]:
		var world: Dictionary = _world(shape)
		var arrays: Array = BuildingGeometry.build_arrays(world["buildings"][0])
		var underside: int = 0
		for i: int in range(arrays[Mesh.ARRAY_VERTEX].size()):
			if arrays[Mesh.ARRAY_VERTEX][i].y > 2.85 and arrays[Mesh.ARRAY_NORMAL][i].y < -0.1:
				underside += 1
		assert_gt(underside, 10)


func test_repeated_resize_keeps_identity_seed_and_door_dimensions() -> void:
	for shape: String in ["rect", "round"]:
		var world: Dictionary = _world(shape)
		var original: Dictionary = world["buildings"][0].duplicate(true)
		var ids: Array[String] = [original["id"]]
		for size: Vector3 in [Vector3(6, 4, 6), Vector3(8, 6, 8), Vector3(3, 2.4, 3)]:
			BuildingEdits.resize(world, ids, size)
			assert_eq(WorldDocument.validate(world), "")
			assert_eq(world["buildings"][0]["id"], original["id"])
			assert_eq(world["buildings"][0]["seed"], original["seed"])
			assert_eq_deep(world["buildings"][0]["openings"], original["openings"])


func test_resize_into_manual_prop_is_rejected_as_one_transaction() -> void:
	var doc: WorldDocument = WorldDocument.new()
	doc.state = _world()
	InstanceEdits.allocate(doc.state, Vector3(4, 0, 0))
	var session: EditSession = EditSession.new(doc)
	var before: Dictionary = doc.snapshot()
	var draft: Dictionary = doc.snapshot()
	BuildingEdits.resize(draft, [draft["buildings"][0]["id"]], Vector3(10, 3, 5))
	assert_false(session.commit_snapshot(draft, "collision")["ok"])
	assert_eq_deep(doc.snapshot(), before)
	assert_eq(session.history_count(), 0)
	session.dispose()


func test_resize_cannot_squeeze_existing_locked_opening() -> void:
	var world: Dictionary = _world()
	world["buildings"][0]["openings"][0]["width"] = 3.4
	world["buildings"][0]["openings"][0]["locked"] = true
	BuildingEdits.resize(world, [world["buildings"][0]["id"]], Vector3(3, 3, 3))
	assert_ne(WorldDocument.validate(world), "")


func test_delete_parent_retains_manual_frames_with_world_pose() -> void:
	var world: Dictionary = _world()
	var id_value: String = world["buildings"][0]["id"]
	BuildingEdits.remove(world, [id_value])
	assert_eq(world["buildings"].size(), 0)
	assert_eq(world["attachments"].size(), 1)
	assert_eq(world["attachments"][0]["parent_id"], "")
	assert_eq(world["attachments"][0]["position"], [0.0, 0.0, 2.5])
	assert_eq(WorldDocument.validate(world), "")


func test_delete_auto_door_omits_it_but_retains_locked_auto_door() -> void:
	var world: Dictionary = _world()
	world["buildings"][0]["openings"][0]["source"] = "auto_path"
	var unlocked: Dictionary = world.duplicate(true)
	BuildingEdits.remove(unlocked, [unlocked["buildings"][0]["id"]])
	assert_true(unlocked["attachments"].is_empty())
	world["buildings"][0]["openings"][0]["locked"] = true
	BuildingEdits.remove(world, [world["buildings"][0]["id"]])
	assert_eq(world["attachments"].size(), 1)


func test_reattach_preserves_id_and_is_reversible_with_derived_frames() -> void:
	var doc: WorldDocument = WorldDocument.new()
	doc.state = _world()
	var source: Dictionary = doc.snapshot()
	var session: EditSession = EditSession.new(doc)
	var draft: Dictionary = doc.snapshot()
	BuildingEdits.remove(draft, [draft["buildings"][0]["id"]])
	var target: Dictionary = WorldDocument.allocate_building(
		draft, Vector3(8, 0, 0), Vector3(5, 3, 5)
	)
	assert_true(session.commit_snapshot(draft, "delete")["ok"])
	var detached: Dictionary = doc.snapshot()
	var key: String = detached["attachments"][0]["id"]
	draft = doc.snapshot()
	assert_true(BuildingEdits.reattach(draft, key, target["id"]))
	assert_true(session.commit_snapshot(draft, "reattach")["ok"])
	assert_eq(doc.state["buildings"][0]["openings"][0]["attachment_id"], key)
	assert_true(session.request_undo()["ok"])
	assert_eq_deep(doc.state["attachments"], detached["attachments"])
	assert_true(session.request_undo()["ok"])
	assert_eq_deep(doc.state["buildings"], source["buildings"])
	assert_true(session.request_redo()["ok"])
	assert_true(session.request_redo()["ok"])
	assert_true(doc.state["attachments"].is_empty())
	session.dispose()


func test_detached_curved_opening_near_seam_remains_valid() -> void:
	var world: Dictionary = _world("round")
	world["buildings"][0]["openings"][0]["center"] = 0.94
	BuildingEdits.remove(world, [world["buildings"][0]["id"]])
	assert_eq(WorldDocument.validate(world), "")


func test_duplicate_or_invalid_attachment_reference_is_rejected() -> void:
	var world: Dictionary = _world()
	BuildingEdits.remove(world, [world["buildings"][0]["id"]])
	world["attachments"].append(world["attachments"][0].duplicate(true))
	assert_ne(WorldDocument.validate(world), "")
	world["attachments"].pop_back()
	world["attachments"][0]["parent_id"] = "ghost"
	assert_ne(WorldDocument.validate(world), "")


func test_fifty_mixed_commands_batch_delete_and_branch_redo_cleanup() -> void:
	var doc: WorldDocument = WorldDocument.new()
	doc.state = _world()
	var session: EditSession = EditSession.new(doc)
	var initial: Dictionary = doc.snapshot()
	for i: int in range(49):
		var draft: Dictionary = doc.snapshot()
		if i % 2 == 0:
			draft["buildings"][0]["size"][1] = 3.0 + float(i % 3) * 0.1
		else:
			draft["environment"]["dusk"] = not draft["environment"]["dusk"]
		assert_true(session.commit_snapshot(draft, "size")["ok"])
	var deleted: Dictionary = doc.snapshot()
	BuildingEdits.remove(deleted, [deleted["buildings"][0]["id"]])
	assert_true(session.commit_snapshot(deleted, "delete batch")["ok"])
	assert_eq(session.history_count(), 50)
	for i: int in range(50):
		assert_true(session.request_undo()["ok"])
	assert_eq_deep(doc.state["buildings"], initial["buildings"])
	for i: int in range(50):
		assert_true(session.request_redo()["ok"])
	assert_eq(doc.state["attachments"].size(), 1)
	assert_true(session.request_undo()["ok"])
	var branch: Dictionary = doc.snapshot()
	branch["environment"]["dusk"] = true
	assert_true(session.commit_snapshot(branch, "branch")["ok"])
	assert_false(session.request_redo()["ok"])
	session.dispose()


func test_history_source_budget_rejects_without_publication() -> void:
	var doc: WorldDocument = WorldDocument.new()
	var session: EditSession = EditSession.new(doc)
	var draft: Dictionary = doc.snapshot()
	draft["padding"] = "a".repeat(EditSession.MAX_SOURCE_BYTES)
	assert_eq(session.commit_snapshot(draft, "large")["error"], "history_source_budget")
	assert_eq(session.history_count(), 0)
	assert_false(doc.state.has("padding"))
	session.dispose()


func test_batch_delete_two_parents_keeps_all_manual_attachments_in_one_history_entry() -> void:
	var doc: WorldDocument = WorldDocument.new()
	doc.state = _world()
	var second: Dictionary = WorldDocument.allocate_building(
		doc.state, Vector3(9, 0, 0), Vector3(4, 3, 4)
	)
	second["openings"] = [
		{"kind": "round", "center": 0.5, "width": 0.8, "height": 0.8, "sill": 1.0}
	]
	var original: Array = doc.state["buildings"].duplicate(true)
	var session: EditSession = EditSession.new(doc)
	var draft: Dictionary = doc.snapshot()
	BuildingEdits.remove(draft, [draft["buildings"][0]["id"], second["id"]])
	assert_true(session.commit_snapshot(draft, "batch delete")["ok"])
	assert_eq(session.history_count(), 1)
	assert_eq(doc.state["attachments"].size(), 2)
	assert_true(session.request_undo()["ok"])
	assert_eq_deep(doc.state["buildings"], original)
	assert_true(doc.state["attachments"].is_empty())
	session.dispose()


func test_conflicting_reattach_keeps_detached_source_and_history() -> void:
	var doc: WorldDocument = WorldDocument.new()
	doc.state = _world()
	BuildingEdits.remove(doc.state, [doc.state["buildings"][0]["id"]])
	var target: Dictionary = WorldDocument.allocate_building(
		doc.state, Vector3.ZERO, Vector3(5, 3, 5)
	)
	target["openings"] = [{"kind": "rect", "center": 0.5, "width": 1.0, "height": 1.0, "sill": 1.0}]
	var original: Dictionary = doc.snapshot()
	var session: EditSession = EditSession.new(doc)
	var draft: Dictionary = doc.snapshot()
	assert_true(BuildingEdits.reattach(draft, draft["attachments"][0]["id"], target["id"]))
	assert_false(session.commit_snapshot(draft, "conflict")["ok"])
	assert_eq_deep(doc.snapshot(), original)
	assert_eq(session.history_count(), 0)
	session.dispose()


func test_malformed_detached_dimensions_fail_validation_without_script_error() -> void:
	var world: Dictionary = _world()
	BuildingEdits.remove(world, [world["buildings"][0]["id"]])
	world["attachments"][0]["former_size"] = []
	assert_eq(WorldDocument.validate(world), "invalid_detached_opening")
	world["attachments"][0]["former_size"] = [5.0, "bad", 5.0]
	assert_eq(WorldDocument.validate(world), "invalid_detached_opening")


func test_terrain_fitting_support_perimeter_preserves_horizontal_floor() -> void:
	var world: Dictionary = _world()
	world = TerrainField.brush(world, Vector2(2, 0), -0.5, 3.0)
	var field: TerrainField = TerrainField.new(world)
	var points: Array = SupportGeometry.perimeter(world["buildings"][0], field)
	assert_eq(points.size(), 64)
	var low: float = 0.0
	for point: Array in points:
		assert_almost_eq(point[1], field.height_at(Vector2(point[0], point[2])), 0.0001)
		low = minf(low, point[1])
	assert_lt(low, -0.1)
	assert_eq(world["buildings"][0]["position"][1], 0.0)


func test_round_wall_uvs_unwrap_across_full_circumference() -> void:
	var world: Dictionary = _world("round")
	var arrays: Array = BuildingGeometry.build_arrays(world["buildings"][0])
	var max_u: float = 0.0
	for i: int in range(arrays[Mesh.ARRAY_VERTEX].size()):
		var p: Vector3 = arrays[Mesh.ARRAY_VERTEX][i]
		var n: Vector3 = arrays[Mesh.ARRAY_NORMAL][i]
		if absf(n.y) < 0.01 and absf(Vector2(p.x, p.z).length() - 2.5) < 0.001:
			max_u = maxf(max_u, arrays[Mesh.ARRAY_TEX_UV][i].x)
	assert_gt(max_u, 15.5)
