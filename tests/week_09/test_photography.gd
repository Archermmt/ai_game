extends "res://tests/week_09/playground_test_base.gd"


func test_photo_hides_tools_and_returns_exact_camera_source_selection() -> void:
	playground.tools.selected.assign([playground.document.state["buildings"][0]["id"]])
	playground._show_selection()
	var source: Dictionary = playground.document.snapshot()
	var camera: Dictionary = playground._camera_record()
	assert_true(playground.enter_photo())
	assert_false(playground.gizmo_root.visible)
	assert_false(playground.preview_root.visible)
	for panel: CanvasItem in playground.hud._panels:
		assert_false(panel.visible)
	playground.camera_rig.yaw += 1
	playground.camera_rig.distance = 17
	playground.camera_rig.refresh()
	playground.exit_photo()
	assert_eq_deep(playground._camera_record(), camera)
	assert_eq_deep(playground.document.snapshot(), source)
	assert_eq(playground.tools.selected.size(), 1)
	assert_true(playground.gizmo_root.visible)
	assert_false(playground.hud.photo_panel.visible)


func test_freeze_is_reversible_without_mutating_preferences_or_source() -> void:
	var source: Dictionary = playground.document.snapshot()
	var material: ShaderMaterial = playground.wind_materials[0]
	var original: Variant = material.get_shader_parameter("freeze_time")
	playground.enter_photo()
	assert_true(material.get_shader_parameter("freeze_time"))
	playground._freeze_photo(false)
	assert_eq(material.get_shader_parameter("freeze_time"), original)
	playground._freeze_photo(true)
	playground.exit_photo()
	assert_eq(material.get_shader_parameter("freeze_time"), original)
	assert_eq_deep(playground.document.snapshot(), source)
	assert_false(playground.preferences.values["reduce_motion"])


func test_photo_entry_rejected_during_gesture() -> void:
	playground.session.begin_gesture()
	assert_false(playground.enter_photo())
	playground.session.cancel_gesture()
	assert_true(playground.enter_photo())
	assert_false(playground.enter_photo())


func test_photo_blocks_building_undo_and_autosave() -> void:
	var source: Dictionary = playground.document.snapshot()
	playground.enter_photo()
	for action: StringName in [&"undo", &"redo", &"delete", &"rect", &"save", &"entry"]:
		playground._on_action(action)
	assert_eq_deep(playground.document.snapshot(), source)
	assert_true(playground._busy())
	assert_eq(playground.session.history_count(), 0)


func test_bookmark_is_explicit_source_transaction_and_roundtrips() -> void:
	playground.enter_photo()
	playground.camera_rig.yaw = 2.1
	playground._photo_action("bookmark")
	var source: Dictionary = playground.document.snapshot()
	assert_eq(source["camera_bookmarks"].size(), 3)
	assert_eq(source["camera_bookmarks"][2]["yaw"], 2.1)
	assert_eq(playground.session.history_count(), 1)
	var decoded: Dictionary = SnapshotDto.unpack(SnapshotDto.pack(source, "摄影构图"))
	assert_true(decoded["ok"])
	assert_eq_deep(decoded["snapshot"], source)
	playground.exit_photo()
	assert_true(playground.session.request_undo(playground._prepare_views)["ok"])
	assert_eq(playground.document.state["camera_bookmarks"].size(), 2)


func test_apply_saved_composition_and_exit_restores_editor_view() -> void:
	var original: Dictionary = playground._camera_record()
	playground.enter_photo()
	playground.hud.bookmarks.select(1)
	playground._photo_action("restore")
	assert_eq(playground.camera_rig.distance, 19.0)
	playground.exit_photo()
	assert_eq_deep(playground._camera_record(), original)


func test_filename_sanitizes_path_and_collisions() -> void:
	assert_false("/" in PhotoExport.safe_title("../花园:?.png"))
	assert_ne(PhotoExport.output_path("/tmp", "花园"), PhotoExport.output_path("/tmp", "花园"))
	assert_true(PhotoExport.output_path("/tmp", "花园").begins_with("/tmp/花园_"))
	assert_eq(PhotoExport.safe_title("   "), "林间作品")


func test_headless_export_failure_is_retryable() -> void:
	var result: Dictionary = await playground.photography.capture(
		playground.camera_rig.camera, Vector2i(1920, 1080), "/missing/p.png"
	)
	assert_false(result["ok"])
	assert_false(playground.photography.busy)
	result = await playground.photography.capture(
		playground.camera_rig.camera, Vector2i(3, 3), "/missing/p.png"
	)
	assert_eq(result["error"], "invalid_size")
	assert_false(playground.photography.busy)


func test_bookmark_limit_rejects_without_source_change() -> void:
	var draft: Dictionary = playground.document.snapshot()
	for i: int in range(30):
		var record: Dictionary = draft["camera_bookmarks"][0].duplicate(true)
		record["id"] = "limit_%d" % i
		draft["camera_bookmarks"].append(record)
	assert_true(playground.session.commit_snapshot(draft, "fill", playground._prepare_views)["ok"])
	playground.enter_photo()
	var before: Dictionary = playground.document.snapshot()
	playground._photo_action("bookmark")
	assert_eq_deep(playground.document.snapshot(), before)


func test_close_in_photo_restores_editor_before_unsaved_decision() -> void:
	var before: Dictionary = playground._camera_record()
	playground.enter_photo()
	playground.camera_rig.yaw += 1
	playground._notification(NOTIFICATION_WM_CLOSE_REQUEST)
	assert_false(playground.photo_active)
	assert_eq_deep(playground._camera_record(), before)
	assert_true(playground.hud.decision.visible)
	assert_eq(playground._intent, "quit")
	playground._decision_made("cancel")
	assert_eq(playground._intent, "")
