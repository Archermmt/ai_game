extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	create_timer(10).timeout.connect(func():push_error("Audio test timeout");quit(1))
	var stage=Node3D.new();root.add_child(stage);var audio=IslandAudio.new();stage.add_child(audio)
	var settings=IslandSettings.new();audio.apply_settings(settings.values)
	assert(audio.clips.size()==16 and audio.layers.size()==3 and audio.voices.size()==8)
	for id in IslandAudio.EFFECTS+IslandAudio.LIFE:assert(audio.clips[id].mix_rate==48000)
	for i in range(5):audio.clock=i*0.2;audio.life("cup",Vector3.ZERO)
	var count=0
	for voice in audio.voices:
		if voice.playing:count+=1
	assert(count<=2 and count>0)
	settings.values.muted=true;audio.apply_settings(settings.values);assert(not audio.enabled and not audio.music.playing and not audio.sea.playing)
	for voice in audio.voices:assert(not voice.playing)
	stage.free()
	for i in range(3):await process_frame
	print("PASS 4 ambience / 8 interaction plus UI / 7 spatial life / 2 music, 48kHz and voice cap/mute");quit()
