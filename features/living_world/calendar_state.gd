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
const WEATHER: Array[String] = ["clear", "cloudy", "rain", "snow"]
const SPEEDS: Array[float] = [0.0, 1.0, 5.0, 20.0, 60.0]
var year: int = 1
var month: int = 5
var day: int = 15
var minute_of_day: float = 630.0
var speed: float = 1.0
var weather: String = "clear"


func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0:
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


func season() -> String:
	return SEASONS[month - 1]


func record() -> Dictionary:
	return {
		"year": year,
		"month": month,
		"day": day,
		"minute_of_day": minute_of_day,
		"speed": speed,
		"weather": weather
	}


func sample() -> Dictionary:
	var result: Dictionary = record()
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
	weather = value["weather"]
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
	return (
		value["year"] >= 1
		and value["year"] <= 99999
		and value["month"] >= 1
		and value["month"] <= 12
		and value["day"] >= 1
		and value["day"] <= 30
		and value["minute_of_day"] >= 0
		and value["minute_of_day"] < 1440
		and value["speed"] in SPEEDS
		and value.get("weather") in WEATHER
	)
