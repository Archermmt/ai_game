extends GutTest


func _audio() -> Array:
	return JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/manifest.json"))


func test_six_audio_families_and_seventeen_original_files() -> void:
	var entries: Array = _audio()
	assert_eq(entries.size(), 17)
	var families: Dictionary = {}
	for item: Dictionary in entries:
		families[item["family"]] = true
		assert_string_contains(item["license"], "original")
		assert_true(FileAccess.file_exists("res://" + item["source"]))
	assert_eq(families.size(), 6)


func test_audio_pcm_headers_and_original_sources_match() -> void:
	for item: Dictionary in _audio():
		var raw: PackedByteArray = FileAccess.get_file_as_bytes("res://" + item["export"])
		assert_eq(raw.slice(0, 4).get_string_from_ascii(), "RIFF")
		assert_eq(raw.decode_u16(22), 1)
		assert_eq(raw.decode_u32(24), 48000)
		assert_eq(raw.decode_u16(34), 16)
		assert_eq(raw, FileAccess.get_file_as_bytes("res://" + item["source"]))
		var stream: AudioStreamWAV = load("res://" + item["export"])
		assert_eq(
			stream.loop_mode,
			AudioStreamWAV.LOOP_FORWARD if item["loop"] else AudioStreamWAV.LOOP_DISABLED
		)


func test_ambient_loops_have_no_hard_seam_and_audio_has_headroom() -> void:
	for item: Dictionary in _audio():
		assert_lt(item["peak_dbfs"], -6.0)
		assert_lt(item["rms_dbfs"], -15.0)
		if item["loop"]:
			assert_lte(item["seam_delta"], 128.0)
			assert_eq(item["seconds"], 8.0)


func test_three_variants_for_each_surface_and_ui_are_distinct() -> void:
	for prefix: String in ["wood", "stone", "grass", "ui"]:
		var hashes: Dictionary = {}
		for item: Dictionary in _audio():
			if String(item["name"]).begins_with(prefix + "_"):
				hashes[item["sha256"]] = true
		assert_eq(hashes.size(), 3)


func test_tool_icons_and_feedback_have_editable_vector_sources() -> void:
	var manifest: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://assets/ui/manifest.json")
	)
	assert_eq(manifest["tools"].size(), 16)
	assert_eq(manifest["feedback"].size(), 4)
	for name: String in manifest["tools"] + manifest["feedback"]:
		var runtime: String = FileAccess.get_file_as_string("res://assets/ui/" + name + ".svg")
		assert_eq(
			runtime, FileAccess.get_file_as_string("res://art_source/week_06/ui/" + name + ".svg")
		)
		assert_string_contains(runtime, 'viewBox="0 0 64 64"')
		assert_string_contains(runtime, "<path")


func test_bundled_font_has_pinned_origin_hash_and_full_license() -> void:
	var manifest: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://assets/fonts/manifest.json")
	)
	assert_eq(manifest["version_commit"].length(), 40)
	assert_string_contains(manifest["source"], manifest["version_commit"])
	var hashing: HashingContext = HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(FileAccess.get_file_as_bytes("res://assets/fonts/NotoSansSC-Regular.otf"))
	assert_eq(hashing.finish().hex_encode(), manifest["sha256"])
	assert_string_contains(
		FileAccess.get_file_as_string("res://assets/fonts/OFL.txt"), "SIL OPEN FONT LICENSE"
	)


func test_finished_tea_and_lantern_stay_within_triangle_budgets() -> void:
	for name: String in ["tea_set", "lantern"]:
		var data: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string("res://assets/week_06/" + name + ".asset.json")
		)
		assert_lte(data["triangles"], data["budget"])
		assert_eq(data["stage"], "w06_source")
		assert_eq(data["supersedes"], "week_05")


func test_source_kit_parts_are_components_not_new_asset_families() -> void:
	var manifest: Array = JSON.parse_string(
		FileAccess.get_file_as_string("res://art_source/week_06/manifest.json")
	)
	var parts: Array = manifest.filter(func(i: Dictionary) -> bool: return i["component"])
	assert_eq(parts.size(), 6)
	for part: Dictionary in parts:
		assert_true(part["asset_id"] in ["BLD-03", "BLD-10", "BLD-11", "BLD-19"])
		assert_has(part["sockets"], "socket_start")
		assert_has(part["sockets"], "socket_end")


func test_runtime_generator_sections_match_source_profiles() -> void:
	var profiles: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://assets/week_06/profiles.json")
	)
	for i: int in range(3):
		assert_almost_eq(profiles["wood_post"]["size_godot"][i], KitProfiles.POST[i], 0.00001)
	assert_almost_eq(profiles["wood_rail"]["size_godot"][1], KitProfiles.RAIL.y, 0.00001)
	assert_almost_eq(profiles["stone_tread"]["size_godot"][1], KitProfiles.TREAD_RISE, 0.00001)
	assert_almost_eq(profiles["timber_trim"]["size_godot"][1], KitProfiles.TRIM_HEIGHT, 0.00001)


func test_lantern_has_four_emissive_panes_and_consistent_light_anchor() -> void:
	var view: Node3D = WeekSixCatalog.create("PROP-08", "lamp", null, null)
	var panes: Array = view.find_children("lamp_emission*", "MeshInstance3D", true, false)
	assert_eq(panes.size(), 4)
	for pane: MeshInstance3D in panes:
		assert_true(pane.material_override.emission_enabled)
	assert_eq(view.find_children("socket_light", "Node3D", true, false).size(), 1)
	view.free()


func test_tea_cups_have_separate_thick_inner_wall_meshes() -> void:
	var view: Node3D = WeekSixCatalog.create("PROP-07", "tea", null, null)
	assert_eq(view.find_children("pot_cup_inner_wall*", "MeshInstance3D", true, false).size(), 2)
	assert_eq(view.find_children("pot_teapot_thick_body*", "MeshInstance3D", true, false).size(), 1)
	view.free()


func test_lamp_modes_separate_emission_from_local_light_budget() -> void:
	assert_eq(LanternController.strength_for("off", 1), 0.0)
	assert_eq(LanternController.strength_for("on", 0), 1.0)
	assert_eq(LanternController.strength_for("auto", 0.5), 0.5)


func test_invalid_lamp_or_height_lock_fields_rejected() -> void:
	var world: Dictionary = WorldDocument.new().snapshot()
	var item: Dictionary = InstanceEdits.allocate(world, Vector3.ZERO)
	item["lamp_mode"] = "on"
	assert_eq(WorldDocument.validate(world), "invalid_lamp_mode")
	item.erase("lamp_mode")
	item["height_locked"] = true
	item["locked_y"] = INF
	assert_ne(WorldDocument.validate(world), "")


func test_batch_custom_data_phase_is_stable_after_unrelated_edits() -> void:
	var world: Dictionary = WorldDocument.new().snapshot()
	VegetationBrush.paint(world, Vector2(10, 10), "plants", 3, 1, {})
	var data: Dictionary = LocalRebuild.evaluate(world, {})
	var groups: Dictionary = FoliageBatches.groups(world)
	var items: Array = groups.values()[0]
	var a: Node3D = FoliageBatches.build(items, data["poses"], null, null)
	world["environment"]["dusk"] = true
	var b: Node3D = FoliageBatches.build(
		items, LocalRebuild.evaluate(world, {})["poses"], null, null
	)
	assert_eq(
		a.get_child(0).multimesh.get_instance_custom_data(0),
		b.get_child(0).multimesh.get_instance_custom_data(0)
	)
	assert_eq(a.position, b.position)
	a.free()
	b.free()
