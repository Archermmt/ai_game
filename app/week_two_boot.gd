extends "res://app/boot.gd"
## W02 risk laboratory: layered terrain, serial asynchronous edits and grey tools.

const W02_SAVE: String = "user://week_02/forest.wgs"
const WINDOW_RECT: PackedScene = preload("res://assets/buildings/window_rect.glb")
const WINDOW_ROUND: PackedScene = preload("res://assets/buildings/window_round.glb")

var queue: RebuildQueue
var tools: WorldTools
var foundation_root: Node3D
var path_root: Node3D
var gizmo_root: Node3D
var terrain_root: Node3D
var instance_root: Node3D
var water_view: MeshInstance3D
var terrain_material: ShaderMaterial
var architecture_material: ShaderMaterial
var window_material: ShaderMaterial
var water_material: ShaderMaterial
var wood_material: StandardMaterial3D
var stone_material: StandardMaterial3D
var _resource_cache: Dictionary = {}
var _terrain_views: Array[MeshInstance3D] = []
var _building_views: Dictionary = {}
var _tool_dragging: bool = false
var _last_point: Vector3
var _field: TerrainField
var _instance_views: Dictionary = {}
var _preview_token: int = -1
var _preview_visible: bool = false
var _apply_samples: Array[float] = []
var _probe_edits: int = 0


func _ready() -> void:
	_setup_materials()
	super._ready()
	tools = WorldTools.new(session)
	queue = RebuildQueue.new()
	queue.name = "RebuildQueue"
	add_child(queue)
	queue.batch_prepared.connect(_on_batch)
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--render-probe":
			_setup_alpha_probe()
	_field = TerrainField.new(document.state)
	camera_rig.surface_height = func(point: Vector2) -> float: return _field.height_at(point)
	camera_rig.refresh()
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--contact-demo":
			_setup_contact_demo()
		if argument == "--road-demo":
			_setup_road_demo()
		if argument == "--low-angle":
			camera_rig.pitch = 0.33
			camera_rig.distance = 20.0
			camera_rig.target = Vector3(0, 1, 0)
			camera_rig.refresh()
			# Hide only foreground bootstrap decorations in this inspection capture.
			for child: Node in world_view.get_children():
				if child is Node3D and child.position.z > 7.0 and child.position.length() > 10.0:
					child.visible = false
		if argument.begins_with("--wind-time="):
			water_material.set_shader_parameter("freeze_time", true)
			water_material.set_shader_parameter("sample_time", 0.0)
	if "--dusk" in OS.get_cmdline_user_args():
		_apply_light(true)
	if "--still" in OS.get_cmdline_user_args():
		_set_wind(true)
	hud.set_status("W02：试试画池、刷坡或放几个灰模道具")
	if "--edit-benchmark" in OS.get_cmdline_user_args():
		_exercise_edits.call_deferred()


func _setup_materials() -> void:
	architecture_material = ShaderMaterial.new()
	architecture_material.shader = preload("res://features/environment/architecture.gdshader")
	architecture_material.set_shader_parameter(
		"plaster_map", preload("res://assets/materials/textures/plaster.png")
	)
	architecture_material.set_shader_parameter(
		"tile_map", preload("res://assets/materials/textures/terracotta.png")
	)
	terrain_material = ShaderMaterial.new()
	terrain_material.shader = preload("res://features/terrain/terrain.gdshader")
	terrain_material.set_shader_parameter(
		"grass_map", preload("res://assets/materials/textures/grass.png")
	)
	terrain_material.set_shader_parameter(
		"soil_map", preload("res://assets/materials/textures/soil.png")
	)
	terrain_material.set_shader_parameter(
		"wet_map", preload("res://assets/materials/textures/wet_bank.png")
	)
	window_material = ShaderMaterial.new()
	window_material.shader = preload("res://features/environment/window_light.gdshader")
	window_material.set_shader_parameter(
		"light_mask", preload("res://assets/materials/textures/window_emission.png")
	)
	water_material = ShaderMaterial.new()
	water_material.shader = preload("res://features/environment/water_sample.gdshader")
	wood_material = StandardMaterial3D.new()
	wood_material.albedo_texture = preload("res://assets/materials/textures/wood.png")
	wood_material.roughness = 0.87
	stone_material = StandardMaterial3D.new()
	stone_material.albedo_texture = preload("res://assets/materials/textures/stone.png")
	stone_material.roughness = 0.95


