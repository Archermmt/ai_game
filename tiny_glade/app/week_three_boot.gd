extends "res://app/week_two_boot.gd"
## W03 composition: building parameters, attachment recovery and path groundwork.

const W03_SAVE: String = "user://week_03/forest.wgs"

var selected_buildings: Array[String] = []
var path_width: float = 1.2
var _default_layout: Dictionary = {}
var _path_drag: bool = false
var _path_id: String = ""
var _tree_views: Dictionary = {}
var _instance_kinds: Dictionary = {}
var _gpu_samples: Array[float] = []


func _ready() -> void:
	super._ready()
	if _benchmark_seconds > 0.0 and DisplayServer.get_name() != "headless":
		RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_default_layout = document.snapshot()
	hud.building_selection_changed.connect(_select_buildings)
	hud.size_preview_requested.connect(_preview_size)
	hud.path_width_changed.connect(func(value: float) -> void: path_width = value)
	if not document.state["buildings"].is_empty():
		selected_buildings.assign([document.state["buildings"][0]["id"]])
	hud.sync(document.snapshot(), selected_buildings)
	hud.set_status("W03：右侧选择小屋，调整尺寸后提交；也可拖画石径")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--view-angle="):
			camera_rig.yaw = deg_to_rad(argument.trim_prefix("--view-angle=").to_float())
			camera_rig.refresh()
		if argument == "--hide-ui":
			hud.visible = false
		if argument.begins_with("--tree-lod="):
			var forced: int = argument.trim_prefix("--tree-lod=").to_int()
			for view: Node3D in _tree_views.values():
				for level: int in range(2):
					view.get_child(level).visible = level == forced
					for mesh: MeshInstance3D in view.get_child(level).find_children(
						"*", "MeshInstance3D", true, false
					):
						mesh.visibility_range_begin = 0.0
						mesh.visibility_range_end = 0.0
		if argument == "--no-water":
			water_view.visible = false
		if argument == "--opaque-water":
			water_material.set_shader_parameter("opaque_probe", true)


func _setup_materials() -> void:
	super._setup_materials()
	water_material.shader = preload("res://features/environment/pond_water.gdshader")


func _setup_samples() -> void:
	for entry: Array in [["cloth_sample", Vector3(4, 0, 4)], ["bench_sample", Vector3(-4, 0, 4)]]:
		var packed: PackedScene = load("res://assets/samples/" + entry[0] + ".glb")
		var view: Node3D = packed.instantiate() as Node3D
		view.position = entry[1]
		world_view.add_child(view)
		_assign_wind(view, 1)


func _setup_initial_buildings() -> void:
	super._setup_initial_buildings()
	var draft: Dictionary = document.snapshot()
	for index: int in range(9):
		var angle: float = float(index) * TAU / 9.0
		var item: Dictionary = InstanceEdits.allocate(
			draft, Vector3(sin(angle) * 14, 0, cos(angle) * 14)
		)
		item["asset_id"] = ["NAT-01", "NAT-02", "NAT-03"][index % 3]
		item["scale"] = 0.85 + float(index % 3) * 0.13
	PathGeometry.allocate(draft, [[-0.75, 0, 8], [-0.75, 0, 1.5]])
	session.replace_document(draft, _prepare_views)


func _on_published(snapshot: Dictionary, prepared: Dictionary) -> void:
	super._on_published(snapshot, prepared)
	if not snapshot["pool"].is_empty():
		water_material.set_shader_parameter("radius", snapshot["pool"]["radius"])
		water_view.mesh.cap_bottom = false
	var existing: Array[String] = []
	for building: Dictionary in snapshot["buildings"]:
		if building["id"] in selected_buildings:
			existing.append(building["id"])
	selected_buildings = existing
	hud.sync(snapshot, selected_buildings)


func _add_support(_spec: Dictionary, support: Dictionary) -> void:
	var floor_y: float = support["floor"]
	var points: Array = support["perimeter"]
	var builder: BuildingGeometry = BuildingGeometry.new()
	for index: int in range(points.size()):
		var a: Array = points[index]
		var b: Array = points[(index + 1) % points.size()]
		var lower_a: Vector3 = Vector3(a[0], a[1], a[2])
		var lower_b: Vector3 = Vector3(b[0], b[1], b[2])
		var upper_a: Vector3 = Vector3(a[0], floor_y, a[2])
		var upper_b: Vector3 = Vector3(b[0], floor_y, b[2])
		var normal: Vector3 = (upper_b - upper_a).cross(Vector3.UP).normalized()
		builder._quad(lower_a, lower_b, upper_b, upper_a, normal, BuildingGeometry.STONE)
	if builder._vertices.is_empty():
		return
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = builder._vertices
	arrays[Mesh.ARRAY_NORMAL] = builder._normals
	arrays[Mesh.ARRAY_TEX_UV] = builder._uvs
	arrays[Mesh.ARRAY_COLOR] = builder._colors
	var view: MeshInstance3D = MeshInstance3D.new()
	view.mesh = BuildingGeometry.mesh_from_arrays(arrays)
	view.material_override = stone_material
	foundation_root.add_child(view)


