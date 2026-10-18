class_name ViewPlan
extends RefCounted
## Resources and detached view nodes only on the calling main thread.

var owner_root: Node3D
var cache: Dictionary = {}


func _init(root: Node3D) -> void:
	owner_root = root


func prepare(data: Dictionary, stage: ResourceStage = null) -> Dictionary:
	if not data.get("ok", false):
		return {"payload": data, "jobs": []}
	var snapshot: Dictionary = data["snapshot"]
	var payload: Dictionary = {"ok": true, "source": snapshot, "data": data, "units": {}}
	var jobs: Array[Callable] = []
	var versions: Dictionary = data["versions"]
	for i: int in range(snapshot["buildings"].size()):
		var home: Dictionary = snapshot["buildings"][i]
		_unit(
			"building:" + home["id"],
			versions["building:" + home["id"]],
			func() -> Node3D:
				return owner_root._building_view(
					home, BuildingGeometry.mesh_from_arrays(data["building_arrays"][i])
				),
			payload,
			jobs,
			stage
		)
		_unit(
			"support:" + home["id"],
			versions["support:" + home["id"]],
			func() -> Node3D: return _support(data["supports"][i]),
			payload,
			jobs,
			stage
		)
	for i: int in range(data["terrain_arrays"].size()):
		_unit(
			"terrain:%d" % i,
			versions["terrain:%d" % i],
			func() -> ArrayMesh: return _mesh(data["terrain_arrays"][i]),
			payload,
			jobs,
			stage
		)
	for pair: Array in [
		["path", "path_arrays"], ["fence", "fence_arrays"], ["water", "water_arrays"]
	]:
		_unit(
			pair[0],
			versions[pair[0]],
			func() -> ArrayMesh: return _mesh(data[pair[1]]),
			payload,
			jobs,
			stage
		)
	for pair: Array in [["bridges", "bridge"], ["stairs", "stair"]]:
		for i: int in range(snapshot.get(pair[0], []).size()):
			var item: Dictionary = snapshot[pair[0]][i]
			_unit(
				"structure:" + item["id"],
				versions["structure:" + item["id"]],
				func() -> Node3D:
					return _view(_mesh(data["structures"][pair[1]][i]), owner_root.path_material),
				payload,
				jobs,
				stage
			)
	var grouped: Dictionary = FoliageBatches.groups(snapshot)
	var batched: Dictionary = {}
	for key: String in grouped:
		var signatures: Array = []
		for item: Dictionary in grouped[key]:
			batched[item["id"]] = true
			signatures.append(versions["instance:" + item["id"]])
		_unit(
			"batch:" + key,
			DirtyGraph.key(signatures),
			func() -> Node3D:
				return FoliageBatches.build(
					grouped[key], data["poses"], owner_root.wood_material, owner_root.stone_material
				),
			payload,
			jobs,
			stage
		)
	for item: Dictionary in snapshot["instances"]:
		if batched.has(item["id"]):
			continue
		_unit(
			"item:" + item["id"],
			DirtyGraph.key([item["asset_id"], item["id"]]),
			func() -> Node3D:
				return WeekSixCatalog.create(
					item["asset_id"],
					item["id"],
					owner_root.wood_material,
					owner_root.stone_material
				),
			payload,
			jobs,
			stage
		)
	return {"payload": payload, "jobs": jobs}


func _unit(
	id_value: String,
	signature: String,
	create: Callable,
	payload: Dictionary,
	jobs: Array[Callable],
	stage: ResourceStage
) -> void:
	var entry: Dictionary = cache.get(id_value, {})
	if (
		entry.get("signature", "") == signature
		and (not entry.get("node", false) or is_instance_valid(entry["value"]))
	):
		payload["units"][id_value] = entry["value"]
		return
	jobs.append(
		func() -> void:
			var value: Variant = create.call()
			if stage != null and value is Node:
				stage.own(value)
			cache[id_value] = {"signature": signature, "value": value, "node": value is Node}
			payload["units"][id_value] = value
	)


func prune(units: Dictionary) -> void:
	for key: String in cache.keys():
		if not units.has(key):
			cache.erase(key)


func _support(support: Dictionary) -> Node3D:
	var node: Node3D = Node3D.new()
	for part: String in ["wood", "stone"]:
		var mesh: ArrayMesh = _mesh(support["foundation"][part + "_arrays"])
		if mesh != null:
			node.add_child(
				_view(
					mesh, owner_root.wood_material if part == "wood" else owner_root.stone_material
				)
			)
	return node


static func _mesh(arrays: Array) -> ArrayMesh:
	return (
		BuildingGeometry.mesh_from_arrays(arrays) if arrays[Mesh.ARRAY_VERTEX].size() > 0 else null
	)


static func _view(mesh: ArrayMesh, material: Material) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	return node
