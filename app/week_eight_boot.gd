extends "res://app/week_seven_boot.gd"
## W08 scene-owned persistence, accessibility and staged asynchronous loading.

const SCENE_LAYOUT: Resource = preload("res://levels/forest_slope/scn_01_filled.tres")
const PREFERENCES: String = "user://week_08/preferences.cfg"
const AUTOSAVE_SECONDS: float = 60.0
var preferences: UserPreferences
var saves: SaveService
var qa_mode: bool = false
var active_slot: int = -1
var active_title: String = "林间作品"
var idle_seconds: float = 0.0
var autosave_seconds: float = 0.0
var last_save_worker_ms: float = 0.0
var last_thumbnail_bytes: int = 0
var brush_source_ms: Array[float] = []
var _saved_source: String = ""
var _saved_camera: String = ""
var _source_key: String = ""
var _source_revision: int = -1
var _camera_key: String = ""
var _writing_source: String = ""
var _writing_camera: String = ""
var _writing_slot: int = 0
var _writing_title: String = ""
var _capturing: bool = false
var _loading: bool = false
var _load_result: Dictionary = {}
var _load_index: int = 0
var _intent: String = ""
var _intent_index: int = 0
var _applying_preferences: bool = false
var _orbit_recording: bool = false


func _ready() -> void:
	super._ready()
	preferences = UserPreferences.new()
	qa_mode = qa_mode or "--qa-settings" in OS.get_cmdline_user_args()
	if not qa_mode:
		preferences.load_file(PREFERENCES)
	saves = SaveService.new()
	if qa_mode and "--qa-slots" in OS.get_cmdline_user_args():
		saves.directory = "user://week_08/qa_slots"
	saves.name = "SaveService"
	add_child(saves)
	saves.completed.connect(_save_completed)
	if qa_mode:
		active_slot = 0
	else:
		saves.request("catalog")
	hud.slot_requested.connect(_slot_requested)
	hud.preference_changed.connect(_preference_changed)
	hud.binding_requested.connect(_binding_requested)
	hud.preferences_reset.connect(_reset_preferences)
	hud.decision_made.connect(_decision_made)
	_apply_preferences()
	get_tree().auto_accept_quit = false
	_refresh_dirty_keys()
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--ui-scale=1.5":
			preferences.values["ui_scale"] = 1.5
			_apply_preferences()
		if argument == "--w08-library":
			_on_action(&"library")
		if argument == "--w08-settings":
			hud.settings.popup_centered()
		if argument == "--w08-reduced":
			preferences.values["reduce_motion"] = true
			_apply_preferences()
		if argument == "--w08-orbit":
			_orbit_recording = true
		if argument == "--w08-day":
			_recommended_view(0)
		if argument == "--w08-dof":
			preferences.values["dof"] = true
			_apply_preferences()
		if argument == "--w08-aged":
			var draft: Dictionary = document.snapshot()
			draft["environment"]["aged"] = true
			session.replace_document(draft, _prepare_views)
		if argument == "--w08-near":
			_recommended_view(1)
		if argument == "--w08-far":
			camera_rig.distance = 49
			camera_rig.refresh()
		if argument == "--w08-save-probe":
			saves.directory = "user://week_08/qa_slots"
			_start_save(0, "发布版存档探针")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--view-angle="):
			camera_rig.yaw = deg_to_rad(argument.trim_prefix("--view-angle=").to_float())
			camera_rig.refresh()
	hud.set_status("我的作品：五个命名存档 · 设置：缩放、景深、减少动态与快捷键")


func _camera_record() -> Dictionary:
	return {
		"target": [camera_rig.target.x, camera_rig.target.y, camera_rig.target.z],
		"distance": camera_rig.distance,
		"yaw": camera_rig.yaw,
		"pitch": camera_rig.pitch
	}


func _refresh_dirty_keys() -> void:
	if _source_revision != int(document.state["revision"]):
		var source: Dictionary = document.snapshot()
		source.erase("revision")
		_source_key = DirtyGraph.key(source)
		_source_revision = int(document.state["revision"])
	var next_camera: String = DirtyGraph.key(_camera_record())
	if _camera_key != next_camera:
		idle_seconds = 0
		_camera_key = next_camera


