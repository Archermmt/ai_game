extends "res://tests/garden_presentation/playground_test_base.gd"
## Compare cached membership with a fresh traversal of the live presentation.


func _fixture(with_pond: bool = false) -> Dictionary:
	var source: Dictionary = WorldDocument.new("perf02-wind").snapshot()
	if with_pond:
		source = TerrainField.pond(source, Vector2.ZERO, 3)
	for point: Vector3 in [Vector3(0, 0, 8), Vector3(4, 0, 8)]:
		var item: Dictionary = InstanceEdits.allocate(source, point)
		item["asset_id"] = "NAT-01"
	var brush: Dictionary = InstanceEdits.allocate(source, Vector3(10, 0, 10), false)
	brush["asset_id"] = "NAT-04"
	brush["category"] = "plants"
	return source


func _replace(source: Dictionary) -> void:
	assert_true(playground.session.replace_document(source, playground._prepare_views)["ok"])
	await _settle()


func _assert_live_materials() -> void:
	var expected: Dictionary = {}
	for root: Node3D in [
		playground.instance_root, playground._curtain, playground._pond_bank, playground.meadow
	]:
		for paint: ShaderMaterial in WeekSixCatalog.wind_materials(root):
			expected[paint.get_instance_id()] = true
	var actual: Dictionary = {}
	for paint: ShaderMaterial in playground.wind_materials:
		actual[paint.get_instance_id()] = true
	assert_eq(actual.size(), playground.wind_materials.size(), "No duplicate wind materials")
	assert_eq_deep(actual, expected)


func test_initial_cache_contains_every_live_material_and_diagnostic_count() -> void:
	_assert_live_materials()
	assert_gt(playground._art_wind_collections, 0)
	assert_eq(
		playground._delivery_metrics()["art_wind_root_collections"],
		playground._art_wind_collections
	)
	assert_true(playground._art_wind_cache.has("curtain"))
	assert_true(playground._art_wind_cache.has("bank"))


func test_environment_and_distant_terrain_reuse_existing_root_materials() -> void:
	await _replace(_fixture())
	var collections: int = playground._art_wind_collections
	var roots: Dictionary = playground._art_wind_cache.duplicate(true)
	var draft: Dictionary = playground.document.snapshot()
	draft["environment"]["wind_strength"] = 0.2
	playground._submit_async(draft, "cached wind parameters")
	await _settle()
	playground._submit_async(
		TerrainField.brush(playground.document.snapshot(), Vector2(-18, -18), 0.02),
		"distant terrain"
	)
	await _settle()
	assert_eq(playground._art_wind_collections, collections)
	assert_eq_deep(playground._art_wind_cache, roots)
	for paint: ShaderMaterial in playground.wind_materials:
		assert_eq(paint.get_shader_parameter("wind_strength"), 0.2)
	_assert_live_materials()


func test_added_deleted_and_undone_manual_tree_never_leaves_orphan_materials() -> void:
	await _replace(_fixture())
	var draft: Dictionary = playground.document.snapshot()
	var added: Dictionary = InstanceEdits.allocate(draft, Vector3(-8, 0, 8))
	added["asset_id"] = "NAT-02"
	var key: String = "item:" + added["id"]
	playground._submit_async(draft, "add tree")
	await _settle()
	assert_true(playground._art_wind_cache.has(key))
	_assert_live_materials()
	draft = playground.document.snapshot()
	draft["instances"] = draft["instances"].filter(
		func(item: Dictionary) -> bool: return item["id"] != added["id"]
	)
	playground._submit_async(draft, "delete tree")
	await _settle()
	assert_false(playground._art_wind_cache.has(key))
	_assert_live_materials()
	playground._on_action(&"undo")
	await _settle()
	assert_true(playground._art_wind_cache.has(key))
	_assert_live_materials()


