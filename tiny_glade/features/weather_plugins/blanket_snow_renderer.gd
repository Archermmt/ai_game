class_name BlanketSnowRenderer
extends Node3D
## Disposable Blanket geometry, bound to the scene's published objects and terrain.

const DEPTH: float = 0.20
const MATERIAL: StandardMaterial3D = preload("res://addons/blanket/materials/snow_standard.tres")

var host: Node3D
var baked_count: int = 0
var cap_count: int = 0
var batching_enabled: bool = true
var opaque_material_enabled: bool = true
var _snapshot: Dictionary = {}
var _signature: int = 0
var _dirty: bool = false
var _jobs: Array[Dictionary] = []
var _cache: Dictionary = {}
var _views: Array[GeometryInstance3D] = []
var _records: Array[Dictionary] = []
var _batch_mode: bool = false
var _batch_dirty: bool = false
var _material: StandardMaterial3D
var _cover: float = 0.0


func configure(value: Node3D) -> void:
	host = value
	name = "BlanketSnowCover"
	_material = MATERIAL.duplicate() as StandardMaterial3D
	_material.next_pass = null
	_material.albedo_color = Color(0.65, 0.70, 0.76)
	_material.albedo_texture = load("res://addons/puchik_snow/textures/snow/snow_02_diff_2k.jpg")
	_material.normal_texture = load("res://addons/puchik_snow/textures/snow/snow_02_nor_gl_1k.jpg")
	_material.normal_scale = 0.38
	_material.roughness = 0.92
	_material.uv1_scale = Vector3.ONE * 0.55
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_HASH
	request(host.document.snapshot())


func request(snapshot: Dictionary) -> void:
	var signature: int = MeadowData.signature(snapshot)
	if signature == _signature and not _snapshot.is_empty():
		return
	_signature = signature
	_snapshot = snapshot.duplicate(true)
	_dirty = true
	_jobs.clear()
	_clear_views()
	_records.clear()
	cap_count = 0
	_batch_dirty = false


func sync(cover: float) -> void:
	_cover = clampf(cover, 0, 1)
	visible = _cover > 0.35
	_sync_material()
	if _jobs.is_empty() and _batch_mode != (batching_enabled and _cover >= 0.9):
		_rebuild_views()
	if (
		not visible
		or DisplayServer.get_name() == "headless"
		or RenderingServer.get_rendering_device() == null
	):
		return
	if host.queue.is_busy() or host.stage.is_busy() or host.meadow.is_busy():
		return
	if _dirty:
		_collect()
		_dirty = false
	for index: int in mini(12, _jobs.size()):
		var job: Dictionary = _jobs.pop_front()
		var cached: bool = _cache.has(job["key"])
		_publish(job)
		if not cached:
			break
	if _jobs.is_empty() and _batch_dirty:
		_rebuild_views()


func is_busy() -> bool:
	return (
		visible
		and DisplayServer.get_name() != "headless"
		and RenderingServer.get_rendering_device() != null
		and (_dirty or not _jobs.is_empty())
	)


func shutdown() -> void:
	_jobs.clear()
	_cache.clear()
	_records.clear()
	cap_count = 0
	_clear_views()
	BlanketShaders.shutdown()


func _clear_views() -> void:
	for view: GeometryInstance3D in _views:
		view.free()
	_views.clear()


func _collect() -> void:
	_scan(host.world_view)
	var retained: Dictionary = {}
	for job: Dictionary in _jobs:
		if _cache.has(job["key"]):
			retained[job["key"]] = _cache[job["key"]]
	_cache = retained


func _scan(node: Node) -> void:
	if node in [self, host.meadow, host.terrain_root, host.preview_root, host.gizmo_root]:
		return
	if node is MeshInstance3D and node.mesh != null:
		var mesh: Mesh = node.mesh
		var kind: String = _kind(mesh.resource_name, str(node.name), node.material_override)
		if not kind.is_empty():
			_enqueue(
				mesh,
				node.global_transform,
				kind,
				node.visibility_range_begin,
				node.visibility_range_end
			)
	elif node is MultiMeshInstance3D and node.multimesh != null:
		var mesh: Mesh = node.multimesh.mesh
		var kind: String = _kind(mesh.resource_name, "", node.material_override)
		if not kind.is_empty():
			for index: int in node.multimesh.instance_count:
				_enqueue(
					mesh,
					node.global_transform * node.multimesh.get_instance_transform(index),
					kind,
					node.visibility_range_begin,
					node.visibility_range_end
				)
	for child: Node in node.get_children():
		_scan(child)


static func _kind(mesh_name: String, node_name: String, material: Material) -> String:
	if node_name == "HandLaidTiles":
		return "roof"
	if (
		material is ShaderMaterial
		and material.get_shader_parameter("season_deciduous") == true
		and mesh_name.contains("foliage")
	):
		return ""
	for key: String in ["stone_", "branch_pads", "compact_shrub_body", "bark_"]:
		if mesh_name.contains(key):
			return "nature"
	return ""


