extends GutTest


func _state(weather: String, season: String = "summer") -> Dictionary:
	return {"weather": weather, "season": season}


func test_first_sample_is_ready_without_a_startup_fade() -> void:
	var blend: WeatherBlend = WeatherBlend.new()
	assert_eq(blend.advance(0, _state("storm"))["rain"], 1.0)
	assert_eq(blend.current["energy"], 0.18)


func test_clouds_and_dimming_precede_the_first_rain() -> void:
	var blend: WeatherBlend = WeatherBlend.new()
	blend.advance(0, _state("clear"))
	blend.advance(0, _state("rain"))
	assert_eq(blend.current["rain"], 0.0)
	assert_eq(blend.current["energy"], 1.0)
	blend.advance(4, _state("rain"))
	assert_gt(blend.current["cloud"], 0.18)
	assert_lt(blend.current["energy"], 1.0)
	assert_eq(blend.current["rain"], 0.0)
	blend.advance(5, _state("rain"))
	assert_gt(blend.current["rain"], 0.0)
	assert_lt(blend.current["rain"], 0.55)


func test_all_weather_pairs_are_continuous_and_reach_their_targets() -> void:
	for a: String in WeatherBlend.PROFILES:
		for b: String in WeatherBlend.PROFILES:
			var blend: WeatherBlend = WeatherBlend.new()
			blend.advance(0, _state(a))
			var before: Dictionary = blend.current.duplicate()
			blend.advance(0, _state(b))
			assert_eq(blend.current, before)
			for i: int in range(18):
				blend.advance(1, _state(b))
				for key: String in blend.target:
					assert_between(
						blend.current[key],
						minf(before[key], blend.target[key]) - 0.00001,
						maxf(before[key], blend.target[key]) + 0.00001
					)
			assert_eq(blend.current, blend.target)


func test_rapid_retarget_starts_at_the_current_visual_without_a_jump() -> void:
	var blend: WeatherBlend = WeatherBlend.new()
	blend.advance(0, _state("clear"))
	blend.advance(8, _state("storm"))
	var before: Dictionary = blend.current.duplicate()
	blend.advance(0, _state("duststorm"))
	assert_eq(blend.current, before)
	blend.advance(18, _state("duststorm"))
	assert_eq(blend.current["rain"], 0.0)
	assert_eq(blend.current["dust"], 1.0)


func test_freeze_holds_transition_and_unfreeze_resumes() -> void:
	var blend: WeatherBlend = WeatherBlend.new()
	blend.advance(0, _state("clear"))
	blend.advance(7, _state("snow", "winter"))
	var before: Dictionary = blend.current.duplicate()
	blend.advance(100, _state("snow", "winter"), true)
	assert_eq(blend.current, before)
	blend.advance(18, _state("snow", "winter"))
	assert_eq(blend.current, blend.target)


func test_partitioned_time_matches_coarse_steps() -> void:
	var a: WeatherBlend = WeatherBlend.new()
	var b: WeatherBlend = WeatherBlend.new()
	a.advance(0, _state("clear"))
	b.advance(0, _state("clear"))
	a.advance(9, _state("blizzard", "winter"))
	for i: int in range(90):
		b.advance(0.1, _state("blizzard", "winter"))
	for key: String in a.current:
		assert_almost_eq(a.current[key], b.current[key], 0.00001)


func test_clearing_rain_ends_before_clouds_finish_clearing() -> void:
	var blend: WeatherBlend = WeatherBlend.new()
	blend.advance(0, _state("storm"))
	blend.advance(13, _state("clear"))
	assert_eq(blend.current["rain"], 0.0)
	assert_gt(blend.current["cloud"], 0.18)


func test_season_change_blends_snow_cover_without_mutating_source() -> void:
	var blend: WeatherBlend = WeatherBlend.new()
	var state: Dictionary = _state("clear")
	blend.advance(0, state)
	blend.advance(0, _state("clear", "winter"))
	assert_eq(blend.current["cover"], 0.0)
	blend.advance(9, _state("clear", "winter"))
	assert_between(blend.current["cover"], 0.01, 0.97)
	blend.advance(9, _state("clear", "winter"))
	assert_eq(blend.current["cover"], 0.98)
	# Cover is independent of snowfall, and thaws back to the original season.
	assert_eq(blend.current["snow"], 0.0)
	blend.advance(9, state)
	assert_between(blend.current["cover"], 0.01, 0.97)
	blend.advance(9, state)
	assert_eq(blend.current["cover"], 0.0)
	assert_eq(state, _state("clear"))


func test_already_overcast_weather_can_start_precipitation_when_retargeted_quickly() -> void:
	var blend: WeatherBlend = WeatherBlend.new()
	blend.advance(0, _state("cloudy"))
	blend.advance(3, _state("rain"))
	assert_gt(blend.current["rain"], 0.0)
	var rain: float = blend.current["rain"]
	blend.advance(3, _state("storm"))
	assert_gt(blend.current["rain"], rain)
