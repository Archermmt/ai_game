extends GutTest


func test_twelve_palette_ids_cover_five_existing_material_groups() -> void:
	assert_eq(GardenPalette.CARDS.size(), 12)
	var ids: Dictionary = {}
	for card: Dictionary in GardenPalette.CARDS:
		assert_false(ids.has(card["id"]))
		ids[card["id"]] = true
		assert_true(GardenPalette.valid({card["group"]: card["id"]}))
		assert_true(FileAccess.file_exists("res://art_source/week_07/ui/" + card["id"] + ".svg"))
		assert_eq(PaletteThumbnails.TEXTURES[card["id"]].get_size(), Vector2(96, 96))
	assert_eq(GardenPalette.DEFAULTS.size(), 5)


func test_invalid_palette_keys_cannot_enter_source_or_history() -> void:
	for value: Variant in [
		[], null, {"wall": "plaster_cream"}, {"wood": "roof_smoke"}, {"wood": "missing"}
	]:
		var world: Dictionary = WorldDocument.new().snapshot()
		world["environment"]["palette"] = value
		assert_eq(WorldDocument.validate(world), "invalid_palette")


func test_all_seventeen_ids_have_owned_wrappers_and_simple_pick_proxies() -> void:
	var world: Dictionary = WorldDocument.new().snapshot()
	for asset_id: String in AssetRegistry.WRAPPERS:
		var item: Dictionary = InstanceEdits.allocate(world, Vector3.ZERO)
		item["asset_id"] = asset_id
		var wrapper: Node3D = AssetRegistry.create(item, world, null, null)
		assert_eq(wrapper.get_meta("object_id"), item["id"])
		assert_true(wrapper.get_node("PickProxy/SelectionShape").shape is BoxShape3D)
		assert_eq(wrapper.get_node("PickProxy").collision_layer, 2)
		assert_true(wrapper.has_node("GroundAnchor"))
		wrapper.free()


func test_support_and_lamp_anchors_match_runtime_contract() -> void:
	var world: Dictionary = WorldDocument.new().snapshot()
	for asset_id: String in ["PROP-01", "PROP-05", "PROP-08"]:
		var item: Dictionary = InstanceEdits.allocate(world, Vector3.ZERO)
		item["asset_id"] = asset_id
		var view: Node3D = AssetRegistry.create(item, world, null, null)
		var anchor: String = "LampAnchor" if asset_id == "PROP-08" else "SupportSurface"
		assert_almost_eq(
			view.get_node(anchor).position.y,
			0.28 if asset_id == "PROP-08" else (0.8 if asset_id == "PROP-05" else 0.58),
			0.001
		)
		view.free()


func test_source_query_picks_bench_ends_and_rotated_clothesline() -> void:
	var world: Dictionary = WorldDocument.new().snapshot()
	var item: Dictionary = InstanceEdits.allocate(world, Vector3.ZERO)
	item["asset_id"] = "PROP-01"
	assert_eq(AssetRegistry.pick(world, Vector2(0.95, 0)), item["id"])
	item["asset_id"] = "PROP-04"
	item["yaw"] = PI / 2
	assert_eq(AssetRegistry.pick(world, Vector2(0, -1.2)), item["id"])
	assert_eq(AssetRegistry.pick(world, Vector2(4, 4)), "")


func test_wrapper_keeps_imported_meshes_and_source_bytes_unchanged() -> void:
	var hash_before: String = FileAccess.get_sha256("res://assets/week_06/lantern.glb")
	var world: Dictionary = WorldDocument.new().snapshot()
	var item: Dictionary = InstanceEdits.allocate(world, Vector3.ZERO)
	item["asset_id"] = "PROP-08"
	var view: Node3D = AssetRegistry.create(item, world, null, null)
	assert_true(view.get_node("Visual").get_child_count() > 0)
	assert_eq(FileAccess.get_sha256("res://assets/week_06/lantern.glb"), hash_before)
	view.free()


func test_timber_kit_has_no_posts_above_eaves_at_min_and_max_heights() -> void:
	for size: Vector3 in [Vector3(3, 2.4, 3), Vector3(12, 7.2, 12)]:
		var world: Dictionary = WorldDocument.new().snapshot()
		var home: Dictionary = WorldDocument.allocate_building(world, Vector3.ZERO, size)
		var kit: Node3D = ArchitecturalKit.assemble(home, null)
		for part: Node3D in kit.get_children():
			for mesh: MeshInstance3D in part.find_children("*", "MeshInstance3D", true, false):
				var transform_value: Transform3D = part.transform * mesh.transform
				var bounds: AABB = transform_value * mesh.get_aabb()
				assert_lte(bounds.end.y, size.y + 0.001)
		assert_gt(kit.get_child_count(), 4)
		kit.free()


func test_curved_kit_and_contact_wall_trim_are_bounded() -> void:
	var world: Dictionary = WorldDocument.new().snapshot()
	var home: Dictionary = WorldDocument.allocate_building(
		world, Vector3.ZERO, Vector3(3, 2.4, 3), "round"
	)
	var kit: Node3D = ArchitecturalKit.assemble(home, null)
	assert_gt(kit.get_child_count(), 10)
	kit.free()
	home["shape"] = "rect"
	WorldDocument.allocate_building(world, Vector3(3, 0, 0), Vector3(3, 2.4, 3))
	kit = ArchitecturalKit.assemble(home, null, world["buildings"])
	var other: Node3D = ArchitecturalKit.assemble(world["buildings"][1], null, world["buildings"])
	assert_eq(kit.get_child_count() + other.get_child_count(), 36)
	other.free()
	kit.free()


func test_extreme_buildings_keep_valid_holes_and_complete_roof_shells() -> void:
	var world: Dictionary = BuildingGallery.create()
	assert_eq(WorldDocument.validate(world), "")
	for home: Dictionary in world["buildings"]:
		var arrays: Array = BuildingGeometry.build_arrays(home, world["buildings"])
		assert_gt(arrays[Mesh.ARRAY_VERTEX].size(), 100)
		var finite_vertices: bool = true
		for p: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
			finite_vertices = (
				finite_vertices and is_finite(p.x) and is_finite(p.y) and is_finite(p.z)
			)
		assert_true(finite_vertices)
		var roof_vertices: int = 0
		for p: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
			if p.y > home["size"][1]:
				roof_vertices += 1
		assert_gt(roof_vertices, 0)


func test_feedback_translates_recoverable_errors_into_player_actions() -> void:
	for code: String in [
		"missing_support", "hedge_clearance", "bridge_adjust_heads", "stair_height_0_15_to_0_9"
	]:
		var text: String = EditorFeedback.humanize("不能放下：" + code)
		assert_false(code in text)
		assert_gt(text.length(), 8)


func test_formal_round_window_replaces_over_budget_block_ring() -> void:
	var meta: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://assets/week_07/window_round.asset.json")
	)
	assert_lte(int(meta["triangles"]), 1600)
	var world: Dictionary = ForestTemplate.create()
	var view: Node3D = Node3D.new()
	OpeningAssembly.attach(view, world["buildings"][0], func(_node: Node3D) -> void: pass)
	var found: bool = false
	for child: Node3D in view.get_children():
		found = found or child.get_meta("opening_kind") == "round_window"
		assert_eq(child.scale, Vector3.ONE)
	assert_true(found)
	view.free()
