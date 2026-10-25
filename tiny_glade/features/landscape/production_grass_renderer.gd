class_name ProductionGrassRenderer
extends MeadowRenderer
## Source state stays in WorldDocument. ProtonScatter supplies stable candidates;
## the inherited single worker/token lifecycle publishes disposable chunk views.

const LOCAL: String = "res://assets/painterly_grass/local/valley/"
const IDS: Array[String] = ["blades", "detail", "puffs", "floor"]
const CANDIDATE_COUNTS: Array[int] = [3040, 4800, 2640, 14400]

var ready_for_grass: bool = false
var failed: bool = false
var failure_message: String = ""
var meshes: Array[Mesh] = []
var height_layers: Texture2DArray
var clearance_layers: Texture2DArray
var candidate_pools: Array[Array] = []
var groups: Dictionary = {}
var published_chunks: Dictionary = {}
var published_signature: int = -1
var _profiles: Array[Dictionary] = []
var _loading: bool = false
var _preparing_candidates: bool = false
var _candidate_seed: String = ""
var _production_cache: Dictionary = {}
var _stage_groups: Dictionary = {}


func _init() -> void:
	material.shader = preload("res://features/landscape/production_grass.gdshader")
	material.set_shader_parameter("root_color", Color("495e36"))
	material.set_shader_parameter("tip_color", Color("a2aa6b"))
	material.set_shader_parameter("floor_color", Color("82954e"))
	material.set_shader_parameter("reduce_motion", false)
	material.set_shader_parameter("freeze_time", false)
	material.set_shader_parameter("sample_time", 0.0)


func _ready() -> void:
	super._ready()
	initialize.call_deferred()


func initialize() -> void:
	if ready_for_grass or _loading or _closed or failed:
		return
	_loading = true
	for id: String in IDS:
		var pack: PackedScene = await _load_asset(LOCAL + id + ".glb") as PackedScene
		if pack == null:
			return
		var mesh: Mesh = PainterlyGrassSamples.mesh_from(pack)
		if mesh == null:
			_fail("Valley草地缺少可用网格：" + id)
			return
		meshes.append(mesh)
	var coverage: Texture2D = await _load_asset(LOCAL + "coverage4k.png") as Texture2D
	if coverage == null:
		return
	var source: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(LOCAL + "scatter_full.json")
	)
	if not source is Dictionary or source.get("layers", []).size() != 4:
		_fail("Valley草地缺少四层作者尺度与埋根数据。")
		return
	for kind: int in 4:
		var layer_data: Dictionary = source["layers"][kind]
		if layer_data.get("asset_id", "") != IDS[kind] or layer_data["instances"].is_empty():
			_fail("Valley草地作者层次记录不完整。")
			return
		var scale_sum: float = 0.0
		var offset_sum: float = 0.0
		for item: Dictionary in layer_data["instances"]:
			var up: Array = item["basis"][1]
			scale_sum += Vector3(up[0], up[1], up[2]).length()
			offset_sum += float(item["ground_offset_m"])
		_profiles.append(
			{
				"scale": scale_sum / layer_data["instances"].size(),
				"ground_offset": offset_sum / layer_data["instances"].size()
			}
		)
	height_layers = _empty_layers(Image.FORMAT_RF)
	clearance_layers = _empty_layers(Image.FORMAT_R8)
	material.set_shader_parameter("height_layers", height_layers)
	material.set_shader_parameter("clearance_layers", clearance_layers)
	material.set_shader_parameter("coverage", coverage)
	_loading = false
	ready_for_grass = true
	if not _pending.is_empty() and density > 0:
		_start()


func _load_asset(path: String) -> Resource:
	if not ResourceLoader.exists(path) or ResourceLoader.load_threaded_request(path) != OK:
		_fail("缺少本地Valley草地素材：" + path.get_file())
		return null
	while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		if _closed:
			return null
		await get_tree().process_frame
	if _closed:
		return null
	if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_LOADED:
		_fail("Valley草地素材读取失败：" + path.get_file())
		return null
	return ResourceLoader.load_threaded_get(path)


func _start() -> void:
	if _pending.is_empty() or _closed or failed or _preparing_candidates:
		return
	if not ready_for_grass:
		initialize()
		return
	var seed_value: String = str(_pending["source"]["world_seed"])
	if _candidate_seed != seed_value:
		_prepare_candidates(seed_value)
		return
	var job: Dictionary = _pending
	_pending = {}
	var candidates: Array[Array] = candidate_pools
	_task = WorkerThreadPool.add_task(
		func() -> void:
			var data: Dictionary = ProductionGrassData.generate(
				job["source"], candidates, _production_cache
			)
			_deliver.call_deferred(job["token"], data),
		false,
		"Four-layer Valley grass"
	)