func _setup_ground() -> void:
	terrain_root = Node3D.new()
	terrain_root.name = "LayeredTerrain"
	world_view.add_child(terrain_root)
	foundation_root = Node3D.new()
	foundation_root.name = "FoundationProbe"
	world_view.add_child(foundation_root)
	path_root = Node3D.new()
	path_root.name = "RoadProbe"
	world_view.add_child(path_root)
	gizmo_root = Node3D.new()
	gizmo_root.name = "SelectionHandles"
	world_view.add_child(gizmo_root)
	instance_root = Node3D.new()
	instance_root.name = "EditableInstances"
	world_view.add_child(instance_root)
	water_view = MeshInstance3D.new()
	water_view.name = "PondWaterSample"
	water_view.material_override = water_material
	world_view.add_child(water_view)


func _setup_initial_buildings() -> void:
	super._setup_initial_buildings()
	var draft: Dictionary = TerrainField.pond(document.snapshot(), Vector2(7, -1), 2.5)
	draft = TerrainField.brush(draft, Vector2(-9, 7), 0.5, 5.0)
	InstanceEdits.allocate(draft, Vector3(1, 0, 5))
	InstanceEdits.allocate(draft, Vector3(3, 0, 6))
	draft["environment"]["aged"] = "--aged" in OS.get_cmdline_user_args()
	session.replace_document(draft, _prepare_views)


func _prepare_views(snapshot: Dictionary) -> Dictionary:
	return _prepare_resources(WorldRebuild.evaluate(snapshot))


func _on_published(snapshot: Dictionary, prepared: Dictionary) -> void:
	_field = TerrainField.new(snapshot)
	camera_rig.refresh()
	var alive: Dictionary = {}
	for index: int in range(snapshot["buildings"].size()):
		var spec: Dictionary = snapshot["buildings"][index]
		alive[spec["id"]] = true
		var view: MeshInstance3D = _building_views.get(spec["id"])
		if view == null or view.mesh != prepared["meshes"][index]:
			if view != null:
				view.free()
			view = _building_view(spec, prepared["meshes"][index])
			building_root.add_child(view)
			_building_views[spec["id"]] = view
		view.position = Vector3(spec["position"][0], spec["position"][1], spec["position"][2])
	for id_value: String in _building_views.keys():
		if not alive.has(id_value):
			_building_views[id_value].free()
			_building_views.erase(id_value)
	for index: int in range(prepared["terrain_meshes"].size()):
		if index >= _terrain_views.size():
			var view: MeshInstance3D = MeshInstance3D.new()
			view.material_override = terrain_material
			terrain_root.add_child(view)
			_terrain_views.append(view)
		_terrain_views[index].mesh = prepared["terrain_meshes"][index]
	_clear_children(foundation_root)
	for index: int in range(snapshot["buildings"].size()):
		_add_support(snapshot["buildings"][index], prepared["supports"][index])
	_apply_light(snapshot["environment"]["dusk"])
	_set_wind(snapshot["environment"]["reduce_motion"])
	for material: ShaderMaterial in wind_materials:
		material.set_shader_parameter("wind_strength", snapshot["environment"]["wind_strength"])
	_rebuild_instances(snapshot)
	_rebuild_probe_paths(snapshot)
	water_view.visible = not snapshot["pool"].is_empty()
	if water_view.visible:
		var pond_data: Dictionary = snapshot["pool"]
		var circle: CylinderMesh = CylinderMesh.new()
		circle.top_radius = float(pond_data["radius"]) - 0.08
		circle.bottom_radius = circle.top_radius
		circle.height = 0.015
		circle.radial_segments = 96
		water_view.mesh = circle
		water_view.position = Vector3(
			pond_data["center"][0], pond_data["water_y"], pond_data["center"][1]
		)
	var aged: bool = snapshot["environment"].get("aged", false)
	architecture_material.set_shader_parameter("aged", aged)
	wood_material.roughness = 0.97 if aged else 0.87
	wood_material.albedo_color = Color(0.82, 0.9, 0.78) if aged else Color.WHITE
	stone_material.roughness = 0.99 if aged else 0.95
	stone_material.albedo_color = Color(0.78, 0.88, 0.73) if aged else Color.WHITE


