extends "res://app/week_four_boot.gd"
## W05 bounded garden construction with one atomic source transaction per gesture.

const W05_SAVE: String = "user://week_05/forest.wgs"
var structure_root: Node3D
var _five_drag: bool = false
var _five_before: Dictionary = {}
var _outline: Array = []
var _fence_points: Array = []
var _structure_issues: Array = []
var _draw_mode: String = ""
var _edit_structure: String = ""


func _ready() -> void:
	super._ready()
	for argument: String in OS.get_cmdline_user_args():
		if argument in ["--w05-gallery", "--w05-stairs", "--w05-invalid-bridge"]:
			_five_demo(argument)
	hud.set_status("W05：拖绘自由池岸/围栏；短桥与短阶拖出后确认提交")


func _setup_ground() -> void:
	super._setup_ground()
	structure_root = Node3D.new()
	structure_root.name = "GardenStructures"
	world_view.add_child(structure_root)


func _setup_initial_buildings() -> void:
	super._setup_initial_buildings()
	var draft: Dictionary = document.snapshot()
	# A compact two-bank sample; every element remains source-editable.
	draft = PondShape.draw(
		draft, [[5.6, -2.5], [8.4, -2.5], [8.8, -0.5], [8.4, 1.5], [5.6, 1.5], [5.2, -0.5]]
	)
	GardenStructures.allocate(draft, "bridge", Vector2(7, -3), Vector2(7, 2))
	for entry: Array in [
		["PROP-03", Vector3(-3, 0, 4)],
		["PROP-05", Vector3(1, 0, 5)],
		["PROP-06", Vector3(2.5, 0, 5)]
	]:
		var item: Dictionary = InstanceEdits.allocate(draft, entry[1])
		item["asset_id"] = entry[0]
	FenceGeometry.allocate(draft, [[-8, 0, 3], [-8, 0, 8], [-4, 0, 8]])
	session.replace_document(draft, _prepare_views)


func _prepare_resources(data: Dictionary) -> Dictionary:
	var result: Dictionary = super._prepare_resources(data)
	if not result.get("ok", false):
		return result
	result["garden_meshes"] = {"bridge": [], "stair": []}
	for kind: String in ["bridge", "stair"]:
		for arrays: Array in data["structures"][kind]:
			result["garden_meshes"][kind].append(BuildingGeometry.mesh_from_arrays(arrays))
	result["garden_issues"] = data["structures"]["issues"].duplicate(true)
	result["water_mesh"] = null
	if data["water_arrays"][Mesh.ARRAY_VERTEX].size() > 0:
		result["water_mesh"] = BuildingGeometry.mesh_from_arrays(data["water_arrays"])
	return result


func _on_published(snapshot: Dictionary, prepared: Dictionary) -> void:
	super._on_published(snapshot, prepared)
	if structure_root == null:
		return
	_clear_children(structure_root)
	for kind: String in ["bridge", "stair"]:
		for mesh: ArrayMesh in prepared.get("garden_meshes", {}).get(kind, []):
			var view: MeshInstance3D = MeshInstance3D.new()
			view.mesh = mesh
			view.material_override = path_material
			structure_root.add_child(view)
	_structure_issues = prepared.get("garden_issues", [])
	if prepared.get("water_mesh") != null:
		water_view.mesh = prepared["water_mesh"]
		water_view.position = Vector3.ZERO
		var poly: PackedVector2Array = PondShape.contour(snapshot["pool"])
		var center: Vector2 = Vector2.ZERO
		var low: Vector2 = poly[0]
		var high: Vector2 = poly[0]
		for p: Vector2 in poly:
			center += p / poly.size()
			low = low.min(p)
			high = high.max(p)
		water_material.set_shader_parameter("surface_origin", center)
		water_material.set_shader_parameter("radius", maxf(high.x - low.x, high.y - low.y) * 0.5)
	if hud.has_method("sync_garden"):
		hud.sync_garden(snapshot, _structure_issues)


