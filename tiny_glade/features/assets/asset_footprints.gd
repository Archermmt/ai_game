class_name AssetFootprints
extends RefCounted


static func dimensions(asset_id: String) -> Vector3:
	if asset_id in ["NAT-01", "NAT-02", "NAT-03"]:
		return Vector3(2.0, 4.5, 2.0)
	if asset_id == "PROP-01":
		return Vector3(2.0, 1.2, 0.7)
	if asset_id == "PROP-04":
		return Vector3(2.8, 1.7, 0.9)
	return Vector3(0.85, 0.8, 0.75)
