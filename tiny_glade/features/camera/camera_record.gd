class_name CameraRecord
extends RefCounted


static func valid(value: Variant) -> bool:
	if not value is Dictionary or not value.get("target") is Array or value["target"].size() != 3:
		return false
	for number: Variant in value["target"]:
		if not numeric(number) or absf(float(number)) > 1000:
			return false
	for key: String in ["distance", "yaw", "pitch"]:
		if not numeric(value.get(key)):
			return false
	return (
		value["distance"] >= 7
		and value["distance"] <= 60
		and value["pitch"] >= 0.15
		and value["pitch"] <= 1.45
	)


static func numeric(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))
