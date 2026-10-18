extends "res://app/week_six_boot.gd"
## W07 composition only: inherited transactions and all previous weekly fixtures remain.

const W07_SAVE: String = "user://week_07/forest.wgs"
var _hedge_drag: bool = false
var _hedge_before: Dictionary = {}
var _hedge_points: Array = []
var _hedge_control: int = -1
var _hedge_id: String = ""


func _ready() -> void:
	super._ready()
	tools = WeekSevenTools.new(session)
	tools.mode = "rect"
	hud.instance_selected.connect(_select_objects)
	hud.palette_selected.connect(_choose_palette)
	hud.sync_objects(document.snapshot(), tools.selected)
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--w07-template":
			var template: Dictionary = ForestTemplate.create()
			_show_result(session.replace_document(template, _prepare_views), "林间坡地示范草案")
		if argument in ["--w07-hedges", "--w07-hedge-slope"]:
			_hedge_gallery()
		if argument == "--w07-buildings":
			session.replace_document(BuildingGallery.create(), _prepare_views)
			camera_rig.distance = 49
			camera_rig.target = Vector3(0, 2, 0)
			camera_rig.refresh()
		if argument in ["--w07-contact", "--w07-round-close"]:
			_building_close(argument)
		if argument == "--w07-palette":
			var pages: TabContainer = (
				hud._panels[1].find_children("*", "TabContainer", true, false)[0]
			)
			pages.current_tab = 5
		if argument == "--w07-objects":
			_show_object_card()
	_apply_render_flags()
	hud.set_active_tool(tools.mode)
	hud.set_status("选择底部工具，左键拖绘；属性修改后点提交，Esc 取消")


func _instance_signature(item: Dictionary, snapshot: Dictionary) -> String:
	return DirtyGraph.key(
		[
			item["asset_id"],
			item["id"],
			item.get("hedge", {}),
			[item["position"], item["yaw"], item["scale"]] if item.has("hedge") else [],
			DirtyGraph.field_key(snapshot, HedgeRules.bounds(item)) if item.has("hedge") else "",
			item.get("height_locked", false)
		]
	)


func _instance_view(item: Dictionary, snapshot: Dictionary) -> Node3D:
	return AssetRegistry.create(item, snapshot, wood_material, stone_material)


func _decorated_building_view(home: Dictionary, mesh: ArrayMesh, snapshot: Dictionary) -> Node3D:
	var view: MeshInstance3D = _building_view(home, mesh)
	view.add_child(ArchitecturalKit.assemble(home, wood_material, snapshot["buildings"]))
	return view


func _on_published(snapshot: Dictionary, prepared: Dictionary) -> void:
	super._on_published(snapshot, prepared)
	GardenPalette.apply(self, snapshot)
	if tools != null:
		hud.sync_objects(snapshot, tools.selected)


func _select_objects(ids: Array[String]) -> void:
	if session.phase == EditSession.Phase.PENDING_COMMIT:
		return
	_cancel_edit()
	tools.selected = ids.duplicate()
	hud.sync_objects(document.snapshot(), tools.selected)
	_show_selection()


func _choose_palette(group: String, id_value: String) -> void:
	if session.phase == EditSession.Phase.PENDING_COMMIT:
		return
	_cancel_edit()
	var draft: Dictionary = document.snapshot()
	if not draft["environment"].has("palette"):
		draft["environment"]["palette"] = {}
	draft["environment"]["palette"][group] = id_value
	_submit_async(draft, "调整整园色板")