func _building_view(spec: Dictionary, mesh: ArrayMesh) -> MeshInstance3D:
	var view: MeshInstance3D = super._building_view(spec, mesh)
	view.material_override = architecture_material
	for child: Node in view.get_children():
		child.free()
	for opening: Dictionary in spec["openings"]:
		var is_window: bool = float(opening["height"]) < 1.8
		var packed: PackedScene = WINDOW_ROUND if opening["kind"] == "round" else WINDOW_RECT
		if not is_window:
			packed = DOOR_ARCH if opening["kind"] == "arch" else DOOR_PLANK
			if opening.get("variant", "") == "glass":
				packed = preload("res://assets/buildings/door_glass.glb")
		var attachment: Node3D = packed.instantiate() as Node3D
		var facade: int = int(opening.get("facade", 0))
		var width: float = float(spec["size"][0])
		var depth: float = float(spec["size"][2])
		var length: float = (
			PI * width if spec["shape"] == "round" else (width if facade % 2 == 0 else depth)
		)
		var u: float = float(opening["center"]) * length
		var normal: Vector3 = BuildingGeometry._normal(
			u, facade, width, depth, spec["shape"] == "round"
		)
		attachment.position = (
			BuildingGeometry._point(u, facade, width, depth, spec["shape"] == "round")
			+ normal * -0.05
			+ Vector3.UP * float(opening.get("sill", 0))
		)
		# glTF panels face +Z; rotate toward the wall normal and recess the full frame thickness.
		attachment.rotation.y = atan2(normal.x, normal.z)
		view.add_child(attachment)
		_apply_asset_materials(attachment)
	return view


func _apply_asset_materials(root: Node) -> void:
	if root is MeshInstance3D:
		var mesh: MeshInstance3D = root as MeshInstance3D
		mesh.material_override = (
			window_material
			if (mesh.name.begins_with("window_light") or mesh.name == "glass_insert")
			else wood_material
		)
		if (
			mesh.name.contains("dark")
			or mesh.name.contains("hinge")
			or mesh.name.contains("handle")
		):
			var metal: StandardMaterial3D = StandardMaterial3D.new()
			metal.albedo_color = Color("303b31")
			metal.roughness = 0.48
			mesh.material_override = metal
	for child: Node in root.get_children():
		_apply_asset_materials(child)


func _add_support(spec: Dictionary, support: Dictionary) -> void:
	var height: float = support["floor"] - support["bottom"]
	if height < 0.015:
		return
	var mesh: MeshInstance3D = MeshInstance3D.new()
	if spec["shape"] == "round":
		var cylinder: CylinderMesh = CylinderMesh.new()
		cylinder.top_radius = float(spec["size"][0]) * 0.5
		cylinder.bottom_radius = cylinder.top_radius
		cylinder.height = height
		mesh.mesh = cylinder
	else:
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(spec["size"][0], height, spec["size"][2])
		mesh.mesh = box
	mesh.position = Vector3(
		spec["position"][0], float(support["floor"]) - height * 0.5, spec["position"][2]
	)
	mesh.material_override = stone_material
	foundation_root.add_child(mesh)


func _rebuild_instances(snapshot: Dictionary) -> void:
	_clear_children(instance_root)
	_instance_views.clear()
	for item: Dictionary in snapshot["instances"]:
		var mesh: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(0.65, 0.8, 0.65)
		mesh.mesh = box
		mesh.material_override = wood_material
		var p: Array = item["position"]
		mesh.position = Vector3(
			p[0], p[1] + _field.height_at(Vector2(p[0], p[2])) + 0.4 * float(item["scale"]), p[2]
		)
		mesh.scale = Vector3.ONE * float(item["scale"])
		mesh.rotation.y = float(item["yaw"])
		instance_root.add_child(mesh)
		_instance_views[item["id"]] = mesh
	_show_selection()


func _show_selection() -> void:
	if tools == null:
		return
	_clear_children(gizmo_root)
	for key: String in _instance_views:
		var view: MeshInstance3D = _instance_views[key]
		if key in tools.selected:
			var selected_material: StandardMaterial3D = wood_material.duplicate()
			selected_material.albedo_color = Color("ffd48a")
			selected_material.emission_enabled = true
			selected_material.emission = Color(0.1, 0.07, 0.01)
			view.material_override = selected_material
			for axis: Vector3 in [Vector3.RIGHT, Vector3.BACK]:
				var handle: MeshInstance3D = MeshInstance3D.new()
				var bar: BoxMesh = BoxMesh.new()
				bar.size = (
					Vector3(1.15, 0.045, 0.075)
					if axis == Vector3.RIGHT
					else Vector3(0.075, 0.045, 1.15)
				)
				handle.mesh = bar
				handle.position = (
					Vector3(
						view.position.x,
						_field.height_at(Vector2(view.position.x, view.position.z)) + 0.08,
						view.position.z
					)
					+ axis * 0.65
				)
				var tint: StandardMaterial3D = StandardMaterial3D.new()
				tint.albedo_color = Color("d76042") if axis == Vector3.RIGHT else Color("518fa5")
				tint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				handle.material_override = tint
				gizmo_root.add_child(handle)
		else:
			view.material_override = wood_material


