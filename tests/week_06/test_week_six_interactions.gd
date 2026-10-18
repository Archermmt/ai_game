extends "res://tests/week_06/playground_test_base.gd"


func test_lamp_mode_buttons_are_transactions() -> void:
	var lamp: Dictionary = _with_asset("PROP-08")
	playground.tools.selected.assign([lamp["id"]])
	playground._on_action(&"lamp_on")
	await _settle()
	assert_eq(_record(lamp["id"])["lamp_mode"], "on")
	assert_eq(playground.session.history_count(), 1)
	playground._on_action(&"undo")
	assert_false(
		(
			playground
			. document
			. state["instances"]
			. filter(func(i: Dictionary) -> bool: return i["id"] == lamp["id"])[0]
			. has("lamp_mode")
		)
	)


func test_height_lock_preserves_world_y_when_terrain_changes() -> void:
	var item: Dictionary = _with_asset("PROP-05")
	playground.tools.selected.assign([item["id"]])
	playground._on_action(&"lock_height")
	await _settle()
	var y: float = playground._instance_views[item["id"]].position.y
	var p: Array = item["position"]
	playground._submit_async(
		TerrainEdits.stroke(playground.document.snapshot(), Vector2(p[0], p[2]), "raise"), "terrain"
	)
	await _settle()
	assert_eq(playground._instance_views[item["id"]].position.y, y)


func test_ui_150_percent_panels_stay_inside_viewport_and_scroll() -> void:
	playground.hud.set_ui_scale(1.5)
	await get_tree().process_frame
	for panel: PanelContainer in playground.hud._panels:
		var bounds: Rect2 = Rect2(panel.position * 1.5, panel.size * 1.5)
		assert_lte(bounds.end.x, 1280.1)
		assert_lte(bounds.end.y, 800.1)
		assert_true(panel.get_child(0) is ScrollContainer)
		assert_same(panel.theme.default_font, GardenTheme.FONT)


func test_chinese_font_covers_core_product_labels() -> void:
	for character: String in "林间小屋植被撤销存档提灯":
		assert_true(GardenTheme.FONT.has_char(character.unicode_at(0)), character)


func test_cancel_after_visible_preview_restores_every_source_field() -> void:
	var before: Dictionary = playground.document.snapshot()
	playground.session.begin_gesture()
	var draft: Dictionary = TerrainEdits.stroke(before, Vector2(14, 10), "raise")
	playground.session.update_gesture(draft)
	playground._preview_linked()
	await _settle()
	assert_true(playground._preview_visible)
	playground._on_action(&"cancel")
	await _settle()
	assert_eq_deep(playground.document.snapshot(), before)
	assert_eq(playground.session.history_count(), 0)


func test_failed_pond_edit_keeps_source_and_derived_resources() -> void:
	var before: Dictionary = playground.document.snapshot()
	var water: ArrayMesh = playground.water_view.mesh
	var invalid: Dictionary = PondShape.draw(before, [[-3, -1], [3, -1], [3, 0], [-3, 0]])
	playground._submit_async(invalid, "invalid")
	await _settle()
	assert_eq_deep(playground.document.snapshot(), before)
	assert_same(playground.water_view.mesh, water)


func test_sixth_week_source_roundtrip_preserves_lamp_and_height_modes() -> void:
	var world: Dictionary = playground.document.snapshot()
	world["instances"].back()["lamp_mode"] = "on"
	world["instances"].back()["height_locked"] = true
	world["instances"].back()["locked_y"] = 1.23
	var result: Dictionary = SaveCodec.decode(SaveCodec.encode(world))
	assert_true(result["ok"])
	assert_eq(result["snapshot"]["instances"].back()["lamp_mode"], "on")
	assert_eq(result["snapshot"]["instances"].back()["locked_y"], 1.23)


func test_promoting_batched_plant_keeps_original_id_and_creates_individual_view() -> void:
	var draft: Dictionary = playground.document.snapshot()
	VegetationBrush.paint(draft, Vector2(14, 10), "plants", 3, 1, {})
	playground._submit_async(draft, "brush")
	await _settle()
	var automatic: Dictionary = _automatic()
	var id_value: String = automatic["id"]
	playground.tools.selected.assign([id_value])
	playground._on_action(&"rotate")
	await _settle()
	assert_true(playground._instance_views.has(id_value))
	assert_eq(playground._instance_views[id_value].get_meta("object_id"), id_value)


func test_rapid_previews_never_publish_a_stale_height() -> void:
	var before: Dictionary = playground.document.snapshot()
	playground.session.begin_gesture()
	for i: int in range(5):
		var draft: Dictionary = TerrainEdits.stroke(
			before, Vector2(18, 18), "raise", 2, float(i + 1) * 0.1
		)
		playground.session.update_gesture(draft)
		playground._preview_linked()
	await _settle()
	assert_almost_eq(
		playground._field.height_at(Vector2(18, 18)),
		TerrainField.new(playground.session.preview).height_at(Vector2(18, 18)),
		0.0001
	)
	assert_eq_deep(playground.document.snapshot(), before)
	playground._on_action(&"cancel")


func test_metrics_separate_atomic_publication_and_preparation_slices() -> void:
	playground._submit_async(
		TerrainEdits.stroke(playground.document.snapshot(), Vector2(18, -18), "raise"), "terrain"
	)
	await _settle()
	var metrics: Dictionary = playground._delivery_metrics()
	assert_gt(metrics["preparation_slices"], 0)
	assert_has(metrics, "preparation_slice_max_ms")
	assert_gt(metrics["main_apply_samples"], 0)


func test_preview_replacement_frees_unpublished_nodes_before_cache_reuse() -> void:
	playground.stage.budget_usec = 1
	playground.session.begin_gesture()
	var draft: Dictionary = playground.document.snapshot()
	var first: Dictionary = InstanceEdits.allocate(draft, Vector3(14, 0, -10))
	first["asset_id"] = "PROP-08"
	var second: Dictionary = InstanceEdits.allocate(draft, Vector3(15, 0, -10))
	second["asset_id"] = "PROP-08"
	playground.session.update_gesture(draft)
	playground._preview_linked()
	var start: int = Time.get_ticks_msec()
	while playground.stage._owned.is_empty() and Time.get_ticks_msec() - start < 5000:
		await get_tree().process_frame
	draft["instances"].back()["position"][0] = 16.0
	playground.session.update_gesture(draft)
	playground._preview_linked()
	await _settle()
	assert_true(is_instance_valid(playground._instance_views[first["id"]]))
	assert_true(is_instance_valid(playground._instance_views[second["id"]]))
	playground._on_action(&"cancel")


func _record(id_value: String) -> Dictionary:
	for item: Dictionary in playground.document.state["instances"]:
		if item["id"] == id_value:
			return item
	return {}


func _with_asset(asset_id: String) -> Dictionary:
	for item: Dictionary in playground.document.state["instances"]:
		if item["asset_id"] == asset_id:
			return item
	return {}


func _automatic() -> Dictionary:
	for item: Dictionary in playground.document.state["instances"]:
		if item.has("category"):
			return item
	return {}
