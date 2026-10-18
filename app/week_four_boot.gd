extends "res://app/week_three_boot.gd"
## W04 composition. Source transactions reconcile paths and doors before publication.

signal dependencies_changed(bounds: Rect2, path_ids: Array[String])

const W04_SAVE: String = "user://week_04/forest.wgs"
var selected_path: String = ""
var opening_variant: int = 0
var selected_asset: String = "PROP-01"
var control_root: Node3D
var path_material: StandardMaterial3D
var fence_root: Node3D
var light_rig: LightRig
var _worker_terrain_cache: Dictionary = {}
var _main_terrain_cache: Dictionary = {}
var _w4_kinds: Dictionary = {}
var _extra_wind: Array[ShaderMaterial] = []
var _custom_drag: bool = false
var _custom_before: Dictionary = {}
var _control_index: int = -1
var _light_mix: float = 0.0
var _light_target: float = 0.0
var _lighting_ready: bool = false
var _last_committed: Dictionary = {}
var _notices: Array = []
var _terrain_rebuilt: int = 0


func _ready() -> void:
	super._ready()
	tools = WeekFourTools.new(session)
	tools.mode = "rect"
	queue.evaluator = func(snapshot: Dictionary) -> Dictionary:
		return WorldRebuild.evaluate(snapshot, _worker_terrain_cache)
	hud.path_selected.connect(
		func(key: String) -> void:
			if session.phase == EditSession.Phase.PENDING_COMMIT:
				return
			_cancel_edit()
			selected_path = key
			_refresh_inspector()
	)
	hud.asset_selected.connect(func(key: String) -> void: selected_asset = key)
	hud.opening_variant_selected.connect(func(index: int) -> void: opening_variant = index)
	hud.environment_changed.connect(_environment_value)
	_light_mix = (
		1.0
		if document.state["environment"]["dusk"] or "--dusk" in OS.get_cmdline_user_args()
		else 0.0
	)
	_lighting_ready = true
	_advance_light(0)
	_refresh_inspector()
	for argument: String in OS.get_cmdline_user_args():
		if argument in ["--w04-links-demo", "--w04-terrain-demo", "--w04-asset-gallery"]:
			_setup_demo(argument)
	hud.set_status("W04：曲线石径连墙可生门；门窗手放优先，Esc 取消")


func _setup_samples() -> void:
	pass


func _setup_materials() -> void:
	super._setup_materials()
	window_material.shader = preload("res://features/lighting/window_transition.gdshader")
	path_material = StandardMaterial3D.new()
	path_material.vertex_color_use_as_albedo = true
	path_material.vertex_color_is_srgb = true
	path_material.roughness = 0.95


func _setup_ground() -> void:
	super._setup_ground()
	control_root = Node3D.new()
	control_root.name = "PathControlPoints"
	world_view.add_child(control_root)
	fence_root = Node3D.new()
	fence_root.name = "Fences"
	world_view.add_child(fence_root)
	light_rig = LightRig.new()
	light_rig.name = "ControlledLampProbes"
	world_view.add_child(light_rig)


func _setup_initial_buildings() -> void:
	super._setup_initial_buildings()
	var draft: Dictionary = document.snapshot()
	draft["terrain"]["base_profile"] = "forest_slope_v1"
	draft["pool"] = {}
	draft = TerrainField.pond(draft, Vector2(7, -1), 2.5)
	for entry: Array in [
		["NAT-04", Vector3(-5, 0, 6)],
		["NAT-05", Vector3(-4, 0, 6)],
		["NAT-06", Vector3(-7, 0, 5)],
		["NAT-08", Vector3(10, 0, 7)],
		["NAT-09", Vector3(11, 0, 6)],
		["PROP-01", Vector3(-4, 0, 4)],
		["PROP-02", Vector3(-2, 0, 7)],
		["PROP-04", Vector3(4, 0, 5.5)]
	]:
		var item: Dictionary = InstanceEdits.allocate(draft, entry[1])
		item["asset_id"] = entry[0]
	for path: Dictionary in draft["paths"]:
		path["curved"] = true
	draft["environment"]["wind_direction"] = 0.4
	draft["environment"]["lamp_probes"] = []
	for i: int in range(6):
		draft["environment"]["lamp_probes"].append(
			{"id": "lamp-probe-%d" % i, "position": [-1.8, 0.8, 3.0 + float(i) * 1.3]}
		)
	var linked: Dictionary = DoorRules.reconcile(draft)
	session.replace_document(linked["snapshot"], _prepare_views)


func _prepare_views(snapshot: Dictionary) -> Dictionary:
	return _prepare_resources(WorldRebuild.evaluate(snapshot, _main_terrain_cache))