func _unhandled_input(event: InputEvent) -> void:
	if tools == null or tools.mode in ["rect", "round"]:
		if (
			tools != null
			and event is InputEventMouseButton
			and event.button_index == MOUSE_BUTTON_LEFT
		):
			if event.pressed and session.phase == EditSession.Phase.PENDING_COMMIT:
				hud.set_status("正在完成上一笔；可继续转动相机")
				get_viewport().set_input_as_handled()
				return
			if not event.pressed and dragging:
				dragging = false
				_submit_async(session.preview, "创建小屋")
				get_viewport().set_input_as_handled()
				return
		super._unhandled_input(event)
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.shift_pressed:
			return
		var point: Variant = camera_rig.ground_point(event.position)
		if event.pressed and point is Vector3:
			if session.phase == EditSession.Phase.PENDING_COMMIT:
				hud.set_status("正在完成上一笔；可继续转动相机")
			else:
				_tool_dragging = tools.begin(point, event.ctrl_pressed or event.meta_pressed)
				_last_point = point
				_preview_tool()
				_show_selection()
		elif _tool_dragging:
			_tool_dragging = false
			if tools.has_changes():
				_submit_async(session.preview, "编辑：" + tools.mode)
			else:
				_cancel_edit()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _tool_dragging:
		var point: Variant = camera_rig.ground_point(event.position)
		if point is Vector3:
			_last_point = point
			tools.update(point)
			_preview_tool()
	else:
		# Keep the inherited keyboard actions available in every tool.
		super._unhandled_input(event)


func _input(event: InputEvent) -> void:
	super._input(event)
	if event is InputEventMouseButton and not event.pressed and _tool_dragging:
		if get_viewport().gui_get_hovered_control() != null:
			_cancel_edit()


func _update_drag(point: Vector3) -> void:
	super._update_drag(point)
	var error: String = WorldDocument.validate(session.preview)
	if not error.is_empty():
		hud.set_status(_reason(error))
		for child: MeshInstance3D in preview_root.get_children():
			child.material_override.albedo_color = Color(1, 0.3, 0.18, 0.6)


func _preview_tool() -> void:
	if session.phase != EditSession.Phase.PREVIEW:
		return
	var error: String = WorldDocument.validate(session.preview)
	hud.set_status("预览中；松手提交，Esc 取消" if error.is_empty() else _reason(error))
	_clear_children(preview_root)
	var cursor: MeshInstance3D = MeshInstance3D.new()
	var ring: TorusMesh = TorusMesh.new()
	ring.inner_radius = 1.65 if tools.mode in ["raise", "lower"] else 0.4
	ring.outer_radius = ring.inner_radius + 0.09
	cursor.mesh = ring
	cursor.position = _last_point + Vector3.UP * 0.06
	var tint: StandardMaterial3D = StandardMaterial3D.new()
	tint.albedo_color = Color("e9b561") if error.is_empty() else Color("d95637")
	tint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cursor.material_override = tint
	preview_root.add_child(cursor)
	_preview_token = queue.request(
		session.preview,
		Rect2(Vector2(_last_point.x, _last_point.z) - Vector2.ONE * 3, Vector2.ONE * 6)
	)


func _submit_async(candidate: Dictionary, label: String) -> void:
	var detached: Dictionary = candidate.duplicate(true)
	var result: Dictionary = session.reserve_commit(detached, label)
	_clear_children(preview_root)
	if not result["ok"]:
		queue.invalidate()
		_restore_view()
		hud.set_status(_reason(result["error"]))
		return
	if queue.request(detached, Rect2(-32, -32, 64, 64), true) < 0:
		session.cancel_gesture()
		_restore_view()
		hud.set_status("上一笔仍在计算，当前操作未提交")
		return
	hud.set_status("正在完成上一笔；可继续转动相机")