func test_same_source_id_with_new_asset_invalidates_only_its_root() -> void:
	await _replace(_fixture())
	var draft: Dictionary = playground.document.snapshot()
	var tree: Dictionary = draft["instances"][0]
	var key: String = "item:" + tree["id"]
	var previous_id: int = playground._art_wind_cache[key]["root_id"]
	var collections: int = playground._art_wind_collections
	tree["asset_id"] = "NAT-02"
	playground._submit_async(draft, "replace tree asset")
	await _settle()
	assert_ne(playground._art_wind_cache[key]["root_id"], previous_id)
	assert_eq(playground._art_wind_collections, collections + 1)
	_assert_live_materials()


func test_rebuilt_brush_batch_refreshes_membership_without_rescanning_other_roots() -> void:
	await _replace(_fixture())
	var key: String = "batch:NAT-04:1:1"
	var previous_id: int = playground._art_wind_cache[key]["root_id"]
	var collections: int = playground._art_wind_collections
	var draft: Dictionary = playground.document.snapshot()
	var item: Dictionary = InstanceEdits.allocate(draft, Vector3(11, 0, 10), false)
	item["asset_id"] = "NAT-04"
	item["category"] = "plants"
	playground._submit_async(draft, "extend grass batch")
	await _settle()
	assert_ne(playground._art_wind_cache[key]["root_id"], previous_id)
	assert_eq(playground._art_wind_collections, collections + 1)
	_assert_live_materials()


func test_seed_replacement_refreshes_derived_curtain_and_bank_materials() -> void:
	await _replace(_fixture(true))
	var curtain_id: int = playground._art_wind_cache["curtain"]["root_id"]
	var bank_id: int = playground._art_wind_cache["bank"]["root_id"]
	var draft: Dictionary = playground.document.snapshot()
	draft["world_seed"] = "perf02-new-wind-seed"
	await _replace(draft)
	assert_ne(playground._art_wind_cache["curtain"]["root_id"], curtain_id)
	assert_ne(playground._art_wind_cache["bank"]["root_id"], bank_id)
	_assert_live_materials()


func test_near_bank_terrain_and_undo_refresh_only_the_bank_material_root() -> void:
	await _replace(_fixture(true))
	var bank_id: int = playground._art_wind_cache["bank"]["root_id"]
	var collections: int = playground._art_wind_collections
	playground._submit_async(
		TerrainField.brush(playground.document.snapshot(), Vector2(4, 0), 0.02, 0.8),
		"near bank terrain"
	)
	await _settle()
	var changed_id: int = playground._art_wind_cache["bank"]["root_id"]
	assert_ne(changed_id, bank_id)
	assert_eq(playground._art_wind_collections, collections + 1)
	_assert_live_materials()
	playground._on_action(&"undo")
	await _settle()
	assert_ne(playground._art_wind_cache["bank"]["root_id"], changed_id)
	assert_eq(playground._art_wind_collections, collections + 2)
	_assert_live_materials()


func test_cached_resources_keep_reduce_motion_and_photo_freeze_restore_complete() -> void:
	await _replace(_fixture(true))
	playground._preference_changed("reduce_motion", true)
	var draft: Dictionary = playground.document.snapshot()
	draft["environment"]["wind_strength"] = 0.3
	playground._submit_async(draft, "reuse cached materials")
	await _settle()
	_assert_live_materials()
	assert_true(playground.meadow.material in playground.wind_materials)
	var source: Dictionary = playground.document.snapshot()
	var freeze_before: Dictionary = {}
	for paint: ShaderMaterial in playground.wind_materials:
		freeze_before[paint] = paint.get_shader_parameter("freeze_time")
		assert_true(paint.get_shader_parameter("reduce_motion"))
	assert_true(playground.enter_photo())
	for paint: ShaderMaterial in playground.wind_materials:
		assert_true(paint.get_shader_parameter("freeze_time"))
	playground.exit_photo()
	for paint: ShaderMaterial in playground.wind_materials:
		assert_eq(paint.get_shader_parameter("freeze_time"), freeze_before[paint])
		assert_true(paint.get_shader_parameter("reduce_motion"))
	assert_eq_deep(playground.document.state, source)
	_assert_live_materials()