func _setup_demo(mode: String) -> void:
	var draft: Dictionary = document.snapshot()
	if mode == "--w04-asset-gallery":
		draft["buildings"] = []
		draft["paths"] = []
		draft["instances"] = []
		draft["pool"] = {}
		draft["environment"]["lamp_probes"] = []
		for entry: Array in [
			["NAT-04", Vector3(-3, 0, 2)],
			["NAT-05", Vector3(-1, 0, 2)],
			["NAT-06", Vector3(1, 0, 2)],
			["NAT-08", Vector3(-3, 0, -1)],
			["NAT-09", Vector3(-1, 0, -1)],
			["PROP-01", Vector3(2, 0, -1)],
			["PROP-02", Vector3(4, 0, 2)]
		]:
			var item: Dictionary = InstanceEdits.allocate(draft, entry[1])
			item["asset_id"] = entry[0]
		camera_rig.distance = 13.0
		camera_rig.target = Vector3(0, 0.6, 0)
		camera_rig.refresh()
	elif mode == "--w04-links-demo":
		draft["buildings"][0]["openings"] = [draft["buildings"][0]["openings"][1]]
		draft["paths"] = []
		PathGeometry.allocate(draft, [[-1.5, 0, 9], [-2.5, 0, 6], [-1.5, 0, 1.5]])
		PathGeometry.allocate(draft, [[3, 0, 8], [1, 0, 5], [-1.4, 0, 1.5]])
		for path: Dictionary in draft["paths"]:
			path["curved"] = true
		FenceGeometry.allocate(draft, [[-6, 0, 6], [3, 0, 6]])
	else:
		draft["buildings"][0]["position"][1] = 0.6
		draft = TerrainEdits.stroke(draft, Vector2(0, -1), "lower", 4.0, 0.6)
	var linked: Dictionary = DoorRules.reconcile(draft)
	session.replace_document(linked["snapshot"], _prepare_views)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--wind-time="):
			for paint: ShaderMaterial in wind_materials:
				paint.set_shader_parameter("freeze_time", true)
				paint.set_shader_parameter(
					"sample_time", argument.trim_prefix("--wind-time=").to_float()
				)


func _prepare_resources(data: Dictionary) -> Dictionary:
	var previous_supports: Array = _resource_cache.get("supports", [])
	var result: Dictionary = super._prepare_resources(data)
	if not result.get("ok", false):
		return result
	result["supports"] = data["supports"].duplicate(true)
	for index: int in range(result["supports"].size()):
		var support: Dictionary = result["supports"][index]
		for part: String in ["stone", "wood"]:
			var arrays: Array = support["foundation"][part + "_arrays"]
			if (
				index < previous_supports.size()
				and previous_supports[index].get("foundation", {}) == support["foundation"]
			):
				support[part + "_mesh"] = previous_supports[index].get(part + "_mesh")
				continue
			support[part + "_mesh"] = (
				BuildingGeometry.mesh_from_arrays(arrays)
				if arrays[Mesh.ARRAY_VERTEX].size() > 0
				else null
			)
	result["fence_mesh"] = null
	if (
		data.get("fence_arrays", []).size() > 0
		and data["fence_arrays"][Mesh.ARRAY_VERTEX].size() > 0
	):
		result["fence_mesh"] = BuildingGeometry.mesh_from_arrays(data["fence_arrays"])
	_terrain_rebuilt = data.get("terrain_rebuilt", 64)
	return result


func _rebuild_probe_paths(snapshot: Dictionary) -> void:
	super._rebuild_probe_paths(snapshot)
	for view: MeshInstance3D in path_root.get_children():
		view.material_override = path_material


func _add_support(_spec: Dictionary, support: Dictionary) -> void:
	for part: String in ["stone", "wood"]:
		if support.get(part + "_mesh") == null:
			continue
		var view: MeshInstance3D = MeshInstance3D.new()
		view.mesh = support[part + "_mesh"]
		view.material_override = stone_material if part == "stone" else wood_material
		foundation_root.add_child(view)


func _on_published(snapshot: Dictionary, prepared: Dictionary) -> void:
	super._on_published(snapshot, prepared)
	_clear_children(fence_root)
	if prepared.get("fence_mesh") != null:
		var view: MeshInstance3D = MeshInstance3D.new()
		view.mesh = prepared["fence_mesh"]
		view.material_override = wood_material
		fence_root.add_child(view)
	_sync_wind(snapshot)
	if session.phase == EditSession.Phase.IDLE:
		_emit_dependencies(snapshot)
	_refresh_inspector()


