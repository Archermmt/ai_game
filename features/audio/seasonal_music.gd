class_name SeasonalMusic
extends Node
## Two bounded voices with smooth linear crossfades; no world-source edits.

const DIRECTORY: String = "res://assets/audio/seasonal_music/"
const TRACKS: Array[String] = [
	"winter",
	"all_seasons",
	"summer_flowers",
	"summer_breeze",
	"pastoral",
	"autumn",
	"stars",
	"sunny_pasture"
]
const FADE_SECONDS: float = 6.0
const MAX_GAIN: float = 0.32
var voices: Array[AudioStreamPlayer] = []
var streams: Dictionary = {}
var pool: Array[String] = []
var bag: Array[String] = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var current: String = ""
var active: int = -1
var envelopes: Array[float] = [0.0, 0.0]
var targets: Array[float] = [0.0, 0.0]
var volume: float = 0.5
var gain: float = 0.0
var duck: float = 1.0
var target_duck: float = 1.0
var stable_seconds: float = 0.0
var closing: bool = false
var stopped: bool = false


func _ready() -> void:
	rng.randomize()
	for track: String in TRACKS:
		var stream: AudioStreamMP3 = load(DIRECTORY + track + ".mp3")
		streams[track] = stream
	for i: int in range(2):
		var voice: AudioStreamPlayer = AudioStreamPlayer.new()
		voice.name = "SeasonalMusic%d" % i
		voice.volume_db = -80
		add_child(voice)
		voices.append(voice)


static func candidates(season: String, hour: float) -> Array[String]:
	if hour < 6 or hour >= 21:
		return ["stars", "summer_breeze" if season == "summer" else "winter", "all_seasons"]
	if hour >= 17:
		return ["pastoral", "autumn" if season == "autumn" else "all_seasons", "stars"]
	if hour < 9:
		return ["pastoral", "all_seasons", "winter" if season == "winter" else "sunny_pasture"]
	match season:
		"summer":
			return ["summer_flowers", "summer_breeze", "all_seasons"]
		"autumn":
			return ["autumn", "pastoral", "all_seasons"]
		"winter":
			return ["winter", "stars", "all_seasons"]
	return ["sunny_pasture", "pastoral", "all_seasons"]


func sync_calendar(sample: Dictionary) -> void:
	if closing or stopped:
		return
	var next: Array[String] = candidates(sample["season"], float(sample["minute_of_day"]) / 60)
	if next != pool:
		pool = next
		bag.clear()
		stable_seconds = 0
	target_duck = {"clear": 1.0, "cloudy": 0.85, "rain": 0.5, "snow": 0.65}[sample["weather"]]
	if float(sample["minute_of_day"]) < 360 or float(sample["minute_of_day"]) >= 1260:
		target_duck *= 0.7


func configure(value: float) -> void:
	volume = clampf(value, 0, 1)


func _pick() -> String:
	if bag.is_empty():
		bag.assign(pool)
		for i: int in range(bag.size() - 1, 0, -1):
			var j: int = rng.randi_range(0, i)
			var temporary: String = bag[i]
			bag[i] = bag[j]
			bag[j] = temporary
	if bag.size() > 1 and bag[-1] == current:
		var temporary: String = bag[0]
		bag[0] = bag[-1]
		bag[-1] = temporary
	return bag.pop_back()


func _next() -> void:
	if pool.is_empty() or closing or stopped:
		return
	var incoming: int = 0 if active != 0 else 1
	if targets[incoming] > 0 or envelopes[incoming] > 0:
		return
	current = _pick()
	voices[incoming].stream = streams[current]
	voices[incoming].volume_db = -80
	voices[incoming].play()
	targets = [0.0, 0.0]
	targets[incoming] = 1.0
	active = incoming


func _process(delta: float) -> void:
	if stopped:
		return
	stable_seconds += delta
	gain = move_toward(gain, 0.0 if closing else volume, delta / (1.2 if closing else 3.0))
	duck = move_toward(duck, target_duck, delta / 2.0)
	for i: int in range(voices.size()):
		envelopes[i] = move_toward(envelopes[i], targets[i], delta / FADE_SECONDS)
		var amplitude: float = envelopes[i] * gain * duck * MAX_GAIN
		voices[i].volume_db = linear_to_db(amplitude) if amplitude > 0.0001 else -80
		if envelopes[i] == 0 and targets[i] == 0:
			voices[i].stop()
	if gain == 0:
		for voice: AudioStreamPlayer in voices:
			voice.stop()
		active = -1
		envelopes = [0.0, 0.0]
		targets = [0.0, 0.0]
		return
	if closing or pool.is_empty() or stable_seconds < 2:
		return
	if active < 0:
		_next()
	elif envelopes[1 - active] == 0:
		var voice: AudioStreamPlayer = voices[active]
		var remaining: float = voice.stream.get_length() - voice.get_playback_position()
		if current not in pool or not voice.playing or remaining <= FADE_SECONDS:
			_next()


func fade_out() -> void:
	closing = true


func shutdown() -> void:
	stopped = true
	set_process(false)
	for voice: AudioStreamPlayer in voices:
		voice.stop()
		voice.stream = null
	streams.clear()


func _exit_tree() -> void:
	shutdown()
