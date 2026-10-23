extends "res://app/week_nine_boot.gd"
## Art-direction revision. Same editable document and transactions, new presentation.

var art_materials: Dictionary = {}
var _art_sync_paths: Dictionary = {}
var _art_worker_paths: Dictionary = {}
var _curtain: Node3D
var _pond_bank: Node3D
var _curtain_seed: String = ""
var _bank_signature: int = 0
var _art_wind_cache: Dictionary = {}
var _art_wind_collections: int = 0


func _setup_materials() -> void:
	super._setup_materials()
	art_materials = ArtMaterials.create()
	architecture_material = art_materials["architecture"]
	terrain_material = art_materials["terrain"]
	water_material = art_materials["water"]
	wood_material = art_materials["wood"]
	stone_material = art_materials["stone"]
	window_material = art_materials["window"]
	path_material = stone_material.duplicate()
	path_material.vertex_color_use_as_albedo = true
	ArtFoliageCatalog.configure(art_materials["foliage"].shader)
	_planner = ArtViewPlan.new(self)


func _setup_environment() -> void:
	super._setup_environment()
	ArtEnvironment.configure(world_environment.environment, sun)
	get_viewport().use_taa = true


func _advance_light(delta: float) -> void:
	super._advance_light(delta)
	if sun != null and world_environment != null:
		ArtEnvironment.apply(self, _light_mix)


func _setup_initial_buildings() -> void:
	var source: Dictionary = ArtLayout.create()
	if "--w09-stress" in OS.get_cmdline_user_args():
		source = StressLayout.create()
	elif "--w09-stress-reduced" in OS.get_cmdline_user_args():
		source = StressLayout.create(0.5)
	_show_result(session.replace_document(source, _prepare_views), "手绘林间坡地")


func _ready() -> void:
	if "--art-fhd" in OS.get_cmdline_user_args() and "--qa-settings" in OS.get_cmdline_user_args():
		get_window().content_scale_size = Vector2i(1920, 1080)
		get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	super._ready()
	if qa_mode:
		saves.directory = "user://qa_art_01_native"
	_art_worker_paths = _art_sync_paths.duplicate(true)
	saves.evaluator = func(snapshot: Dictionary) -> Dictionary:
		return _evaluate_art(snapshot, {}, {})
	queue.evaluator = func(snapshot: Dictionary) -> Dictionary:
		return _evaluate_art(snapshot, _worker_cache, _art_worker_paths)
	_recommended_view(1 if "--art-near" in OS.get_cmdline_user_args() else 0)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--art-angle="):
			camera_rig.yaw = deg_to_rad(arg.trim_prefix("--art-angle=").to_float())
			camera_rig.refresh()
		if arg == "--art-low":
			camera_rig.pitch = 0.32
			camera_rig.refresh()
		if arg == "--art-far":
			camera_rig.distance = 43
			camera_rig.refresh()
	hud.set_status("林间坡地 · 美术返工样板 / 可建造、拆改与保存")
	if "--art-save-probe" in OS.get_cmdline_user_args() and qa_mode:
		_start_save(0, "美术发布版存档探针")


func _recommended_view(index: int) -> void:
	_restore_camera(ArtLayout.empty()["camera_bookmarks"][index])


func _prepare_views(snapshot: Dictionary) -> Dictionary:
	return _prepare_resources(_evaluate_art(snapshot, _sync_cache, _art_sync_paths))


static func _evaluate_art(
	snapshot: Dictionary, geometry: Dictionary, paths: Dictionary
) -> Dictionary:
	var data: Dictionary = LocalRebuild.evaluate(snapshot, geometry)
	if data.get("ok", false):
		var signature: String = data["versions"]["path"]
		if paths.get("signature", "") != signature:
			paths["signature"] = signature
			paths["arrays"] = ArtPathGeometry.arrays(snapshot)
		data["art_path_arrays"] = paths["arrays"]
	return data


func _decorated_building_view(home: Dictionary, mesh: ArrayMesh, snapshot: Dictionary) -> Node3D:
	var root: Node3D = CottageArt.decorate(
		home,
		mesh,
		snapshot,
		{
			"wall": architecture_material,
			"roof": art_materials["roof"],
			"wood": wood_material,
			"stone": stone_material
		}
	)
	OpeningAssembly.attach(root, home, _apply_asset_materials)
	return root