func _emit_dependencies(snapshot: Dictionary) -> void:
	var changed: Array[String] = []
	var bounds: Rect2 = Rect2()
	for path: Dictionary in snapshot["paths"] + _last_committed.get("paths", []):
		var counterpart: Array = (
			_last_committed.get("paths", []) if path in snapshot["paths"] else snapshot["paths"]
		)
		if path not in counterpart:
			if path["id"] not in changed:
				changed.append(path["id"])
			var region: Rect2 = PathCurve.dirty_bounds(path)
			bounds = region if bounds.size == Vector2.ZERO else bounds.merge(region)
	if not changed.is_empty():
		dependencies_changed.emit(bounds, changed)
	_last_committed = snapshot.duplicate(true)


func _rebuild_instances(snapshot: Dictionary) -> void:
	wind_materials = wind_materials.filter(
		func(m: ShaderMaterial) -> bool: return m not in _extra_wind
	)
	_extra_wind.clear()
	super._rebuild_instances(snapshot)
	for item: Dictionary in snapshot["instances"]:
		var key: String = item["id"]
		if not WeekFourCatalog.NAMES.has(item["asset_id"]):
			continue
		var view: Node3D = _instance_views[key]
		if _w4_kinds.get(key, "") != item["asset_id"]:
			var real: Node3D = WeekFourCatalog.create(
				item["asset_id"], key, wood_material, stone_material
			)
			real.transform = view.transform
			view.free()
			instance_root.add_child(real)
			_instance_views[key] = real
			_w4_kinds[key] = item["asset_id"]
			view = real
		var p: Array = item["position"]
		var next_position: Vector3 = Vector3(
			p[0], p[1] + _field.height_at(Vector2(p[0], p[2])), p[2]
		)
		if view.position != next_position:
			view.position = next_position
		if String(item["asset_id"]).begins_with("NAT"):
			var normal: Vector3 = _field.normal_at(Vector2(p[0], p[2]))
			var next_basis: Basis = (
				(Basis(Quaternion(Vector3.UP, normal)) * Basis(Vector3.UP, item["yaw"]))
				. scaled(Vector3.ONE * float(item["scale"]))
			)
			if not view.basis.is_equal_approx(next_basis):
				view.basis = next_basis
		_collect_extra_wind(view)
	for key: String in _w4_kinds.keys():
		if not _instance_views.has(key):
			_w4_kinds.erase(key)
	_sync_wind(snapshot)


func _collect_extra_wind(root: Node) -> void:
	if root is MeshInstance3D and root.material_override is ShaderMaterial:
		_extra_wind.append(root.material_override)
		wind_materials.append(root.material_override)
	for child: Node in root.get_children():
		_collect_extra_wind(child)


func _sync_wind(snapshot: Dictionary) -> void:
	for paint: ShaderMaterial in wind_materials:
		paint.set_shader_parameter(
			"wind_direction", snapshot["environment"].get("wind_direction", 0.4)
		)
		paint.set_shader_parameter("wind_strength", snapshot["environment"]["wind_strength"])
		paint.set_shader_parameter("reduce_motion", snapshot["environment"]["reduce_motion"])


func _submit_async(candidate: Dictionary, label: String) -> void:
	var incoming: Dictionary = candidate.duplicate(true)
	for path: Dictionary in incoming["paths"]:
		if not path.has("curved"):
			path["curved"] = true
	var linked: Dictionary = DoorRules.reconcile(incoming)
	_notices = linked["notices"]
	if linked["snapshot"] == document.state:
		_cancel_edit()
		hud.set_status("未发生修改；作品和历史保持不变")
		return
	super._submit_async(linked["snapshot"], label)


func _on_batch(token: int, data: Dictionary, committed: bool) -> void:
	super._on_batch(token, data, committed)
	if committed and not _notices.is_empty():
		hud.set_status("已提交；" + str(_notices[0]))


func _preview_size(size: Vector3) -> void:
	super._preview_size(size)
	if session.phase == EditSession.Phase.PREVIEW:
		_preview_linked()


func _preview_linked() -> void:
	for path: Dictionary in session.preview["paths"]:
		if not path.has("curved"):
			path["curved"] = true
	var linked: Dictionary = DoorRules.reconcile(session.preview)
	session.update_gesture(linked["snapshot"])
	_preview_token = queue.request(session.preview, Rect2(-24, -24, 48, 48))
	var error: String = WorldDocument.validate(session.preview)
	hud.set_status("预览中；松手或按钮提交，Esc 取消" if error.is_empty() else _reason(error))


func _refresh_inspector() -> void:
	if hud.has_method("sync_extra"):
		hud.sync_extra(document.snapshot(), selected_buildings, selected_path)
	_draw_controls()


