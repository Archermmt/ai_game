class_name WeatherBlend
extends RefCounted
## Presentation only; calendar remains the authoritative weather choice.

const DURATION: float = 18.0
const PROFILES: Dictionary = {
	"clear": [0.18, 1.0, 0.0008, 0.0, 0.0, 0.0],
	"cloudy": [0.78, 0.48, 0.0008, 0.0, 0.0, 0.0],
	"rain": [0.9, 0.48, 0.0018, 0.55, 0.0, 0.0],
	"snow": [0.85, 0.48, 0.0018, 0.0, 0.55, 0.0],
	"storm": [1.0, 0.18, 0.004, 1.0, 0.0, 0.0],
	"blizzard": [1.0, 0.23, 0.009, 0.0, 1.0, 0.0],
	"duststorm": [0.85, 0.28, 0.012, 0.0, 0.0, 1.0],
	"fog": [0.72, 0.35, 0.012, 0.0, 0.0, 0.0]
}
const KEYS: Array[String] = ["cloud", "energy", "fog", "rain", "snow", "dust"]
var current: Dictionary = {}
var origin: Dictionary = {}
var target: Dictionary = {}
var weather: String = ""
var season: String = ""
var age: float = DURATION


func advance(delta: float, state: Dictionary, frozen: bool = false) -> Dictionary:
	if weather != state["weather"] or season != state["season"]:
		weather = state["weather"]
		season = state["season"]
		origin = current.duplicate()
		target = {}
		for i: int in range(KEYS.size()):
			target[KEYS[i]] = float(PROFILES[weather][i])
		target["cover"] = maxf(0.28 if season == "winter" else 0, target["snow"] * 0.8)
		if current.is_empty():
			current = target.duplicate()
			origin = current.duplicate()
		age = 0
	if not frozen:
		age = minf(DURATION, age + maxf(0, delta))
	if age >= DURATION:
		current = target.duplicate()
		return current
	var progress: float = age / DURATION
	for key: String in target:
		var start: float = 0
		var end: float = 1
		if key in ["cloud", "energy"]:
			start = 0.2 if target["cloud"] < origin["cloud"] else 0
			end = 1 if start > 0 else 0.7
		elif key in ["rain", "snow", "dust"]:
			start = 0.25 if target[key] > origin[key] and origin["cloud"] < 0.6 else 0
			end = 1 if target[key] > origin[key] else 0.7
		current[key] = lerpf(origin[key], target[key], smoothstep(start, end, progress))
	return current