func _instance_view(item: Dictionary, snapshot: Dictionary) -> Node3D:
	var wrapper: Node3D = super._instance_view(item, snapshot)
	if ArtFoliageCatalog.supports(item["asset_id"]):
		var old: Node = wrapper.get_node("Visual")
		wrapper.remove_child(old)
		old.free()
		var visual: Node3D
		if item.has("hedge"):
			var layout: Dictionary = HedgeView.plan(item, snapshot)
			visual = ArtViewPlan.build_batch(
				layout["items"],
				layout["poses"],
				wood_material,
				stone_material,
				ArtViewPlan.describe("NAT-06", wood_material, stone_material)
			)
			visual.set_meta("object_id", item["id"])
			visual.set_meta("asset_id", "NAT-07")
		else:
			visual = ArtFoliageCatalog.create(
				item["asset_id"], item["id"], wood_material, stone_material
			)
			var bounds: AABB = visual.get_meta("pick_bounds")
			var proxy: CollisionShape3D = wrapper.get_node("PickProxy/SelectionShape")
			(proxy.shape as BoxShape3D).size = bounds.size.max(Vector3.ONE * 0.1)
			proxy.position = bounds.get_center()
		visual.name = "Visual"
		wrapper.add_child(visual)
		wrapper.visual = visual
	return wrapper


func _on_published(snapshot: Dictionary, prepared: Dictionary) -> void:
	super._on_published(snapshot, prepared)
	if art_materials.is_empty():
		return
	art_materials["roof"].set_shader_parameter(
		"roof_tint", GardenPalette.tint(snapshot["environment"], "roof")
	)
	art_materials["roof"].set_shader_parameter("aged", snapshot["environment"].get("aged", false))
	if _curtain == null or _curtain_seed != str(snapshot["world_seed"]):
		if is_instance_valid(_curtain):
			_curtain.queue_free()
		_curtain = ArtScenery.curtain(snapshot, wood_material, stone_material, terrain_material)
		_curtain_seed = str(snapshot["world_seed"])
		world_view.add_child(_curtain)
	var signature: int = ArtScenery.bank_signature(snapshot)
	if signature != _bank_signature:
		if is_instance_valid(_pond_bank):
			_pond_bank.queue_free()
		_pond_bank = ArtScenery.bank(snapshot, wood_material, stone_material)
		world_view.add_child(_pond_bank)
		_bank_signature = signature
	wind_materials.assign(_collect_art_wind())
	for paint: ShaderMaterial in wind_materials:
		if paint.shader == art_materials["foliage"].shader:
			paint.set_shader_parameter(
				"foliage_tint", GardenPalette.tint(snapshot["environment"], "foliage")
			)
	_sync_wind(snapshot)


func _collect_art_wind() -> Array[ShaderMaterial]:
	# View hierarchies/material identities are immutable after construction. Source
	# edits replace the corresponding root; wind/tint/freeze only change parameters.
	var roots: Dictionary = {}
	for key: String in _live_units:
		if key.begins_with("item:") or key.begins_with("batch:"):
			roots[key] = _live_units[key]
	for pair: Array in [["curtain", _curtain], ["bank", _pond_bank]]:
		if is_instance_valid(pair[1]):
			roots[pair[0]] = pair[1]
	var result: Array[ShaderMaterial] = []
	var known: Dictionary = {}
	for key: String in roots:
		var node: Node3D = roots[key]
		var root_id: int = node.get_instance_id()
		if _art_wind_cache.get(key, {}).get("root_id", 0) != root_id:
			_art_wind_cache[key] = {
				"root_id": root_id, "materials": WeekSixCatalog.wind_materials(node)
			}
			_art_wind_collections += 1
		for paint: ShaderMaterial in _art_wind_cache[key]["materials"]:
			var material_id: int = paint.get_instance_id()
			if not known.has(material_id):
				known[material_id] = true
				result.append(paint)
	for key: String in _art_wind_cache.keys():
		if not roots.has(key):
			_art_wind_cache.erase(key)
	return result


func _delivery_metrics() -> Dictionary:
	var result: Dictionary = super._delivery_metrics()
	result["art_wind_root_collections"] = _art_wind_collections
	result["art_wind_cached_roots"] = _art_wind_cache.size()
	return result


func _apply_layout() -> void:
	_cancel_edit()
	var source: Dictionary = ArtLayout.empty() if _layout_kind == "empty" else ArtLayout.create()
	var result: Dictionary = session.replace_document(source, _prepare_views)
	if result["ok"]:
		active_slot = -1
		active_title = "林间新作品"
		tools.selected.clear()
		_show_selection()
		_recommended_view(0)
