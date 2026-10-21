extends "res://features/garden_presentation/garden_playground.gd"
## UX-02 direct manipulation. Existing source validation/history remain authoritative.

var direct: Dictionary = {}
var _suppress_left: bool = false
var _opening_point: Variant = null


func _ready() -> void:
	super._ready()
	if qa_mode:
		saves.directory = "user://qa_ux02_native"
	hud.direct_handles.drag_requested.connect(begin_direct)
	(camera_rig as DirectOrbitCamera).secondary_clicked.connect(_secondary_clicked)
	hud.set_status("点底栏就画 · 右键点物体就改 · 双指旋转 / 捏合缩放 · ⌥+左键平移")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ux-tool=") and qa_mode:
			hud.open_group(argument.trim_prefix("--ux-tool="))
		if argument == "--ux-select" and qa_mode and not document.state["buildings"].is_empty():
			selected_buildings.assign([document.state["buildings"][0]["id"]])
			tools.mode = "inspect"


func _process(delta: float) -> void:
	super._process(delta)
	if hud.direct_handles == null or tools == null:
		return
	var allowed: bool = (
		not _busy() and _intent.is_empty() and not hud.settings.visible and not hud.library.visible
	)
	for button: Button in hud.ribbon_buttons.values():
		button.disabled = not allowed or session.phase == EditSession.Phase.PENDING_COMMIT
	var subject: Dictionary = _subject()
	var editing: bool = (
		allowed
		and (tools.mode == "inspect" or not direct.is_empty())
		and not subject.is_empty()
		and not hud.quick.visible
		and not hud.context.visible
	)
	hud.show_object_actions(
		subject.get("house", false),
		editing and direct.is_empty() and session.phase == EditSession.Phase.IDLE
	)
	if not editing or session.phase == EditSession.Phase.PENDING_COMMIT:
		hud.direct_handles.clear()
	else:
		hud.direct_handles.present(
			subject["item"],
			subject["house"],
			camera_rig.camera,
			hud._scale_value,
			subject["origin"],
			direct.get("kind", "")
		)
	if photo_active:
		hud.direct_handles.hide()
		hud.object_bar.hide()


func _show_selection() -> void:
	super._show_selection()
	if tools != null and tools.mode == "inspect":
		_clear_children(gizmo_root)


func _subject() -> Dictionary:
	var house: bool = direct.get("house", not selected_buildings.is_empty())
	var ids: Array[String] = selected_buildings if house else tools.selected
	var id_value: String = direct.get("id", "" if ids.is_empty() else ids[0])
	if id_value.is_empty():
		return {}
	var source: Dictionary = (
		session.preview
		if not direct.is_empty() and session.phase == EditSession.Phase.PREVIEW
		else document.state
	)
	var item: Dictionary = DirectEditData.find(source, id_value, house)
	if item.is_empty():
		if direct.is_empty() and session.phase == EditSession.Phase.IDLE:
			if house:
				selected_buildings.clear()
			else:
				tools.selected.clear()
		return {}
	var p: Array = item["position"]
	var y: float = p[1] if house else p[1] + InstanceEdits.support_height(source, item, 0, _field)
	return {"item": item, "house": house, "id": id_value, "origin": Vector3(p[0], y, p[2])}


func begin_direct(kind: String, screen: Vector2) -> void:
	if (
		_busy()
		or not _intent.is_empty()
		or session.phase != EditSession.Phase.IDLE
		or not direct.is_empty()
	):
		return
	var subject: Dictionary = _subject()
	if (
		subject.is_empty()
		or kind not in ["move", "width", "depth", "height", "rotate", "scale", "copy"]
	):
		return
	if subject["house"] and kind in ["rotate", "scale"]:
		return
	if not subject["house"] and kind in ["width", "depth", "height"]:
		return
	if not session.begin_gesture():
		return
	var source: Dictionary = document.snapshot()
	var id_value: String = subject["id"]
	if kind == "copy":
		var copied: Dictionary = DirectEditData.clone(source, id_value, subject["house"])
		source = copied["source"]
		id_value = copied["id"]
	direct = {
		"kind": kind,
		"source": source,
		"original": subject["id"],
		"id": id_value,
		"house": subject["house"],
		"screen": screen,
		"origin": subject["origin"],
		"ground": _plane_point(screen, subject["origin"].y)
	}
	if kind == "copy":
		direct["ground"] = subject["origin"]
		if subject["house"]:
			selected_buildings.assign([id_value])
		else:
			tools.selected.assign([id_value])
	tools.mode = "inspect"
	hud.close_context()
	update_direct(screen)


