extends "res://tests/week_09/playground_test_base.gd"


func test_empty_and_demo_share_terrain_and_peripheral_trees() -> void:
	var empty: Dictionary = ForestTemplate.empty()
	var demo: Dictionary = ForestTemplate.create()
	assert_eq_deep(empty["terrain"], demo["terrain"])
	for item: Dictionary in empty["instances"]:
		assert_true(item in demo["instances"])
	assert_eq(empty["buildings"].size(), 0)
	assert_eq(demo["buildings"].size(), 2)


func test_dirty_layout_switch_requires_choice_and_cancel_preserves_source() -> void:
	var before: Dictionary = playground.document.snapshot()
	playground._request_layout("empty")
	assert_true(playground.hud.decision.visible)
	assert_eq_deep(playground.document.snapshot(), before)
	playground._decision_made("cancel")
	assert_eq_deep(playground.document.snapshot(), before)
	assert_eq(playground._intent, "")


func test_discard_switch_uses_same_scene_clears_history_and_does_not_overwrite_slot() -> void:
	playground._request_layout("empty")
	playground._decision_made("discard")
	assert_eq(playground.document.state["buildings"].size(), 0)
	assert_eq(playground.document.state["instances"].size(), 12)
	assert_eq(playground.active_slot, -1)
	assert_true(playground.is_dirty())
	assert_eq(playground.session.history_count(), 0)
	assert_eq(playground.get_parent(), viewport)
	for action: String in ["rect", "round", "place_asset", "path"]:
		assert_true(playground.hud.buttons.has(action))


func test_overwrite_dialog_requires_explicit_confirmation() -> void:
	assert_true(
		(
			SlotStore
			. write_slot(playground.saves.directory, 1, playground.document.snapshot(), "原作品")["ok"]
		)
	)
	playground._slot_requested("save", 1, "新作品")
	assert_true(playground.hud.overwrite.visible)
	assert_false(playground.saves.is_busy())
	assert_eq(SlotStore.read_slot(playground.saves.directory, 1)["metadata"]["title"], "原作品")
	playground.hud.overwrite.hide()
	playground._confirm_overwrite()
	await _settle()
	assert_eq(SlotStore.read_slot(playground.saves.directory, 1)["metadata"]["title"], "新作品")


func test_invalid_entry_does_not_change_source() -> void:
	var before: Dictionary = playground.document.snapshot()
	playground._request_layout("invalid")
	assert_eq_deep(playground.document.snapshot(), before)


func test_new_entry_and_photo_ui_respect_150_percent_and_viewport_bounds() -> void:
	playground._preference_changed("ui_scale", 1.5)
	assert_eq(playground.hud.entry.content_scale_factor, 1.5)
	playground.enter_photo()
	assert_lte(playground.hud._photo_scroll.custom_minimum_size.y * 1.5 + 30, 800.0)
	assert_lte(playground.hud._photo_scroll.custom_minimum_size.x * 1.5 + 30, 1280.0)
	assert_true(playground.hud._photo_scroll is ScrollContainer)


func test_qa_root_automatically_uses_independent_save_directory() -> void:
	var isolated: SubViewport = SubViewport.new()
	isolated.size = Vector2i(1280, 800)
	isolated.own_world_3d = true
	add_child_autofree(isolated)
	var other: Node3D = load("res://app/week_nine_root.tscn").instantiate()
	other.qa_mode = true
	isolated.add_child(other)
	assert_eq(other.saves.directory, "user://qa_w09_native")
	assert_ne(other.saves.directory, "user://week_08/saves")
