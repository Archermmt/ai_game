extends GutTest


func test_default_probabilities_sum_to_100_and_never_pick_forbidden_seasons() -> void:
	var weights: Dictionary = WeatherCycle.defaults()
	assert_true(WeatherCycle.valid(weights))
	for season: String in WeatherCycle.SEASONS:
		for slot: int in range(240):
			var weather: String = WeatherCycle.choose(1973, slot, season, weights)
			assert_true(WeatherCycle.allowed(season, weather))
	assert_false(WeatherCycle.allowed("spring", "snow"))
	assert_false(WeatherCycle.allowed("summer", "blizzard"))
	assert_false(WeatherCycle.allowed("winter", "rain"))
	assert_false(WeatherCycle.allowed("winter", "storm"))


func test_reweighting_zero_and_full_preserve_total_and_recover_other_weights() -> void:
	var weights: Dictionary = WeatherCycle.defaults()
	WeatherCycle.reweight(weights, "summer", "storm", 100)
	for slot: int in range(30):
		assert_eq(WeatherCycle.choose(8, slot, "summer", weights), "storm")
	WeatherCycle.reweight(weights, "summer", "storm", 70)
	assert_almost_eq(weights["summer"]["clear"], 30.0, 0.0001)
	assert_true(WeatherCycle.valid(weights))
	var before: Dictionary = weights.duplicate(true)
	WeatherCycle.reweight(weights, "summer", "snow", 100)
	assert_eq(weights, before)
	for i: int in range(120):
		WeatherCycle.reweight(weights, "summer", ["clear", "rain", "storm"][i % 3], (i * 17) % 101)
		assert_true(WeatherCycle.valid(weights))


func test_weighted_sampling_tracks_the_configured_ratio_and_seed() -> void:
	var weights: Dictionary = WeatherCycle.defaults()
	WeatherCycle.reweight(weights, "summer", "storm", 30)
	var storms: int = 0
	var differences: int = 0
	for slot: int in range(2000):
		var weather: String = WeatherCycle.choose(23, slot, "summer", weights)
		storms += int(weather == "storm")
		differences += int(weather != WeatherCycle.choose(24, slot, "summer", weights))
	assert_between(storms, 500, 700)
	assert_gt(differences, 500)


func test_skip_morning_rolls_month_season_and_year_even_while_paused() -> void:
	var clock: CalendarState = CalendarState.new()
	clock.month = 2
	clock.day = 30
	clock.minute_of_day = 1200
	clock.speed = 0
	clock.weather = "snow"
	assert_true(clock.next_morning())
	assert_eq([clock.month, clock.day], [3, 1])
	assert_eq(clock.minute_of_day, 360.0)
	assert_eq(clock.speed, 0.0)
	assert_true(WeatherCycle.allowed("spring", clock.weather))
	clock.month = 12
	clock.day = 30
	assert_true(clock.next_morning())
	assert_eq([clock.year, clock.month, clock.day], [2, 1, 1])
	assert_eq(clock.minute_of_day, 360.0)


func test_skip_at_maximum_date_is_atomic() -> void:
	var clock: CalendarState = CalendarState.new()
	clock.year = 99999
	clock.month = 12
	clock.day = 30
	var before: Dictionary = clock.record()
	assert_false(clock.next_morning())
	assert_eq(clock.record(), before)


func test_weather_changes_within_day_and_pause_does_not_draw() -> void:
	var clock: CalendarState = CalendarState.new()
	WeatherCycle.reweight(clock.weather_weights, "spring", "storm", 100)
	clock.weather = "clear"
	clock.align_weather()
	clock.advance(89)
	assert_eq(clock.weather, "clear")
	clock.advance(1)
	assert_eq(clock.weather, "storm")
	assert_eq(clock.day, 15)
	clock.speed = 0
	var before: Dictionary = clock.record()
	clock.advance(999999)
	assert_eq(clock.record(), before)


func test_coarse_fine_and_resumed_time_choose_the_same_final_weather() -> void:
	var coarse: CalendarState = CalendarState.new()
	var fine: CalendarState = CalendarState.new()
	coarse.advance(720)
	for i: int in range(720):
		fine.advance(1)
	assert_eq(coarse.record(), fine.record())
	var loaded: CalendarState = CalendarState.new()
	assert_true(loaded.restore(fine.record()))
	fine.advance(400)
	loaded.advance(400)
	assert_eq(fine.record(), loaded.record())


func test_manual_mode_and_legacy_saves_still_obey_season_compatibility() -> void:
	var clock: CalendarState = CalendarState.new()
	clock.automatic_weather = false
	clock.weather = "rain"
	clock.advance(1440)
	assert_eq(clock.weather, "rain")
	var legacy: Dictionary = clock.record()
	legacy.erase("weather_cycle")
	legacy["month"] = 1
	assert_true(clock.restore(legacy))
	assert_eq(clock.weather, "snow")
	assert_true(clock.automatic_weather)
	clock.month = 7
	clock.align_weather()
	assert_eq(clock.weather, "cloudy")


func test_invalid_cycle_is_rejected_without_replacing_the_clock() -> void:
	var clock: CalendarState = CalendarState.new()
	var before: Dictionary = clock.record()
	for bad_value: Variant in [-1, NAN, "random"]:
		var bad: Dictionary = before.duplicate(true)
		bad["weather_cycle"]["seed"] = bad_value
		assert_false(clock.restore(bad))
		assert_eq(clock.record(), before)
	var bad: Dictionary = before.duplicate(true)
	bad["weather_cycle"]["weights"]["winter"]["rain"] = 5
	assert_false(clock.restore(bad))
	assert_eq(clock.record(), before)
