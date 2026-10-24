extends GutTest


func test_seeded_brush_is_repeatable_including_ids_yaw_and_scale() -> void:
	var a: Dictionary = WorldDocument.new("same").snapshot()
	var b: Dictionary = WorldDocument.new("same").snapshot()
	VegetationBrush.paint(a, Vector2(10, 10), "plants", 3, 1, {})
	VegetationBrush.paint(b, Vector2(10, 10), "plants", 3, 1, {})
	assert_eq_deep(a, b)
	assert_gt(a["instances"].size(), 3)
	assert_eq(WorldDocument.validate(a), "")


func test_density_zero_places_nothing_and_high_density_is_bounded() -> void:
	var world: Dictionary = WorldDocument.new().snapshot()
	assert_eq(VegetationBrush.paint(world, Vector2.ZERO, "plants", 6, 0, {}), 0)
	assert_true(world["instances"].is_empty())
	VegetationBrush.paint(world, Vector2.ZERO, "plants", 6, 1, {})
	assert_lte(world["instances"].size(), 800)
	assert_gt(world["instances"].size(), 30)


func test_tree_density_and_spacing_are_separate_from_grass() -> void:
	var trees: Dictionary = WorldDocument.new().snapshot()
	var plants: Dictionary = WorldDocument.new().snapshot()
	VegetationBrush.paint(trees, Vector2.ZERO, "trees", 6, 1, {})
	VegetationBrush.paint(plants, Vector2.ZERO, "plants", 6, 1, {})
	assert_lt(trees["instances"].size(), plants["instances"].size())
	for a: Dictionary in trees["instances"]:
		for b: Dictionary in trees["instances"]:
			if a["id"] != b["id"]:
				assert_gte(
					(
						Vector2(
							a["position"][0] - b["position"][0], a["position"][2] - b["position"][2]
						)
						. length()
					),
					2.5999
				)


func test_erase_only_current_category_and_protects_manual_and_locked() -> void:
	var world: Dictionary = WorldDocument.new().snapshot()
	VegetationBrush.paint(world, Vector2.ZERO, "plants", 4, 1, {})
	VegetationBrush.paint(world, Vector2.ZERO, "rocks", 4, 1, {})
	var manual: Dictionary = InstanceEdits.allocate(world, Vector3.ZERO)
	manual["asset_id"] = "NAT-04"
	var locked: Dictionary = world["instances"][0]
	locked["locked"] = true
	var rock_ids: Array = (
		world["instances"]
		. filter(
			func(i: Dictionary) -> bool: return i["asset_id"] in VegetationBrush.CATEGORIES["rocks"]
		)
		. map(func(i: Dictionary) -> String: return i["id"])
	)
	VegetationBrush.paint(world, Vector2.ZERO, "plants", 6, 1, {}, true)
	assert_has(world["instances"], manual)
	assert_has(world["instances"], locked)
	for id_value: String in rock_ids:
		assert_true(world["instances"].any(func(i: Dictionary) -> bool: return i["id"] == id_value))


func test_visited_cells_and_repeated_strokes_do_not_duplicate_source_ids() -> void:
	var world: Dictionary = WorldDocument.new().snapshot()
	var visited: Dictionary = {}
	VegetationBrush.paint(world, Vector2.ZERO, "plants", 3, 1, visited)
	var before: Dictionary = world.duplicate(true)
	assert_eq(VegetationBrush.paint(world, Vector2.ZERO, "plants", 3, 1, visited), 0)
	assert_eq(VegetationBrush.paint(world, Vector2.ZERO, "plants", 3, 1, {}), 0)
	assert_eq_deep(world, before)


func test_brush_avoids_paths_door_clearance_and_pool_bank() -> void:
	var world: Dictionary = TerrainField.pond(WorldDocument.new().snapshot(), Vector2(10, 10), 2)
	var home: Dictionary = WorldDocument.allocate_building(world, Vector3.ZERO, Vector3(5, 3, 5))
	home["openings"] = [{"kind": "arch", "width": 1.1, "height": 2.05, "center": 0.5}]
	PathGeometry.allocate(world, [[0, 0, 3], [0, 0, 12]])
	VegetationBrush.paint(world, Vector2(0, 6), "plants", 6, 1, {})
	VegetationBrush.paint(world, Vector2(10, 10), "plants", 6, 1, {})
	for item: Dictionary in world["instances"]:
		var p: Vector2 = Vector2(item["position"][0], item["position"][2])
		assert_true(VegetationBrush.geometry_clear(world, p))
	assert_eq(WorldDocument.validate(world), "")


