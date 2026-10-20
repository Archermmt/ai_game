extends "res://tests/week_09/playground_test_base.gd"


func _same(a: Dictionary, b: Dictionary) -> bool:
	a = a.duplicate(true)
	b = b.duplicate(true)
	a.erase("revision")
	b.erase("revision")
	return a == b


func test_fifty_runtime_transactions_delete_parent_undo_redo_keep_twenty_props_and_far_trees(
) -> void:
	var draft: Dictionary = playground.document.snapshot()
	for i: int in range(20):
		var item: Dictionary = InstanceEdits.allocate(draft, Vector3(13 + i % 4, 0, 12 + i / 4))
		item["asset_id"] = "PROP-05"
	assert_true(playground.session.replace_document(draft, playground._prepare_views)["ok"])
	var initial: Dictionary = playground.document.snapshot()
	for i: int in range(50):
		draft = playground.document.snapshot()
		if i == 25:
			BuildingEdits.remove(draft, [draft["buildings"][0]["id"]])
		else:
			match i % 5:
				0:
					draft["buildings"][0]["size"][1] = 3.2 + float(i) * 0.001
				1:
					draft = TerrainField.brush(draft, Vector2(17, -17), 0.01, 1)
				2:
					draft["environment"]["dusk"] = not draft["environment"]["dusk"]
				3:
					draft["paths"].clear()
					draft = DoorRules.reconcile(draft)["snapshot"]
				4:
					VegetationBrush.paint(draft, Vector2(14, 7), "plants", 1, 0.3, {})
		assert_true(
			playground.session.commit_snapshot(draft, "mix %d" % i, playground._prepare_views)["ok"]
		)
		assert_eq(WorldDocument.validate(playground.document.state), "")
		for item: Dictionary in initial["instances"]:
			if (
				item["source"] == "manual"
				or Vector2(item["position"][0], item["position"][2]).distance_to(Vector2(14, 7)) > 4
			):
				assert_true(item in playground.document.state["instances"])
	var final: Dictionary = playground.document.snapshot()
	assert_gt(final["attachments"].size(), 0)
	for item: Dictionary in final["attachments"]:
		assert_eq(item["parent_id"], "")
	for i: int in range(50):
		assert_true(playground.session.request_undo(playground._prepare_views)["ok"])
	assert_true(_same(initial, playground.document.snapshot()))
	for i: int in range(50):
		assert_true(playground.session.request_redo(playground._prepare_views)["ok"])
	assert_true(_same(final, playground.document.snapshot()))
	assert_eq(playground._live_units.keys().size(), playground._planner.cache.keys().size())


func test_locked_path_door_survives_path_delete_and_undo_in_full_template() -> void:
	var draft: Dictionary = playground.document.snapshot()
	draft["buildings"][0]["openings"].clear()
	draft["paths"][0]["points"][-1] = [-2, 0, 1.5]
	draft = DoorRules.reconcile(draft)["snapshot"]
	assert_gt(draft["buildings"][0]["openings"].size(), 0)
	DoorRules.lock(draft["buildings"][0]["openings"][0])
	assert_true(playground.session.commit_snapshot(draft, "lock", playground._prepare_views)["ok"])
	var before: Dictionary = playground.document.snapshot()
	draft = before.duplicate(true)
	draft["paths"].clear()
	draft = DoorRules.reconcile(draft)["snapshot"]
	assert_true(
		playground.session.commit_snapshot(draft, "remove path", playground._prepare_views)["ok"]
	)
	assert_eq(playground.document.state["buildings"][0]["openings"].size(), 1)
	assert_eq(playground.document.state["buildings"][0]["openings"][0]["source"], "manual")
	assert_true(playground.session.request_undo(playground._prepare_views)["ok"])
	assert_true(_same(before, playground.document.snapshot()))


func test_manual_window_blocks_auto_door_in_full_template() -> void:
	var draft: Dictionary = playground.document.snapshot()
	draft["buildings"][0]["openings"] = [
		{
			"kind": "rect",
			"center": 0.5,
			"width": 2.4,
			"height": 0.9,
			"sill": 1.0,
			"source": "manual"
		}
	]
	draft["paths"][0]["points"][-1] = [-2, 0, 1.5]
	var result: Dictionary = DoorRules.reconcile(draft)
	assert_false(result["notices"].is_empty())
	assert_eq(result["snapshot"]["buildings"][0]["openings"].size(), 1)
	assert_true(
		(
			playground
			. session
			. commit_snapshot(result["snapshot"], "manual window", playground._prepare_views)["ok"]
		)
	)
	assert_eq(playground.document.state["buildings"][0]["openings"][0]["sill"], 1.0)


func test_full_template_invalidated_bridge_stays_visible_and_undo_restores() -> void:
	var before: Dictionary = playground.document.snapshot()
	var draft: Dictionary = PondShape.draw(before, [[5, -3.5], [9, -3.5], [9, 2.5], [5, 2.5]])
	assert_true(playground.session.commit_snapshot(draft, "shore", playground._prepare_views)["ok"])
	assert_false(
		(
			GardenStructures
			. status(playground.document.state, playground.document.state["bridges"][0])
			. is_empty()
		)
	)
	assert_true(
		(
			playground._live_units.has("structure:bridge:" + before["bridges"][0]["id"])
			or playground.structure_root.get_child_count() > 0
		)
	)
	assert_true(playground.session.request_undo(playground._prepare_views)["ok"])
	assert_true(_same(before, playground.document.snapshot()))
	assert_eq(
		GardenStructures.status(playground.document.state, playground.document.state["bridges"][0]),
		""
	)


func test_boundary_dimensions_reject_entire_transaction_with_no_view_change() -> void:
	var before: Dictionary = playground.document.snapshot()
	var keys: Array = playground._live_units.keys()
	for size: float in [2.99, 12.01]:
		var draft: Dictionary = before.duplicate(true)
		draft["buildings"][0]["size"][0] = size
		assert_false(
			(
				playground
				. session
				. commit_snapshot(draft, "bad boundary", playground._prepare_views)["ok"]
			)
		)
		assert_eq_deep(playground.document.snapshot(), before)
		assert_eq(playground._live_units.keys(), keys)
	assert_eq(playground.session.history_count(), 0)


func test_three_metre_foundation_accepts_then_rejects_without_view_or_source_change() -> void:
	var source: Dictionary = WorldDocument.new("w09-support").snapshot()
	WorldDocument.allocate_building(source, Vector3.ZERO, Vector3(3, 3, 3))
	source["terrain"]["height_deltas"] = [[64, 64, -3.0]]
	assert_true(playground.session.replace_document(source, playground._prepare_views)["ok"])
	var before: Dictionary = playground.document.snapshot()
	var live: Dictionary = playground._live_units.duplicate()
	var draft: Dictionary = before.duplicate(true)
	draft["terrain"]["height_deltas"][0][2] = -3.01
	assert_eq(
		(
			playground
			. session
			. commit_snapshot(draft, "over support", playground._prepare_views)["error"]
		),
		"foundation_exceeds_3m"
	)
	assert_eq_deep(playground.document.snapshot(), before)
	assert_eq(playground._live_units, live)
	assert_eq(playground.session.history_count(), 0)
