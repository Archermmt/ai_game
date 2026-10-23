class_name LocalRebuild
extends RefCounted
## One worker-owned cache, or a separate main-thread cache; never shared across threads.

const HeightIndex = preload("res://core/rebuild/height_delta_index.gd")


static func evaluate(snapshot: Dictionary, cache: Dictionary) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	var error: String = WorldDocument.validate(snapshot)
	if not error.is_empty():
		return {"ok": false, "error": error}
	var field: TerrainField = TerrainField.new(snapshot)
	var height_index: HeightIndex = HeightIndex.new(snapshot)
	var versions: Dictionary = {}
	var reused: Array[String] = []
	var generated: Array[String] = []
	var memo: Callable = func(id_value: String, signature: String, build: Callable) -> Variant:
		versions[id_value] = signature
		if cache.has(id_value) and cache[id_value]["key"] == signature:
			reused.append(id_value)
			return cache[id_value]["data"]
		generated.append(id_value)
		var value: Variant = build.call()
		cache[id_value] = {"key": signature, "data": value}
		return value
	var result: Dictionary = {
		"ok": true,
		"snapshot": snapshot,
		"versions": versions,
		"building_arrays": [],
		"supports": [],
		"terrain_arrays": [],
		"terrain_rebuilt": 0
	}
	for home: Dictionary in snapshot["buildings"]:
		var region: Rect2 = DirtyGraph.bounds(home)
		result["building_arrays"].append(
			memo.call(
				"building:" + home["id"],
				DirtyGraph.key([home, DirtyGraph.nearby(snapshot["buildings"], region)]),
				func() -> Array: return BuildingGeometry.build_arrays(home, snapshot["buildings"])
			)
		)
		result["supports"].append(
			memo.call(
				"support:" + home["id"],
				DirtyGraph.key([home, DirtyGraph.field_key(snapshot, region, height_index)]),
				func() -> Dictionary: return _support(home, field)
			)
		)
	for z: int in range(-32, 32, 8):
		for x: int in range(-32, 32, 8):
			var origin: Vector2 = Vector2(x, z)
			var id_value: String = "terrain:%d" % result["terrain_arrays"].size()
			result["terrain_arrays"].append(
				memo.call(
					id_value,
					TerrainChunks.signature(snapshot, origin, height_index),
					func() -> Array: return TerrainGeometry.chunk(field, origin)
				)
			)
			if id_value in generated:
				result["terrain_rebuilt"] += 1
	var paths: Array = snapshot["paths"]
	var path_region: Rect2 = DirtyGraph.union(paths)
	result["path_arrays"] = memo.call(
		"path",
		DirtyGraph.key(
			[
				paths,
				DirtyGraph.nearby(snapshot["buildings"], path_region),
				DirtyGraph.field_key(snapshot, path_region, height_index)
			]
		),
		func() -> Array: return PathGeometry.arrays(snapshot)
	)
	var fences: Array = snapshot.get("fences", [])
	var fence_region: Rect2 = DirtyGraph.union(fences)
	result["fence_arrays"] = memo.call(
		"fence",
		DirtyGraph.key(
			[
				fences,
				DirtyGraph.nearby(paths, fence_region),
				DirtyGraph.field_key(snapshot, fence_region, height_index)
			]
		),
		func() -> Array: return FenceGeometry.build(snapshot)
	)
	result["water_arrays"] = memo.call(
		"water",
		DirtyGraph.key(snapshot["pool"]),
		func() -> Array: return PondShape.water_arrays(snapshot["pool"])
	)
	result["structures"] = {"bridge": [], "stair": [], "issues": []}
	for pair: Array in [["bridges", "bridge"], ["stairs", "stair"]]:
		for item: Dictionary in snapshot.get(pair[0], []):
			var region: Rect2 = DirtyGraph.bounds(item)
			var signature: String = DirtyGraph.key(
				[
					item,
					DirtyGraph.nearby(snapshot["buildings"], region),
					snapshot["pool"],
					DirtyGraph.field_key(snapshot, region, height_index)
				]
			)
			var structure: Dictionary = memo.call(
				"structure:" + item["id"],
				signature,
				func() -> Dictionary:
					var one: Dictionary = snapshot.duplicate()
					one["bridges"] = [item] if pair[1] == "bridge" else []
					one["stairs"] = [item] if pair[1] == "stair" else []
					return GardenStructures.build(one)
			)
			result["structures"][pair[1]].append_array(structure[pair[1]])
			result["structures"]["issues"].append_array(structure["issues"])
	result["poses"] = {}
	for item: Dictionary in snapshot["instances"]:
		var signature: String = DirtyGraph.key(
			[
				item,
				_support_chain(snapshot, item, 0, height_index),
				DirtyGraph.field_key(snapshot, DirtyGraph.bounds(item), height_index)
			]
		)
		result["poses"][item["id"]] = memo.call(
			"instance:" + item["id"],
			signature,
			func() -> Transform3D: return pose(snapshot, item, field)
		)
	for id_value: String in cache.keys():
		if not versions.has(id_value):
			cache.erase(id_value)
	result["worker_ms"] = float(Time.get_ticks_usec() - started) / 1000
	result["generated"] = generated
	result["reused"] = reused
	return result


static func _support(home: Dictionary, field: TerrainField) -> Dictionary:
	var points: Array = SupportGeometry.perimeter(home, field)
	var lowest: float = float(home["position"][1])
	for p: Array in points:
		lowest = minf(lowest, float(p[1]))
	return {
		"bottom": lowest,
		"floor": home["position"][1],
		"perimeter": points,
		"foundation": FoundationGeometry.build(home, field)
	}


static func pose(snapshot: Dictionary, item: Dictionary, field: TerrainField) -> Transform3D:
	var p: Array = item["position"]
	var point: Vector2 = Vector2(p[0], p[2])
	var y: float = p[1] + InstanceEdits.support_height(snapshot, item, 0, field)
	if item.get("height_locked", false):
		y = item.get("locked_y", y)
	var basis_value: Basis = Basis(Vector3.UP, float(item["yaw"]))
	if (
		not item.has("hedge")
		and item["asset_id"] in ["NAT-04", "NAT-05", "NAT-06", "NAT-07", "NAT-08", "NAT-09"]
	):
		basis_value = Basis(Quaternion(Vector3.UP, field.normal_at(point))) * basis_value
	return Transform3D(
		basis_value.scaled(Vector3.ONE * float(item["scale"])), Vector3(p[0], y, p[2])
	)


static func _support_chain(
	snapshot: Dictionary, item: Dictionary, depth: int = 0, height_index: HeightIndex = null
) -> Array:
	if depth > 8 or not item.has("support_id"):
		return []
	for parent: Dictionary in snapshot["instances"]:
		if parent["id"] == item.get("support_id", ""):
			return [
				parent,
				DirtyGraph.field_key(snapshot, DirtyGraph.bounds(parent), height_index),
				_support_chain(snapshot, parent, depth + 1, height_index)
			]
	return []
