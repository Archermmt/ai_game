extends GutTest
## A stopped player is insufficient: verify the mixer's final references disappear.


func _mix_stamp() -> float:
	return Time.get_ticks_usec() / 1000000.0 - AudioServer.get_time_since_last_mix()


func _live_count(refs: Array[WeakRef]) -> int:
	var count: int = 0
	for ref: WeakRef in refs:
		if ref.get_ref() != null:
			count += 1
	return count


func _verify_release(paused: bool) -> void:
	var audio: WorldAudio = WorldAudio.new()
	add_child_autofree(audio)
	audio.sync_world(TerrainField.pond(WorldDocument.new().snapshot(), Vector2.ZERO, 3))
	if paused:
		audio.configure({"ambient_volume": 0.0})
	await get_tree().create_timer(0.12, true, false, true).timeout
	var refs: Array[WeakRef] = []
	for voice: Node in [
		audio.loops["forest"], audio.loops["wind_low"], audio.loops["wind_high"], audio.water
	]:
		assert_eq(voice.stream_paused, paused)
		refs.append(weakref(voice.get_stream_playback()))
		refs.append(weakref(voice.stream))
	assert_eq(_live_count(refs), 8)
	var mix_before: float = _mix_stamp()
	audio.shutdown()
	assert_false(audio.is_processing())
	assert_true(audio.streams.is_empty())
	var deadline: int = Time.get_ticks_msec() + 2000
	while (
		(_mix_stamp() - mix_before < 0.05 or _live_count(refs) > 0)
		and Time.get_ticks_msec() < deadline
	):
		await get_tree().create_timer(0.05, true, false, true).timeout
	assert_gt(_mix_stamp() - mix_before, 0.04, "The actual audio mix clock must advance")
	assert_eq(_live_count(refs), 0, "The mixer must release all four playback/stream pairs")


func test_playing_ambient_shutdown_releases_mixer_playback_and_stream_references() -> void:
	await _verify_release(false)


func test_paused_ambient_shutdown_releases_mixer_playback_and_stream_references() -> void:
	await _verify_release(true)
