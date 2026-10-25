extends GutTest

var audio: WorldAudio


func before_each() -> void:
	audio = WorldAudio.new()
	add_child_autofree(audio)


func test_scene_owns_bounded_voices_and_loads_all_families() -> void:
	assert_eq(audio.effects.size(), 4)
	assert_eq(audio.loops.size(), 3)
	assert_eq(audio.streams.size(), 17)
	for key: String in ["forest", "wind_low", "wind_high", "water"]:
		assert_eq(audio.streams[key].loop_mode, AudioStreamWAV.LOOP_FORWARD)
	assert_false(audio.music.playing)


func test_wind_blend_is_continuous_equal_power_at_extremes_and_middle() -> void:
	for strength: float in [0.0, 0.25, 0.5, 0.75, 1.0]:
		var gains: Dictionary = WorldAudio.wind_gains(strength)
		assert_almost_eq(pow(gains["wind_low"], 2) + pow(gains["wind_high"], 2), 0.16, 0.0001)
	assert_eq(WorldAudio.wind_gains(0)["wind_high"], 0.0)
	assert_eq(WorldAudio.wind_gains(1)["wind_low"], 0.0)


func test_zero_wind_keeps_forest_and_low_wind() -> void:
	audio.wind = 0
	audio._process(1)
	assert_true(audio.loops["forest"].playing)
	assert_gt(audio.loops["forest"].volume_db, -80.0)
	assert_eq(audio.loops["wind_high"].volume_db, -80.0)


func test_brush_rate_limit_rejects_flood_and_cycles_three_variants() -> void:
	assert_true(audio.play_effect("grass"))
	for index: int in range(30):
		assert_false(audio.play_effect("grass"))
	for index: int in range(2):
		audio.elapsed += 0.13
		assert_true(audio.play_effect("grass"))
	assert_eq(audio.played, ["grass_1", "grass_2", "grass_3"])


func test_music_can_be_enabled_muted_and_reenabled_without_changing_world() -> void:
	var world: Dictionary = ArtLayout.create()
	var before: Dictionary = world.duplicate(true)
	audio.sync_world(world)
	audio.configure({"music_volume": 0.3})
	assert_true(audio.music.playing)
	audio.configure({"music_volume": 0.0})
	assert_false(audio.music.playing)
	assert_eq(audio.music.volume_db, -80.0)
	audio.configure({"music_volume": 0.2})
	assert_true(audio.music.playing)
	assert_eq_deep(world, before)


func test_mute_applies_to_all_voices_immediately() -> void:
	audio.play_effect("wood")
	audio.configure({"ambient_volume": 0.0, "effects_volume": 0.0, "music_volume": 0.0})
	for key: String in audio.loops:
		assert_eq(audio.loops[key].volume_db, -80.0)
		assert_true(audio.loops[key].stream_paused)
	for voice: AudioStreamPlayer in audio.effects:
		assert_eq(voice.volume_db, -80.0)
		assert_false(voice.playing)
	assert_eq(audio.water.volume_db, -80.0)
	assert_false(audio.play_effect("stone"))


func test_pond_is_localized_and_stops_when_deleted() -> void:
	var world: Dictionary = ArtLayout.create()
	audio.sync_world(world)
	assert_true(audio.water.playing)
	assert_eq(audio.water.position.x, float(world["pool"]["center"][0]))
	assert_eq(audio.water.position.z, float(world["pool"]["center"][1]))
	assert_eq(audio.water.max_distance, 26.0)
	world["pool"] = {}
	audio.sync_world(world)
	assert_false(audio.water.playing)


func test_material_families_and_no_sound_for_unchanged_world() -> void:
	var before: Dictionary = ArtLayout.create()
	assert_eq(WorldAudio.change_family(before, before), "")
	for pair: Array in [["buildings", "stone"], ["fences", "wood"], ["instances", "grass"]]:
		var after: Dictionary = before.duplicate(true)
		after[pair[0]].clear()
		assert_eq(WorldAudio.change_family(before, after), pair[1])


func test_ui_has_three_distinct_variants_and_rejects_unknown_families() -> void:
	for index: int in range(1, 4):
		audio.elapsed += 0.2
		assert_true(audio.play_effect("ui", index))
	assert_eq(audio.played, ["ui_1", "ui_2", "ui_3"])
	assert_false(audio.play_effect("wind_chime"))


func test_startup_has_quiet_fade_and_bounded_event_history() -> void:
	assert_eq(audio.loops["forest"].volume_db, -80.0)
	for index: int in range(100):
		audio.elapsed += 0.2
		audio.play_effect("stone")
	assert_eq(audio.played.size(), 32)
