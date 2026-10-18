extends Node3D
## Week-one playable laboratory, not the finished SCN-01 asset set.

const SAVE_PATH: String = "user://week_01/forest.wgs"
const WIND_SHADER: Shader = preload("res://features/environment/wind.gdshader")
const DOOR_ARCH: PackedScene = preload("res://assets/buildings/door_arch.glb")
const DOOR_PLANK: PackedScene = preload("res://assets/buildings/door_plank.glb")

var document: WorldDocument = WorldDocument.new()
var session: EditSession
var building_root: Node3D
var preview_root: Node3D
var sun: DirectionalLight3D
var world_environment: WorldEnvironment
var wind_materials: Array[ShaderMaterial] = []
var current_shape: String = "rect"
var drag_start: Vector3
var dragging: bool = false
var _smoke_frames: int = 0
var _capture_path: String = ""
var _report_path: String = ""
var _benchmark: Array[float] = []
var _benchmark_seconds: float = 0.0
var _benchmark_started_ms: int = 0

@onready var world_view: Node3D = %WorldView
@onready var camera_rig: OrbitCamera = %CameraRig
@onready var hud: WeekOneHud = %Hud


func _ready() -> void:
	session = EditSession.new(document)
	session.state_published.connect(_on_published)
	hud.action_requested.connect(_on_action)
	building_root = Node3D.new()
	building_root.name = "Buildings"
	world_view.add_child(building_root)
	preview_root = Node3D.new()
	preview_root.name = "Preview"
	world_view.add_child(preview_root)
	_setup_environment()
	_setup_ground()
	_setup_samples()
	_setup_initial_buildings()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			_capture_path = argument.trim_prefix("--capture=")
		if argument.begins_with("--smoke-output="):
			_report_path = argument.trim_prefix("--smoke-output=")
		if argument == "--dusk":
			_apply_light(true)
		if argument == "--still":
			_set_wind(true)
		if argument.begins_with("--wind-time="):
			for material: ShaderMaterial in wind_materials:
				material.set_shader_parameter("freeze_time", true)
				material.set_shader_parameter(
					"sample_time", argument.trim_prefix("--wind-time=").to_float()
				)
		if argument.begins_with("--wind-strength="):
			for material: ShaderMaterial in wind_materials:
				material.set_shader_parameter(
					"wind_strength", argument.trim_prefix("--wind-strength=").to_float()
				)
		if argument.begins_with("--benchmark-seconds="):
			_benchmark_seconds = clampf(
				argument.trim_prefix("--benchmark-seconds=").to_float(), 1.0, 120.0
			)
	if not _report_path.is_empty() or not _capture_path.is_empty():
		_smoke_frames = 150
		_benchmark_started_ms = Time.get_ticks_msec()
		if _benchmark_seconds > 0.0:
			_smoke_frames = 999999


func _process(delta: float) -> void:
	if _smoke_frames <= 0:
		return
	var elapsed: float = float(Time.get_ticks_msec() - _benchmark_started_ms) / 1000.0
	if _benchmark_seconds > 0.0 and elapsed >= 2.0 + _benchmark_seconds:
		_smoke_frames = 1
	if (_benchmark_seconds > 0.0 and elapsed > 2.0) or _smoke_frames < 120:
		_benchmark.append(delta * 1000.0)
	_smoke_frames -= 1
	if _smoke_frames == 0:
		_finish_smoke.call_deferred()


func _exit_tree() -> void:
	if session != null:
		session.dispose()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not event.pressed and dragging:
		if get_viewport().gui_get_hovered_control() != null:
			_cancel_edit()


func _unhandled_input(event: InputEvent) -> void:
	for binding: Array in [
		["cancel_edit", "cancel"],
		["redo_edit", "redo"],
		["undo_edit", "undo"],
		["save_work", "save"],
		["load_work", "load"]
	]:
		if event.is_action_pressed(binding[0]) and not event.is_echo():
			_on_action(StringName(binding[1]))
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.shift_pressed or (event.alt_pressed and event.pressed):
			return
		if event.pressed:
			var point: Variant = camera_rig.ground_point(event.position)
			if point is Vector3 and session.begin_gesture():
				drag_start = point
				dragging = true
				_update_drag(point)
		elif dragging:
			dragging = false
			var result: Dictionary = session.release_gesture("创建小屋", _prepare_views)
			_clear_children(preview_root)
			_show_result(result, "小屋已放下；可继续拖出下一间")
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and dragging:
		var point: Variant = camera_rig.ground_point(event.position)
		if point is Vector3:
			_update_drag(point)


