class_name CalendarState
extends RefCounted
## Fictional360-day calendar. No operating-system clock and no geometry/history edits.

const SEASONS: Array[String] = [
	"winter",
	"winter",
	"spring",
	"spring",
	"spring",
	"summer",
	"summer",
	"summer",
	"autumn",
	"autumn",
	"autumn",
	"winter"
]
const WEATHER: Array[String] = WeatherCycle.TYPES
const MIN_SPEED: float = 1.0
const MAX_SPEED: float = 60.0
var year: int = 1
var month: int = 5
var day: int = 15
var minute_of_day: float = 630.0
var speed: float = 1.0
var weather: String = "clear"
var automatic_weather: bool = true
var weather_weights: Dictionary = WeatherCycle.defaults()
var weather_seed: int = 1973
var _weather_slot: int = -1


func _init() -> void:
	_weather_slot = weather_slot()


func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0 or speed == 0:
		return
	minute_of_day += delta * speed
	var days: int = floori(minute_of_day / 1440.0)
	minute_of_day = fposmod(minute_of_day, 1440.0)
	var ordinal: int = (year - 1) * 360 + (month - 1) * 30 + day - 1 + days
	if ordinal >= 99999 * 360:
		ordinal = 99999 * 360 - 1
		minute_of_day = 1439.999
		speed = 0
	year = 1 + ordinal / 360
	month = 1 + (ordinal % 360) / 30
	day = 1 + ordinal % 30
	_update_weather()


func season() -> String:
	return SEASONS[month - 1]


func record() -> Dictionary:
	return {
		"year": year,
		"month": month,
		"day": day,
		"minute_of_day": minute_of_day,
		"speed": speed,
		"weather": weather,
		"weather_cycle":
		{
			"automatic": automatic_weather,
			"seed": weather_seed,
			"slot": _weather_slot,
			"weights": weather_weights.duplicate(true)
		}
	}


func sample() -> Dictionary:
	var result: Dictionary = {
		"year": year,
		"month": month,
		"day": day,
		"minute_of_day": minute_of_day,
		"speed": speed,
		"weather": weather
	}
	result.merge(
		{
			"hour": floori(minute_of_day / 60),
			"minute": floori(minute_of_day) % 60,
			"season": season()
		}
	)
	return result


func restore(value: Dictionary) -> bool:
	if not valid(value):
		return false
	year = int(value["year"])
	month = int(value["month"])
	day = int(value["day"])
	minute_of_day = float(value["minute_of_day"])
	speed = float(value["speed"])
	weather = WeatherCycle.compatible(season(), value["weather"])
	var cycle: Dictionary = value.get("weather_cycle", {})
	automatic_weather = cycle.get("automatic", true)
	weather_seed = int(cycle.get("seed", 1973))
	weather_weights = cycle.get("weights", WeatherCycle.defaults()).duplicate(true)
	_weather_slot = int(cycle.get("slot", weather_slot()))
	return true


static func valid(value: Dictionary) -> bool:
	for key: String in ["year", "month", "day", "minute_of_day", "speed"]:
		if not value.get(key) is float and not value.get(key) is int:
			return false
		if not is_finite(float(value[key])):
			return false
	for key: String in ["year", "month", "day"]:
		if float(value[key]) != floorf(float(value[key])):
			return false
	if value.has("weather_cycle") and not _valid_cycle(value["weather_cycle"]):
		return false
	return (
		value["year"] >= 1
		and value["year"] <= 99999
		and value["month"] >= 1
		and value["month"] <= 12
		and value["day"] >= 1
		and value["day"] <= 30
		and value["minute_of_day"] >= 0
		and value["minute_of_day"] < 1440
		and (value["speed"] == 0 or (value["speed"] >= MIN_SPEED and value["speed"] <= MAX_SPEED))
		and value.get("weather") in WEATHER
	)


static func _valid_cycle(cycle: Variant) -> bool:
	if not cycle is Dictionary or not cycle.get("automatic") is bool:
		return false
	for key: String in ["seed", "slot"]:
		var value: Variant = cycle.get(key)
		if not value is int and not value is float:
			return false
		if (
			not is_finite(float(value))
			or value != floorf(float(value))
			or value < 0
			or value > 2147483647
		):
			return false
	return WeatherCycle.valid(cycle.get("weights"))


func weather_slot() -> int:
	return int(((year - 1) * 360 + (month - 1) * 30 + day - 1) * 8 + floori(minute_of_day / 180))


func align_weather() -> void:
	weather = WeatherCycle.compatible(season(), weather)
	_weather_slot = weather_slot()


func _update_weather(force: bool = false) -> void:
	var slot: int = weather_slot()
	weather = WeatherCycle.compatible(season(), weather)
	if automatic_weather and (force or slot != _weather_slot):
		weather = WeatherCycle.choose(weather_seed, slot, season(), weather_weights)
	_weather_slot = slot


func next_morning() -> bool:
	if year == 99999 and month == 12 and day == 30:
		return false
	var ordinal: int = (year - 1) * 360 + (month - 1) * 30 + day
	year = 1 + ordinal / 360
	month = 1 + (ordinal % 360) / 30
	day = 1 + ordinal % 30
	minute_of_day = 360
	_update_weather(true)
	return true
