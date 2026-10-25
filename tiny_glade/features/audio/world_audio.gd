class_name WorldAudio
extends Node
## Scene-owned voices; no global buses or world-source changes. Zero is a true mute.

const DIRECTORY: String = "res://assets/audio/"
const INTERVAL: float = 0.12
const WIND_GAIN: float = 0.4
var levels: Dictionary = {"ambient_volume": 0.7, "effects_volume": 0.65, "music_volume": 0.0}
var loops: Dictionary = {}
var effects: Array[AudioStreamPlayer] = []
var water: AudioStreamPlayer3D
var music: AudioStreamPlayer
var wind: float = 0.45
var elapsed: float = 0.0
var last_effect: float = -1.0
var sequence: int = 0
var played: Array[String] = []
var streams: Dictionary = {}
var ambient_gain: float = 1.0
var music_override: bool = false
var _fade: float = 0.0


func _ready() -> void:
	for key: String in ["forest", "wind_low", "wind_high"]:
		var voice: AudioStreamPlayer = AudioStreamPlayer.new()
		voice.name = key.to_pascal_case()
		voice.stream = _stream(key, true)
		voice.volume_db = -80
		add_child(voice)
		voice.play()
		loops[key] = voice
	water = AudioStreamPlayer3D.new()
	water.name = "PondWater"
	water.stream = _stream("water", true)
	water.unit_size = 4
	water.max_distance = 26
	water.volume_db = -80
	add_child(water)
	music = AudioStreamPlayer.new()
	music.name = "SparseMusic"
	music.stream = _stream("sparse_music", true)
	music.volume_db = -80
	add_child(music)
	for index: int in range(4):
		var voice: AudioStreamPlayer = AudioStreamPlayer.new()
		voice.name = "Effect%d" % index
		add_child(voice)
		effects.append(voice)
	# Import/load short sounds once, never on the publication path.
	for family: String in ["wood", "stone", "grass", "ui"]:
		for index: int in range(1, 4):
			_stream("%s_%d" % [family, index])


func _stream(key: String, looped: bool = false) -> AudioStreamWAV:
	if not streams.has(key):
		var stream: AudioStreamWAV = (
			load(DIRECTORY + ("forest_stereo" if key == "forest" else key) + ".wav").duplicate()
		)
		if looped:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_begin = 0
			stream.loop_end = int(stream.get_length() * stream.mix_rate)
		streams[key] = stream
	return streams[key]


func configure(values: Dictionary) -> void:
	for key: String in levels:
		levels[key] = float(values.get(key, levels[key]))
	if music != null and not music_override:
		if levels["music_volume"] > 0 and not music.playing:
			music.play()
		elif levels["music_volume"] == 0:
			music.stop()
		music.volume_db = _db(levels["music_volume"] * 0.5 * _fade)
	for voice: AudioStreamPlayer in effects:
		voice.volume_db = _db(levels["effects_volume"] * 0.8)
		if levels["effects_volume"] == 0:
			voice.stop()
	_apply_ambient()


func sync_world(snapshot: Dictionary) -> void:
	wind = float(snapshot["environment"]["wind_strength"])
	var pool: Dictionary = snapshot["pool"]
	if water != null:
		var center: Array = pool.get("center", [0, 0])
		water.position = Vector3(center[0], float(pool.get("water_y", 0.0)), center[1])
		if not pool.is_empty():
			if not water.playing:
				water.play()
		else:
			water.stop()


func _process(delta: float) -> void:
	elapsed += delta
	_fade = minf(1.0, _fade + delta * 1.5)
	_apply_ambient()
	if music != null and not music_override:
		music.volume_db = _db(levels["music_volume"] * 0.5 * _fade)


func _apply_ambient() -> void:
	var gains: Dictionary = wind_gains(wind)
	for key: String in loops:
		var target: float = (
			float(gains.get(key, 0.6)) * levels["ambient_volume"] * _fade * ambient_gain
		)
		var voice: AudioStreamPlayer = loops[key]
		voice.stream_paused = levels["ambient_volume"] == 0
		voice.volume_db = lerpf(voice.volume_db, _db(target), 0.15) if target > 0 else -80
	if water != null:
		water.stream_paused = levels["ambient_volume"] == 0
		water.volume_db = _db(levels["ambient_volume"] * 0.7 * _fade * ambient_gain)


static func wind_gains(strength: float) -> Dictionary:
	var amount: float = clampf(strength, 0, 1)
	return {"wind_low": sqrt(1.0 - amount) * WIND_GAIN, "wind_high": sqrt(amount) * WIND_GAIN}


static func _db(value: float) -> float:
	return linear_to_db(value) if value > 0 else -80.0


func play_effect(family: String, variant: int = 0) -> bool:
	if family not in ["wood", "stone", "grass", "ui"] or elapsed - last_effect < INTERVAL:
		return false
	if levels["effects_volume"] <= 0 or effects.is_empty():
		return false
	last_effect = elapsed
	var number: int = variant if variant in [1, 2, 3] else (sequence % 3 + 1)
	var key: String = "%s_%d" % [family, number]
	var voice: AudioStreamPlayer = effects[sequence % effects.size()]
	sequence += 1
	voice.stream = streams[key]
	voice.volume_db = _db(levels["effects_volume"] * 0.8)
	voice.play()
	played.append(key)
	if played.size() > 32:
		played.pop_front()
	return true


static func change_family(before: Dictionary, after: Dictionary) -> String:
	for pair: Array in [
		["buildings", "stone"],
		["paths", "stone"],
		["stairs", "stone"],
		["fences", "wood"],
		["bridges", "wood"],
		["terrain", "grass"],
		["pool", "grass"]
	]:
		if before.get(pair[0]) != after.get(pair[0]):
			return pair[1]
	if before.get("instances") != after.get("instances"):
		var previous: Dictionary = {}
		for item: Dictionary in before.get("instances", []):
			previous[item["id"]] = item
		for item: Dictionary in after.get("instances", []):
			if previous.get(item["id"], {}) != item:
				return _asset_family(item["asset_id"])
		for item: Dictionary in before.get("instances", []):
			if not after["instances"].any(
				func(i: Dictionary) -> bool: return i["id"] == item["id"]
			):
				return _asset_family(item["asset_id"])
	return ""


static func _asset_family(asset: String) -> String:
	if asset.begins_with("NAT-"):
		return "stone" if asset in ["NAT-08", "NAT-09"] else "grass"
	return "wood"


func shutdown() -> void:
	set_process(false)
	# Release active mixer playback references before the scene resources disappear.
	for child: Node in get_children():
		if child.has_method("shutdown"):
			child.shutdown()
		if child is AudioStreamPlayer or child is AudioStreamPlayer3D:
			child.stop()
			child.stream = null
	streams.clear()


func _exit_tree() -> void:
	shutdown()