func _update_drag(point: Vector3) -> void:
	var candidate: Dictionary = document.snapshot()
	var size: Vector3 = Vector3(
		clampf(absf(point.x - drag_start.x), 3.0, 12.0),
		3.0,
		clampf(absf(point.z - drag_start.z), 3.0, 12.0)
	)
	if current_shape == "round":
		size.z = size.x
	var center: Vector3 = (point + drag_start) * 0.5
	center.y = 0.0
	var building: Dictionary = WorldDocument.allocate_building(
		candidate, center, size, current_shape
	)
	session.update_gesture(candidate)
	_clear_children(preview_root)
	var mesh: MeshInstance3D = _building_view(building, BuildingGeometry.build(building))
	var material: StandardMaterial3D = _building_material()
	material.albedo_color = Color(0.55, 0.83, 0.65, 0.65)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material_override = material
	preview_root.add_child(mesh)


func _on_action(action: StringName) -> void:
	if action in [&"rect", &"round"]:
		_cancel_edit()
		current_shape = String(action)
		hud.set_status("已选%s；在草地拖动" % ("圆形小屋" if action == &"round" else "矩形小屋"))
		return
	if action == &"cancel":
		_cancel_edit()
		hud.set_status("已取消预览，作品保持不变")
	elif action == &"undo" or action == &"redo":
		_cancel_edit()
		var result: Dictionary = (
			session.request_undo(_prepare_views)
			if action == &"undo"
			else session.request_redo(_prepare_views)
		)
		_show_result(result, "已撤销" if action == &"undo" else "已重做")
	elif action == &"save":
		var error: Error = SaveCodec.write_file(SAVE_PATH, document.snapshot())
		hud.set_status("已保存到本机" if error == OK else "保存失败：" + error_string(error))
	elif action == &"load":
		_cancel_edit()
		var loaded: Dictionary = SaveCodec.read_file(SAVE_PATH)
		if loaded["ok"]:
			_show_result(session.replace_document(loaded["snapshot"], _prepare_views), "已读取作品")
		else:
			hud.set_status("没有可用存档；当前作品保持不变")
	elif action == &"camera":
		camera_rig.reset_view()
	elif action == &"light":
		_change_environment("dusk", not document.state["environment"]["dusk"])
	elif action == &"wind":
		_change_environment("reduce_motion", not document.state["environment"]["reduce_motion"])


func _change_environment(key: String, value: bool) -> void:
	_cancel_edit()
	var candidate: Dictionary = document.snapshot()
	candidate["environment"][key] = value
	_show_result(session.commit_snapshot(candidate, "切换氛围", _prepare_views), "氛围已更新")


func _cancel_edit() -> void:
	dragging = false
	session.cancel_gesture()
	_clear_children(preview_root)


func _prepare_views(snapshot: Dictionary) -> Dictionary:
	var meshes: Array[ArrayMesh] = []
	for spec: Dictionary in snapshot["buildings"]:
		meshes.append(BuildingGeometry.build(spec))
	return {"ok": true, "meshes": meshes}


func _on_published(snapshot: Dictionary, prepared: Dictionary) -> void:
	_clear_children(building_root)
	for index: int in range(snapshot["buildings"].size()):
		building_root.add_child(
			_building_view(snapshot["buildings"][index], prepared["meshes"][index])
		)
	_apply_light(snapshot["environment"]["dusk"])
	_set_wind(snapshot["environment"]["reduce_motion"])
	for material: ShaderMaterial in wind_materials:
		material.set_shader_parameter("wind_strength", snapshot["environment"]["wind_strength"])


