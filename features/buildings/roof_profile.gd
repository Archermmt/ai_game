class_name RoofProfile
extends RefCounted
## Optional saved rise; absent fields retain the approved historical silhouette.


static func rise(home: Dictionary) -> float:
	return float(
		home.get("roof_rise", float(home["size"][0]) * (0.48 if home["shape"] == "round" else 0.38))
	)
