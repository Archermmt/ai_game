extends "res://app/week_five_boot.gd"
## W06 local generation, staged preparation, then one atomic publication.

const W06_SAVE: String = "user://week_06/forest.wgs"
var stage: ResourceStage
var lanterns: LanternController
var _submitted_usec: int = 0
var _commit_latencies: Array[float] = []
var _last_worker_ms: float = 0.0
var _planner: ViewPlan
var _worker_cache: Dictionary = {}
var _sync_cache: Dictionary = {}
var _live_units: Dictionary = {}
var _static_views: Dictionary = {}
var _six_snapshot: Dictionary = {}
var _six_poses: Dictionary = {}
var _stage_epoch: int = -1
var _stage_committed: bool = false
var _prepare_started: int = 0
var _latencies: Array[float] = []
var _last_generated: Array = []
var _batch_count: int = 0
var _phase_timings: Array[Dictionary] = []
var _phase_timing: Dictionary = {}


func _ready() -> void:
	stage = ResourceStage.new()
	stage.name = "ResourceStage"
	add_child(stage)
	stage.completed.connect(_stage_done)
	_planner = ViewPlan.new(self)
	super._ready()
	tools = WeekSixTools.new(session)
	tools.mode = "rect"
	_worker_cache = _sync_cache.duplicate(true)
	queue.evaluator = func(snapshot: Dictionary) -> Dictionary:
		return LocalRebuild.evaluate(snapshot, _worker_cache)
	hud.vegetation_changed.connect(_vegetation_settings)
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--w06-gallery":
			_six_demo(false)
		if argument == "--w06-foliage":
			_six_demo(true)
		if argument == "--ui-scale=1.5":
			hud.set_ui_scale(1.5)
	_apply_render_flags()
	hud.set_status("W06：刷出林下草木，摆上茶具与提灯；Esc 取消")


func _setup_ground() -> void:
	super._setup_ground()
	lanterns = LanternController.new()
	lanterns.name = "LanternController"
	world_view.add_child(lanterns)


func _setup_initial_buildings() -> void:
	super._setup_initial_buildings()
	var draft: Dictionary = document.snapshot()
	draft["environment"]["lamp_probes"] = []
	for entry: Array in [
		["PROP-07", Vector3(-4, 0, 4)],
		["PROP-08", Vector3(3.5, 0, 4.5)],
		["PROP-08", Vector3(-2.5, 0, 6)]
	]:
		var item: Dictionary = InstanceEdits.allocate(draft, entry[1])
		item["asset_id"] = entry[0]
		if entry[0] == "PROP-07":
			for parent: Dictionary in draft["instances"]:
				if parent["asset_id"] == "PROP-01":
					item["support_id"] = parent["id"]
					item["position"] = parent["position"].duplicate()
	session.replace_document(draft, _prepare_views)


func _prepare_views(snapshot: Dictionary) -> Dictionary:
	return _prepare_resources(LocalRebuild.evaluate(snapshot, _sync_cache))


func _prepare_resources(data: Dictionary) -> Dictionary:
	if not data.get("ok", false):
		return data
	var plan: Dictionary = _planner.prepare(data)
	for work: Callable in plan["jobs"]:
		work.call()
	return plan["payload"]


func _submit_async(candidate: Dictionary, label: String) -> void:
	_submitted_usec = Time.get_ticks_usec()
	super._submit_async(VegetationBrush.reconcile(candidate), label)


func _preview_linked() -> void:
	for path: Dictionary in session.preview["paths"]:
		if not path.has("curved"):
			path["curved"] = true
	var linked: Dictionary = DoorRules.reconcile(session.preview)
	session.update_gesture(VegetationBrush.reconcile(linked["snapshot"]))
	_preview_token = queue.request(session.preview, Rect2(-24, -24, 48, 48))
	var error: String = WorldDocument.validate(session.preview)
	hud.set_status("预览中；松手或确认提交，Esc 取消" if error.is_empty() else _reason(error))