func _building_view(spec: Dictionary, mesh: ArrayMesh) -> MeshInstance3D:
	var view: MeshInstance3D = MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = _building_material()
	var position_values: Array = spec["position"]
	view.position = Vector3(position_values[0], position_values[1], position_values[2])
	view.set_meta("object_id", spec["id"])
	for opening: Dictionary in spec.get("openings", []):
		if float(opening.get("height", 0.0)) < 1.8 or int(opening.get("facade", 0)) != 0:
			continue
		var door: Node3D = (
			(DOOR_ARCH.instantiate() if opening.get("kind") == "arch" else DOOR_PLANK.instantiate())
			as Node3D
		)
		var center: float = float(opening.get("center", 0.5))
		var dimensions: Array = spec["size"]
		if spec["shape"] == "round":
			var angle: float = center * TAU
			door.position = Vector3(sin(angle), 0, cos(angle)) * (float(dimensions[0]) * 0.5 + 0.02)
			door.rotation.y = angle
		else:
			door.position = Vector3(
				(center - 0.5) * float(dimensions[0]), 0, float(dimensions[2]) * 0.5 + 0.02
			)
		view.add_child(door)
	return view


func _setup_initial_buildings() -> void:
	var draft: Dictionary = document.snapshot()
	var home: Dictionary = WorldDocument.allocate_building(
		draft, Vector3(0, 0, -1), Vector3(5, 3, 5)
	)
	home["openings"] = [
		{"kind": "arch", "center": 0.35, "width": 1.1, "height": 2.05, "facade": 0},
		{"kind": "rect", "center": 0.78, "width": 0.9, "height": 0.9, "sill": 1.0, "facade": 0},
	]
	var tower: Dictionary = WorldDocument.allocate_building(
		draft, Vector3(-6, 0, -3.5), Vector3(3.6, 3.0, 3.6), "round"
	)
	tower["openings"] = [
		{"kind": "arch", "center": 0.1, "width": 1.0, "height": 2.0},
		{"kind": "round", "center": 0.3, "width": 0.75, "height": 0.75, "sill": 1.2},
	]
	session.replace_document(draft, _prepare_views)


func _setup_environment() -> void:
	world_environment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("b9ccc0")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c9d8c1")
	environment.ambient_light_energy = 0.6
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	world_view.add_child(world_environment)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	world_view.add_child(sun)
	_apply_light(false)


func _setup_ground() -> void:
	var ground: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(52, 0.7, 52)
	ground.mesh = box
	ground.position.y = -0.4
	var grass: StandardMaterial3D = StandardMaterial3D.new()
	grass.albedo_color = Color("899b71")
	grass.roughness = 1.0
	ground.material_override = grass
	world_view.add_child(ground)
	var path: MeshInstance3D = MeshInstance3D.new()
	var path_mesh: BoxMesh = BoxMesh.new()
	path_mesh.size = Vector3(1.2, 0.06, 9)
	path.mesh = path_mesh
	path.position = Vector3(-0.75, 0.0, 5.0)
	var stone: StandardMaterial3D = StandardMaterial3D.new()
	stone.albedo_color = Color("b6ad92")
	path.material_override = stone
	world_view.add_child(path)


func _setup_samples() -> void:
	var assets: Array[String] = ["tree_sample", "cloth_sample", "bench_sample"]
	for index: int in range(assets.size()):
		var location: String = "res://assets/samples/" + assets[index] + ".glb"
		if not ResourceLoader.exists(location):
			continue
		var packed: PackedScene = load(location) as PackedScene
		var sample: Node3D = packed.instantiate() as Node3D
		world_view.add_child(sample)
		sample.position = [Vector3(6, 0, -4), Vector3(4, 0, 4), Vector3(-4, 0, 4)][index]
		if index < 2:
			_assign_wind(sample, index)
	# Reuse the tree prototype; these are sample instances, not new assets.
	for index: int in range(9):
		var location: String = "res://assets/samples/tree_sample.glb"
		if not ResourceLoader.exists(location):
			break
		var sample: Node3D = (load(location) as PackedScene).instantiate() as Node3D
		world_view.add_child(sample)
		var angle: float = float(index) * TAU / 9.0
		sample.position = Vector3(sin(angle) * 12.0, 0, cos(angle) * 12.0)
		sample.scale = Vector3.ONE * (0.85 + float(index % 3) * 0.13)
		_assign_wind(sample, 0)


