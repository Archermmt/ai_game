extends GutTest


func test_pond_is_derived_and_delete_restores_exact_player_heights() -> void:
	var original: Dictionary = TerrainField.brush(WorldDocument.new().snapshot(), Vector2.ZERO, 0.1)
	var pond: Dictionary = TerrainField.pond(original, Vector2.ZERO, 2.0)
	assert_eq(WorldDocument.validate(pond), "")
	assert_eq_deep(pond["terrain"], original["terrain"])
	var derived: TerrainField = TerrainField.new(pond)
	assert_almost_eq(derived.height_at(Vector2.ZERO), pond["pool"]["water_y"] - 0.45, 0.00001)
	pond["pool"] = {}
	assert_eq_deep(pond, original)
	assert_almost_eq(TerrainField.new(pond).height_at(Vector2.ZERO), 0.1, 0.00001)


func test_ordinary_brush_cannot_change_pool_or_shore_source_samples() -> void:
	var source: Dictionary = TerrainField.pond(WorldDocument.new().snapshot(), Vector2.ZERO, 2.0)
	var changed: Dictionary = TerrainField.brush(source, Vector2.ZERO, 0.35, 2.7)
	assert_eq_deep(changed, source)
	changed = TerrainField.brush(source, Vector2(3, 0), 0.1, 2.0)
	var field: TerrainField = TerrainField.new(changed)
	for entry: Array in changed["terrain"]["height_deltas"]:
		assert_false(field.is_protected(Vector2(entry[0], entry[1]) * 0.5 - Vector2.ONE * 32))


func test_pool_water_stays_fixed_after_resize_and_move() -> void:
	var source: Dictionary = TerrainField.pond(WorldDocument.new().snapshot(), Vector2.ZERO, 2.0)
	var edited: Dictionary = TerrainField.pond(source, Vector2(1, 0), 3.0)
	assert_eq(edited["pool"]["water_y"], source["pool"]["water_y"])
	assert_eq(WorldDocument.validate(edited), "")


func test_slope_width_boundary_and_flooding_reject_before_publication() -> void:
	var source: Dictionary = TerrainField.brush(
		WorldDocument.new().snapshot(), Vector2.ZERO, 0.7, 1.0
	)
	assert_eq(
		WorldDocument.validate(TerrainField.pond(source, Vector2.ZERO, 2)),
		"pool_slope_exceeds_0_6m"
	)
	assert_eq(
		WorldDocument.validate(
			TerrainField.pond(WorldDocument.new().snapshot(), Vector2.ZERO, 0.9)
		),
		"pool_minimum_width"
	)
	assert_eq(
		WorldDocument.validate(
			TerrainField.pond(WorldDocument.new().snapshot(), Vector2(21, 0), 2)
		),
		"pool_boundary_2m"
	)
	source = TerrainField.pond(WorldDocument.new().snapshot(), Vector2.ZERO, 2)
	source["pool"]["water_y"] = 0.1
	assert_eq(WorldDocument.validate(source), "pool_flooding")


func test_foundation_exact_three_meters_accepts_but_next_edit_is_atomic_rejection() -> void:
	var doc: WorldDocument = WorldDocument.new()
	var draft: Dictionary = doc.snapshot()
	WorldDocument.allocate_building(draft, Vector3.ZERO, Vector3(3, 3, 3))
	draft["terrain"]["height_deltas"] = [[64, 64, -3.0]]
	assert_eq(WorldDocument.validate(draft), "")
	var session: EditSession = EditSession.new(doc)
	assert_true(session.replace_document(draft)["ok"])
	var before: Dictionary = doc.snapshot()
	draft = doc.snapshot()
	draft["terrain"]["height_deltas"][0][2] = -3.01
	assert_eq(session.commit_snapshot(draft, "bad slope")["error"], "foundation_exceeds_3m")
	assert_eq_deep(doc.snapshot(), before)
	assert_eq(session.history_count(), 0)
	session.dispose()


func test_pool_building_safety_is_symmetric_and_tangent_is_legal() -> void:
	var draft: Dictionary = TerrainField.pond(WorldDocument.new().snapshot(), Vector2.ZERO, 2)
	WorldDocument.allocate_building(draft, Vector3(4.75, 0, 0), Vector3(3, 3, 3))
	assert_eq(WorldDocument.validate(draft), "")
	draft["buildings"][0]["position"][0] = 4.74
	assert_eq(WorldDocument.validate(draft), "pool_building_safety")
	draft["buildings"][0]["position"][0] = 4.75
	draft["pool"]["radius"] = 2.01
	assert_eq(WorldDocument.validate(draft), "pool_building_safety")


func test_pool_cannot_swallow_hand_placed_instance() -> void:
	var draft: Dictionary = TerrainField.pond(WorldDocument.new().snapshot(), Vector2.ZERO, 2)
	InstanceEdits.allocate(draft, Vector3(2, 0, 0))
	assert_eq(WorldDocument.validate(draft), "pool_manual_instance_safety")


func test_adjacent_chunks_share_exact_border_positions_and_normals_at_both_spacings() -> void:
	for step: float in [0.25, 0.5]:
		var draft: Dictionary = WorldDocument.new().snapshot()
		draft["terrain"]["spacing"] = step
		draft = TerrainField.brush(draft, Vector2(8, 1), 0.35)
		var field: TerrainField = TerrainField.new(draft)
		assert_gt(field.height_at(Vector2(8, 1)), 0.3)
		var left: Array = TerrainGeometry.chunk(field, Vector2.ZERO)
		var right: Array = TerrainGeometry.chunk(field, Vector2(8, 0))
		var count: int = roundi(8 / step) + 1
		var match_all: bool = true
		for row: int in range(count):
			match_all = (
				match_all
				and (
					left[Mesh.ARRAY_VERTEX][row * count + count - 1]
					== right[Mesh.ARRAY_VERTEX][row * count]
				)
			)
			match_all = (
				match_all
				and (
					left[Mesh.ARRAY_NORMAL][row * count + count - 1]
					== right[Mesh.ARRAY_NORMAL][row * count]
				)
			)
		assert_true(match_all)
		var vertices: PackedVector3Array = left[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = left[Mesh.ARRAY_INDEX]
		assert_lt(
			(
				(vertices[indices[1]] - vertices[indices[0]])
				. cross(vertices[indices[2]] - vertices[indices[0]])
				. y
			),
			0.0
		)


func test_pond_edits_save_and_undo_restore_layer_source_exactly() -> void:
	var doc: WorldDocument = WorldDocument.new()
	var session: EditSession = EditSession.new(doc)
	var draft: Dictionary = TerrainField.pond(doc.snapshot(), Vector2.ZERO, 2)
	assert_true(session.commit_snapshot(draft, "pond")["ok"])
	var saved: Dictionary = SaveCodec.decode(SaveCodec.encode(doc.snapshot()))
	assert_true(saved["ok"])
	assert_eq_deep(saved["snapshot"]["pool"], doc.state["pool"])
	draft = doc.snapshot()
	draft["pool"] = {}
	assert_true(session.commit_snapshot(draft, "delete pond")["ok"])
	assert_true(session.request_undo()["ok"])
	assert_eq_deep(doc.state["pool"], saved["snapshot"]["pool"])
	assert_true(session.request_redo()["ok"])
	assert_true(doc.state["pool"].is_empty())
	session.dispose()