func _on_batch(token: int, data: Dictionary, committed: bool) -> void:
	stage.cancel()
	if not data.get("ok", false):
		if committed:
			session.cancel_gesture()
		_restore_view()
		hud.set_status(_reason(data.get("error", "generation_failed")))
		return
	if not committed and (token != _preview_token or session.phase != EditSession.Phase.PREVIEW):
		return
	_prepare_started = Time.get_ticks_usec()
	_phase_timing = {
		"worker_ms": data.get("worker_ms", 0.0),
		"request_to_ready_ms": float(_prepare_started - _submitted_usec) / 1000.0
	}
	var plan: Dictionary = _planner.prepare(data, stage)
	_phase_timing["planner_ms"] = float(Time.get_ticks_usec() - _prepare_started) / 1000.0
	_stage_epoch = queue.epoch
	_stage_committed = committed
	queue.consumer_busy = true
	queue.consumer_locked = committed
	stage.begin(token, plan["jobs"], plan["payload"])


func _stage_done(token: int, payload: Dictionary) -> void:
	if token != queue.newest_token or queue.epoch != _stage_epoch:
		_discard(payload)
		queue.consumer_busy = false
		queue.consumer_locked = false
		return
	var start: int = Time.get_ticks_usec()
	if _stage_committed:
		var result: Dictionary = session.finish_prepared(payload)
		hud.set_status("已提交，可撤销" if result["ok"] else _reason(result["error"]))
		if not result["ok"]:
			_discard(payload)
			_restore_view()
		_preview_visible = false
		if _submitted_usec > 0 and result["ok"]:
			_commit_latencies.append(float(Time.get_ticks_usec() - _submitted_usec) / 1000)
			_phase_timing["publish_ms"] = float(Time.get_ticks_usec() - start) / 1000.0
			_phase_timing["complete_ms"] = _commit_latencies.back()
			_phase_timings.append(_phase_timing.duplicate())
			if _phase_timings.size() > 50:
				_phase_timings.pop_front()
		_submitted_usec = 0
	elif session.phase == EditSession.Phase.PREVIEW:
		_on_published(session.preview, payload)
		_preview_visible = true
	else:
		_discard(payload)
	_apply_samples.append(float(Time.get_ticks_usec() - start) / 1000)
	_latencies.append(float(Time.get_ticks_usec() - _prepare_started) / 1000)
	queue.consumer_busy = false
	queue.consumer_locked = false