func _plane_point(screen: Vector2, y: float) -> Variant:
	return Plane(Vector3.UP, y).intersects_ray(
		camera_rig.camera.project_ray_origin(screen), camera_rig.camera.project_ray_normal(screen)
	)


func update_direct(screen: Vector2) -> void:
	if direct.is_empty() or session.phase != EditSession.Phase.PREVIEW:
		return
	var kind: String = direct["kind"]
	var delta: Vector2 = screen - direct["screen"]
	var amount: Vector3 = Vector3.ZERO
	if kind in ["move", "copy"]:
		var point: Variant = _plane_point(screen, direct["origin"].y)
		if point is Vector3 and direct["ground"] is Vector3:
			amount = point - direct["ground"]
	elif kind in ["width", "depth", "height"]:
		var axis: Vector3 = {"width": Vector3.RIGHT, "depth": Vector3.BACK, "height": Vector3.UP}[kind]
		var pixel_axis: Vector2 = (
			camera_rig.camera.unproject_position(direct["origin"] + axis)
			- camera_rig.camera.unproject_position(direct["origin"])
		)
		amount.x = (
			delta.dot(pixel_axis)
			/ maxf(pixel_axis.length_squared(), 0.01)
			* (1 if kind == "height" else 2)
		)
	else:
		amount.x = delta.x * (0.015 if kind == "rotate" else 0.01)
	var draft: Dictionary = DirectEditData.transform(
		direct["source"], direct["id"], direct["house"], kind, amount
	)
	session.update_gesture(draft)
	_preview_token = queue.request(draft, Rect2(-24, -24, 48, 48))
	var error: String = WorldDocument.validate(draft)
	var value: Dictionary = DirectEditData.find(draft, direct["id"], direct["house"])
	hud.set_status(
		(
			_reason(error)
			if not error.is_empty()
			else (
				"复制预览：移动鼠标，左键放下，右键取消"
				if kind == "copy"
				else "拖动预览 · %s · 松手完成，右键取消" % str(value.get("size", value.get("position", [])))
			)
		)
	)


func finish_direct() -> void:
	if direct.is_empty():
		return
	var pending: Dictionary = direct
	direct = {}
	if session.preview == document.state:
		_cancel_edit()
		return
	_submit_async(session.preview, "直接调整" if pending["kind"] != "copy" else "复制对象")
	if session.phase == EditSession.Phase.IDLE and pending["kind"] == "copy":
		if pending["house"]:
			selected_buildings.assign([pending["original"]])
		else:
			tools.selected.assign([pending["original"]])


func _cancel_edit() -> void:
	if not direct.is_empty() and direct["kind"] == "copy":
		if direct["house"]:
			selected_buildings.assign([direct["original"]])
		else:
			tools.selected.assign([direct["original"]])
	direct = {}
	super._cancel_edit()


func _input(event: InputEvent) -> void:
	if session == null:
		return

	if (
		_suppress_left
		and event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and not event.pressed
	):
		_suppress_left = false
		get_viewport().set_input_as_handled()
		return
	if not direct.is_empty():
		if (
			event is InputEventMouseButton
			and event.button_index == MOUSE_BUTTON_RIGHT
			and event.pressed
		):
			_on_action(&"cancel")
		elif event is InputEventMouseMotion:
			update_direct(event.position)
		elif event.is_action_pressed("cancel_edit"):
			_on_action(&"cancel")
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if (
				(direct["kind"] == "copy" and event.pressed)
				or (direct["kind"] != "copy" and not event.pressed)
			):
				var hovered: Control = get_viewport().gui_get_hovered_control()
				if (
					hud.blocks_scene_at(event.position)
					or (hovered != null and not hud.direct_handles.is_ancestor_of(hovered))
				):
					_on_action(&"cancel")
				else:
					update_direct(event.position)
					finish_direct()
				_suppress_left = event.pressed
		get_viewport().set_input_as_handled()
		return
	super._input(event)


func _secondary_clicked(screen: Vector2) -> void:
	if hud.blocks_scene_at(screen):
		return
	if session.phase == EditSession.Phase.PREVIEW:
		_on_action(&"cancel")
	else:
		inspect_at(screen)


