extends "res://app/week_eight_boot.gd"
## W09 photography, same-world entries and repeatable capacity probes.

var photography: PhotoExport
var photo_active: bool = false
var initial_load_ms: float = 0
var main_callback_ms: Array[float] = []
var _editor_camera: Dictionary = {}
var _photo_visibility: Dictionary = {}
var _dynamic_state: Array[Dictionary] = []
var _layout_kind: String = "demo"
var _directory_dialog: FileDialog
var _overwrite_approved: bool = false
var _initial_start: int = Time.get_ticks_usec()


func _ready() -> void:
	super._ready()
	camera_rig.touchpad_orbit = true
	if qa_mode:
		saves.directory = "user://qa_w09_native"
		if DisplayServer.get_name() != "headless":
			_announce_first_draw.call_deferred()
	photography = PhotoExport.new()
	photography.name = "Photography"
	add_child(photography)
	hud.photo_requested.connect(_photo_action)
	hud.layout_requested.connect(_request_layout)
	_directory_dialog = FileDialog.new()
	_directory_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	_directory_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_directory_dialog.use_native_dialog = true
	_directory_dialog.dir_selected.connect(
		func(path: String) -> void: hud.photo_directory.text = path
	)
	add_child(_directory_dialog)
	hud.sync_preferences(preferences)
	initial_load_ms = float(Time.get_ticks_usec() - _initial_start) / 1000
	if "--w09-photo" in OS.get_cmdline_user_args():
		enter_photo()
	if "--w09-empty" in OS.get_cmdline_user_args():
		_layout_kind = "empty"
		_apply_layout()
	if (
		"--w09-entry" in OS.get_cmdline_user_args()
		or (not qa_mode and _report_path.is_empty() and _capture_path.is_empty())
	):
		hud.entry.popup_centered()
	if "--w09-photo-probe" in OS.get_cmdline_user_args():
		_photo_probe.call_deferred()
	hud.set_status("双指移动旋转 · 捏合缩放 · Option+左键平移 · 顶部进入摄影/选择布局")


func _setup_initial_buildings() -> void:
	var source: Dictionary = SCENE_LAYOUT.snapshot()
	if "--w09-stress" in OS.get_cmdline_user_args():
		source = StressLayout.create()
	elif "--w09-stress-reduced" in OS.get_cmdline_user_args():
		source = StressLayout.create(0.5)
	_show_result(session.replace_document(source, _prepare_views), "林间坡地")


func enter_photo() -> bool:
	if photo_active or _busy() or session.phase != EditSession.Phase.IDLE or queue.is_busy():
		return false
	_editor_camera = _camera_record().duplicate(true)
	photo_active = true
	for node: Node in hud._panels + [hud._feedback, hud.hint, gizmo_root, preview_root]:
		_photo_visibility[node] = node.visible
		node.hide()
	# Node3D and CanvasItem do not share an inheritance branch; hide 3D tools separately.
	hud.photo_panel.show()
	hud.refresh_bookmarks(document.state["camera_bookmarks"])
	_freeze_photo(hud.freeze.button_pressed)
	return true


func exit_photo() -> void:
	if not photo_active or photography.busy:
		return
	_freeze_photo(false)
	_restore_camera(_editor_camera)
	for node: Node in _photo_visibility:
		if is_instance_valid(node):
			node.visible = _photo_visibility[node]
	_photo_visibility.clear()
	hud.photo_panel.hide()
	photo_active = false
	idle_seconds = 0


func _freeze_photo(enabled: bool) -> void:
	for record: Dictionary in _dynamic_state:
		for key: String in record["values"]:
			record["material"].set_shader_parameter(key, record["values"][key])
	_dynamic_state.clear()
	if not enabled:
		return
	var materials: Array = wind_materials.duplicate()
	if water_material != null:
		materials.append(water_material)
	for material: ShaderMaterial in materials:
		var values: Dictionary = {}
		for key: String in ["freeze_time", "sample_time"]:
			values[key] = material.get_shader_parameter(key)
		_dynamic_state.append({"material": material, "values": values})
		material.set_shader_parameter("freeze_time", true)
		material.set_shader_parameter("sample_time", float(Time.get_ticks_msec()) / 1000)


func _photo_action(action: String) -> void:
	if photography.busy:
		return
	match action:
		"exit":
			exit_photo()
		"hide":
			hud.photo_panel.hide()
		"directory":
			_directory_dialog.popup_centered(Vector2i(800, 520))
		"freeze":
			_freeze_photo(hud.freeze.button_pressed)
		"export":
			var path: String = PhotoExport.output_path(hud.photo_directory.text, active_title)
			var result: Dictionary = await photography.capture(
				camera_rig.camera, PhotoExport.SIZES[hud.photo_size.selected], path
			)
			hud.photo_note.text = (
				"已导出：" + path if result["ok"] else "导出失败：" + result["error"] + "；修改目录后重试"
			)
		"bookmark":
			var draft: Dictionary = document.snapshot()
			if draft["camera_bookmarks"].size() >= 32:
				hud.photo_note.text = "最多保存 32 个构图"
				return
			var record: Dictionary = _camera_record()
			record["id"] = "构图_%d" % Time.get_ticks_usec()
			draft["camera_bookmarks"].append(record)
			var result: Dictionary = session.commit_snapshot(draft, "保存摄影构图", _prepare_views)
			hud.photo_note.text = "构图已加入作品；请保存作品到存档槽" if result["ok"] else "构图保存失败"
			hud.refresh_bookmarks(document.state["camera_bookmarks"])
			_freeze_photo(hud.freeze.button_pressed)
			gizmo_root.hide()
			preview_root.hide()
		"restore":
			var selected: PackedInt32Array = hud.bookmarks.get_selected_items()
			if not selected.is_empty():
				_restore_camera(document.state["camera_bookmarks"][selected[0]])


