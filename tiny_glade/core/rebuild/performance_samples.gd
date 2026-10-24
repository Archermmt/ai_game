class_name PerformanceSamples
extends RefCounted
## Nearest-rank percentile. Keep maximum and raw samples separately for startup spikes.


static func percentile(samples: Array[float], fraction: float = 0.95) -> float:
	if samples.is_empty():
		return 0.0
	var ordered: Array[float] = samples.duplicate()
	ordered.sort()
	var index: int = clampi(
		ceili(clampf(fraction, 0, 1) * ordered.size()) - 1, 0, ordered.size() - 1
	)
	return ordered[index]
