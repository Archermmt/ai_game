extends GutTest

var music: SeasonalMusic


func before_each() -> void:
	music = SeasonalMusic.new()
	add_child(music)
	music.set_process(false)
	music.rng.seed = 4837


func after_each() -> void:
	music.shutdown()
	await SceneShutdown.wait_wallclock(get_tree(), 0.4)
	music.free()


func test_every_season_and_time_has_three_distinct_valid_candidates() -> void:
	for season: String in ["spring", "summer", "autumn", "winter"]:
		for hour: float in [0.0, 6.0, 12.0, 18.0, 23.0]:
			var pool: Array[String] = SeasonalMusic.candidates(season, hour)
			assert_eq(pool.size(), 3)
			for track: String in pool:
				assert_true(track in SeasonalMusic.TRACKS)
			assert_ne(pool[0], pool[1])
			assert_ne(pool[0], pool[2])
			assert_ne(pool[1], pool[2])
	assert_true("summer_flowers" in SeasonalMusic.candidates("summer", 12))
	assert_true("stars" in SeasonalMusic.candidates("spring", 23))
	assert_true("winter" in SeasonalMusic.candidates("winter", 12))


func test_shuffle_bag_plays_all_candidates_without_immediate_repeats() -> void:
	music.pool = SeasonalMusic.candidates("summer", 12)
	for cycle: int in range(20):
		var seen: Array[String] = []
		for i: int in range(3):
			var picked: String = music._pick()
			assert_ne(picked, music.current)
			assert_false(picked in seen)
			seen.append(picked)
			music.current = picked
		assert_eq(seen.size(), 3)


func test_fade_in_crossfade_and_mute_have_bounded_continuous_gain() -> void:
	music.configure(1)
	music.sync_calendar(_sample("summer", 720, "clear"))
	music._process(3)
	assert_eq(music.gain, 1.0)
	assert_true(music.voices[music.active].playing)
	assert_eq(music.envelopes[music.active], 0.0)
	music._process(3)
	assert_almost_eq(music.envelopes[music.active], 0.5, 0.0001)
	music._process(3)
	var old: String = music.current
	music._next()
	assert_ne(music.current, old)
	music._process(3)
	assert_almost_eq(music.envelopes[0] + music.envelopes[1], 1.0, 0.0001)
	for voice: AudioStreamPlayer in music.voices:
		assert_lte(voice.volume_db, linear_to_db(SeasonalMusic.MAX_GAIN))
	music.configure(0)
	music._process(1)
	assert_gt(music.gain, 0.0)
	music._process(3)
	assert_eq(music.gain, 0.0)
	for voice: AudioStreamPlayer in music.voices:
		assert_false(voice.playing)
		assert_eq(voice.volume_db, -80.0)


func test_context_debounce_and_weather_ducking() -> void:
	music.sync_calendar(_sample("summer", 720, "clear"))
	music._process(1)
	assert_eq(music.active, -1)
	music.sync_calendar(_sample("winter", 0, "rain"))
	music._process(1)
	assert_eq(music.active, -1)
	music._process(2)
	assert_true(music.current in SeasonalMusic.candidates("winter", 0))
	assert_almost_eq(music.target_duck, 0.35, 0.0001)
	assert_almost_eq(music.duck, 0.35, 0.0001)


func test_all_streams_are_full_length_non_looping_music() -> void:
	assert_eq(music.streams.size(), 8)
	for stream: AudioStreamMP3 in music.streams.values():
		assert_gt(stream.get_length(), 60.0)
		assert_false(stream.loop)


func test_quit_fades_then_shutdown_releases_both_voices_idempotently() -> void:
	music.configure(1)
	music.sync_calendar(_sample("spring", 600, "clear"))
	music._process(3)
	music._process(6)
	music.fade_out()
	music._process(0.6)
	assert_gt(music.gain, 0.0)
	assert_lt(music.gain, 1.0)
	music._process(0.7)
	assert_eq(music.gain, 0.0)
	music.shutdown()
	music.shutdown()
	assert_true(music.streams.is_empty())
	assert_false(music.is_processing())
	for voice: AudioStreamPlayer in music.voices:
		assert_false(voice.playing)
		assert_null(voice.stream)


func _sample(season: String, minute: float, weather: String) -> Dictionary:
	return {"season": season, "minute_of_day": minute, "weather": weather}