func _prepare_candidates(seed_value: String) -> void:
	_preparing_candidates = true
	var next: Array[Array] = []
	for kind: int in 4:
		if _closed:
			_preparing_candidates = false
			return
		var adapter: LandscapeScatterAdapter = LandscapeScatterAdapter.new()
		var scale_value: float = _profiles[kind]["scale"]
		var poses: Array[Transform3D] = await adapter.generate(
			self,
			ProductionGrassData.BOUNDS,
			CANDIDATE_COUNTS[kind],
			(seed_value + ":valley:%d" % kind).hash(),
			func(_point: Vector2) -> Dictionary:
				return {"height": 0.0, "normal": Vector3.UP, "allowed": true},
			{
				"scale_min": scale_value * 0.78,
				"scale_max": scale_value * 1.22,
				"normal_alignment": 0.0
			}
		)
		if poses.size() != CANDIDATE_COUNTS[kind]:
			_preparing_candidates = false
			_fail("ProtonScatter未能生成完整的Valley草地候选。")
			return
		var items: Array[Dictionary] = []
		for index: int in poses.size():
			items.append(
				{
					"pose": poses[index],
					"ground_offset": _profiles[kind]["ground_offset"],
					"rank": _fraction(seed_value + ":rank:%d:%d" % [kind, index]),
					"phase": _fraction(seed_value + ":phase:%d:%d" % [kind, index]),
					"tint": _fraction(seed_value + ":tint:%d:%d" % [kind, index])
				}
			)
		next.append(items)
		await get_tree().process_frame
	if not _closed and not _latest.is_empty() and str(_latest["world_seed"]) == seed_value:
		candidate_pools = next
		_candidate_seed = seed_value
	_preparing_candidates = false
	if not _pending.is_empty() and density > 0:
		_start()


func _process(_delta: float) -> void:
	if _data.is_empty() or not ready_for_grass:
		return
	var started: int = Time.get_ticks_usec()
	while not _chunk_keys.is_empty():
		var key: Vector2i = _chunk_keys.pop_back()
		var views: Array[MultiMeshInstance3D] = []
		if _published_versions.get(key, []) == _data["versions"][key]:
			views.assign(groups[key])
			_reused += 1
		else:
			for kind: int in 4:
				var buffer: PackedFloat32Array = _data["buffers"][key][kind]
				if buffer.is_empty():
					continue
				var view: MultiMeshInstance3D = MultiMeshInstance3D.new()
				view.name = "ValleyGrass%d" % kind
				view.set_meta("grass_layer", kind)
				view.position = Vector3(key.x * 8 + 4, 0, key.y * 8 + 4)
				view.multimesh = MultiMesh.new()
				view.multimesh.transform_format = MultiMesh.TRANSFORM_3D
				view.multimesh.use_custom_data = true
				view.multimesh.mesh = meshes[kind]
				view.multimesh.instance_count = buffer.size() / 16
				view.multimesh.buffer = buffer
				view.material_override = material
				view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				view.extra_cull_margin = 2.0
				views.append(view)
			_rebuilt += 1
		_stage_groups[key] = views
		_staging.append_array(views)
		if Time.get_ticks_usec() - started > 2000:
			break
	apply_max_ms = maxf(apply_max_ms, float(Time.get_ticks_usec() - started) / 1000.0)
	if not _chunk_keys.is_empty():
		return
	for key: Vector2i in _data["images"]:
		if _published_versions.get(key, []) != _data["versions"][key]:
			height_layers.update_layer(_data["images"][key], ProductionGrassData.layer(key))
			clearance_layers.update_layer(_data["masks"][key], ProductionGrassData.layer(key))
	for view: MultiMeshInstance3D in batches:
		if view not in _staging:
			view.queue_free()
	batches = _staging
	_staging = []
	for view: MultiMeshInstance3D in batches:
		if view.get_parent() == null:
			add_child(view)
		view.multimesh.visible_instance_count = floori(view.multimesh.instance_count * density)
		view.visible = density > 0
	groups = _stage_groups
	_stage_groups = {}
	published_chunks = _data["chunks"]
	published_signature = _data["signature"]
	_published_versions = _data["versions"]
	rebuilt_chunks = _rebuilt
	reused_chunks = _reused
	_rebuilt = 0
	_reused = 0
	total = _data["count"]
	worker_ms = _data["worker_ms"]
	_data = {}


func is_busy() -> bool:
	return not failed and (_loading or _preparing_candidates or super.is_busy())


func _clear_staging() -> void:
	super._clear_staging()
	_stage_groups.clear()


func _fail(message: String) -> void:
	failure_message = message
	failed = true
	_loading = false
	push_error(message)


static func _empty_layers(format: Image.Format) -> Texture2DArray:
	var result: Texture2DArray = Texture2DArray.new()
	var flat: Image = Image.create(
		ProductionGrassData.RESOLUTION, ProductionGrassData.RESOLUTION, false, format
	)
	var images: Array[Image] = []
	for index: int in 36:
		images.append(flat)
	assert(result.create_from_images(images) == OK)
	return result


static func _fraction(key: String) -> float:
	return float(posmod(key.hash(), 1000000)) / 1000000.0