func is_dirty() -> bool:
	_refresh_dirty_keys()
	return _source_key != _saved_source or _camera_key != _saved_camera


func _process(delta: float) -> void:
	super._process(delta)
	if saves == null:
		return
	var previous: int = _source_revision
	_refresh_dirty_keys()
	if previous != _source_revision:
		idle_seconds = 0
	idle_seconds += delta
	autosave_seconds += delta
	if _orbit_recording:
		camera_rig.yaw += delta * 0.45
		camera_rig.refresh()
	if (
		idle_seconds >= AUTOSAVE_SECONDS
		and autosave_seconds >= AUTOSAVE_SECONDS
		and is_dirty()
		and _intent.is_empty()
		and active_slot >= 0
		and not _busy()
		and session.phase == EditSession.Phase.IDLE
	):
		autosave_seconds = 0
		_start_save(active_slot, active_title, true)


func _busy() -> bool:
	return _capturing or _loading or saves == null or saves.is_busy()


func _on_action(action: StringName) -> void:
	if _capturing:
		return
	if action == &"preferences":
		hud.settings.popup_centered()
		return
	if action == &"library":
		hud.library.popup_centered()
		if not _busy():
			saves.request("catalog")
		return
	if _loading or not _intent.is_empty():
		return
	if action in [&"view_day", &"view_garden"]:
		_recommended_view(0 if action == &"view_day" else 1)
		return
	super._on_action(action)


func _recommended_view(index: int) -> void:
	# Recommended views remain available even after a custom bookmark is recorded.
	_restore_camera(ForestTemplate.empty()["camera_bookmarks"][index])


func _restore_camera(record: Dictionary) -> void:
	if record.is_empty():
		return
	camera_rig.target = Vector3(record["target"][0], record["target"][1], record["target"][2])
	camera_rig.distance = record["distance"]
	camera_rig.yaw = record["yaw"]
	camera_rig.pitch = record["pitch"]
	camera_rig.refresh()


func _save_action(action: StringName) -> void:
	if active_slot < 0:
		_on_action(&"library")
		hud.set_status("请选择存档槽；五槽已满时需要明确选择要替换的作品")
		return
	if action == &"save":
		_start_save(active_slot, active_title)
	else:
		_slot_requested("load", active_slot, active_title)


func _slot_requested(operation: String, index: int, title: String) -> void:
	if _busy() or session.phase != EditSession.Phase.IDLE:
		hud.set_status("正在完成操作，请稍后再试")
		return
	if operation == "save":
		_start_save(index, title)
	else:
		_intent_index = index
		if is_dirty():
			_intent = "load"
			hud.decision.popup_centered()
		else:
			_start_load(index)


func _start_save(index: int, title: String, preserve_dialogs: bool = false) -> void:
	if _busy() or session.phase != EditSession.Phase.IDLE:
		hud.set_status("正在完成操作，尚未保存")
		return
	_capturing = true
	_writing_slot = index
	_writing_title = title.strip_edges().left(64)
	if _writing_title.is_empty():
		_writing_title = "林间作品"
	_refresh_dirty_keys()
	_writing_source = _source_key
	_writing_camera = _camera_key
	var snapshot: Dictionary = document.snapshot()
	var presentation: Dictionary = {
		"camera": _camera_record(), "saved_unix": int(Time.get_unix_time_from_system())
	}
	if DisplayServer.get_name() != "headless":
		var was_visible: bool = hud.visible
		var library_was_visible: bool = hud.library.visible and preserve_dialogs
		var settings_was_visible: bool = hud.settings.visible
		hud.settings.hide()
		hud.library.hide()
		hud.hide()
		await RenderingServer.frame_post_draw
		var image: Image = get_viewport().get_texture().get_image()
		image.resize(320, 200, Image.INTERPOLATE_LANCZOS)
		var png: PackedByteArray = image.save_png_to_buffer()
		last_thumbnail_bytes = png.size()
		presentation["thumbnail"] = Marshalls.raw_to_base64(png)
		hud.visible = was_visible
		if settings_was_visible:
			hud.settings.show()
		elif library_was_visible:
			hud.library.show()
	_capturing = false
	if saves.request("save", index, snapshot, _writing_title, presentation):
		hud.set_status("正在后台保存作品…")
	else:
		_intent = ""
		hud.set_status("保存未启动，请重试")


