extends SceneTree
## Capture engine bus PCM, never microphone or device loopback.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var weather: String = "clear"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--mix-weather="):
			weather = argument.trim_prefix("--mix-weather=")
	if weather not in ["clear", "storm"]:
		push_error("Mix weather must be clear or storm")
		quit(1)
		return
	# Capture precedes Master; mute this process's device output throughout the probe.
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	var world: Node3D = load("res://app/living_root.tscn").instantiate()
	world.qa_mode = true
	root.add_child(world)
	world.calendar.speed = 0
	world.calendar.month = 7
	world.calendar.minute_of_day = 720
	world.calendar.automatic_weather = false
	world.calendar.weather = weather
	world.atmosphere.blend.advance(WeatherBlend.DURATION, world.calendar.sample())
	world._preference_changed("ambient_volume", 0.7)
	world._preference_changed("effects_volume", 0.65)
	world._preference_changed("music_volume", 0.5)
	world.seasonal_music.sync_calendar(world.calendar.sample())
	world.seasonal_music.bag.assign(["all_seasons"])
	var taps: Array[AudioEffectCapture] = []
	var bus_names: Array[String] = ["QaMusic", "QaAmbient", "QaWind"]
	for bus_name: String in bus_names:
		AudioServer.add_bus()
		var bus: int = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus, bus_name)
		AudioServer.set_bus_send(bus, "QaAmbient" if bus_name == "QaWind" else "Master")
		var tap: AudioEffectCapture = AudioEffectCapture.new()
		tap.buffer_length = 1
		AudioServer.add_bus_effect(bus, tap)
		taps.append(tap)
	for voice: AudioStreamPlayer in world.seasonal_music.voices:
		voice.bus = "QaMusic"
	for key: String in world.soundscape.loops:
		var voice: AudioStreamPlayer = world.soundscape.loops[key]
		voice.bus = "QaAmbient" if key == "forest" else "QaWind"
	world.soundscape.water.bus = "QaAmbient"
	await SceneShutdown.wait_wallclock(self, 8)
	var frames: Array[int] = [0, 0, 0]
	var energy: Array[float] = [0, 0, 0]
	var peaks: Array[float] = [0, 0, 0]
	for tap: AudioEffectCapture in taps:
		tap.clear_buffer()
	for i: int in range(20):
		await SceneShutdown.wait_wallclock(self, 0.2)
		for id: int in range(taps.size()):
			var samples: PackedVector2Array = taps[id].get_buffer(taps[id].get_frames_available())
			frames[id] += samples.size()
			for sample: Vector2 in samples:
				energy[id] += sample.length_squared()
				peaks[id] = maxf(peaks[id], maxf(absf(sample.x), absf(sample.y)))
	var music: SeasonalMusic = world.seasonal_music
	var result: Dictionary = {
		"driver": AudioServer.get_driver_name(),
		"weather": weather,
		"calendar_weather": world.calendar.weather,
		"automatic_weather": world.calendar.automatic_weather,
		"minute_of_day": world.calendar.minute_of_day,
		"weather_blend_age": world.atmosphere.blend.age,
		"duck": music.duck,
		"target_duck": music.target_duck,
		"wind_strength": world.soundscape.wind,
		"bus_order": bus_names,
		"frames": frames,
		"peaks": peaks,
		"music_rms": sqrt(energy[0] / maxf(frames[0] * 2, 1)),
		"ambient_rms": sqrt(energy[1] / maxf(frames[1] * 2, 1)),
		"wind_rms": sqrt(energy[2] / maxf(frames[2] * 2, 1)),
		"track": music.current,
		"position": music.voices[music.active].get_playback_position(),
		"music_volume_db": music.voices[music.active].volume_db,
		"mix_age": AudioServer.get_time_since_last_mix(),
		"master_muted": AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")),
		"capture_seconds": 4.0,
		"physical_listening_verified": false
	}
	world.soundscape.shutdown()
	await SceneShutdown.wait_wallclock(self, 0.4)
	await SceneShutdown.release_scene(world)
	for index: int in range(bus_names.size() - 1, -1, -1):
		AudioServer.remove_bus(AudioServer.get_bus_index(bus_names[index]))
	var suffix: String = "_storm" if weather == "storm" else ""
	var output: String = (
		"res://reports/music_mix_" + AudioServer.get_driver_name() + suffix + ".json"
	)
	var file: FileAccess = FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	print("MUSIC_MIX ", result)
	quit()
