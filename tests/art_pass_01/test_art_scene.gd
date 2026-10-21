extends "res://tests/art_pass_01/playground_test_base.gd"
## Exercise the live art renderer through the same published transactions as tools.


func test_scene_source_is_valid_and_every_cottage_uses_the_art_renderer() -> void:
	assert_eq(WorldDocument.validate(playground.document.state), "")
	assert_eq(playground.document.state["buildings"].size(), 3)
	for home: Dictionary in playground.document.state["buildings"]:
		var view: Node3D = playground._live_units["building:" + home["id"]]
		assert_eq(view.get_meta("object_id"), home["id"])
		assert_true(view.has_node("HandLaidTiles"))
		assert_true(view.has_node("HoneyTimber"))
	assert_true(playground._planner is ArtViewPlan)
	assert_gt(playground._curtain.get_child_count(), 0)
	assert_gt(playground._pond_bank.get_child_count(), 0)
	assert_ne(playground.saves.directory, "user://week_08/saves")


func test_async_path_edit_is_atomic_and_undo_restores_the_actual_flagstones() -> void:
	var before: Dictionary = playground.document.snapshot()
	var first_mesh: ArrayMesh = playground._static_views["path"].mesh
	var first_arrays: Array = first_mesh.surface_get_arrays(0)
	var draft: Dictionary = before.duplicate(true)
	PathGeometry.allocate(draft, [[12, 0, 10], [14, 0, 12]], 1.2)
	playground._submit_async(draft, "art path")
	assert_eq_deep(playground.document.snapshot(), before)
	await _settle()
	assert_eq(playground.session.history_count(), 1)
	assert_ne(playground._static_views["path"].mesh.surface_get_arrays(0), first_arrays)
	playground._on_action(&"undo")
	assert_true(_same(playground.document.snapshot(), before))
	assert_eq_deep(playground._static_views["path"].mesh.surface_get_arrays(0), first_arrays)
	playground._on_action(&"redo")
	assert_eq(playground.document.state["paths"].size(), before["paths"].size() + 1)


func test_distant_edit_reuses_cottages_and_water_and_refreshes_bank_only_when_needed() -> void:
	var before: Dictionary = playground.document.snapshot()
	var homes: Dictionary = {}
	for home: Dictionary in before["buildings"]:
		homes[home["id"]] = playground._live_units["building:" + home["id"]]
	var water: ArrayMesh = playground.water_view.mesh
	var bank: Node3D = playground._pond_bank
	var draft: Dictionary = before.duplicate(true)
	draft["environment"]["wind_strength"] = 0.15
	playground._submit_async(draft, "wind")
	await _settle()
	assert_same(playground._pond_bank, bank)
	for id_value: String in homes:
		assert_same(playground._live_units["building:" + id_value], homes[id_value])
	playground._submit_async(
		TerrainField.brush(playground.document.snapshot(), Vector2(17, -17), 0.02, 1.0), "terrain"
	)
	await _settle()
	assert_same(playground.water_view.mesh, water)
	assert_same(playground._pond_bank, bank)
	for id_value: String in homes:
		assert_same(playground._live_units["building:" + id_value], homes[id_value])


func test_invalid_cottage_resize_rejects_source_and_decorated_view_together() -> void:
	var before: Dictionary = playground.document.snapshot()
	var views: Dictionary = playground._live_units.duplicate()
	var draft: Dictionary = before.duplicate(true)
	draft["buildings"][0]["size"][0] = 12.1
	playground._submit_async(draft, "invalid")
	await _settle()
	assert_eq_deep(playground.document.snapshot(), before)
	assert_eq(playground._live_units, views)
	assert_eq(playground.session.history_count(), 0)


func test_photo_freezes_derived_forest_and_returns_all_wind_materials_to_preferences() -> void:
	var source: Dictionary = playground.document.snapshot()
	var freeze_before: Dictionary = {}
	playground._preference_changed("reduce_motion", true)
	assert_gt(playground.wind_materials.size(), 5)
	for paint: ShaderMaterial in playground.wind_materials:
		assert_true(paint.get_shader_parameter("reduce_motion"))
		freeze_before[paint] = paint.get_shader_parameter("freeze_time")
	playground.enter_photo()
	for paint: ShaderMaterial in playground.wind_materials:
		assert_true(paint.get_shader_parameter("freeze_time"))
	playground.exit_photo()
	for paint: ShaderMaterial in playground.wind_materials:
		assert_eq(paint.get_shader_parameter("freeze_time"), freeze_before[paint])
		assert_true(paint.get_shader_parameter("reduce_motion"))
	assert_eq_deep(playground.document.snapshot(), source)