func _assign_wind(root: Node, kind: int) -> void:
	if root is MeshInstance3D:
		var mesh: MeshInstance3D = root as MeshInstance3D
		if mesh.name.to_lower().contains("leaves") or mesh.name.to_lower().contains("cloth"):
			var material: ShaderMaterial = ShaderMaterial.new()
			material.shader = WIND_SHADER
			material.set_shader_parameter(
				"base_color", Color("ede3c9") if kind == 1 else Color("6d8655")
			)
			material.set_shader_parameter("phase", float(wind_materials.size()) * 1.7)
			material.set_shader_parameter(
				"wind_strength", document.state["environment"]["wind_strength"]
			)
			mesh.material_override = material
			mesh.extra_cull_margin = 0.5
			wind_materials.append(material)
	for child: Node in root.get_children():
		_assign_wind(child, kind)


func _apply_light(dusk: bool) -> void:
	if sun != null:
		sun.light_color = Color("ffc78a") if dusk else Color("fff1d3")
		sun.light_energy = 1.1 if dusk else 1.65
		sun.rotation_degrees.x = -18.0 if dusk else -48.0
		world_environment.environment.ambient_light_color = (
			Color("94a3aa") if dusk else Color("c9d8c1")
		)


func _set_wind(reduced: bool) -> void:
	for material: ShaderMaterial in wind_materials:
		material.set_shader_parameter("reduce_motion", reduced)


func _finish_smoke() -> void:
	if not _capture_path.is_empty():
		# Capture tools may be occluded by macOS while cycling windows; request a real draw.
		RenderingServer.force_draw(false)
		get_viewport().get_texture().get_image().save_png(_capture_path)
	if not _report_path.is_empty():
		_benchmark.sort()
		var stream: FileAccess = FileAccess.open(_report_path, FileAccess.WRITE)
		var renderer: String = RenderingServer.get_current_rendering_method()
		stream.store_string(
			JSON.stringify(
				{
					"engine": Engine.get_version_info()["string"],
					"renderer": renderer,
					"viewport_size": [get_viewport().size.x, get_viewport().size.y],
					"buildings": document.state["buildings"].size(),
					"paths": document.state["paths"].size(),
					"instances": document.state["instances"].size(),
					"terrain_samples": document.state["terrain"]["height_deltas"].size(),
					"pond_present": not document.state["pool"].is_empty(),
					"wind_materials": wind_materials.size(),
					"test_framework_in_pack": ResourceLoader.exists("res://addons/gut/gut.gd"),
					"test_sources_in_pack":
					(
						ResourceLoader.exists("res://tests/week_01/test_playground.gd")
						or ResourceLoader.exists("res://tests/week_02/test_week_two_playground.gd")
						or ResourceLoader.exists(
							"res://tests/week_03/test_week_three_playground.gd"
						)
						or ResourceLoader.exists("res://tests/week_04/test_week_four_playground.gd")
						or ResourceLoader.exists("res://tests/week_05/test_garden_rules.gd")
					),
					"frames": _benchmark.size(),
					"sample_duration_seconds": _benchmark_seconds,
					"edit_metrics": _delivery_metrics(),
					"p95_frame_ms": _benchmark[int(_benchmark.size() * 0.95)],
					"mean_frame_ms":
					(
						_benchmark.reduce(func(a: float, b: float) -> float: return a + b, 0.0)
						/ _benchmark.size()
					),
				},
				"  "
			)
		)
		stream.close()
	get_tree().quit()


static func _building_material() -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.95
	return material


static func _clear_children(root: Node) -> void:
	for child: Node in root.get_children():
		root.remove_child(child)
		child.free()


func _show_result(result: Dictionary, success: String) -> void:
	hud.set_status(success if result["ok"] else "保留原状：" + String(result["error"]))


func _delivery_metrics() -> Dictionary:
	return {}
