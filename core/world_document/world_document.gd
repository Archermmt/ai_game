class_name WorldDocument
extends RefCounted
## Authoritative serializable state. Generated nodes and meshes never live here.

const SCHEMA_VERSION: int = 1
const GENERATOR_VERSION: String = "w01.1"
const COLLECTIONS: Array[String] = [
	"buildings", "paths", "bridges", "attachments", "instances", "camera_bookmarks"
]

var state: Dictionary = {}


func _init(seed_value: String = "windhaven-forest-001") -> void:
	state = {
		"schema_version": SCHEMA_VERSION,
		"generator_version": GENERATOR_VERSION,
		"revision": 0,
		"world_seed": seed_value,
		"next_id": 1,
		"terrain": {"size_m": 64.0, "height_deltas": []},
		"pool": {},
		"buildings": [],
		"paths": [],
		"bridges": [],
		"attachments": [],
		"instances": [],
		"camera_bookmarks": [],
		"environment": {"dusk": false, "wind_strength": 0.45, "reduce_motion": false},
	}


func snapshot() -> Dictionary:
	return state.duplicate(true)


static func allocate_building(
	draft: Dictionary, position: Vector3, size: Vector3, shape: String = "rect"
) -> Dictionary:
	var sequence: int = int(draft["next_id"])
	var key: String = "%s:building:%d" % [draft["world_seed"], sequence]
	var record: Dictionary = {
		"id": key.sha256_text().left(24),
		"shape": shape,
		"position": [position.x, position.y, position.z],
		"size": [size.x, size.y, size.z],
		"yaw": 0.0,
		"seed": key.sha256_text(),
		"openings": [],
		"source": "manual",
		"locked": false,
	}
	draft["next_id"] = sequence + 1
	draft["buildings"].append(record)
	return record