func _rebuild_instances(snapshot: Dictionary) -> void:
	super._rebuild_instances(snapshot)
	for item: Dictionary in snapshot["instances"]:
		if not WeekFiveCatalog.PACKS.has(item["asset_id"]):
			continue
		var old: Node3D = _instance_views[item["id"]]
		if not old.has_meta("w05_asset"):
			var view: Node3D = WeekFiveCatalog.create(
				item["asset_id"], item["id"], wood_material, stone_material
			)
			view.transform = old.transform
			old.free()
			instance_root.add_child(view)
			_instance_views[item["id"]] = view
			_collect_extra_wind(view)
		var view: Node3D = _instance_views[item["id"]]
		view.position.y = item["position"][1] + InstanceEdits.support_height(snapshot, item)
	_sync_wind(snapshot)


func _update_custom(point: Vector3) -> void:
	super._update_custom(point)
	if tools.mode == "place_asset" and selected_asset in ["PROP-03", "PROP-05", "PROP-06"]:
		var draft: Dictionary = session.preview.duplicate(true)
		var item: Dictionary = draft["instances"].back()
		for parent: Dictionary in _custom_before["instances"]:
			if (
				parent["asset_id"] == "PROP-05"
				and (
					(
						Vector2(point.x - parent["position"][0], point.z - parent["position"][2])
						. length()
					)
					< 0.25
				)
			):
				item["support_id"] = parent["id"]
				item["position"] = parent["position"].duplicate()
				break
		session.update_gesture(draft)
		_preview_linked()


func _on_action(action: StringName) -> void:
	if tools == null:
		return
	if session.phase == EditSession.Phase.PENDING_COMMIT and action not in [&"cancel", &"camera"]:
		hud.set_status("正在完成上一笔；Esc 可取消")
		return
	if action in [&"shore", &"bridge", &"stair", &"fence", &"edit_garden"]:
		_cancel_edit()
		tools.mode = String(action)
		_draw_controls()
		hud.set_status(
			"拖绘轮廓；围栏靠近起点自动闭合。桥/阶预览后点确认。" if action != &"edit_garden" else "选择右侧结构，再拖动靠近的端点/控制点"
		)
		return
	if action == &"confirm_garden":
		if session.phase == EditSession.Phase.PREVIEW and not _five_drag:
			_submit_async(session.preview, "确认庭园结构")
		return
	if action == &"delete_garden":
		_cancel_edit()
		var draft: Dictionary = document.snapshot()
		var key: String = hud.garden_id()
		for collection: String in ["bridges", "stairs", "fences"]:
			for i: int in range(draft.get(collection, []).size() - 1, -1, -1):
				if draft[collection][i]["id"] == key:
					draft[collection].remove_at(i)
		_submit_async(draft, "删除庭园结构")
		return
	super._on_action(action)


func _unhandled_input(event: InputEvent) -> void:
	if tools == null or tools.mode not in ["shore", "bridge", "stair", "fence", "edit_garden"]:
		super._unhandled_input(event)
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.alt_pressed or event.shift_pressed:
			return
		var point: Variant = camera_rig.ground_point(event.position)
		if event.pressed and point is Vector3 and session.begin_gesture():
			_five_drag = true
			_five_before = document.snapshot()
			drag_start = point
			_outline = [[point.x, point.z]]
			_fence_points = [[point.x, 0, point.z]]
			_edit_structure = hud.garden_id()
			_update_garden(point)
		elif not event.pressed and _five_drag:
			_five_drag = false
			if point is Vector3:
				_update_garden(point)
			if tools.mode in ["bridge", "stair"]:
				hud.set_status("结构预览：点“确认桥/阶”提交，Esc 取消")
			else:
				_submit_async(session.preview, "编辑庭园")
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _five_drag:
		var point: Variant = camera_rig.ground_point(event.position)
		if point is Vector3:
			_update_garden(point)
	else:
		super._unhandled_input(event)


