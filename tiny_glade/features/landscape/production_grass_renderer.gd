class_name ProductionGrassRenderer
extends MeadowRenderer
## Source state stays in WorldDocument. ProtonScatter supplies stable candidates;
## the inherited single worker/token lifecycle publishes disposable chunk views.

const WOODLAND_GRASSES: GDScript = preload("res://features/landscape/woodland_grasses.gd")
const CANDIDATE_COUNTS: Array[int] = [3040, 4800, 2640, 14400]

var winter_floor_cull_enabled: bool = true
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
var _snow_cover: float = 0.0
var _floor_buried: bool = false
var _loading: bool = false
var _preparing_candidates: bool = false
var _candidate_seed: String = ""
var _production_cache: Dictionary = {}
var _stage_groups: Dictionary = {}
var _walker_contact: GrassWalkerContact = GrassWalkerContact.new()
var _walker_samples: PackedVector4Array = PackedVector4Array()


func _init() -> void:
	material.shader = preload("res://features/landscape/production_grass.gdshader")
	material.set_shader_parameter("root_color", Color("576c47"))
	material.set_shader_parameter("tip_color", Color("99b960"))
	material.set_shader_parameter("floor_color", Color("8fa75c"))
	material.set_shader_parameter("reduce_motion", false)
	material.set_shader_parameter("freeze_time", false)
	material.set_shader_parameter("sample_time", 0.0)
	material.set_shader_parameter("walker_radius", GrassWalkerContact.RADIUS)
	_sync_walker_contact(0.0)


func _ready() -> void:
	super._ready()
	initialize.call_deferred()


func initialize() -> void:
	if ready_for_grass or _loading or _closed or failed:
		return
	_loading = true
	for kind: int in 4:
		meshes.append(WOODLAND_GRASSES.make(kind))
	height_layers = _empty_layers(Image.FORMAT_RF)
	clearance_layers = _empty_layers(Image.FORMAT_R8)
	material.set_shader_parameter("height_layers", height_layers)
	material.set_shader_parameter("clearance_layers", clearance_layers)
	_loading = false
	ready_for_grass = true
	if not _pending.is_empty() and density > 0:
		_start()


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
		"Woodland meadow"
	)


func _prepare_candidates(seed_value: String) -> void:
	_preparing_candidates = true
	var next: Array[Array] = []
	for kind: int in 4:
		if _closed:
			_preparing_candidates = false
			return
		var adapter: LandscapeScatterAdapter = LandscapeScatterAdapter.new()
		var poses: Array[Transform3D] = await adapter.generate(
			self,
			ProductionGrassData.BOUNDS,
			CANDIDATE_COUNTS[kind],
			(seed_value + ":woodland:%d" % kind).hash(),
			func(_point: Vector2) -> Dictionary:
				return {"height": 0.0, "normal": Vector3.UP, "allowed": true},
			{"scale_min": 0.76, "scale_max": 1.28, "normal_alignment": 0.0}
		)
		if poses.size() != CANDIDATE_COUNTS[kind]:
			_preparing_candidates = false
			_fail("ProtonScatter未能生成完整的林间草甸候选。")
			return
		var items: Array[Dictionary] = []
		for index: int in poses.size():
			items.append(
				{
					"pose": poses[index],
					"ground_offset": -0.018,
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


func _process(delta: float) -> void:
	_sync_walker_contact(delta)
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
				view.name = WOODLAND_GRASSES.NAMES[kind]
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
	_sync_floor_visibility()


func set_snow_cover(cover: float) -> void:
	_snow_cover = cover
	var buried: bool = winter_floor_cull_enabled and cover >= 0.65
	if buried == _floor_buried:
		return
	_floor_buried = buried
	_sync_floor_visibility()


func set_floor_culling_enabled(enabled: bool) -> void:
	winter_floor_cull_enabled = enabled
	set_snow_cover(_snow_cover)


func set_density(value: float) -> void:
	super.set_density(value)
	_sync_floor_visibility()


func _sync_floor_visibility() -> void:
	for view: MultiMeshInstance3D in batches:
		if view.get_meta("grass_layer", -1) == 3:
			view.visible = density > 0 and _pending.is_empty() and not _floor_buried


func set_walker_contact(feet: Vector3, active: bool, frozen: bool = false) -> void:
	_walker_contact.set_contact(feet, active, frozen)


func get_walker_contacts() -> PackedVector4Array:
	return _walker_samples.duplicate()


func _sync_walker_contact(delta: float) -> void:
	_walker_contact.advance(
		delta,
		bool(material.get_shader_parameter("reduce_motion")),
		bool(material.get_shader_parameter("freeze_time"))
	)
	var contacts: PackedVector4Array = _walker_contact.samples()
	if contacts == _walker_samples:
		return
	_walker_samples = contacts
	var extent: float = 0.0
	var lead: Vector4 = contacts[0]
	for contact: Vector4 in contacts:
		if contact.w > 0.0:
			extent = maxf(
				extent,
				(
					Vector2(contact.x, contact.z).distance_to(Vector2(lead.x, lead.z))
					+ GrassWalkerContact.RADIUS
				)
			)
	material.set_shader_parameter("walker_contacts", contacts)
	material.set_shader_parameter("walker_interaction_active", extent > 0.0)
	material.set_shader_parameter("walker_contact_extent", extent)


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