func _enqueue(mesh: Mesh, pose: Transform3D, kind: String, begin: float, end: float) -> void:
	var key: String = str(
		hash(
			[
				mesh.get_rid(),
				(pose.basis.inverse() * Vector3.UP).normalized().snapped(Vector3.ONE * 0.001),
				kind
			]
		)
	)
	_jobs.append(
		{
			"key": key,
			"kind": kind,
			"mesh": mesh,
			"pose": pose,
			"begin": begin,
			"end": end,
			"depth": 0.34 if kind == "roof" else DEPTH
		}
	)


func _publish(job: Dictionary) -> void:
	var mesh: ArrayMesh = _cache.get(job["key"])
	if mesh == null:
		var source: ArrayMesh = source_mesh(
			job["mesh"], Transform3D.IDENTITY, job["kind"] == "roof"
		)
		if source.get_surface_count() == 0:
			return
		mesh = BlanketBaker.bake(source, job["depth"], job.get("pose", Transform3D.IDENTITY))
		if mesh == null:
			return
		_cache[job["key"]] = mesh
		baked_count += 1
	var record: Dictionary = job.duplicate()
	record["baked_mesh"] = mesh
	_records.append(record)
	cap_count = _records.size()
	_batch_dirty = true
	_single_view(record)


func set_opaque_enabled(enabled: bool) -> void:
	opaque_material_enabled = enabled
	_sync_material()


func _sync_material() -> void:
	_material.albedo_color.a = smoothstep(0.35, 0.9, _cover)
	var mode: int = (
		BaseMaterial3D.TRANSPARENCY_DISABLED
		if opaque_material_enabled and _cover >= 0.9
		else BaseMaterial3D.TRANSPARENCY_ALPHA_HASH
	)
	if _material.transparency != mode:
		_material.transparency = mode


func set_batching_enabled(enabled: bool) -> void:
	batching_enabled = enabled
	_rebuild_views()


func _single_view(record: Dictionary) -> void:
	var view: MeshInstance3D = MeshInstance3D.new()
	view.name = "SnowCap"
	view.set_meta("snow_kind", record["kind"])
	view.set_meta("cap_count", 1)
	view.mesh = record["baked_mesh"]
	view.material_override = _material
	view.visibility_range_begin = record.get("begin", 0.0)
	view.visibility_range_end = record.get("end", 0.0)
	view.layers = 1 | PondReflections.REFLECTION_LAYER
	add_child(view)
	view.transform = record.get("pose", Transform3D.IDENTITY)
	_views.append(view)


func _rebuild_views() -> void:
	_clear_views()
	_batch_mode = batching_enabled and _cover >= 0.9
	_batch_dirty = false
	var groups: Dictionary = {}
	for record: Dictionary in _records:
		# Keep every distance-limited cap's own visibility origin and all roofs.
		# Hash fading also retains the original per-object shader path.
		if (
			not _batch_mode
			or record["kind"] == "roof"
			or record["begin"] != 0.0
			or record["end"] != 0.0
		):
			_single_view(record)
			continue
		var pose: Transform3D = record["pose"]
		var cell: Vector2i = Vector2i(floori(pose.origin.x / 8), floori(pose.origin.z / 8))
		var key: String = str([record["baked_mesh"].get_rid(), cell])
		if not groups.has(key):
			groups[key] = []
		groups[key].append(record)
	for group: Array in groups.values():
		if group.size() == 1:
			_single_view(group[0])
			continue
		var multimesh: MultiMesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = group[0]["baked_mesh"]
		multimesh.instance_count = group.size()
		for index: int in group.size():
			multimesh.set_instance_transform(index, group[index]["pose"])
		var view: MultiMeshInstance3D = MultiMeshInstance3D.new()
		view.name = "SnowCapBatch"
		view.multimesh = multimesh
		view.material_override = _material
		view.set_meta("snow_kind", "nature")
		view.set_meta("cap_count", group.size())
		view.layers = 1 | PondReflections.REFLECTION_LAYER
		add_child(view)
		_views.append(view)


static func _bed_color(color: Color) -> bool:
	var target: Color = CottageArt.CLAY.darkened(0.17)
	return Vector3(color.r - target.r, color.g - target.g, color.b - target.b).length() < 0.01


static func source_mesh(mesh: Mesh, pose: Transform3D, roof: bool = false) -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var indices: PackedInt32Array = PackedInt32Array()
	for surface: int in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(surface)
		var source: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var source_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var source_colors: PackedColorArray = (
			arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		)
		var source_indices: PackedInt32Array = (
			arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		)
		if source_indices.is_empty():
			for index: int in source.size():
				source_indices.append(index)
		for start: int in range(0, source_indices.size(), 3):
			var first: int = source_indices[start]
			if (
				roof
				and (
					source_colors.is_empty()
					or not _bed_color(source_colors[first]) and mesh.get_aabb().size.y > 0.22
					or source_normals[first].y < 0.1
				)
			):
				continue
			for corner: int in 3:
				var at: int = source_indices[start + corner]
				indices.append(vertices.size())
				vertices.append(pose * source[at])
				normals.append(
					(pose.basis.inverse().transposed() * source_normals[at]).normalized()
				)
	var result: ArrayMesh = ArrayMesh.new()
	if not vertices.is_empty():
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_INDEX] = indices
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result