func _rebuild_probe_paths(_snapshot: Dictionary) -> void:
	_clear_children(path_root)
	if _resource_cache.get("path_mesh") != null:
		var view: MeshInstance3D = MeshInstance3D.new()
		view.mesh = _resource_cache["path_mesh"]
		view.material_override = stone_material
		path_root.add_child(view)


func _rebuild_instances(snapshot: Dictionary) -> void:
	wind_materials = wind_materials.filter(
		func(m: ShaderMaterial) -> bool: return m.shader == WIND_SHADER
	)
	var alive: Dictionary = {}
	_tree_views.clear()
	for item: Dictionary in snapshot["instances"]:
		var key: String = item["id"]
		alive[key] = true
		var is_tree: bool = VegetationCatalog.NAMES.has(item["asset_id"])
		var view: Node3D = _instance_views.get(key)
		if view != null and _instance_kinds.get(key) != item["asset_id"]:
			view.free()
			view = null
		if view == null:
			if is_tree:
				view = Node3D.new()
				view.name = "TreeInstance"
				for lod: int in range(2):
					view.add_child(VegetationCatalog.instantiate_asset(item["asset_id"], key, lod))
			else:
				var grey: MeshInstance3D = MeshInstance3D.new()
				var box: BoxMesh = BoxMesh.new()
				box.size = Vector3(0.65, 0.8, 0.65)
				grey.mesh = box
				grey.material_override = wood_material
				view = grey
			view.set_meta("object_id", key)
			instance_root.add_child(view)
			_instance_views[key] = view
			_instance_kinds[key] = item["asset_id"]
		var p: Array = item["position"]
		var next_position: Vector3 = Vector3(
			p[0],
			(
				p[1]
				+ _field.height_at(Vector2(p[0], p[2]))
				+ (
					0.0
					if is_tree or item["asset_id"] != "grey_prop"
					else 0.4 * float(item["scale"])
				)
			),
			p[2]
		)
		if view.position != next_position:
			view.position = next_position
		if view.scale != Vector3.ONE * float(item["scale"]):
			view.scale = Vector3.ONE * float(item["scale"])
		if view.rotation.y != item["yaw"]:
			view.rotation.y = item["yaw"]
		if is_tree:
			_tree_views[key] = view
			for lod: int in range(2):
				_collect_tree_materials(view.get_child(lod), lod)
	for key: String in _instance_views.keys():
		if not alive.has(key):
			_instance_views[key].free()
			_instance_views.erase(key)
			_instance_kinds.erase(key)
	_set_wind(snapshot["environment"]["reduce_motion"])
	for material: ShaderMaterial in wind_materials:
		material.set_shader_parameter("wind_strength", snapshot["environment"]["wind_strength"])
		material.set_shader_parameter(
			"wind_direction", snapshot["environment"].get("wind_direction", 0.4)
		)
	_show_selection()


func _collect_tree_materials(root: Node, lod: int) -> void:
	if root is MeshInstance3D:
		root.visibility_range_begin = 34.0 if lod == 1 else 0.0
		root.visibility_range_end = 0.0 if lod == 1 else 34.0
		wind_materials.append(root.material_override)
	for child: Node in root.get_children():
		_collect_tree_materials(child, lod)


func _select_buildings(ids: Array[String]) -> void:
	if session.phase == EditSession.Phase.PENDING_COMMIT:
		hud.sync(document.snapshot(), selected_buildings)
		return
	_cancel_edit()
	selected_buildings = ids.duplicate()
	hud.sync(document.snapshot(), selected_buildings)


func _preview_size(size: Vector3) -> void:
	if selected_buildings.is_empty() or session.phase == EditSession.Phase.PENDING_COMMIT:
		return
	if _path_drag or _tool_dragging or dragging:
		_cancel_edit()
	if session.phase == EditSession.Phase.IDLE:
		session.begin_gesture()
	var draft: Dictionary = document.snapshot()
	BuildingEdits.resize(draft, selected_buildings, size)
	session.update_gesture(draft)
	_preview_token = queue.request(draft, Rect2(-24, -24, 48, 48))
	var error: String = WorldDocument.validate(draft)
	hud.set_status("尺寸预览；点提交尺寸，Esc 取消" if error.is_empty() else _reason(error))