func inspect_at(screen: Vector2) -> void:
	if _busy() or not _intent.is_empty() or session.phase == EditSession.Phase.PENDING_COMMIT:
		return
	_on_action(&"select")
	tools.selected.clear()
	selected_buildings.clear()
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = screen
	super._unhandled_input(event)
	hud.close_context()


func _on_action(action: StringName) -> void:
	if tools == null:
		return
	if action in [&"direct_copy", &"direct_delete", &"finish_edit", &"erase_tool"]:
		if _busy() or session.phase == EditSession.Phase.PENDING_COMMIT:
			return
		if action == &"direct_copy":
			begin_direct("copy", get_viewport().get_mouse_position())
		elif action == &"direct_delete":
			_delete_subject()
		elif action == &"finish_edit":
			_on_action(&"cancel")
			selected_buildings.clear()
			tools.selected.clear()
			tools.mode = "inspect"
			hud.close_context()
		else:
			_cancel_edit()
			tools.mode = "smart_erase"
			hud.set_status("橡皮：点击小屋或手放物件删除；可撤销，右键返回修改")
		return
	super._on_action(action)
	if action == &"select":
		hud.close_context()
	if action in [&"bridge", &"stair"]:
		hud.set_status("拖出两端，松手完成；非法位置会保留原作品")


func _delete_subject() -> void:
	var subject: Dictionary = _subject()
	if subject.is_empty():
		return
	var draft: Dictionary = document.snapshot()
	if subject["house"]:
		BuildingEdits.remove(draft, [subject["id"]])
	else:
		for i: int in range(draft["instances"].size() - 1, -1, -1):
			if draft["instances"][i]["id"] == subject["id"]:
				draft["instances"].remove_at(i)
	_submit_async(DoorRules.reconcile(draft)["snapshot"], "删除对象")


func _unhandled_input(event: InputEvent) -> void:
	if _busy() or not _intent.is_empty():
		return
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and not event.alt_pressed
		and not event.shift_pressed
	):
		if event.pressed and tools.mode == "smart_erase":
			inspect_at(event.position)
			_delete_subject()
			tools.mode = "smart_erase"
			_suppress_left = true
			get_viewport().set_input_as_handled()
			return
		if tools.mode == "place_opening":
			var target: Dictionary = _wall_target(event.position)
			_opening_point = target.get("point")
			if target.is_empty():
				if _custom_drag:
					_cancel_edit()
				hud.set_status("请把门窗放到小屋墙面上")
				get_viewport().set_input_as_handled()
				return
			if event.pressed:
				_select_buildings([target["id"]])
	elif event is InputEventMouseMotion and tools.mode == "place_opening" and _custom_drag:
		_opening_point = _wall_target(event.position).get("point")
		if _opening_point == null:
			return
	var finish_structure: bool = (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and not event.pressed
		and _five_drag
		and tools.mode in ["bridge", "stair"]
	)
	super._unhandled_input(event)
	if finish_structure and session.phase == EditSession.Phase.PREVIEW:
		super._on_action(&"confirm_garden")


func _wall_target(screen: Vector2) -> Dictionary:
	var origin: Vector3 = camera_rig.camera.project_ray_origin(screen)
	var direction: Vector3 = camera_rig.camera.project_ray_normal(screen)
	var nearest: float = INF
	var result: Dictionary = {}
	for home: Dictionary in document.state["buildings"]:
		var p: Array = home["position"]
		var s: Array = home["size"]
		var hit: Variant = DirectEditData.wall_hit(home, origin, direction)
		if hit is Vector3 and hit.y < p[1] + s[1] - 0.02 and origin.distance_to(hit) < nearest:
			nearest = origin.distance_to(hit)
			result = {"id": home["id"], "point": hit}
	return result


func _update_custom(point: Vector3) -> void:
	super._update_custom(
		_opening_point if tools.mode == "place_opening" and _opening_point is Vector3 else point
	)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and session != null:
		if not direct.is_empty():
			_cancel_edit()


func _delivery_metrics() -> Dictionary:
	var result: Dictionary = super._delivery_metrics()
	result["ux02_direct_interface"] = true
	result["ribbon_categories"] = hud.ribbon_buttons.size()
	result["inspector_visible"] = hud.context.visible
	return result