func _on_published(snapshot: Dictionary, prepared: Dictionary) -> void:
	var units: Dictionary = prepared["units"]
	var data: Dictionary = prepared["data"]
	_field = TerrainField.new(snapshot)
	camera_rig.refresh()
	for key: String in units:
		var value: Variant = units[key]
		if value is Node3D:
			var parent: Node3D = instance_root
			if key.begins_with("building:"):
				parent = building_root
			elif key.begins_with("support:"):
				parent = foundation_root
			elif key.begins_with("structure:"):
				parent = structure_root
			if value.get_parent() == null:
				parent.add_child(value)
		elif key.begins_with("terrain:"):
			var index: int = int(key.trim_prefix("terrain:"))
			while _terrain_views.size() <= index:
				var view: MeshInstance3D = MeshInstance3D.new()
				view.material_override = terrain_material
				terrain_root.add_child(view)
				_terrain_views.append(view)
			if _terrain_views[index].mesh != value:
				_terrain_views[index].mesh = value
	for key: String in _live_units:
		var old: Variant = _live_units[key]
		if old is Node3D and (not units.has(key) or units[key] != old) and is_instance_valid(old):
			if old.get_parent() != null:
				old.get_parent().remove_child(old)
			old.queue_free()
	_static_mesh("path", units["path"], path_root, path_material)
	_static_mesh("fence", units["fence"], fence_root, wood_material)
	water_view.visible = units["water"] != null
	if water_view.visible:
		water_view.mesh = units["water"]
		water_view.position = Vector3.ZERO
		var poly: PackedVector2Array = PondShape.contour(snapshot["pool"])
		var center: Vector2 = Vector2.ZERO
		var region: Rect2 = Rect2(poly[0], Vector2.ZERO)
		for p: Vector2 in poly:
			center += p / poly.size()
			region = region.expand(p)
		water_material.set_shader_parameter("surface_origin", center)
		water_material.set_shader_parameter("radius", maxf(region.size.x, region.size.y) * 0.5)
	_instance_views.clear()
	_tree_views.clear()
	var renew_wind: bool = false
	for key: String in units:
		if key.begins_with("item:"):
			var id_value: String = key.trim_prefix("item:")
			var node: Node3D = units[key]
			_instance_views[id_value] = node
			if node.transform != data["poses"][id_value]:
				node.transform = data["poses"][id_value]
			if VegetationCatalog.NAMES.has(node.get_meta("asset_id")):
				_tree_views[id_value] = node
		if (
			(key.begins_with("item:") or key.begins_with("batch:"))
			and _live_units.get(key) != units[key]
		):
			renew_wind = true
	if renew_wind or units.size() != _live_units.size():
		wind_materials.clear()
		var known_materials: Dictionary = {}
		for key: String in units:
			if key.begins_with("item:") or key.begins_with("batch:"):
				for material: ShaderMaterial in WeekSixCatalog.wind_materials(units[key]):
					if not known_materials.has(material.get_instance_id()):
						known_materials[material.get_instance_id()] = true
						wind_materials.append(material)
	if renew_wind or snapshot["environment"] != _six_snapshot.get("environment", {}):
		_sync_wind(snapshot)
	var aged: bool = snapshot["environment"].get("aged", false)
	architecture_material.set_shader_parameter("aged", aged)
	wood_material.albedo_color = Color("cfe5c7") if aged else Color.WHITE
	stone_material.albedo_color = Color("c6e0ba") if aged else Color.WHITE
	_apply_light(snapshot["environment"]["dusk"])
	_structure_issues = data["structures"]["issues"]
	_terrain_rebuilt = data["terrain_rebuilt"]
	_last_generated = data["generated"]
	_last_worker_ms = data.get("worker_ms", 0.0)
	_batch_count = (
		units.keys().filter(func(k: String) -> bool: return k.begins_with("batch:")).size()
	)
	_six_poses = data["poses"]
	lanterns.configure(snapshot, _six_poses, _instance_views)
	_live_units = units.duplicate()
	_planner.prune(units)
	_six_snapshot = snapshot.duplicate(true)
	var selected_alive: Array[String] = []
	for home: Dictionary in snapshot["buildings"]:
		if home["id"] in selected_buildings:
			selected_alive.append(home["id"])
	selected_buildings = selected_alive
	hud.sync(snapshot, selected_buildings)
	hud.sync_extra(snapshot, selected_buildings, selected_path)
	hud.sync_garden(snapshot, _structure_issues)
	_draw_controls()
	_show_selection()


func _static_mesh(key: String, mesh: ArrayMesh, parent: Node3D, paint: Material) -> void:
	if not _static_views.has(key):
		var node: MeshInstance3D = MeshInstance3D.new()
		node.material_override = paint
		parent.add_child(node)
		_static_views[key] = node
	if _static_views[key].mesh != mesh:
		_static_views[key].mesh = mesh


func _advance_light(delta: float) -> void:
	super._advance_light(delta)
	if lanterns != null and camera_rig.camera != null:
		lanterns.advance(camera_rig.camera.global_position, _light_mix)


