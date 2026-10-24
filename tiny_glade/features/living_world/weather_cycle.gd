class_name WeatherCycle
extends RefCounted
## Seeded weighted draws by game-time slot, independent of frame rate and OS time.

const TYPES: Array[String] = [
	"clear", "cloudy", "rain", "snow", "storm", "blizzard", "duststorm", "fog"
]
const LABELS: Array[String] = ["晴", "阴", "雨", "雪", "暴风雨", "暴风雪", "沙尘暴", "雾"]
const SEASONS: Array[String] = ["spring", "summer", "autumn", "winter"]
const SLOT_MINUTES: int = 180


static func allowed(season: String, weather: String) -> bool:
	if season == "winter":
		return weather in ["clear", "cloudy", "snow", "blizzard", "fog"]
	return weather in ["clear", "cloudy", "rain", "storm", "duststorm", "fog"]


static func defaults() -> Dictionary:
	var result: Dictionary = {}
	var rows: Array = [
		[40, 25, 20, 0, 5, 0, 2, 8],
		[45, 20, 18, 0, 12, 0, 2, 3],
		[45, 25, 12, 0, 3, 0, 3, 12],
		[30, 25, 0, 25, 0, 8, 0, 12]
	]
	for i: int in range(SEASONS.size()):
		var weights: Dictionary = {}
		for j: int in range(TYPES.size()):
			weights[TYPES[j]] = float(rows[i][j])
		result[SEASONS[i]] = weights
	return result


static func valid(weights: Variant) -> bool:
	if not weights is Dictionary or weights.size() != 4:
		return false
	for season: String in SEASONS:
		var row: Variant = weights.get(season)
		if not row is Dictionary or row.size() != TYPES.size():
			return false
		var total: float = 0
		for weather: String in TYPES:
			var weight: Variant = row.get(weather)
			if not weight is float and not weight is int:
				return false
			if not is_finite(float(weight)) or weight < 0 or weight > 100:
				return false
			if not allowed(season, weather) and weight != 0:
				return false
			total += float(weight)
		if not is_equal_approx(total, 100.0):
			return false
	return true


static func reweight(weights: Dictionary, season: String, weather: String, value: float) -> void:
	if not allowed(season, weather) or not is_finite(value):
		return
	var row: Dictionary = weights[season]
	var selected: float = clampf(value, 0, 100)
	var others: float = 0
	for key: String in TYPES:
		if key != weather:
			others += float(row[key])
	row[weather] = selected
	for key: String in TYPES:
		if key != weather:
			row[key] = float(row[key]) * (100 - selected) / others if others > 0 else 0.0
	if others == 0 and selected < 100:
		row["cloudy" if weather == "clear" else "clear"] = 100 - selected


static func choose(seed_value: int, slot: int, season: String, weights: Dictionary) -> String:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash("%d:%d:%s" % [seed_value, slot, season])
	var roll: float = rng.randf() * 100.0
	var accumulated: float = 0
	var fallback: String = "clear"
	for weather: String in TYPES:
		var weight: float = float(weights[season][weather])
		if weight > 0 and allowed(season, weather):
			fallback = weather
			accumulated += weight
			if roll < accumulated:
				return weather
	return fallback


static func compatible(season: String, weather: String) -> String:
	if allowed(season, weather):
		return weather
	if season == "winter":
		return {"rain": "snow", "storm": "blizzard", "duststorm": "fog"}.get(weather, "cloudy")
	return "cloudy"
