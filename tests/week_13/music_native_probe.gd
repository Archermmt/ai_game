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
	world.calendar.weather = "clear"
	var music: SeasonalMusic = world.seasonal_music
	world._preference_changed("music_volume", 0.5)
	await SceneShutdown.wait_wallclock(self, 4)
	var checks: Dictionary = {
		"calendar_selects_music": music.current in SeasonalMusic.candidates("summer", 12),
		"legacy_motif_stopped": not world.soundscape.music.playing,
		"music_playing_softly": music.active >= 0 and music.voices[music.active].playing,
		"fade_in_progress": music.envelopes[music.active] > 0 and music.envelopes[music.active] < 1,
		"quiet_gain": music.voices[music.active].volume_db < -24
	}
	world.calendar.weather = "rain"
	await SceneShutdown.wait_wallclock(self, 2.2)
	checks["rain_ducks_music"] = music.duck <= 0.51
	world._preference_changed("music_volume", 0.0)
	await SceneShutdown.wait_wallclock(self, 1.8)
	checks["settings_mute_fades_to_stop"] = music.gain == 0 and music.active == -1
	world._apply_preferences()
	checks["mute_survives_preferences_apply"] = world.preferences.values["music_volume"] == 0
	world._preference_changed("music_volume", 0.5)
	await SceneShutdown.wait_wallclock(self, 3)
	checks["settings_unmute_resumes"] = music.active >= 0 and music.voices[music.active].playing
	var chosen: String = music.current
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
				"physical_listening_verified": false
			},
			"\t"
		)
	)
	file.close()
	quit(0 if passed else 1)
