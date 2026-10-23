extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _clock() -> float:
	return Time.get_ticks_usec() / 1000000.0 - AudioServer.get_time_since_last_mix()


func _live(refs: Array[WeakRef]) -> int:
	var count: int = 0
	for ref: WeakRef in refs:
		if ref.get_ref() != null:
			count += 1
	return count


func _run() -> void:
	var results: Array = []
	for mode: String in ["current_playing", "current_paused", "retain_stream", "unpause_stop"]:
		var audio: WorldAudio = WorldAudio.new()
		root.add_child(audio)
		audio.sync_world(TerrainField.pond(WorldDocument.new().snapshot(), Vector2.ZERO, 3))
		if mode in ["current_paused", "unpause_stop"]:
			audio.configure({"ambient_volume": 0.0})
		await create_timer(0.12, true, false, true).timeout
		var refs: Array[WeakRef] = []
		var states: Array = []
		for voice: Node in [audio.loops["forest"], audio.loops["wind_low"], audio.loops["wind_high"], audio.water]:
			states.append({"playing": voice.playing, "paused": voice.stream_paused, "volume_db": voice.volume_db})
			refs.append(weakref(voice.get_stream_playback()))
			refs.append(weakref(voice.stream))
		var clock_before: float = _clock()
		var since_before: float = AudioServer.get_time_since_last_mix()
		if mode == "retain_stream":
			audio.set_process(false)
			for child: Node in audio.get_children():
				if child is AudioStreamPlayer or child is AudioStreamPlayer3D:
					child.stop()
			await create_timer(0.4, true, false, true).timeout
		elif mode == "unpause_stop":
			for child: Node in audio.get_children():
				if child is AudioStreamPlayer or child is AudioStreamPlayer3D:
					child.stream_paused = false
		audio.shutdown()
		audio.queue_free()
		await create_timer(0.5, true, false, true).timeout
		results.append({"mode": mode, "states": states, "mix_clock_advanced_seconds": _clock() - clock_before,
			"time_since_last_mix_before": since_before, "time_since_last_mix_after": AudioServer.get_time_since_last_mix(),
			"live_playback_and_streams": _live(refs)})
	print(JSON.stringify({"driver": AudioServer.get_driver_name(), "results": results}, "\t"))
	quit()