func _on_batch(token: int, data: Dictionary, committed: bool) -> void:
	var apply_started: int = Time.get_ticks_usec()
	if committed:
		var result: Dictionary = session.finish_reserved(_prepare_resources(data))
		hud.set_status("已提交，可撤销" if result["ok"] else _reason(result["error"]))
		if result["ok"]:
			_preview_visible = false
		else:
			_restore_view()
	elif (
		token == _preview_token
		and session.phase == EditSession.Phase.PREVIEW
		and data.get("ok", false)
	):
		_on_published(session.preview, _prepare_resources(data))
		_preview_visible = true
	_apply_samples.append(float(Time.get_ticks_usec() - apply_started) / 1000.0)


func _cancel_edit() -> void:
	super._cancel_edit()
	_tool_dragging = false
	if queue != null:
		queue.invalidate()
	_restore_view()


func _restore_view() -> void:
	if _preview_visible:
		_on_published(document.snapshot(), _prepare_views(document.snapshot()))
	_preview_visible = false


func _on_action(action: StringName) -> void:
	if tools == null:
		return
	if action == &"cancel":
		_cancel_edit()
		hud.set_status("已取消；作品和历史保持不变")
		return
	if session.phase == EditSession.Phase.PENDING_COMMIT and action not in [&"camera"]:
		hud.set_status("正在完成上一笔；完成后再操作，Esc 可取消")
		return
	if (
		action
		in [
			&"rect",
			&"round",
			&"select",
			&"move",
			&"prop",
			&"brush",
			&"erase",
			&"raise",
			&"lower",
			&"pool"
		]
	):
		_cancel_edit()
		tools.mode = String(action)
		if action in [&"rect", &"round"]:
			current_shape = String(action)
		hud.set_status("工具：" + _tool_name(String(action)) + "；左键操作，Esc 取消")
		return
	_document_action(action)


func _document_action(action: StringName) -> void:
	if action in [&"copy", &"delete", &"rotate", &"scale_up", &"scale_down", &"delete_pool"]:
		_cancel_edit()
		var candidate: Dictionary = tools.selection_action(String(action))
		if candidate != document.state:
			_submit_async(candidate, "编辑选中对象")
		return
	if action == &"age":
		_cancel_edit()
		var draft: Dictionary = document.snapshot()
		draft["environment"]["aged"] = not draft["environment"].get("aged", false)
		_show_result(session.commit_snapshot(draft, "切换岁月", _prepare_views), "岁月已更新")
		return
	if action == &"save":
		_cancel_edit()
		hud.set_status(
			"作品已保存" if SaveCodec.write_file(W02_SAVE, document.snapshot()) == OK else "保存失败，作品仍保留"
		)
		return
	if action == &"load":
		_cancel_edit()
		var loaded: Dictionary = SaveCodec.read_file(W02_SAVE)
		if loaded["ok"]:
			_show_result(session.replace_document(loaded["snapshot"], _prepare_views), "作品已读取")
		else:
			hud.set_status("没有有效存档，保留当前作品")
		return
	super._on_action(action)


func _apply_light(dusk: bool) -> void:
	super._apply_light(dusk)
	if window_material != null:
		window_material.set_shader_parameter("dusk", dusk)


func _set_wind(reduced: bool) -> void:
	super._set_wind(reduced)
	if water_material != null:
		water_material.set_shader_parameter("reduce_motion", reduced)


static func _tool_name(mode: String) -> String:
	return (
		{
			"rect": "矩形小屋",
			"round": "圆形小屋",
			"select": "选择灰模（Ctrl/Cmd 多选）",
			"move": "移动选中灰模",
			"prop": "放灰模道具",
			"brush": "灰模刷植",
			"erase": "擦除刷植（保护手放）",
			"raise": "抬高地形",
			"lower": "降低地形",
			"pool": "圆形池岸样板"
		}
		. get(mode, mode)
	)


static func _reason(error: String) -> String:
	return (
		{
			"foundation_exceeds_3m": "不能放下：基座将超过 3 米，保留原地形",
			"terrain_above_fixed_floor": "不能放下：地形高于固定地坪",
			"pool_slope_exceeds_0_6m": "不能画池：原地面坡差超过 0.6 米",
			"pool_building_safety": "不能放下：池岸与建筑需保留 0.5 米安全带",
			"pool_manual_instance_safety": "不能改岸：会吞入已放置物件",
			"opening_on_contact": "不能贴靠：已有门窗被遮挡",
			"building_overlap": "不能放下：建筑体块重叠"
		}
		. get(error, "不能放下：" + error)
	)


