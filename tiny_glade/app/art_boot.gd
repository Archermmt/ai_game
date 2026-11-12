extends "res://app/week_nine_boot.gd"
## Art-direction revision. Same editable document and transactions, new presentation.

const CabinOpenings = preload("res://features/art_direction/architecture/cabin_openings.gd")

var art_materials: Dictionary = {}
var _art_sync_paths: Dictionary = {}
var _art_worker_paths: Dictionary = {}
var _curtain: Node3D
var _pond_bank: Node3D
var _curtain_seed: String = ""
var _bank_signature: int = 0
var _woodland_contacts: MeshInstance3D
var _art_wind_cache: Dictionary = {}
var _art_wind_collections: int = 0


func _woodland_style() -> bool:
	return false


func _setup_materials() -> void:
	super._setup_materials()
	art_materials = ArtMaterials.create(_woodland_style())
	architecture_material = art_materials["architecture"]
	terrain_material = art_materials["terrain"]
	water_material = art_materials["water"]
	wood_material = art_materials["wood"]
	stone_material = art_materials["stone"]
	window_material = art_materials["window"]
	path_material = stone_material.duplicate()
	path_material.vertex_color_use_as_albedo = true
	if _woodland_style():
		path_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_HASH
		path_material.alpha_hash_scale = 0.65
	if not _woodland_style():
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
		var path_region: Rect2 = DirtyGraph.union(snapshot["paths"])
		var path_inputs: Array = [data["versions"]["path"]]
		for kind: String in ["bridges", "stairs"]:
			for structure: Dictionary in DirtyGraph.nearby(snapshot.get(kind, []), path_region):
				# A slope edit at the opposite bridgehead can invalidate both landings.
				path_inputs.append(data["versions"]["structure:" + structure["id"]])
		var signature: String = DirtyGraph.key(path_inputs)
		data["versions"]["path"] = signature
		if paths.get("signature", "") != signature:
			paths["signature"] = signature
			paths["arrays"] = ArtPathGeometry.arrays(snapshot)
		data["art_path_arrays"] = paths["arrays"]
		var contact_key: String = WoodlandContacts.signature(snapshot)
		if paths.get("contact_signature", "") != contact_key:
			paths["contact_signature"] = contact_key
			paths["contacts"] = WoodlandContacts.generate(snapshot)
		data["woodland_contact_signature"] = contact_key
		data["woodland_contacts"] = paths["contacts"]
	return data


func _decorated_building_view(home: Dictionary, mesh: ArrayMesh, snapshot: Dictionary) -> Node3D:
	var root: Node3D = CottageArt.decorate(
		home,
		mesh,
		snapshot,
		{
			"wall": architecture_material,
			"roof": art_materials["roof"],
			"wood": art_materials["joinery"],
			"stone": art_materials["masonry"]
		}
	)
	OpeningAssembly.attach(
		root,
		home,
		Callable(),
		func(kind: String, opening: Dictionary) -> Node3D:
			var radius: float = float(home["size"][0]) * 0.5 if home["shape"] == "round" else 0.0
			return CabinOpenings.make(
				kind, opening, art_materials["joinery"], window_material, radius
			)
	)
	if CottageArt.has_chimney(home):
		var smoke: MeshInstance3D = MeshInstance3D.new()
		smoke.name = "HearthSmoke"
		var card: QuadMesh = QuadMesh.new()
		card.size = Vector2(1.45, 2.08)
		smoke.mesh = card
		smoke.material_override = art_materials["smoke"]
		smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		smoke.position = CottageArt.Joinery.chimney_mouth(home) + Vector3.UP * card.size.y * 0.5
		smoke.set_instance_shader_parameter("phase", float(hash(home["id"]) % 127) * 0.24)
		smoke.extra_cull_margin = 0.73
		root.add_child(smoke)
	return root


func _instance_view(item: Dictionary, snapshot: Dictionary) -> Node3D:
	if not WoodlandNature.supports(item["asset_id"]):
		return super._instance_view(item, snapshot)
	var visual: Node3D
	if item.has("hedge"):
		var layout: Dictionary = HedgeView.plan(item, snapshot)
		visual = ArtViewPlan.build_batch(
			layout["items"],
			layout["poses"],
			wood_material,
			stone_material,
			ArtViewPlan.describe("NAT-06", wood_material, stone_material, _woodland_style())
		)
		visual.set_meta("object_id", item["id"])
		visual.set_meta("asset_id", "NAT-07")
	elif _woodland_style():
		visual = WoodlandNature.create(item["asset_id"], item["id"])
	else:
		visual = ArtFoliageCatalog.create(
			item["asset_id"], item["id"], wood_material, stone_material
		)
	return AssetRegistry.create(item, snapshot, wood_material, stone_material, visual)


func _on_published(snapshot: Dictionary, prepared: Dictionary) -> void:
	super._on_published(snapshot, prepared)
	if art_materials.is_empty():
		return
	ArtMaterials.sync_cottage_palette(art_materials, snapshot["environment"])
	if _woodland_style() and lanterns != null:
		lanterns.configure_woodland(snapshot)
	if _woodland_style() and prepared["units"].has("woodland_contacts"):
		_woodland_contacts = prepared["units"]["woodland_contacts"]
		if _woodland_contacts.material_override != null:
			_woodland_contacts.material_override.set_shader_parameter(
				"foliage_tint", GardenPalette.tint(snapshot["environment"], "foliage")
			)
	if _curtain == null or _curtain_seed != str(snapshot["world_seed"]):
		if is_instance_valid(_curtain):
			_curtain.queue_free()
		_curtain = ArtScenery.curtain(
			snapshot, wood_material, stone_material, terrain_material, _woodland_style()
		)
		_curtain_seed = str(snapshot["world_seed"])
		world_view.add_child(_curtain)
	var signature: int = ArtScenery.bank_signature(snapshot)
	if signature != _bank_signature:
		if is_instance_valid(_pond_bank):
			_pond_bank.queue_free()
		_pond_bank = ArtScenery.bank(snapshot, wood_material, stone_material, _woodland_style())
		if _woodland_style():
			WoodlandPond.add_leaves(_pond_bank, snapshot)
			WoodlandPond.add_shallows(_pond_bank, snapshot)
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
	for pair: Array in [
		["curtain", _curtain], ["bank", _pond_bank], ["contacts", _woodland_contacts]
	]:
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