func test_brush_avoids_bridge_and_stair_endpoints() -> void:
	var world: Dictionary = WorldDocument.new().snapshot()
	var item: Dictionary = GardenStructures.allocate(world, "stair", Vector2(5, 5), Vector2(7, 5))
	assert_false(VegetationBrush.geometry_clear(world, Vector2(5, 5)))
	assert_false(VegetationBrush.geometry_clear(world, Vector2(7, 5)))
	assert_eq(item["kind"], "stair")


func test_far_brush_preserves_all_existing_records() -> void:
	var world: Dictionary = WorldDocument.new().snapshot()
	VegetationBrush.paint(world, Vector2(-12, -12), "plants", 4, 1, {})
	var far: Array = world["instances"].duplicate(true)
	VegetationBrush.paint(world, Vector2(12, 12), "trees", 4, 1, {})
	for item: Dictionary in far:
		assert_has(world["instances"], item)


func test_one_brush_gesture_undoes_and_redoes_as_one_command() -> void:
	var doc: WorldDocument = WorldDocument.new()
	var edit: EditSession = EditSession.new(doc)
	var tool: WeekSixTools = WeekSixTools.new(edit)
	tool.mode = "plant_brush"
	assert_true(tool.begin(Vector3.ZERO))
	tool.update(Vector3(2, 0, 1))
	assert_true(edit.release_gesture("brush")["ok"])
	var source: Array = doc.state["instances"].duplicate(true)
	assert_eq(edit.history_count(), 1)
	assert_true(edit.request_undo()["ok"])
	assert_true(doc.state["instances"].is_empty())
	assert_true(edit.request_redo()["ok"])
	assert_eq_deep(doc.state["instances"], source)
	edit.dispose()


func test_spatial_groups_keep_source_identity_and_manual_unbatched() -> void:
	var world: Dictionary = WorldDocument.new().snapshot()
	VegetationBrush.paint(world, Vector2(10, 10), "plants", 5, 1, {})
	var manual: Dictionary = InstanceEdits.allocate(world, Vector3.ZERO)
	manual["asset_id"] = "NAT-06"
	var groups: Dictionary = FoliageBatches.groups(world)
	var ids: Array = []
	for items: Array in groups.values():
		for item: Dictionary in items:
			ids.append(item["id"])
	assert_false(manual["id"] in ids)
	assert_eq(ids.size(), world["instances"].size() - 1)


func test_manual_edit_promotes_brushed_item_and_preserves_seed() -> void:
	var world: Dictionary = WorldDocument.new().snapshot()
	VegetationBrush.paint(world, Vector2.ZERO, "trees", 4, 1, {})
	var item: Dictionary = world["instances"][0]
	var seed_value: String = item["seed"]
	InstanceEdits.transform_selection(world, [item["id"]], Vector3(1, 0, 1))
	assert_eq(item["source"], "manual")
	assert_eq(item["seed"], seed_value)
	assert_true(item["locked"])


func test_compact_hedge_is_reused_shrub_not_a_new_handmade_asset() -> void:
	var view: Node3D = WeekSixCatalog.create("NAT-07", "hedge", null, null)
	assert_eq(view.get_child_count(), 3)
	assert_eq(view.get_meta("asset_id"), "NAT-07")
	view.free()


func test_new_geometry_clears_only_unlocked_automatic_foliage() -> void:
	var world: Dictionary = WorldDocument.new().snapshot()
	VegetationBrush.paint(world, Vector2(10, 10), "plants", 3, 1, {})
	var before: Array = world["instances"].duplicate(true)
	WorldDocument.allocate_building(world, Vector3(10, 0, 10), Vector3(5, 3, 5))
	var after: Dictionary = VegetationBrush.reconcile(world)
	assert_lt(after["instances"].size(), before.size())
	assert_eq(WorldDocument.validate(after), "")
	var manual: Dictionary = InstanceEdits.allocate(after, Vector3(10, 0, 10))
	manual["asset_id"] = "NAT-04"
	assert_has(VegetationBrush.reconcile(after)["instances"], manual)
	assert_eq(
		WorldDocument.validate(VegetationBrush.reconcile(after)), "instance_building_collision"
	)


func test_invalid_brush_parameters_do_not_mutate_source() -> void:
	var world: Dictionary = WorldDocument.new().snapshot()
	assert_eq(VegetationBrush.paint(world, Vector2.ZERO, "bad", 3, 1, {}), 0)
	assert_eq(VegetationBrush.paint(world, Vector2.ZERO, "plants", INF, 1, {}), 0)
	assert_true(world["instances"].is_empty())