func _start_load(index: int) -> void:
	_cancel_edit()
	_load_index = index
	_loading = saves.request("load", index)
	hud.set_status("正在后台读取并准备场景…")


func _save_completed(operation: String, result: Dictionary) -> void:
	last_save_worker_ms = result.get("worker_ms", 0.0)
	if not result["ok"]:
		_loading = false
		_intent = ""
		hud.set_status("操作失败：" + _save_error(result.get("error", "")) + "；原作品保留")
		return
	if operation == "catalog":
		hud.update_catalog(result["slots"])
		if active_slot < 0:
			for entry: Dictionary in result["slots"]:
				if not entry["ok"] and entry["error"] == "no_valid_save":
					active_slot = entry["index"]
					hud.slots.select(active_slot)
					break
			if active_slot < 0:
				hud.set_status("五个槽位已有作品；请载入或明确选择槽位保存，自动保存暂不覆盖任何作品")
	elif operation == "save":
		active_slot = _writing_slot
		active_title = _writing_title
		_saved_source = _writing_source
		_saved_camera = _writing_camera
		autosave_seconds = 0
		hud.set_status("已保存「" + active_title + "」· 三代备份轮替")
		if not _intent.is_empty():
			if is_dirty():
				hud.decision.popup_centered()
				hud.set_status("保存期间构图发生变化，请再次确认离开")
			else:
				_continue_intent()
	elif operation == "load":
		_load_result = result
		var generated: Dictionary = result["generated"]
		if not generated.get("ok", false):
			_loading = false
			hud.set_status("场景生成失败，原作品保留")
			return
		var plan: Dictionary = _planner.prepare(generated, stage)
		stage.begin(-808, plan["jobs"], plan["payload"])


func _stage_done(token: int, payload: Dictionary) -> void:
	if token != -808:
		super._stage_done(token, payload)
		return
	var result: Dictionary = session.replace_prepared(_load_result["snapshot"], payload)
	_loading = false
	if not result["ok"]:
		_discard(payload)
		_restore_view()
		hud.set_status("载入失败，原作品保留")
		return
	active_slot = _load_index
	active_title = _load_result.get("metadata", {}).get("title", "林间作品")
	_restore_camera(_load_result.get("metadata", {}).get("presentation", {}).get("camera", {}))
	tools.selected.clear()
	_show_selection()
	_refresh_dirty_keys()
	_saved_source = _source_key
	_saved_camera = _camera_key
	idle_seconds = 0
	_sync_wind(document.state)
	hud.library.hide()
	hud.set_status(
		(
			"已载入「"
			+ active_title
			+ "」"
			+ (" · 从备份恢复，请另存到空槽" if _load_result.get("recovered_backup", 0) > 0 else "")
		)
	)
	_load_result.clear()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and saves != null:
		if _busy() or session.phase != EditSession.Phase.IDLE:
			hud.set_status("操作进行中，请稍后关闭窗口")
		elif is_dirty():
			_intent = "quit"
			hud.decision.popup_centered()
		else:
			get_tree().quit()


func _decision_made(choice: String) -> void:
	if choice == "cancel":
		_intent = ""
	elif choice == "discard":
		_continue_intent()
	elif choice == "save":
		if active_slot < 0:
			_intent = ""
			_on_action(&"library")
			hud.set_status("请先选择槽位保存，再继续离开")
		else:
			_start_save(active_slot, active_title)


func _continue_intent() -> void:
	var intent: String = _intent
	_intent = ""
	if intent == "quit":
		get_tree().quit()
	elif intent == "load":
		_start_load(_intent_index)


func _preference_changed(key: String, value: Variant) -> void:
	if preferences == null or _applying_preferences:
		return
	var candidate: Dictionary = preferences.values.duplicate(true)
	candidate[key] = value
	if not UserPreferences.valid(candidate):
		return
	preferences.values = candidate
	_apply_preferences()
	_persist_preferences()


