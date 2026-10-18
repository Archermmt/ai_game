class_name WorldRebuild
extends RefCounted
## Evaluation produces detached plain arrays only. Resource creation is a main-thread step.


static func evaluate(snapshot: Dictionary) -> Dictionary:
	var error: String = WorldDocument.validate(snapshot)
	if not error.is_empty():
		return {"ok": false, "error": error}
	var field: TerrainField = TerrainField.new(snapshot)
	var result: Dictionary = {
		"ok": true, "building_arrays": [], "terrain_arrays": [], "supports": []
	}
	for building: Dictionary in snapshot["buildings"]:
		result["building_arrays"].append(
			BuildingGeometry.build_arrays(building, snapshot["buildings"])
		)
		var p: Array = building["position"]
		var size: Array = building["size"]
		var minimum: float = float(p[1])
		for index: int in range(65):
			var angle: float = TAU * float(index) / 64.0
			var direction: Vector2 = Vector2(sin(angle), cos(angle))
			if building["shape"] == "rect":
				direction /= maxf(absf(direction.x), absf(direction.y))
			var point: Vector2 = Vector2(p[0], p[2]) + direction * Vector2(size[0], size[2]) * 0.5
			minimum = minf(minimum, field.height_at(point))
		result["supports"].append(
			{
				"bottom": minimum,
				"floor": float(p[1]),
				"perimeter": SupportGeometry.perimeter(building, field)
			}
		)
	for z: int in range(-32, 32, 8):
		for x: int in range(-32, 32, 8):
			result["terrain_arrays"].append(TerrainGeometry.chunk(field, Vector2(x, z)))
	result["path_arrays"] = PathGeometry.arrays(snapshot)
	return result


static func materialize(data: Dictionary, cache: Dictionary = {}) -> Dictionary:
	if not data.get("ok", false):
		return data
	var result: Dictionary = {
		"ok": true, "meshes": [], "terrain_meshes": [], "supports": data["supports"]
	}
	for pair: Array in [["building_arrays", "meshes"], ["terrain_arrays", "terrain_meshes"]]:
		var array_key: String = pair[0]
		var mesh_key: String = pair[1]
		for index: int in range(data[array_key].size()):
			if (
				index < cache.get(array_key, []).size()
				and data[array_key][index] == cache[array_key][index]
			):
				result[mesh_key].append(cache[mesh_key][index])
			else:
				result[mesh_key].append(BuildingGeometry.mesh_from_arrays(data[array_key][index]))
		result[array_key] = data[array_key]
	result["path_mesh"] = null
	if data.get("path_arrays", []).size() > 0 and data["path_arrays"][Mesh.ARRAY_VERTEX].size() > 0:
		result["path_mesh"] = BuildingGeometry.mesh_from_arrays(data["path_arrays"])
	return result
