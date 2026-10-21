extends SceneTree
## Native mixer tap measures actual PCM; no microphone access or formal save writes.

var world: Node3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	world = load("res://app/week_ten_root.tscn").instantiate()
	world.qa_mode = true
	root.add_child(world)
	await process_frame
	var tap: AudioEffectCapture = AudioEffectCapture.new()
	tap.buffer_length = 1.0
	var effect_index: int = AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0, tap)
	var audio: WorldAudio = world.soundscape
	audio.configure({"ambient_volume": 1.0, "effects_volume": 1.0, "music_volume": 1.0})
	var peak: float = 0
	var energy: float = 0
	var count: int = 0
	for index: int in range(24):
		audio.play_effect(["wood", "stone", "grass", "ui"][index % 4])
		await create_timer(0.15).timeout
		var samples: PackedVector2Array = tap.get_buffer(tap.get_frames_available())
		for sample: Vector2 in samples:
			peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
			energy += sample.length_squared()
		count += samples.size()
	audio.configure({"ambient_volume": 0.0, "effects_volume": 0.0, "music_volume": 0.0})
	await create_timer(0.3).timeout
	tap.clear_buffer()
	await create_timer(0.2).timeout
	var muted: PackedVector2Array = tap.get_buffer(tap.get_frames_available())
	var mute_peak: float = 0
	for sample: Vector2 in muted:
		mute_peak = maxf(mute_peak, maxf(absf(sample.x), absf(sample.y)))
	var report: Dictionary = {
		"audio_driver": AudioServer.get_driver_name(),
		"frames": count,
		"peak": peak,
		"rms": sqrt(energy / maxf(1, count * 2)),
		"mute_peak": mute_peak,
		"effect_events": audio.sequence,
		"families": ["wood", "stone", "grass", "ui"],
		"passed":
		count > 48000 and audio.sequence == 24 and peak > 0.001 and peak < 1 and mute_peak < 0.00001
	}
	var output: String = "reports/week_10_audio_native.json"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--audio-output="):
			output = argument.trim_prefix("--audio-output=")
	var file: FileAccess = FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	AudioServer.remove_bus_effect(0, effect_index)
	world.preferences.reset()
	world.free()
	await process_frame
	print("W10_NATIVE_AUDIO ", report)
	quit(0 if report["passed"] else 1)
