class_name MeadowRenderer
extends Node3D
## One worker plus latest pending source; detached chunk preparation is time sliced.

var material: ShaderMaterial = ShaderMaterial.new()
var density: float = 0.45
var total: int = 0
var worker_ms: float = 0
var apply_max_ms: float = 0
var rebuilt_chunks: int = 0
var reused_chunks: int = 0
var batches: Array[MultiMeshInstance3D] = []
var _mesh: ArrayMesh
var _signature: int = -1
var _task: int = -1
var _token: int = 0
var _pending: Dictionary = {}
var _latest: Dictionary = {}
var _data: Dictionary = {}
var _chunk_keys: Array = []
var _staging: Array[MultiMeshInstance3D] = []
var _closed: bool = false
var _generation_cache: Dictionary = {}
var _published_chunks: Dictionary = {}
var _published_versions: Dictionary = {}
var _staged_chunks: Dictionary = {}
var _rebuilt: int = 0
var _reused: int = 0


func _init() -> void:
	material.shader = preload("res://features/garden_presentation/meadow.gdshader")
	for key: String in ["reduce_motion", "freeze_time"]:
		material.set_shader_parameter(key, false)
	material.set_shader_parameter("sample_time", 0.0)


func _ready() -> void:
	_mesh = MeadowData.blade_mesh()


func set_density(value: float) -> void:
	density = clampf(value, 0, 1)
	var pending_update: bool = not _pending.is_empty()
	for batch: MultiMeshInstance3D in batches:
		batch.multimesh.visible_instance_count = floori(batch.multimesh.instance_count * density)
		batch.visible = density > 0 and not pending_update
	if density > 0 and _task < 0 and pending_update:
		_start()
	elif density > 0 and batches.is_empty() and not _latest.is_empty() and not is_busy():
		request(_latest, true)


func request(source: Dictionary, force: bool = false) -> void:
	var signature: int = MeadowData.signature(source)
	if not force and signature == _signature:
		return
	_signature = signature
	_latest = source.duplicate(true)
	_token += 1
	_pending = {"source": _latest, "token": _token}
	_clear_staging()
	if _task < 0 and density > 0:
		_start()


func _start() -> void:
	if _pending.is_empty() or _closed:
		return
	var job: Dictionary = _pending
	_pending = {}
	_task = WorkerThreadPool.add_task(
		func() -> void:
			var data: Dictionary = MeadowData.generate_cached(job["source"], _generation_cache)
			_deliver.call_deferred(job["token"], data),
		false,
		"Derived meadow"
	)


func _deliver(token: int, data: Dictionary) -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	if not _closed and token == _token:
		_data = data
		_chunk_keys = data["chunks"].keys()
	if not _pending.is_empty() and density > 0:
		_start()


func _process(_delta: float) -> void:
	if _data.is_empty():
		return
	var started: int = Time.get_ticks_usec()
	while not _chunk_keys.is_empty():
		var key: Vector2i = _chunk_keys.pop_back()
		if _published_versions.get(key, []) == _data["versions"][key]:
			var retained: MultiMeshInstance3D = _published_chunks[key]
			_staging.append(retained)
			_staged_chunks[key] = retained
			_reused += 1
			if Time.get_ticks_usec() - started > 2000:
				break
			continue
		var items: Array = _data["chunks"][key]
		var multimesh: MultiMesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_custom_data = true
		multimesh.mesh = _mesh
		multimesh.instance_count = items.size()
		var origin: Vector3 = Vector3(key.x * 8 + 4, 0, key.y * 8 + 4)
		multimesh.buffer = _data["buffers"][key]
		multimesh.visible_instance_count = floori(items.size() * density)
		var batch: MultiMeshInstance3D = MultiMeshInstance3D.new()
		batch.name = "GrassChunk"
		batch.multimesh = multimesh
		batch.material_override = material
		batch.position = origin
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		batch.extra_cull_margin = 0.5
		batch.visibility_range_end = 62
		_staging.append(batch)
		_staged_chunks[key] = batch
		_rebuilt += 1
		if Time.get_ticks_usec() - started > 2000:
			break
	apply_max_ms = maxf(apply_max_ms, (Time.get_ticks_usec() - started) / 1000.0)
	if _chunk_keys.is_empty():
		for batch: MultiMeshInstance3D in batches:
			if batch not in _staging:
				batch.queue_free()
		batches = _staging
		_staging = []
		for batch: MultiMeshInstance3D in batches:
			if batch.get_parent() == null:
				add_child(batch)
			batch.multimesh.visible_instance_count = floori(
				batch.multimesh.instance_count * density
			)
			batch.visible = density > 0
		_published_chunks = _staged_chunks
		_staged_chunks = {}
		_published_versions = _data["versions"]
		rebuilt_chunks = _rebuilt
		reused_chunks = _reused
		_rebuilt = 0
		_reused = 0
		total = _data["count"]
		worker_ms = _data["worker_ms"]
		_data = {}


func visible_count() -> int:
	var count: int = 0
	for batch: MultiMeshInstance3D in batches:
		count += batch.multimesh.visible_instance_count if batch.visible else 0
	return count


func is_busy() -> bool:
	return _task >= 0 or not _data.is_empty() or (density > 0 and not _pending.is_empty())


func _clear_staging() -> void:
	for batch: MultiMeshInstance3D in _staging:
		if batch.get_parent() == null:
			batch.free()
	_staging.clear()
	_staged_chunks.clear()
	_rebuilt = 0
	_reused = 0
	_chunk_keys.clear()
	_data.clear()


func _exit_tree() -> void:
	_closed = true
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	_clear_staging()