static func validate(candidate: Dictionary) -> String:
	if not _is_data(candidate, 0):
		return "non_serializable_state"
	if candidate.get("schema_version", -1) != SCHEMA_VERSION:
		return "unsupported_schema"
	if candidate.get("generator_version", "") != GENERATOR_VERSION:
		return "unsupported_generator"
	if not candidate.get("world_seed") is String:
		return "invalid_seed"
	if not _integer(candidate.get("revision")) or candidate["revision"] < 0:
		return "invalid_revision"
	if not candidate.get("next_id") is float and not candidate.get("next_id") is int:
		return "invalid_sequence"
	if int(candidate["next_id"]) < 1:
		return "invalid_sequence"
	if float(candidate["next_id"]) != floorf(float(candidate["next_id"])):
		return "invalid_sequence"
	if not candidate.get("terrain") is Dictionary:
		return "invalid_terrain"
	if not candidate["terrain"].get("height_deltas") is Array:
		return "invalid_heights"
	for entry: Variant in candidate["terrain"]["height_deltas"]:
		if not entry is Array or entry.size() != 3:
			return "invalid_heights"
		if not _integer(entry[0]) or not _integer(entry[1]) or not _number(entry[2]):
			return "invalid_heights"
	if not candidate.get("environment") is Dictionary:
		return "invalid_environment"
	for flag: String in ["dusk", "reduce_motion"]:
		if not candidate["environment"].get(flag) is bool:
			return "invalid_environment"
	if candidate["environment"].has("aged") and not candidate["environment"]["aged"] is bool:
		return "invalid_environment"
	var wind: Variant = candidate["environment"].get("wind_strength")
	if not _number(wind) or wind < 0.0 or wind > 1.0:
		return "invalid_environment"
	var direction: Variant = candidate["environment"].get("wind_direction", 0.4)
	if not _number(direction):
		return "invalid_wind_direction"
	var lamps: Variant = candidate["environment"].get("lamp_probes", [])
	if not lamps is Array or lamps.size() > 32:
		return "invalid_lamp_probes"
	var lamp_ids: Dictionary = {}
	for lamp: Variant in lamps:
		if not lamp is Dictionary or not lamp.get("id") is String or lamp_ids.has(lamp["id"]):
			return "invalid_lamp_probes"
		lamp_ids[lamp["id"]] = true
		if not lamp.get("position") is Array or lamp["position"].size() != 3:
			return "invalid_lamp_probes"
		for value: Variant in lamp["position"]:
			if not _number(value):
				return "invalid_lamp_probes"
	for collection: String in COLLECTIONS:
		if not candidate.get(collection) is Array:
			return "invalid_collection:" + collection
	var ids: Dictionary = {}
	for item: Variant in candidate["buildings"]:
		if not item is Dictionary:
			return "invalid_building"
		var building: Dictionary = item
		if not building.get("id") is String or building["id"].is_empty():
			return "invalid_id"
		if ids.has(building["id"]):
			return "duplicate_id"
		ids[building["id"]] = true
		if building.get("shape", "") not in ["rect", "round"]:
			return "invalid_shape"
		for field: String in ["position", "size"]:
			if not building.get(field) is Array or building[field].size() != 3:
				return "invalid_transform"
			for number: Variant in building[field]:
				if not (number is float or number is int) or not is_finite(float(number)):
					return "invalid_number"
		var dimensions: Array = building["size"]
		if not _number(building.get("yaw", 0.0)) or building.get("yaw", 0.0) != 0.0:
			return "unsupported_rotation"
		if (
			building["shape"] == "round"
			and absf(float(dimensions[0]) - float(dimensions[2])) > 0.001
		):
			return "invalid_round_dimensions"
		if float(dimensions[0]) < 3.0 or float(dimensions[0]) > 12.0:
			return "invalid_width"
		if float(dimensions[2]) < 3.0 or float(dimensions[2]) > 12.0:
			return "invalid_depth"
		if float(dimensions[1]) < 2.4 or float(dimensions[1]) > 7.2:
			return "invalid_height"
		if not _valid_openings(building):
			return "invalid_openings"
		var origin: Array = building["position"]
		if absf(float(origin[0])) + float(dimensions[0]) * 0.5 > 24.0:
			return "outside_plot"
		if absf(float(origin[2])) + float(dimensions[2]) * 0.5 > 24.0:
			return "outside_plot"
	for a: int in range(candidate["buildings"].size()):
		var opening_error: String = BuildingContact.validate(
			candidate["buildings"][a], candidate["buildings"]
		)
		if not opening_error.is_empty():
			return opening_error
		for b: int in range(a + 1, candidate["buildings"].size()):
			if PlacementRules.overlaps(candidate["buildings"][a], candidate["buildings"][b]):
				return "building_overlap"
	var attachment_error: String = BuildingEdits.validate_attachments(candidate, ids)
	if not attachment_error.is_empty():
		return attachment_error
	var instance_error: String = InstanceEdits.validate(candidate, ids)
	if not instance_error.is_empty():
		return instance_error
	var fence_error: String = FenceGeometry.validate(candidate, ids)
	if not fence_error.is_empty():
		return fence_error
	var path_error: String = RiskEdits.validate_paths(candidate, ids)
	if not path_error.is_empty():
		return path_error
	var terrain_error: String = TerrainField.validate(candidate)
	if not terrain_error.is_empty():
		return terrain_error
	return GardenStructures.validate(candidate, ids)


static func _number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))


static func _integer(value: Variant) -> bool:
	return _number(value) and float(value) == floorf(float(value))


static func _valid_openings(building: Dictionary) -> bool:
	if not building.get("openings") is Array:
		return false
	for opening: Variant in building["openings"]:
		if not opening is Dictionary or opening.get("kind") not in ["rect", "arch", "round"]:
			return false
		for key: String in ["center", "width", "height"]:
			if not _number(opening.get(key)):
				return false
		var facade: Variant = opening.get("facade", 0)
		if not _integer(facade) or facade < 0 or facade > 3:
			return false
		var length: float = float(building["size"][0 if int(facade) % 2 == 0 else 2])
		if building["shape"] == "round":
			if facade != 0:
				return false
			length = PI * float(building["size"][0])
		var sill: Variant = opening.get("sill", 0.0)
		if not _number(sill) or sill < 0.0 or opening["width"] <= 0.0 or opening["height"] <= 0.0:
			return false
		if sill + opening["height"] > building["size"][1]:
			return false
		var center: float = float(opening["center"]) * length
		if center - opening["width"] * 0.5 < 0 or center + opening["width"] * 0.5 > length:
			return false
	return true


static func _is_data(value: Variant, depth: int) -> bool:
	if depth > 24:
		return false
	if value == null or value is bool or value is int or value is String:
		return true
	if value is float:
		return is_finite(value)
	if value is Array:
		for child: Variant in value:
			if not _is_data(child, depth + 1):
				return false
		return true
	if value is Dictionary:
		for key: Variant in value:
			if not key is String or not _is_data(value[key], depth + 1):
				return false
		return true
	return false