func _update_garden(point: Vector3) -> void:
	var draft: Dictionary = _five_before.duplicate(true)
	var p: Vector2 = Vector2(point.x, point.z)
	if tools.mode == "shore":
		var last: Array = _outline.back()
		if p.distance_to(Vector2(last[0], last[1])) >= 2.1 and _outline.size() < 64:
			_outline.append([p.x, p.y])
		var points: Array = _outline.duplicate(true)
		if points.size() > 3 and p.distance_to(Vector2(points[0][0], points[0][1])) < 1.1:
			points.pop_back()
		draft = PondShape.draw(draft, points)
	elif tools.mode == "fence":
		var last: Array = _fence_points.back()
		if p.distance_to(Vector2(last[0], last[2])) >= 0.9 and _fence_points.size() < 128:
			_fence_points.append([p.x, 0, p.y])
		var points: Array = _fence_points.duplicate(true)
		if points.size() >= 2:
			var closed: bool = (
				points.size() > 3 and p.distance_to(Vector2(points[0][0], points[0][2])) < 0.7
			)
			if closed:
				points.pop_back()
			FenceGeometry.allocate(draft, points)
			draft["fences"].back()["closed"] = closed
	elif tools.mode in ["bridge", "stair"]:
		GardenStructures.allocate(
			draft, tools.mode, Vector2(drag_start.x, drag_start.z), p, hud.garden_width.value
		)
	elif tools.mode == "edit_garden":
		_edit_garden_point(draft, p)
	session.update_gesture(draft)
	_preview_linked()


func _edit_garden_point(draft: Dictionary, point: Vector2) -> void:
	for collection: String in ["bridges", "stairs", "fences"]:
		for item: Dictionary in draft.get(collection, []):
			if item["id"] != _edit_structure:
				continue
			if collection == "fences":
				var best: int = 0
				for i: int in range(item["points"].size()):
					var p: Array = item["points"][i]
					var q: Array = item["points"][best]
					if (
						Vector2(p[0] - drag_start.x, p[2] - drag_start.z).length()
						< Vector2(q[0] - drag_start.x, q[2] - drag_start.z).length()
					):
						best = i
				item["points"][best] = [point.x, 0, point.y]
			else:
				var origin: Vector2 = Vector2(drag_start.x, drag_start.z)
				var a: Vector2 = Vector2(item["a"][0], item["a"][1])
				var b: Vector2 = Vector2(item["b"][0], item["b"][1])
				item["a" if origin.distance_to(a) < origin.distance_to(b) else "b"] = [
					point.x, point.y
				]


func _submit_async(snapshot: Dictionary, label: String) -> void:
	# Creating/editing a structure must be legal; later shore changes may invalidate it.
	for collection: String in ["bridges", "stairs"]:
		for item: Dictionary in snapshot.get(collection, []):
			if item not in document.state.get(collection, []):
				var issue: String = GardenStructures.status(snapshot, item)
				if not issue.is_empty():
					_cancel_edit()
					hud.set_status(_reason(issue))
					return
	super._submit_async(snapshot, label)


func _input(event: InputEvent) -> void:
	super._input(event)
	if (
		event is InputEventMouseButton
		and not event.pressed
		and _five_drag
		and get_viewport().gui_get_hovered_control() != null
	):
		_cancel_edit()


func _cancel_edit() -> void:
	_five_drag = false
	super._cancel_edit()


func _save_action(action: StringName) -> void:
	_cancel_edit()
	if action == &"save":
		hud.set_status(
			"作品已保存" if SaveCodec.write_file(W05_SAVE, document.snapshot()) == OK else "保存失败"
		)
	else:
		var loaded: Dictionary = SaveCodec.read_file(W05_SAVE)
		if loaded["ok"]:
			_show_result(session.replace_document(loaded["snapshot"], _prepare_views), "作品已读取")
		else:
			hud.set_status("没有有效存档；作品保留")