func _on_action(action: StringName) -> void:
	if tools == null:
		return
	if session.phase == EditSession.Phase.PENDING_COMMIT and action not in [&"cancel", &"camera"]:
		hud.set_status("正在完成上一笔；Esc 可取消")
		return
	if action in [&"window_tool", &"tree_tool", &"lamp_tool"]:
		if action == &"window_tool":
			opening_variant = 3
			super._on_action(&"place_opening")
		else:
			selected_asset = "NAT-01" if action == &"tree_tool" else "PROP-08"
			hud.choose_asset(selected_asset)
			super._on_action(&"place_asset")
		return
	if action in [&"hedge", &"edit_hedge"]:
		_cancel_edit()
		tools.mode = String(action)
		hud.set_status("拖绘绿篱，转弯处稍停；松手提交" if action == &"hedge" else "选中绿篱后拖动黄色控制点")
	elif action == &"apply_object":
		_apply_object()
	elif action == &"camera_bookmark":
		_cancel_edit()
		var draft: Dictionary = document.snapshot()
		draft["camera_bookmarks"] = [
			{
				"id": "user_composition",
				"target": [camera_rig.target.x, camera_rig.target.y, camera_rig.target.z],
				"distance": camera_rig.distance,
				"yaw": camera_rig.yaw,
				"pitch": camera_rig.pitch
			}
		]
		_submit_async(draft, "保存构图")
	else:
		super._on_action(action)
	hud.set_active_tool(tools.mode)


func _apply_object() -> void:
	if tools.selected.is_empty():
		hud.set_status("请先选择物件")
		return
	var values: Dictionary = {
		"x": hud.object_x.value,
		"z": hud.object_z.value,
		"yaw": hud.object_yaw.value,
		"scale": hud.object_scale.value,
		"lock": hud.object_lock.button_pressed,
		"lamp": hud.object_lamp.selected,
		"width": hud.hedge_width.value
	}
	_cancel_edit()
	var draft: Dictionary = document.snapshot()
	var first: Dictionary = {}
	for item: Dictionary in draft["instances"]:
		if item["id"] in tools.selected:
			first = item
			break
	if first.is_empty():
		return
	var delta: Vector3 = Vector3(
		values["x"] - first["position"][0], 0, values["z"] - first["position"][2]
	)
	var yaw_delta: float = deg_to_rad(values["yaw"]) - first["yaw"]
	var factor: float = values["scale"] / first["scale"]
	InstanceEdits.transform_selection(draft, tools.selected, delta, yaw_delta, factor)
	for item: Dictionary in draft["instances"]:
		if item["id"] not in tools.selected:
			continue
		item["height_locked"] = values["lock"]
		item["locked_y"] = _six_poses[item["id"]].origin.y
		if item["asset_id"] == "PROP-08":
			item["lamp_mode"] = ["auto", "on", "off"][values["lamp"]]
		if item.has("hedge"):
			item["hedge"]["width"] = values["width"]
	_submit_async(draft, "修改物件属性")


func _show_selection() -> void:
	super._show_selection()
	if tools == null:
		return
	for id_value: String in tools.selected:
		if not _six_poses.has(id_value):
			continue
		var base: Vector3 = _six_poses[id_value].origin
		for axis: Vector3 in [Vector3.RIGHT, Vector3.BACK]:
			var handle: MeshInstance3D = MeshInstance3D.new()
			var box: BoxMesh = BoxMesh.new()
			box.size = Vector3(
				0.8 if axis == Vector3.RIGHT else 0.08, 0.07, 0.8 if axis == Vector3.BACK else 0.08
			)
			handle.mesh = box
			handle.position = base + axis * 0.65 + Vector3.UP * 0.12
			var paint: StandardMaterial3D = StandardMaterial3D.new()
			paint.albedo_color = Color("c08057") if axis == Vector3.RIGHT else Color("5c8081")
			paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			handle.material_override = paint
			gizmo_root.add_child(handle)
			var label: Label3D = Label3D.new()
			label.text = "X →" if axis == Vector3.RIGHT else "Z ↑"
			label.font_size = 32
			label.position = base + axis * 1.12 + Vector3.UP * 0.16
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			gizmo_root.add_child(label)
	if hud.has_method("sync_objects"):
		hud.sync_objects(_six_snapshot, tools.selected)
	_draw_hedge_controls()


func _unhandled_input(event: InputEvent) -> void:
	if tools == null or tools.mode not in ["hedge", "edit_hedge"]:
		super._unhandled_input(event)
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and (event.alt_pressed or event.shift_pressed):
			return
		var point: Variant = camera_rig.ground_point(event.position)
		if event.pressed and point is Vector3 and session.begin_gesture():
			_hedge_drag = true
			_hedge_before = document.snapshot()
			_hedge_points = [[point.x, point.z]]
			_find_hedge_control(Vector2(point.x, point.z))
			_update_hedge(point)
		elif not event.pressed and _hedge_drag:
			_hedge_drag = false
			if point is Vector3:
				_update_hedge(point)
			_submit_async(session.preview, "编辑绿篱")
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _hedge_drag:
		var point: Variant = camera_rig.ground_point(event.position)
		if point is Vector3:
			_update_hedge(point)
	else:
		super._unhandled_input(event)