func _on_action(action: StringName) -> void:
	if photo_active:
		return
	if action == &"photography":
		enter_photo()
	elif action == &"entry":
		hud.entry.popup_centered()
	else:
		super._on_action(action)


func _input(event: InputEvent) -> void:
	if photo_active:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			exit_photo()
			get_viewport().set_input_as_handled()
		return
	super._input(event)


func _unhandled_input(event: InputEvent) -> void:
	if photo_active:
		return
	super._unhandled_input(event)


func _busy() -> bool:
	return photo_active or super._busy()


func _request_layout(kind: String) -> void:
	if kind not in ["demo", "empty"] or _busy() or session.phase != EditSession.Phase.IDLE:
		return
	_layout_kind = kind
	hud.entry.hide()
	if is_dirty():
		_intent = "layout"
		hud.decision.popup_centered()
	else:
		_apply_layout()


func _continue_intent() -> void:
	if _intent == "layout":
		_intent = ""
		_apply_layout()
	else:
		super._continue_intent()


func _apply_layout() -> void:
	_cancel_edit()
	var source: Dictionary = (
		ForestTemplate.empty() if _layout_kind == "empty" else ForestTemplate.create()
	)
	var result: Dictionary = session.replace_document(source, _prepare_views)
	if result["ok"]:
		active_slot = -1
		active_title = "空布局作品" if _layout_kind == "empty" else "林间作品"
		tools.selected.clear()
		_show_selection()
		_recommended_view(0)
		hud.set_status("拖出小屋，再试试石径与花草；所有工具已开放，可跳过提示。")


func _slot_requested(operation: String, index: int, title: String) -> void:
	if operation == "save" and not _overwrite_approved:
		var existing: Dictionary = SlotStore.read_slot(saves.directory, index)
		if existing["ok"]:
			hud._overwrite_request = [operation, index, title]
			if not hud.overwrite.confirmed.is_connected(_confirm_overwrite):
				hud.overwrite.confirmed.connect(_confirm_overwrite)
			hud.overwrite.popup_centered()
			return
	_overwrite_approved = false
	super._slot_requested(operation, index, title)


func _confirm_overwrite() -> void:
	_overwrite_approved = true
	_slot_requested(hud._overwrite_request[0], hud._overwrite_request[1], hud._overwrite_request[2])


func _delivery_metrics() -> Dictionary:
	var result: Dictionary = super._delivery_metrics()
	result["initial_load_ms"] = initial_load_ms
	result["main_callback_max_ms"] = (
		main_callback_ms.max() if not main_callback_ms.is_empty() else 0
	)
	result["main_callback_samples_ms"] = main_callback_ms.duplicate()
	result["static_memory_bytes"] = OS.get_static_memory_usage()
	return result


func _photo_probe() -> void:
	await get_tree().process_frame
	var output: String = "res://reports/week_09_visuals"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--photo-output="):
			output = arg.trim_prefix("--photo-output=")
	DirAccess.make_dir_recursive_absolute(output)
	_recommended_view(0)
	var source: Dictionary = document.snapshot()
	var camera: Dictionary = _camera_record()
	tools.selected.assign([document.state["buildings"][0]["id"]])
	_show_selection()
	var results: Array = []
	var failure: Dictionary = {}
	if enter_photo():
		failure = await photography.capture(
			camera_rig.camera, Vector2i(1920, 1080), "/__windhaven_missing__/photo.png"
		)
		for size: Vector2i in PhotoExport.SIZES + [Vector2i(512, 288)]:
			results.append(
				await photography.capture(
					camera_rig.camera, size, output.path_join("photo_%dx%d.png" % [size.x, size.y])
				)
			)
		exit_photo()
	var report: Dictionary = {
		"results": results,
		"failure_retry":
		not failure.get("ok", true) and failure.get("error") == "directory_missing",
		"source_unchanged": source == document.snapshot(),
		"camera_restored": camera == _camera_record(),
		"selection_restored": tools.selected.size() == 1,
		"outline_restored": gizmo_root.visible,
		"photo_active": photo_active
	}
	var file: FileAccess = FileAccess.open(output.path_join("photo_report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))


func _submit_async(candidate: Dictionary, label: String) -> void:
	var started: int = Time.get_ticks_usec()
	super._submit_async(candidate, label)
	main_callback_ms.append(float(Time.get_ticks_usec() - started) / 1000)


func _on_batch(token: int, data: Dictionary, committed: bool) -> void:
	var started: int = Time.get_ticks_usec()
	super._on_batch(token, data, committed)
	main_callback_ms.append(float(Time.get_ticks_usec() - started) / 1000)


func _finish_smoke() -> void:
	if not _report_path.is_empty():
		var file: FileAccess = FileAccess.open(
			_report_path.trim_suffix(".json") + "_frames.json", FileAccess.WRITE
		)
		file.store_string(JSON.stringify(_benchmark))
	super._finish_smoke()


func _announce_first_draw() -> void:
	await RenderingServer.frame_post_draw
	print("W09_FIRST_DRAW")