static func _reason(error: String) -> String:
	return (
		{
			"invalid_pool_outline": "池岸至少需要三个不重复的轮廓点",
			"invalid_support": "支撑关系不能循环；请先移开上层物件",
			"missing_support": "底箱仍承托物件；请先移开上层物件",
			"support_outside_surface": "移动底箱前，请先移开上层物件",
			"pool_self_intersection": "池岸不能交叉；保留上一合法结果",
			"pool_minimum_width": "池水最窄处需至少 2 米",
			"bridge_length_1_5_to_6": "短桥长度需 1.5–6 米",
			"bridge_height_0_5": "桥头高差需不超过 0.5 米",
			"bridge_missing_pond": "请先画池，再明确确认放桥",
			"bridge_adjust_heads": "调整桥头：两端需落在水外、桥身跨水",
			"stair_height_0_15_to_0_9": "短阶高差需 0.15–0.9 米；请调整地形",
			"stair_length": "短阶长度需 0.6–3 米",
			"stair_pool_conflict": "短阶落脚处不能在池岸保护带内",
			"structure_building_collision": "桥或短阶不能穿入小屋"
		}
		. get(error, preload("res://app/week_two_boot.gd")._reason(error))
	)


func _draw_controls() -> void:
	super._draw_controls()
	if (
		control_root == null
		or tools == null
		or tools.mode != "edit_garden"
		or not hud.has_method("garden_id")
	):
		return
	var key: String = hud.garden_id()
	for collection: String in ["bridges", "stairs", "fences"]:
		for item: Dictionary in document.state.get(collection, []):
			if item["id"] != key:
				continue
			var points: Array = item["points"] if collection == "fences" else [item["a"], item["b"]]
			for p: Array in points:
				var location: Vector2 = Vector2(p[0], p[2] if collection == "fences" else p[1])
				var node: MeshInstance3D = MeshInstance3D.new()
				var mesh: SphereMesh = SphereMesh.new()
				mesh.radius = 0.13
				mesh.height = 0.26
				node.mesh = mesh
				var paint: StandardMaterial3D = StandardMaterial3D.new()
				paint.albedo_color = Color("e9ad60")
				node.material_override = paint
				node.position = Vector3(location.x, _field.height_at(location) + 0.2, location.y)
				control_root.add_child(node)


func _five_demo(mode: String) -> void:
	var draft: Dictionary = document.snapshot()
	if mode == "--w05-invalid-bridge":
		draft = PondShape.draw(draft, [[4.5, -4], [9.5, -4], [9.5, 3], [4.5, 3]])
	else:
		draft["buildings"] = []
		draft["paths"] = []
		draft["pool"] = {}
		draft["instances"] = []
		draft["bridges"] = []
		draft["fences"] = []
		draft["environment"]["lamp_probes"] = []
		if mode == "--w05-gallery":
			for entry: Array in [
				["PROP-03", Vector3(-2, 0, 1)],
				["PROP-04", Vector3(2, 0, -2)],
				["PROP-05", Vector3(-2, 0, -2)],
				["PROP-06", Vector3(1, 0, 1)]
			]:
				var item: Dictionary = InstanceEdits.allocate(draft, entry[1])
				item["asset_id"] = entry[0]
			var top: Dictionary = InstanceEdits.allocate(draft, Vector3(-2, 0, -2))
			top["asset_id"] = "PROP-05"
			top["support_id"] = draft["instances"][2]["id"]
		else:
			draft["terrain"]["base_profile"] = "flat"
			draft = TerrainEdits.stroke(draft, Vector2(2, 0), "raise", 1.1, 0.6)
			GardenStructures.allocate(draft, "stair", Vector2.ZERO, Vector2(2, 0))
			FenceGeometry.allocate(draft, [[-4, 0, -2], [-4, 0, 2], [4, 0, 2]])
		camera_rig.distance = 13
		camera_rig.target = Vector3(0, 0.6, 0)
		camera_rig.refresh()
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--still":
			draft["environment"]["reduce_motion"] = true
		if argument.begins_with("--wind-strength="):
			draft["environment"]["wind_strength"] = (
				argument.trim_prefix("--wind-strength=").to_float()
			)
	session.replace_document(draft, _prepare_views)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--wind-time="):
			for paint: ShaderMaterial in wind_materials:
				paint.set_shader_parameter("freeze_time", true)
				paint.set_shader_parameter(
					"sample_time", argument.trim_prefix("--wind-time=").to_float()
				)
