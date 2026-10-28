class_name PainterlyGardenGrassRenderer
extends MeadowRenderer
## Retains MeadowRenderer's single-worker token/cancel/density/teardown lifecycle.
## Cache is exclusively owned by that worker; main thread only receives immutable results.

var use_new_grass: bool = true
var meshes: Array[Mesh] = []
var old_material: ShaderMaterial = ShaderMaterial.new()
var height_layers: Texture2DArray
var groups: Dictionary = {}
var published_signature: int = -1
var _stage_groups: Dictionary = {}
var _garden_cache: Dictionary = {}


func _init() -> void:
	material.shader = preload("res://features/painterly_grass/garden_grass.gdshader")
	old_material.shader = PainterlyGrassSamples.OLD_SHADER
	for paint: ShaderMaterial in [material, old_material]:
		paint.set_shader_parameter("reduce_motion", false)
		paint.set_shader_parameter("freeze_time", false)
		paint.set_shader_parameter("sample_time", 0.0)


func configure(samples: Array[Mesh], coverage: Texture2D) -> void:
	meshes = samples
	height_layers = Texture2DArray.new()
	var flat: Image = Image.create(129, 129, false, Image.FORMAT_RF)
	var images: Array[Image] = []
	for i: int in 36:
		images.append(flat)
	assert(height_layers.create_from_images(images) == OK)
	material.set_shader_parameter("height_layers", height_layers)
	material.set_shader_parameter("coverage", coverage)


func set_variant(enabled: bool) -> void:
	if use_new_grass == enabled:
		return
	use_new_grass = enabled
	if not _latest.is_empty():
		request(_latest, true)


func _start() -> void:
	if _pending.is_empty() or _closed:
		return
	var job: Dictionary = _pending
	var selected: bool = use_new_grass
	_pending = {}
	_task = WorkerThreadPool.add_task(
		func() -> void:
			var data: Dictionary = PainterlyGardenGrassData.generate(
				job["source"], _garden_cache, selected
			)
			data["signature"] = MeadowData.signature(job["source"])
			_deliver.call_deferred(job["token"], data),
		false,
		"Painterly garden grass"
	)


func _process(_delta: float) -> void:
	if _data.is_empty() or meshes.size() != 3:
		return
	var started: int = Time.get_ticks_usec()
	while not _chunk_keys.is_empty():
		var key: Vector2i = _chunk_keys.pop_back()
		var views: Array[MultiMeshInstance3D] = []
		if _published_versions.get(key, []) == _data["versions"][key]:
			views.assign(groups[key])
			_reused += 1
		else:
			var arrays: Array = _data["buffers"][key]
			for kind: int in arrays.size():
				if arrays[kind].is_empty():
					continue
				var view: MultiMeshInstance3D = MultiMeshInstance3D.new()
				view.name = "PainterlyGrassChunk" if _data["new_grass"] else "OriginalGrassChunk"
				view.position = Vector3(key.x * 8 + 4, 0, key.y * 8 + 4)
				view.multimesh = MultiMesh.new()
				view.multimesh.transform_format = MultiMesh.TRANSFORM_3D
				view.multimesh.use_custom_data = true
				view.multimesh.mesh = meshes[kind] if _data["new_grass"] else _mesh
				view.multimesh.instance_count = arrays[kind].size() / 16
				view.multimesh.buffer = arrays[kind]
				view.material_override = material if _data["new_grass"] else old_material
				view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				view.extra_cull_margin = 0.8
				view.visibility_range_end = 62
				views.append(view)
			_rebuilt += 1
		_stage_groups[key] = views
		_staging.append_array(views)
		if Time.get_ticks_usec() - started > 2000:
			break
	apply_max_ms = maxf(apply_max_ms, float(Time.get_ticks_usec() - started) / 1000)
	if not _chunk_keys.is_empty():
		return
	# Upload terrain only at atomic publication; cancelled staging never changes live layers.
	for key: Vector2i in _data["images"]:
		if _published_versions.get(key, []) != _data["versions"][key]:
			height_layers.update_layer(_data["images"][key], PainterlyGardenGrassData.layer(key))
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
	_published_versions = _data["versions"]
	published_signature = _data["signature"]
	rebuilt_chunks = _rebuilt
	reused_chunks = _reused
	_rebuilt = 0
	_reused = 0
	total = _data["count"]
	worker_ms = _data["worker_ms"]
	_data = {}


func _clear_staging() -> void:
	super._clear_staging()
	_stage_groups.clear()