func _draw_controls() -> void:
	if control_root == null:
		return
	_clear_children(control_root)
	if tools == null or tools.mode != "path_node":
		return
	var snapshot: Dictionary = (
		session.preview if session.phase == EditSession.Phase.PREVIEW else document.state
	)
	var field: TerrainField = TerrainField.new(snapshot)
	for path: Dictionary in snapshot["paths"]:
		if path["id"] != selected_path:
			continue
		for p: Array in path["points"]:
			var view: MeshInstance3D = MeshInstance3D.new()
			var sphere: SphereMesh = SphereMesh.new()
			sphere.radius = 0.13
			sphere.height = 0.26
			view.mesh = sphere
			view.position = Vector3(p[0], field.height_at(Vector2(p[0], p[2])) + 0.18, p[2])
			var paint: StandardMaterial3D = StandardMaterial3D.new()
			paint.albedo_color = Color("edbf67")
			paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			view.material_override = paint
			control_root.add_child(view)


func _apply_light(dusk: bool) -> void:
	_light_target = 1.0 if dusk else 0.0
	if not _lighting_ready:
		_light_mix = _light_target
		_advance_light(0)


func _advance_light(delta: float) -> void:
	if sun == null or world_environment == null:
		return
	_light_mix = move_toward(_light_mix, _light_target, delta / 1.2)
	sun.light_color = Color("fff1d3").lerp(Color("ffc78a"), _light_mix)
	sun.light_energy = lerpf(1.65, 1.1, _light_mix)
	sun.rotation_degrees.x = lerpf(-48.0, -18.0, _light_mix)
	world_environment.environment.ambient_light_color = Color("c9d8c1").lerp(
		Color("94a3aa"), _light_mix
	)
	if window_material != null:
		window_material.set_shader_parameter("dusk_mix", _light_mix)
	if light_rig != null:
		light_rig.sync(
			document.state["environment"].get("lamp_probes", []),
			camera_rig.camera.global_position,
			_light_mix
		)


func _process(delta: float) -> void:
	_advance_light(delta)
	super._process(delta)


func _environment_value(key: String, value: float) -> void:
	if session.phase != EditSession.Phase.IDLE:
		return
	var draft: Dictionary = document.snapshot()
	draft["environment"][key] = value
	_submit_async(draft, "调整环境")


func _save_action(action: StringName) -> void:
	_cancel_edit()
	if action == &"save":
		hud.set_status(
			"作品已保存" if SaveCodec.write_file(W04_SAVE, document.snapshot()) == OK else "保存失败"
		)
	else:
		var loaded: Dictionary = SaveCodec.read_file(W04_SAVE)
		if loaded["ok"]:
			var linked: Dictionary = DoorRules.reconcile(loaded["snapshot"])
			_show_result(session.replace_document(linked["snapshot"], _prepare_views), "作品已读取")


func _on_action(action: StringName) -> void:
	if tools == null:
		return
	if session.phase == EditSession.Phase.PENDING_COMMIT and action not in [&"cancel", &"camera"]:
		hud.set_status("正在完成上一笔；Esc 可取消")
		return
	if (
		action
		in [
			&"smooth",
			&"restore",
			&"place_asset",
			&"place_opening",
			&"move_opening",
			&"path_node",
			&"fence"
		]
	):
		_cancel_edit()
		tools.mode = String(action)
		var label: String = (
			{
				"smooth": "平滑地形",
				"restore": "恢复地形",
				"place_asset": "放置资源",
				"place_opening": "手放门窗",
				"move_opening": "移动门窗",
				"path_node": "拖路径控制点",
				"fence": "围栏初版"
			}
			. get(String(action), String(action))
		)
		hud.set_status("工具：" + label + "；左键拖动，Esc 取消")
		_refresh_inspector()
		return
	if action in [&"lock_opening", &"delete_opening", &"apply_path", &"delete_path"]:
		_editor_action(action)
		return
	super._on_action(action)


func _editor_action(action: StringName) -> void:
	_cancel_edit()
	var draft: Dictionary = document.snapshot()
	if action in [&"apply_path", &"delete_path"] and selected_path.is_empty():
		hud.set_status("请先在石径列表选择路径")
		return
	if action == &"apply_path" or action == &"delete_path":
		for index: int in range(draft["paths"].size()):
			var path: Dictionary = draft["paths"][index]
			if path["id"] != selected_path:
				continue
			if action == &"delete_path":
				draft["paths"].remove_at(index)
			else:
				path["width"] = hud.edit_width.value
				path["curved"] = hud.curved.button_pressed
			break
	else:
		for home: Dictionary in draft["buildings"]:
			if home["id"] not in selected_buildings:
				continue
			var index: int = hud.opening_index()
			if index >= 0 and index < home["openings"].size():
				if action == &"delete_opening":
					if home["openings"][index].get("source", "manual") == "auto_path":
						hud.set_status("自动门由路径维护；请删除供门路径")
						return
					home["openings"].remove_at(index)
				else:
					DoorRules.lock(home["openings"][index])
			break
	_submit_async(draft, "编辑路径或门窗")


