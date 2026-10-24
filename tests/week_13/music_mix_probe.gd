extends SceneTree
## Capture engine bus PCM, never microphone or device loopback.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world: Node3D = load("res://app/living_root.tscn").instantiate()
	world.qa_mode = true
	root.add_child(world)
	world.calendar.speed = 0
	world.calendar.minute_of_day = 720
	world.calendar.weather = "clear"
	world._preference_changed("music_volume", 0.5)
	world.seasonal_music.sync_calendar(world.calendar.sample())
	world.seasonal_music.bag.assign(["all_seasons"])
	var taps: Array[AudioEffectCapture] = []
	for id: int in range(2):
		AudioServer.add_bus()
		var bus: int = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus, "QaMusic" if id == 0 else "QaAmbient")
		var tap: AudioEffectCapture = AudioEffectCapture.new()
		tap.buffer_length = 1
		AudioServer.add_bus_effect(bus, tap)
		taps.append(tap)
	for voice: AudioStreamPlayer in world.seasonal_music.voices:
		voice.bus = "QaMusic"
	for voice: AudioStreamPlayer in world.soundscape.loops.values():
		voice.bus = "QaAmbient"
	world.soundscape.water.bus = "QaAmbient"
	await SceneShutdown.wait_wallclock(self, 8)
	var frames: Array[int] = [0, 0]
	var energy: Array[float] = [0, 0]
	var peaks: Array[float] = [0, 0]
	for tap: AudioEffectCapture in taps:
		tap.clear_buffer()
	for i: int in range(20):
		await SceneShutdown.wait_wallclock(self, 0.2)
		for id: int in range(2):
			var samples: PackedVector2Array = taps[id].get_buffer(taps[id].get_frames_available())
			frames[id] += samples.size()
			for sample: Vector2 in samples:
				energy[id] += sample.length_squared()
				peaks[id] = maxf(peaks[id], maxf(absf(sample.x), absf(sample.y)))
	var music: SeasonalMusic = world.seasonal_music
	var result: Dictionary = {
		"driver": AudioServer.get_driver_name(),
		"frames": frames,
		"peaks": peaks,
		"music_rms": sqrt(energy[0] / maxf(frames[0] * 2, 1)),
		"ambient_rms": sqrt(energy[1] / maxf(frames[1] * 2, 1)),
		"track": music.current,
		"position": music.voices[music.active].get_playback_position(),
		"music_volume_db": music.voices[music.active].volume_db,
		"mix_age": AudioServer.get_time_since_last_mix(),
		"physical_listening_verified": false
	}
	world.soundscape.shutdown()
	await SceneShutdown.wait_wallclock(self, 0.4)
	await SceneShutdown.release_scene(world)
	for name: String in ["QaMusic", "QaAmbient"]:
		AudioServer.remove_bus(AudioServer.get_bus_index(name))
	var output: String = "res://reports/music_mix_" + AudioServer.get_driver_name() + ".json"
	var file: FileAccess = FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	print("MUSIC_MIX ", result)
	quit()
