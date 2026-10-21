extends "res://tests/week_10/playground_test_base.gd"


func test_entry_keeps_accepted_art_and_three_accessible_audio_controls() -> void:
	assert_eq(playground.document.state["buildings"].size(), 3)
	assert_true(playground._planner is ArtViewPlan)
	assert_true(playground.soundscape is WorldAudio)
	assert_eq(playground.hud.volume_controls.size(), 3)
	for key: String in playground.hud.volume_controls:
		assert_eq(playground.hud.volume_controls[key].value, playground.preferences.values[key])
	assert_eq(playground.saves.directory, "user://qa_w10_scene")


func test_setting_volume_changes_sound_without_dirtying_source() -> void:
	var before: Dictionary = playground.document.snapshot()
	playground._preference_changed("ambient_volume", 0.0)
	assert_eq(playground.soundscape.loops["forest"].volume_db, -80.0)
	assert_eq(playground.hud.volume_controls["ambient_volume"].value, 0.0)
	assert_eq_deep(playground.document.state, before)
	playground._reset_preferences()
	assert_eq(playground.soundscape.levels["ambient_volume"], 0.7)
	assert_eq(playground.soundscape.levels["music_volume"], 0.0)


func test_preview_cancel_does_not_emit_placement_audio_or_mutate_source() -> void:
	var before: Dictionary = playground.document.snapshot()
	var draft: Dictionary = TerrainField.brush(before, Vector2(18, 18), 0.02)
	assert_true(playground.session.begin_gesture())
	assert_true(playground.session.update_gesture(draft))
	playground._on_published(draft, playground._prepare_views(draft))
	assert_true(playground.soundscape.played.is_empty())
	playground._cancel_edit()
	assert_eq_deep(playground.document.state, before)
	assert_true(playground.soundscape.played.is_empty())


func test_committed_terrain_edit_plays_once_and_undo_restores_source() -> void:
	var before: Dictionary = playground.document.snapshot()
	playground._submit_async(TerrainField.brush(before, Vector2(18, 18), 0.02), "grass")
	await _settle()
	assert_eq(playground.soundscape.played, ["grass_1"])
	playground._on_action(&"undo")
	assert_true(_same(playground.document.state, before))


func test_rejected_edit_is_silent_and_retains_source_and_art_views() -> void:
	var before: Dictionary = playground.document.snapshot()
	var cottage: Node3D = playground._live_units["building:" + before["buildings"][0]["id"]]
	var draft: Dictionary = before.duplicate(true)
	draft["buildings"][0]["size"][0] = 20.0
	playground._submit_async(draft, "rejected")
	await _settle()
	assert_eq_deep(playground.document.state, before)
	assert_same(playground._live_units["building:" + before["buildings"][0]["id"]], cottage)
	assert_true(playground.soundscape.played.is_empty())


func test_settings_150_reduced_motion_rebind_and_audio_coexist() -> void:
	var before: Dictionary = playground.document.snapshot()
	playground._preference_changed("ui_scale", 1.5)
	playground._preference_changed("reduce_motion", true)
	playground._preference_changed("music_volume", 0.2)
	var event: InputEventKey = InputEventKey.new()
	event.keycode = KEY_K
	event.alt_pressed = true
	playground._binding_requested("save_work", event)
	assert_eq(playground.hud._scale_value, 1.5)
	assert_true(playground.soundscape.music.playing)
	assert_eq(playground.preferences.values["bindings"]["save_work"]["key"], KEY_K)
	for material: ShaderMaterial in playground.wind_materials:
		assert_true(material.get_shader_parameter("reduce_motion"))
	assert_eq_deep(playground.document.state, before)


func test_save_load_rebuilds_art_and_updates_wind_audio() -> void:
	playground._change_environment("dusk", true)
	var before: Dictionary = playground.document.snapshot()
	playground._start_save(0, "第十周联调")
	await _settle()
	playground._change_environment("dusk", false)
	playground._start_load(0)
	await _settle()
	assert_true(_same(playground.document.state, before))
	assert_eq(playground.soundscape.wind, float(before["environment"]["wind_strength"]))
	assert_eq(playground.session.history_count(), 0)


func test_scaled_embedded_dialogs_are_owned_outside_scaled_hud_and_fit_viewport() -> void:
	playground._preference_changed("ui_scale", 1.5)
	for dialog: Window in [playground.hud.settings, playground.hud.library, playground.hud.entry]:
		assert_same(dialog.get_parent(), playground)
		assert_eq(dialog.content_scale_factor, 1.5)
		dialog.popup_centered()
		await get_tree().process_frame
		var bounds: Rect2i = Rect2i(Vector2i.ZERO, viewport.size)
		assert_true(bounds.encloses(Rect2i(dialog.position, dialog.size)))
		dialog.hide()


func test_actual_sliders_change_only_their_own_preference_and_do_not_recurse() -> void:
	var before: Dictionary = playground.document.snapshot()
	for key: String in ["ambient_volume", "effects_volume", "music_volume"]:
		var slider: HSlider = playground.hud.volume_controls[key]
		slider.value = 0.25
		assert_eq(playground.preferences.values[key], 0.25)
		assert_eq(playground.soundscape.levels[key], 0.25)
	assert_eq_deep(playground.document.state, before)
