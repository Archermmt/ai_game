extends GutTest

func test_nearest_rank_p95_does_not_mislabel_the_maximum_of_twenty_edits() -> void:
	var samples: Array[float] = []
	for index: int in range(19):
		samples.append(80.0)
	samples.append(220.0)
	assert_eq(PerformanceSamples.percentile(samples), 80.0)
	assert_eq(samples.max(), 220.0)
	assert_eq(samples.size(), 20)


func test_percentile_empty_singleton_and_small_samples_are_defined() -> void:
	assert_eq(PerformanceSamples.percentile([]), 0.0)
	assert_eq(PerformanceSamples.percentile([7.0]), 7.0)
	assert_eq(PerformanceSamples.percentile([7.0, 9.0]), 9.0)


func test_percentile_unsorted_hundred_samples_preserves_input_order() -> void:
	var samples: Array[float] = []
	for index: int in range(100, 0, -1):
		samples.append(float(index))
	var before: Array[float] = samples.duplicate()
	assert_eq(PerformanceSamples.percentile(samples), 95.0)
	assert_eq_deep(samples, before)