func _on_action(action: StringName) -> void:
	if tools == null:
		return
	if session.phase == EditSession.Phase.PENDING_COMMIT and action not in [&"cancel", &"camera"]:
		hud.set_status("正在完成上一笔；Esc 可取消")
		return
	if action in [&"plant_brush", &"plant_erase", &"single_plant"]:
		_cancel_edit()
		tools.mode = "place_asset" if action == &"single_plant" else String(action)
		hud.set_status("分类笔刷：左键拖绘，Ctrl/Cmd+滚轮调半径；手放内容受保护")
	elif action in [&"lamp_on", &"lamp_off", &"lamp_auto", &"lock_height"]:
		_cancel_edit()
		var draft: Dictionary = document.snapshot()
		for item: Dictionary in draft["instances"]:
			if item["id"] not in tools.selected:
				continue
			if action == &"lock_height":
				item["height_locked"] = not item.get("height_locked", false)
				item["locked_y"] = _six_poses[item["id"]].origin.y
			elif item["asset_id"] == "PROP-08":
				item["lamp_mode"] = String(action).trim_prefix("lamp_")
		_submit_async(draft, "调整物件")
	else:
		super._on_action(action)
	if hud.has_method("set_active_tool"):
		hud.set_active_tool(tools.mode)


func _vegetation_settings(category: String, radius: float, densities: Dictionary) -> void:
	if tools is WeekSixTools:
		tools.category = category
		tools.radius = radius
		tools.densities = densities.duplicate()


func _preview_tool() -> void:
	if session.phase == EditSession.Phase.PREVIEW:
		session.update_gesture(VegetationBrush.reconcile(session.preview))
	super._preview_tool()
	if tools.mode in ["plant_brush", "plant_erase"]:
		if preview_root.get_child_count() > 0:
			var ring: TorusMesh = preview_root.get_child(0).mesh
			ring.inner_radius = maxf(0.1, tools.radius - 0.05)
			ring.outer_radius = tools.radius + 0.05
		hud.set_status(
			(
				"%s · 半径 %.1fm · 本笔 %d 项；达到 800 项上限会停止新增"
				% [
					{"trees": "树木", "plants": "灌草", "rocks": "岩石"}[tools.category],
					tools.radius,
					tools.changed_count
				]
			)
		)


func _unhandled_input(event: InputEvent) -> void:
	if (
		tools is WeekSixTools
		and tools.mode in ["plant_brush", "plant_erase"]
		and event is InputEventMouseButton
		and event.pressed
		and (event.ctrl_pressed or event.meta_pressed)
		and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]
	):
		tools.radius = clampf(
			tools.radius + (0.25 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -0.25), 0.5, 6
		)
		hud.brush_radius.set_value_no_signal(tools.radius)
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)


func _update_custom(point: Vector3) -> void:
	super._update_custom(point)
	if tools.mode == "place_asset" and selected_asset in ["PROP-07", "PROP-08"]:
		var draft: Dictionary = session.preview.duplicate(true)
		var item: Dictionary = draft["instances"].back()
		for parent: Dictionary in _custom_before["instances"]:
			if (
				parent["asset_id"] in ["PROP-01", "PROP-05"]
				and (
					(
						Vector2(point.x - parent["position"][0], point.z - parent["position"][2])
						. length()
					)
					< 0.3
				)
			):
				item["support_id"] = parent["id"]
				item["position"] = parent["position"].duplicate()
				break
		session.update_gesture(draft)
		_preview_linked()


func _show_selection() -> void:
	if tools == null or gizmo_root == null:
		return
	_clear_children(gizmo_root)
	for id_value: String in tools.selected:
		if not _six_poses.has(id_value):
			continue
		var handle: MeshInstance3D = MeshInstance3D.new()
		var shape: TorusMesh = TorusMesh.new()
		shape.inner_radius = 0.5
		shape.outer_radius = 0.55
		handle.mesh = shape
		var paint: StandardMaterial3D = StandardMaterial3D.new()
		paint.albedo_color = Color("e7ad58")
		paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		handle.material_override = paint
		handle.position = _six_poses[id_value].origin + Vector3.UP * 0.06
		gizmo_root.add_child(handle)


func _cancel_edit() -> void:
	_submitted_usec = 0
	if stage != null:
		stage.cancel()
	super._cancel_edit()


func _save_action(action: StringName) -> void:
	_cancel_edit()
	if action == &"save":
		hud.set_status(
			"作品已保存" if SaveCodec.write_file(W06_SAVE, document.snapshot()) == OK else "保存失败"
		)
	else:
		var loaded: Dictionary = SaveCodec.read_file(W06_SAVE)
		if loaded["ok"]:
			_show_result(session.replace_document(loaded["snapshot"], _prepare_views), "作品已读取")
		else:
			hud.set_status("没有有效存档；作品保留")