func _setup_contact_demo() -> void:
	var draft: Dictionary = document.snapshot()
	draft["pool"] = {}
	draft["buildings"][1]["openings"][0]["kind"] = "rect"
	var house: Dictionary = WorldDocument.allocate_building(
		draft, Vector3(4.25, 0, 0), Vector3(3.5, 2.4, 3)
	)
	house["openings"] = [
		{"kind": "rect", "center": 0.5, "width": 1.1, "height": 2.05, "variant": "glass"}
	]
	session.replace_document(draft, _prepare_views)


func _setup_alpha_probe() -> void:
	for index: int in range(3):
		var leaf: MeshInstance3D = MeshInstance3D.new()
		var quad: QuadMesh = QuadMesh.new()
		quad.size = Vector2(0.9, 1.2)
		leaf.mesh = quad
		leaf.position = Vector3(9 + float(index) * 0.5, 0.65, 4.5)
		leaf.rotation.y = 0.65 + float(index) * 0.5
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = preload("res://features/environment/foliage_probe.gdshader")
		material.set_shader_parameter("base_color", Color("789556"))
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--wind-time="):
				material.set_shader_parameter("freeze_time", true)
				material.set_shader_parameter(
					"sample_time", argument.trim_prefix("--wind-time=").to_float()
				)
			if argument == "--wind-strength=0":
				material.set_shader_parameter("wind_strength", 0.0)
			if argument == "--still":
				material.set_shader_parameter("reduce_motion", true)
		leaf.material_override = material
		leaf.extra_cull_margin = 0.4
		world_view.add_child(leaf)
		wind_materials.append(material)


func _rebuild_probe_paths(snapshot: Dictionary) -> void:
	_clear_children(path_root)
	for path: Dictionary in snapshot["paths"]:
		for index: int in range(path["points"].size() - 1):
			var a: Array = path["points"][index]
			var b: Array = path["points"][index + 1]
			var start_point: Vector3 = Vector3(a[0], a[1], a[2])
			var end_point: Vector3 = Vector3(b[0], b[1], b[2])
			var segment: MeshInstance3D = MeshInstance3D.new()
			var box: BoxMesh = BoxMesh.new()
			box.size = Vector3(path["width"], 0.05, start_point.distance_to(end_point))
			segment.mesh = box
			segment.position = (start_point + end_point) * 0.5 + Vector3.UP * 0.02
			segment.rotation.y = atan2(end_point.x - start_point.x, end_point.z - start_point.z)
			segment.material_override = stone_material
			path_root.add_child(segment)


func _setup_road_demo() -> void:
	var draft: Dictionary = WorldDocument.new().snapshot()
	var home: Dictionary = WorldDocument.allocate_building(
		draft, Vector3(0, 0, -1), Vector3(5, 3, 5)
	)
	var candidate: Dictionary = RiskEdits.road_to_door(
		draft, home["id"], Vector3(-0.5, 0, 8), Vector3(-0.5, 0, 1.5)
	)
	if candidate["ok"]:
		session.replace_document(candidate["snapshot"], _prepare_views)


func _exercise_edits() -> void:
	for index: int in range(20):
		if session.phase != EditSession.Phase.IDLE:
			return
		var draft: Dictionary = TerrainField.brush(
			document.snapshot(), Vector2(12, 8), 0.03 if index % 2 == 0 else -0.03
		)
		_submit_async(draft, "W02 edit benchmark")
		while queue.is_busy():
			await get_tree().process_frame
		_probe_edits += 1


func _delivery_metrics() -> Dictionary:
	var samples: Array[float] = _apply_samples.duplicate()
	samples.sort()
	return {
		"probe_edits": _probe_edits,
		"main_apply_samples": samples.size(),
		"main_apply_p95_ms": samples[int(samples.size() * 0.95)] if not samples.is_empty() else 0.0,
		"main_apply_max_ms": samples.back() if not samples.is_empty() else 0.0
	}


func _prepare_resources(data: Dictionary) -> Dictionary:
	var prepared: Dictionary = WorldRebuild.materialize(data, _resource_cache)
	if prepared.get("ok", false):
		_resource_cache = prepared
	return prepared
