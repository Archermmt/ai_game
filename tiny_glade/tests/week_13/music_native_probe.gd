extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world: Node3D = load("res://app/living_root.tscn").instantiate()
	world.qa_mode = true
	root.add_child(world)
	world.calendar.speed = 0
	world.calendar.month = 7
	world.calendar.minute_of_day = 720
	world.calendar.automatic_weather = false
	world.calendar.weather = "clear"
	var music: SeasonalMusic = world.seasonal_music
	world._preference_changed("music_volume", 0.5)
	var diagnostics: Dictionary = {"initial": _snapshot(music)}
	# Preserve the old checkpoint: renderer startup can consume wall time before
	# the music's process-delta debounce and envelopes advance by the same amount.
	await SceneShutdown.wait_wallclock(self, 4)
	diagnostics["original_four_second_checkpoint"] = _snapshot(music)
	await _wait_for_state(music, &"fade", 30)
	diagnostics["fade_checkpoint"] = _snapshot(music)
	var playing: bool = music.active >= 0 and music.voices[music.active].playing
	var envelope: float = music.envelopes[music.active] if music.active >= 0 else 0.0
	var checks: Dictionary = {
		"calendar_selects_music": music.current in SeasonalMusic.candidates("summer", 12),
		"legacy_motif_stopped": not world.soundscape.music.playing,
		"music_playing_softly": playing,
		"fade_in_progress": playing and envelope > 0 and envelope < 1,
		"fade_in_retains_headroom":
		(
			playing
			and music.voices[music.active].volume_db < linear_to_db(SeasonalMusic.MAX_GAIN * 0.5)
		)
	}
	world.calendar.weather = "rain"
	await _wait_for_state(music, &"rain", 5)
	diagnostics["rain_checkpoint"] = _snapshot(music)
	checks["rain_preserves_audible_music"] = music.duck >= 0.75 and music.duck < 1.0
	world._preference_changed("music_volume", 0.0)
	await _wait_for_state(music, &"muted", 5)
	diagnostics["mute_checkpoint"] = _snapshot(music)
	checks["settings_mute_fades_to_stop"] = music.gain == 0 and music.active == -1
	world._apply_preferences()
	checks["mute_survives_preferences_apply"] = world.preferences.values["music_volume"] == 0
	world._preference_changed("music_volume", 0.5)
	await _wait_for_state(music, &"resumed", 8)
	diagnostics["resume_checkpoint"] = _snapshot(music)
	checks["settings_unmute_resumes"] = music.active >= 0 and music.voices[music.active].playing
	var chosen: String = music.current
	var water_max_db: float = world.soundscape.water.max_db
	var automatic_weather: bool = world.calendar.automatic_weather
	diagnostics["calendar"] = world.calendar.record()
	world.soundscape.shutdown()
	checks["shutdown_stops_and_releases"] = music.stopped and music.streams.is_empty()
	for voice: AudioStreamPlayer in music.voices:
		checks["shutdown_stops_and_releases"] = (
			checks["shutdown_stops_and_releases"] and not voice.playing and voice.stream == null
		)
	await SceneShutdown.wait_wallclock(self, 0.4)
	await SceneShutdown.release_scene(world)
	var passed: bool = not checks.values().has(false)
	var file: FileAccess = FileAccess.open(
		"res://reports/seasonal_music_native.json", FileAccess.WRITE
	)
	file.store_string(
		JSON.stringify(
			{
				"checks": checks,
				"passed": passed,
				"track": chosen,
				"audio": AudioServer.get_driver_name(),
				"diagnostics": diagnostics,
				"water_max_db": water_max_db,
				"automatic_weather": automatic_weather,
				"physical_listening_verified": false
			},
			"\t"
		)
	)
	file.close()
	quit(0 if passed else 1)


func _snapshot(music: SeasonalMusic) -> Dictionary:
	return {
		"wallclock_ms": Time.get_ticks_msec(),
		"current": music.current,
		"pool": music.pool.duplicate(),
		"gain": music.gain,
		"envelopes": music.envelopes.duplicate(),
		"stable_seconds": music.stable_seconds,
		"active": music.active,
		"playing": music.active >= 0 and music.voices[music.active].playing,
		"duck": music.duck,
		"target_duck": music.target_duck
	}


func _wait_for_state(music: SeasonalMusic, state: StringName, timeout_seconds: float) -> void:
	var deadline: int = Time.get_ticks_usec() + ceili(timeout_seconds * 1000000.0)
	while Time.get_ticks_usec() < deadline:
		var playing: bool = music.active >= 0 and music.voices[music.active].playing
		var envelope: float = music.envelopes[music.active] if music.active >= 0 else 0.0
		match state:
			&"fade":
				if (
					playing
					and music.current in SeasonalMusic.candidates("summer", 12)
					and envelope >= 0.1
					and envelope <= 0.9
				):
					return
			&"rain":
				if music.target_duck == 0.8 and is_equal_approx(music.duck, music.target_duck):
					return
			&"muted":
				if music.gain == 0 and music.active == -1:
					return
			&"resumed":
				if playing and envelope > 0:
					return
		await process_frame