func _delivery_metrics() -> Dictionary:
	var result: Dictionary = super._delivery_metrics()
	var slices: Array[float] = stage.slices_ms.duplicate() if stage != null else []
	slices.sort()
	result["preparation_slice_max_ms"] = slices.back() if not slices.is_empty() else 0
	result["preparation_slices"] = slices.size()
	result["foliage_batches"] = _batch_count
	result["generated_units"] = _last_generated
	result["worker_compute_ms"] = _last_worker_ms
	var latency: Array[float] = _commit_latencies.duplicate()
	latency.sort()
	result["rebuild_phase_timings"] = _phase_timings.duplicate(true)
	result["commit_latency_samples_ms"] = _commit_latencies.duplicate()
	result["commit_latency_max_ms"] = latency.back() if not latency.is_empty() else 0
	result["commit_latency_legacy_upper_ms"] = (
		latency[int(latency.size() * 0.95)] if not latency.is_empty() else 0
	)
	result["commit_latency_p95_ms"] = PerformanceSamples.percentile(_commit_latencies)
	result["commit_percentile_method"] = "nearest_rank"
	result["local_lights"] = lanterns.active_ids.size() if lanterns != null else 0
	return result


static func _discard(payload: Dictionary) -> void:
	for value: Variant in payload.get("units", {}).values():
		if value is Node and is_instance_valid(value) and value.get_parent() == null:
			value.free()


func _six_demo(foliage: bool) -> void:
	var draft: Dictionary = document.snapshot()
	if foliage:
		VegetationBrush.paint(draft, Vector2(10, 10), "plants", 6, 1, {})
		VegetationBrush.paint(draft, Vector2(-12, -10), "trees", 6, 1, {})
	else:
		draft["buildings"] = []
		draft["paths"] = []
		draft["pool"] = {}
		draft["bridges"] = []
		draft["fences"] = []
		draft["instances"] = []
		for entry: Array in [
			["PROP-01", Vector3(-2, 0, -2)],
			["PROP-07", Vector3(-2, 0, -2)],
			["PROP-08", Vector3(1, 0, 1)],
			["PROP-08", Vector3(2, 0, -2)]
		]:
			var item: Dictionary = InstanceEdits.allocate(draft, entry[1])
			item["asset_id"] = entry[0]
			if entry[0] == "PROP-07":
				item["support_id"] = draft["instances"][0]["id"]
			if entry[0] == "PROP-08":
				item["lamp_mode"] = "on" if entry[1].z > 0 else "off"
		camera_rig.distance = 11
		camera_rig.target = Vector3(0, 0.6, 0)
		camera_rig.refresh()
	session.replace_document(draft, _prepare_views)


func _apply_render_flags() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--dusk":
			_light_target = 1
			_light_mix = 1
		for paint: ShaderMaterial in wind_materials:
			if argument.begins_with("--wind-time="):
				paint.set_shader_parameter("freeze_time", true)
				paint.set_shader_parameter(
					"sample_time", argument.trim_prefix("--wind-time=").to_float()
				)
			if argument == "--still":
				paint.set_shader_parameter("reduce_motion", true)
			if argument.begins_with("--wind-strength="):
				paint.set_shader_parameter(
					"wind_strength", argument.trim_prefix("--wind-strength=").to_float()
				)
	_advance_light(0)


func _instance_signature(item: Dictionary, _snapshot: Dictionary) -> String:
	return DirtyGraph.key([item["asset_id"], item["id"]])


func _instance_view(item: Dictionary, _snapshot: Dictionary) -> Node3D:
	return WeekSixCatalog.create(item["asset_id"], item["id"], wood_material, stone_material)


func _decorated_building_view(home: Dictionary, mesh: ArrayMesh, _snapshot: Dictionary) -> Node3D:
	return _building_view(home, mesh)