func test_fifty_mixed_edits_and_history_keep_source_and_live_art_cache_consistent() -> void:
	var initial: Dictionary = playground.document.snapshot()
	for index: int in range(50):
		var draft: Dictionary = playground.document.snapshot()
		match index % 5:
			0:
				draft["environment"]["dusk"] = not draft["environment"]["dusk"]
			1:
				draft["environment"]["aged"] = not draft["environment"].get("aged", false)
			2:
				draft = TerrainField.brush(draft, Vector2(17, -17), 0.001, 1.0)
			3:
				draft["buildings"][0]["size"][1] = 3.5 + float(index) * 0.001
			4:
				draft["instances"][0]["yaw"] += 0.001
		assert_true(
			playground.session.commit_snapshot(draft, "art mix", playground._prepare_views)["ok"]
		)
	var final: Dictionary = playground.document.snapshot()
	for index: int in range(50):
		assert_true(playground.session.request_undo(playground._prepare_views)["ok"])
	assert_true(_same(initial, playground.document.snapshot()))
	for index: int in range(50):
		assert_true(playground.session.request_redo(playground._prepare_views)["ok"])
	assert_true(_same(final, playground.document.snapshot()))
	await get_tree().process_frame
	assert_eq(playground._live_units.keys().size(), playground._planner.cache.keys().size())
	var live_materials: Array[ShaderMaterial] = []
	for node: Node3D in [playground.instance_root, playground._curtain, playground._pond_bank]:
		for paint: ShaderMaterial in WeekSixCatalog.wind_materials(node):
			if paint not in live_materials:
				live_materials.append(paint)
	assert_eq(
		playground.wind_materials.size(),
		live_materials.size(),
		"No orphan wind materials after 150 publications"
	)


func test_empty_entry_keeps_the_same_terrain_and_curtain_and_can_return_to_demo() -> void:
	var source: Dictionary = playground.document.snapshot()
	var curtain: Node3D = playground._curtain
	playground._layout_kind = "empty"
	playground._apply_layout()
	assert_eq(playground.document.state["buildings"].size(), 0)
	assert_eq_deep(playground.document.state["terrain"], source["terrain"])
	assert_same(playground._curtain, curtain)
	assert_eq(playground._pond_bank.get_child_count(), 0)
	playground._layout_kind = "demo"
	playground._apply_layout()
	assert_true(_same(playground.document.snapshot(), source))
	assert_eq(playground.session.history_count(), 0)


func test_actual_async_save_load_keeps_painted_paths_in_art_and_historical_documents() -> void:
	for legacy: bool in [false, true]:
		var source: Dictionary = ForestTemplate.create() if legacy else ArtLayout.create()
		PathGeometry.allocate(source, [[12, 0, 10], [14, 0, 12]], 1.2)
		assert_true(playground.session.replace_document(source, playground._prepare_views)["ok"])
		var expected: PackedVector3Array = (
			playground._static_views["path"].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		)
		playground._start_save(4, "异步美术作品")
		await _settle()
		playground._layout_kind = "empty"
		playground._apply_layout()
		playground._start_load(4)
		await _settle()
		assert_true(_same(playground.document.snapshot(), source))
		var loaded: ArrayMesh = playground._static_views["path"].mesh
		assert_eq_deep(loaded.surface_get_arrays(0)[Mesh.ARRAY_VERTEX], expected)
		var draft: Dictionary = playground.document.snapshot()
		draft["environment"]["dusk"] = true
		playground._submit_async(draft, "post-load light")
		await _settle()
		assert_eq_deep(
			playground._static_views["path"].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX], expected
		)


func test_world_seed_replacement_rebuilds_derived_pond_bank() -> void:
	var original: Node3D = playground._pond_bank
	var draft: Dictionary = playground.document.snapshot()
	draft["world_seed"] = "art-new-pond-seed"
	assert_true(playground.session.replace_document(draft, playground._prepare_views)["ok"])
	assert_not_same(playground._pond_bank, original)
	assert_eq(playground._curtain_seed, "art-new-pond-seed")


func test_selection_proxy_encloses_the_replacement_nature_meshes() -> void:
	var checked: int = 0
	for item: Dictionary in playground.document.state["instances"]:
		if item["asset_id"] not in ["NAT-01", "NAT-02", "NAT-03"]:
			continue
		var wrapper: GardenAssetWrapper = playground._instance_views[item["id"]]
		assert_same(wrapper.visual, wrapper.get_node("Visual"))
		var model: AABB = wrapper.visual.get_meta("pick_bounds")
		var proxy: CollisionShape3D = wrapper.get_node("PickProxy/SelectionShape")
		var size_value: Vector3 = (proxy.shape as BoxShape3D).size
		var bounds: AABB = AABB(proxy.position - size_value * 0.5, size_value)
		assert_true(bounds.grow(0.001).encloses(model), "Click proxy covers the actual new canopy")
		checked += 1
	assert_gt(checked, 10)


func test_player_hedges_reuse_the_same_painted_shrub_and_survive_undo() -> void:
	var source: Dictionary = ArtLayout.empty()
	var hedge: Dictionary = HedgeRules.allocate(source, [[0, 8], [3, 8], [3, 10]], 0.8)
	assert_true(playground.session.replace_document(source, playground._prepare_views)["ok"])
	var view: GardenAssetWrapper = playground._instance_views[hedge["id"]]
	assert_eq(view.visual.get_meta("asset_id"), "NAT-07")
	for paint: ShaderMaterial in WeekSixCatalog.wind_materials(view.visual):
		assert_same(paint.shader, playground.art_materials["foliage"].shader)
	var draft: Dictionary = playground.document.snapshot()
	draft["instances"].erase(hedge)
	assert_true(
		playground.session.commit_snapshot(draft, "remove hedge", playground._prepare_views)["ok"]
	)
	assert_false(playground._instance_views.has(hedge["id"]))
	assert_true(playground.session.request_undo(playground._prepare_views)["ok"])
	assert_true(playground._instance_views.has(hedge["id"]))