func _find_hedge_control(point: Vector2) -> void:
	_hedge_id = ""
	_hedge_control = -1
	if tools.mode != "edit_hedge":
		return
	var best: float = 1.5
	for item: Dictionary in _hedge_before["instances"]:
		if item["id"] not in tools.selected or not item.has("hedge"):
			continue
		for i: int in range(item["hedge"]["points"].size()):
			var p: Array = item["hedge"]["points"][i]
			var distance_value: float = point.distance_to(
				HedgeRules.world_point(item, Vector2(p[0], p[1]))
			)
			if distance_value < best:
				best = distance_value
				_hedge_id = item["id"]
				_hedge_control = i


func _update_hedge(point: Vector3) -> void:
	var draft: Dictionary = _hedge_before.duplicate(true)
	if tools.mode == "hedge":
		var last: Array = _hedge_points.back()
		if (
			Vector2(point.x - last[0], point.z - last[1]).length() >= 1.0
			and _hedge_points.size() < 31
		):
			_hedge_points.append([point.x, point.z])
		var points: Array = _hedge_points.duplicate(true)
		var tail: Array = points.back()
		if Vector2(point.x - tail[0], point.z - tail[1]).length() > 0.25:
			points.append([point.x, point.z])
		HedgeRules.allocate(draft, points, hud.hedge_width.value)
	elif not _hedge_id.is_empty():
		for item: Dictionary in draft["instances"]:
			if item["id"] != _hedge_id:
				continue
			var local: Vector3 = (
				Basis(Vector3.UP, -item["yaw"])
				* Vector3(point.x - item["position"][0], 0, point.z - item["position"][2])
				/ item["scale"]
			)
			item["hedge"]["points"][_hedge_control] = [local.x, local.z]
			item["source"] = "manual"
			item["locked"] = true
	session.update_gesture(draft)
	_preview_linked()


func _preview_linked() -> void:
	if tools != null and tools.mode in ["hedge", "edit_hedge"]:
		_preview_token = queue.request(session.preview, Rect2(-24, -24, 48, 48))
		var issue: String = WorldDocument.validate(session.preview)
		hud.set_status("绿篱预览；松手提交，Esc 取消" if issue.is_empty() else "绿篱不能放下：请避开池岸、路口和建筑，或缩短线段")
	else:
		super._preview_linked()


func _submit_async(candidate: Dictionary, label: String) -> void:
	for item: Dictionary in candidate["instances"]:
		if item.has("hedge") and item not in document.state["instances"]:
			if (
				not HedgeRules.shape_error(item).is_empty()
				or not HedgeRules.clearance(candidate, item)
			):
				_cancel_edit()
				hud.set_status("绿篱不能放下：请避开建筑、池岸与入口，并保持线段 0.25–16 米")
				return
	super._submit_async(candidate, label)


func _draw_hedge_controls() -> void:
	for item: Dictionary in _six_snapshot.get("instances", []):
		if item["id"] not in tools.selected or not item.has("hedge"):
			continue
		for p: Array in item["hedge"]["points"]:
			var position_value: Vector2 = HedgeRules.world_point(item, Vector2(p[0], p[1]))
			var node: MeshInstance3D = MeshInstance3D.new()
			var shape: SphereMesh = SphereMesh.new()
			shape.radius = 0.14
			shape.height = 0.28
			node.mesh = shape
			node.position = Vector3(
				position_value.x, _field.height_at(position_value) + 0.2, position_value.y
			)
			var paint: StandardMaterial3D = StandardMaterial3D.new()
			paint.albedo_color = Color("edca91")
			node.material_override = paint
			gizmo_root.add_child(node)


func _cancel_edit() -> void:
	_hedge_drag = false
	super._cancel_edit()


func _input(event: InputEvent) -> void:
	super._input(event)
	if (
		event is InputEventMouseButton
		and not event.pressed
		and _hedge_drag
		and get_viewport().gui_get_hovered_control() != null
	):
		_cancel_edit()