func _binding_requested(action: String, event: InputEventKey) -> void:
	var error: String = preferences.rebind(action, event)
	hud.settings_note.text = "快捷键已保存" if error.is_empty() else error
	if error.is_empty():
		_persist_preferences()
	hud.sync_preferences(preferences)


func _reset_preferences() -> void:
	preferences.reset()
	_apply_preferences()
	_persist_preferences()


func _persist_preferences() -> void:
	if not qa_mode and preferences.save_file(PREFERENCES) != OK:
		hud.settings_note.text = "设置写入失败，本次会话仍可使用；请检查磁盘权限"


func _apply_preferences() -> void:
	_applying_preferences = true
	hud.set_ui_scale(preferences.values["ui_scale"])
	hud.sync_preferences(preferences)
	var attributes: CameraAttributesPractical = CameraAttributesPractical.new()
	attributes.dof_blur_far_enabled = preferences.values["dof"]
	attributes.dof_blur_far_distance = 32
	attributes.dof_blur_far_transition = 12
	attributes.dof_blur_amount = 0.08
	camera_rig.camera.attributes = attributes
	_sync_wind(document.state)
	_applying_preferences = false


func _sync_wind(snapshot: Dictionary) -> void:
	super._sync_wind(snapshot)
	if preferences != null and preferences.values["reduce_motion"]:
		for paint: ShaderMaterial in wind_materials:
			paint.set_shader_parameter("reduce_motion", true)
	if water_material != null:
		water_material.set_shader_parameter(
			"reduce_motion",
			(
				snapshot["environment"]["reduce_motion"]
				or (preferences != null and preferences.values["reduce_motion"])
			)
		)
	# Rebuilt materials must retain deterministic capture overrides too.
	_apply_render_flags()


func _input(event: InputEvent) -> void:
	super._input(event)
	if event is InputEventKey or event is InputEventMouseButton:
		idle_seconds = 0


func _unhandled_input(event: InputEvent) -> void:
	if _loading or not _intent.is_empty():
		return
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return
	super._unhandled_input(event)


func _delivery_metrics() -> Dictionary:
	var result: Dictionary = super._delivery_metrics()
	result["save_worker_ms"] = last_save_worker_ms
	result["thumbnail_png_bytes"] = last_thumbnail_bytes
	result["brush_source_ms"] = brush_source_ms.duplicate()
	result["slot_count"] = SlotStore.COUNT
	result["backup_count"] = SlotStore.BACKUPS
	result["preferences_dof"] = preferences.values["dof"] if preferences != null else false
	return result


func _exercise_edits() -> void:
	if "--large-brush-benchmark" not in OS.get_cmdline_user_args():
		super._exercise_edits()
		return
	for index: int in range(8):
		if session.phase != EditSession.Phase.IDLE:
			return
		var start: int = Time.get_ticks_usec()
		var draft: Dictionary = TerrainField.brush(
			document.snapshot(), Vector2(12, 8), 0.02 if index % 2 == 0 else -0.02, 9.0
		)
		brush_source_ms.append(float(Time.get_ticks_usec() - start) / 1000)
		_submit_async(draft, "W08 large brush benchmark")
		while queue.is_busy():
			await get_tree().process_frame
		_probe_edits += 1


func _setup_initial_buildings() -> void:
	_show_result(session.replace_document(SCENE_LAYOUT.snapshot(), _prepare_views), "林间坡地 SCN-01")


func _save_error(code: String) -> String:
	return (
		{
			"protected_invalid_save": "此槽主文件损坏或版本较新，请另存到空槽",
			"unsupported_save_format": "存档版本无法识别，请保留原文件",
			"unsupported_generator": "此存档来自不兼容的生成器版本",
			"no_valid_save": "此槽没有可用的主文件或备份",
			"invalid_save_checksum": "主文件与三份备份均未通过校验",
			"invalid_snapshot": "作品数据未通过校验",
			"invalid_slot": "请选择一个有效存档槽"
		}
		. get(code, "读写失败，请检查磁盘空间与文件权限")
	)


func _apply_render_flags() -> void:
	super._apply_render_flags()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--water-time=") and water_material != null:
			water_material.set_shader_parameter("freeze_time", true)
			water_material.set_shader_parameter(
				"sample_time", argument.trim_prefix("--water-time=").to_float()
			)
