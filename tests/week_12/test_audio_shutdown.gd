extends GutTest


func test_leaving_scene_releases_active_ambient_music_water_and_effect_streams() -> void:
	var audio: WorldAudio = WorldAudio.new()
	add_child(audio)
	audio.sync_world(ArtLayout.create())
	audio.configure({"music_volume": 0.4})
	audio.play_effect("wood")
	assert_true(audio.loops["forest"].playing)
	assert_true(audio.music.playing)
	assert_true(audio.water.playing)
	remove_child(audio)
	for child: Node in audio.get_children():
		if child is AudioStreamPlayer or child is AudioStreamPlayer3D:
			assert_false(child.playing)
			assert_null(child.stream)
	assert_true(audio.streams.is_empty())
	audio.free()


func test_shutdown_is_idempotent_before_scene_teardown() -> void:
	var audio: WorldAudio = WorldAudio.new()
	add_child(audio)
	audio.sync_world(ArtLayout.create())
	audio.shutdown()
	audio.shutdown()
	assert_false(audio.is_processing())
	assert_true(audio.streams.is_empty())
	assert_false(audio.loops["forest"].playing)
	assert_null(audio.water.stream)
	audio.free()