func _on_action(action: StringName) -> void:
	if tools == null:
		return
	if session.phase == EditSession.Phase.PENDING_COMMIT and action not in [&"cancel", &"camera"]:
		hud.set_status("正在完成上一笔；Esc 可取消")
		return
	if action == &"apply_size":
		if session.phase == EditSession.Phase.PREVIEW:
			_submit_async(session.preview, "调整小屋尺寸")
		return
	if action == &"path":
		_cancel_edit()
		tools.mode = "path"
		hud.set_status("石径：在草地拖动；路宽在右侧调整")
		return
	if action in [&"delete_building", &"reset_defaults", &"reattach", &"delete_path"]:
		_building_action(action)
		return
	if action in [&"save", &"load"]:
		_save_action(action)
		return
	super._on_action(action)


func _save_action(action: StringName) -> void:
	if action == &"save":
		_cancel_edit()
		hud.set_status(
			"作品已保存" if SaveCodec.write_file(W03_SAVE, document.snapshot()) == OK else "保存失败"
		)
	elif action == &"load":
		_cancel_edit()
		var loaded: Dictionary = SaveCodec.read_file(W03_SAVE)
		if loaded["ok"]:
			_show_result(session.replace_document(loaded["snapshot"], _prepare_views), "作品已读取")
		else:
			hud.set_status("没有有效存档；作品保留")
		return


func _building_action(action: StringName) -> void:
	_cancel_edit()
	var draft: Dictionary = document.snapshot()
	if action == &"delete_building":
		if selected_buildings.is_empty():
			return
		BuildingEdits.remove(draft, selected_buildings)
	elif action == &"reset_defaults":
		draft = _default_layout.duplicate(true)
		draft["revision"] = document.state["revision"]
	elif action == &"reattach":
		if (
			selected_buildings.is_empty()
			or not BuildingEdits.reattach(draft, hud.selected_attachment(), selected_buildings[0])
		):
			hud.set_status("请先选择待附着门窗和目标小屋")
			return
	elif not draft["paths"].is_empty():
		# W03 paths do not create doors; protect legacy source_path references.
		var id_value: String = draft["paths"].back()["id"]
		for building: Dictionary in draft["buildings"]:
			for opening: Dictionary in building["openings"]:
				if opening.get("source_path", "") == id_value:
					hud.set_status("此旧样板路径依附门；联动删除下周接通")
					return
		draft["paths"].pop_back()
	_submit_async(draft, "小屋与恢复：" + String(action))


func _unhandled_input(event: InputEvent) -> void:
	if tools == null or tools.mode != "path":
		super._unhandled_input(event)
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and (event.alt_pressed or event.shift_pressed):
			return
		var point: Variant = camera_rig.ground_point(event.position)
		if event.pressed and point is Vector3 and session.begin_gesture():
			_path_drag = true
			_path_id = PathGeometry.allocate(
				session.preview, [[point.x, 0, point.z], [point.x, 0, point.z]], path_width
			)
		elif not event.pressed and _path_drag:
			_path_drag = false
			var points: Array = session.preview["paths"].back()["points"]
			if points.size() <= 2:
				_cancel_edit()
			else:
				_submit_async(session.preview, "画石径")
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _path_drag:
		var point: Variant = camera_rig.ground_point(event.position)
		if point is Vector3:
			var points: Array = session.preview["paths"].back()["points"]
			var last: Array = points.back()
			if (
				Vector2(point.x - last[0], point.z - last[2]).length() >= 0.25
				and points.size() < 256
			):
				points.append([point.x, 0, point.z])
			_preview_token = queue.request(session.preview, Rect2(-24, -24, 48, 48))
	else:
		super._unhandled_input(event)


func _input(event: InputEvent) -> void:
	super._input(event)
	if event is InputEventMouseButton and not event.pressed and _path_drag:
		if get_viewport().gui_get_hovered_control() != null:
			_cancel_edit()


func _cancel_edit() -> void:
	_path_drag = false
	super._cancel_edit()


func _process(delta: float) -> void:
	if _benchmark_seconds > 0.0 and Time.get_ticks_msec() - _benchmark_started_ms > 2000:
		var gpu: float = RenderingServer.viewport_get_measured_render_time_gpu(
			get_viewport().get_viewport_rid()
		)
		if gpu > 0.0 and is_finite(gpu):
			_gpu_samples.append(gpu)
	super._process(delta)


func _delivery_metrics() -> Dictionary:
	var result: Dictionary = super._delivery_metrics()
	var samples: Array[float] = _gpu_samples.duplicate()
	samples.sort()
	result["gpu_samples"] = samples.size()
	result["gpu_mean_ms"] = (
		samples.reduce(func(a: float, b: float) -> float: return a + b, 0.0)
		/ maxf(1, samples.size())
	)
	result["gpu_p95_ms"] = samples[int(samples.size() * 0.95)] if not samples.is_empty() else null
	if samples.is_empty():
		result["gpu_mean_ms"] = null
	return result