func _unhandled_input(event: InputEvent) -> void:
	if (
		tools == null
		or tools.mode not in ["place_asset", "place_opening", "move_opening", "path_node", "fence"]
	):
		super._unhandled_input(event)
		if (
			tools != null
			and tools.mode == "path"
			and _path_drag
			and session.phase == EditSession.Phase.PREVIEW
		):
			_preview_linked()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and (event.alt_pressed or event.shift_pressed):
			return
		var point: Variant = camera_rig.ground_point(event.position)
		if event.pressed and point is Vector3 and session.begin_gesture():
			_custom_drag = true
			_custom_before = document.snapshot()
			drag_start = point
			_choose_control(point)
			if (
				(tools.mode == "path_node" and _control_index < 0)
				or (
					tools.mode in ["place_opening", "move_opening"]
					and selected_buildings.is_empty()
				)
			):
				_cancel_edit()
			else:
				_update_custom(point)
		elif not event.pressed and _custom_drag:
			_custom_drag = false
			if (
				tools.mode == "fence"
				and drag_start.distance_to(point if point is Vector3 else drag_start) < 0.25
			):
				_cancel_edit()
			else:
				_submit_async(session.preview, "编辑：" + tools.mode)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _custom_drag:
		var point: Variant = camera_rig.ground_point(event.position)
		if point is Vector3:
			_update_custom(point)
	else:
		super._unhandled_input(event)


func _choose_control(point: Vector3) -> void:
	_control_index = -1
	if tools.mode != "path_node":
		return
	var nearest: float = 1.5
	for path: Dictionary in document.state["paths"]:
		if path["id"] != selected_path:
			continue
		for i: int in range(path["points"].size()):
			var p: Array = path["points"][i]
			var distance: float = Vector2(point.x - p[0], point.z - p[2]).length()
			if distance < nearest:
				nearest = distance
				_control_index = i


func _update_custom(point: Vector3) -> void:
	var draft: Dictionary = _custom_before.duplicate(true)
	if tools.mode == "place_asset":
		var item: Dictionary = InstanceEdits.allocate(draft, Vector3(point.x, 0, point.z))
		item["asset_id"] = selected_asset
	elif tools.mode == "fence":
		FenceGeometry.allocate(draft, [[drag_start.x, 0, drag_start.z], [point.x, 0, point.z]])
	elif tools.mode == "path_node":
		for path: Dictionary in draft["paths"]:
			if path["id"] == selected_path and _control_index >= 0:
				path["points"][_control_index] = [point.x, 0, point.z]
	elif not selected_buildings.is_empty():
		if tools.mode == "place_opening":
			DoorRules.manual_opening(
				draft, selected_buildings[0], Vector2(point.x, point.z), opening_variant
			)
		else:
			_move_manual(draft, point)
	session.update_gesture(draft)
	_preview_linked()


func _move_manual(draft: Dictionary, point: Vector3) -> void:
	for home: Dictionary in draft["buildings"]:
		if home["id"] not in selected_buildings:
			continue
		var index: int = hud.opening_index()
		if index < 0 or index >= home["openings"].size():
			return
		var opening: Dictionary = home["openings"][index]
		opening["source"] = "manual"
		opening.erase("source_path")
		opening.erase("source_paths")
		var place: Dictionary = DoorRules.wall_point(home, Vector2(point.x, point.z))
		opening["center"] = place["center"]
		opening["facade"] = place["facade"]
		DoorRules.snap_manual(home, index, draft["buildings"])
		return


func _input(event: InputEvent) -> void:
	super._input(event)
	if event is InputEventMouseButton and not event.pressed and _custom_drag:
		if get_viewport().gui_get_hovered_control() != null:
			_cancel_edit()


func _cancel_edit() -> void:
	_custom_drag = false
	super._cancel_edit()


func _delivery_metrics() -> Dictionary:
	var result: Dictionary = super._delivery_metrics()
	result["last_worker_terrain_chunks"] = _terrain_rebuilt
	result["local_lights"] = light_rig.active_ids.size() if light_rig != null else 0
	return result