func _save_action(action: StringName) -> void:
	_cancel_edit()
	if action == &"save":
		hud.set_status(
			"作品已保存" if SceneSave.write_file(W07_SAVE, document.snapshot()) == OK else "保存失败，原文件保留"
		)
	else:
		var loaded: Dictionary = SceneSave.read_file(W07_SAVE)
		if loaded["ok"]:
			_show_result(session.replace_document(loaded["snapshot"], _prepare_views), "作品已读取")
		else:
			hud.set_status("存档版本不支持或数据损坏，作品与原文件保留")


func _hedge_gallery() -> void:
	var draft: Dictionary = ForestTemplate.empty()
	HedgeRules.allocate(draft, [[-6, 2], [-2, 2], [-2, 5], [2, 5]])
	HedgeRules.allocate(draft, [[3, -2], [3.6, -2]])
	if "--w07-hedge-slope" in OS.get_cmdline_user_args():
		draft = TerrainField.brush(draft, Vector2(2, 5), 0.4)
	session.replace_document(draft, _prepare_views)
	camera_rig.distance = 15
	camera_rig.target = Vector3(0, 1, 1)
	camera_rig.refresh()


func _show_object_card() -> void:
	for item: Dictionary in document.state["instances"]:
		if item["asset_id"] == "PROP-08":
			_select_objects([item["id"]])
			break
	var pages: TabContainer = hud._panels[1].find_children("*", "TabContainer", true, false)[0]
	pages.current_tab = 4


func _setup_initial_buildings() -> void:
	_show_result(session.replace_document(ForestTemplate.create(), _prepare_views), "林间坡地")


func _building_view(spec: Dictionary, mesh: ArrayMesh) -> MeshInstance3D:
	var view: MeshInstance3D = MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = architecture_material
	view.position = Vector3(spec["position"][0], spec["position"][1], spec["position"][2])
	view.set_meta("object_id", spec["id"])
	OpeningAssembly.attach(view, spec, _apply_asset_materials)
	return view


func _delivery_metrics() -> Dictionary:
	var result: Dictionary = super._delivery_metrics()
	result["wrappers"] = _instance_views.size()
	result["hedge_native_instances"] = 0
	result["hedge_native_height_range"] = 0.0
	for item: Dictionary in _six_snapshot.get("instances", []):
		if not item.has("hedge") or not _instance_views.has(item["id"]):
			continue
		var parts: Array = _instance_views[item["id"]].find_children(
			"*", "MultiMeshInstance3D", true, false
		)
		if parts.is_empty():
			continue
		var batch: MultiMesh = parts[0].multimesh
		result["hedge_native_instances"] += batch.instance_count
		var lo: float = INF
		var hi: float = -INF
		for i: int in range(batch.instance_count):
			var y: float = batch.get_instance_transform(i).origin.y
			lo = minf(lo, y)
			hi = maxf(hi, y)
		result["hedge_native_height_range"] = maxf(result["hedge_native_height_range"], hi - lo)
	return result


func _building_close(mode: String) -> void:
	var draft: Dictionary = WorldDocument.new("w07-close").snapshot()
	if mode == "--w07-contact":
		var home: Dictionary = WorldDocument.allocate_building(
			draft, Vector3(-1.5, 0, 0), Vector3(3, 3, 3)
		)
		home["openings"] = [{"kind": "rect", "center": 0.5, "width": 1.1, "height": 2.05}]
		WorldDocument.allocate_building(draft, Vector3(1.5, 0, 0), Vector3(3, 2.4, 3))
	else:
		var home: Dictionary = WorldDocument.allocate_building(
			draft, Vector3.ZERO, Vector3(3, 2.4, 3), "round"
		)
		home["openings"] = [
			{"kind": "arch", "center": 0.15, "width": 1.2, "height": 2.1},
			{"kind": "round", "center": 0.45, "width": 1.0, "height": 1.0, "sill": 1.1}
		]
	session.replace_document(draft, _prepare_views)
	camera_rig.distance = 10 if mode == "--w07-contact" else 8
	camera_rig.target = Vector3(0, 1.1, 0)
	camera_rig.refresh()
