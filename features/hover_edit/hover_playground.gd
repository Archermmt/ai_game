extends "res://features/direct_edit/simple_playground.gd"
## Hover never changes selection or history. Only a handle press starts a transaction.

var hovered: Dictionary = {}
var surface_selected: Dictionary = {}
var surface_drag: Dictionary = {}
var _hover_signature: String = ""
var _pointer: Vector2 = Vector2(-1, -1)


func _ready() -> void:
	super._ready()
	if qa_mode:
		saves.directory = "user://qa_ux03_native"
	hud.set_status("移到屋顶、墙面、门窗或桥上 → 拖白色图标修改 · 松手完成 · Esc取消")


func _process(delta: float) -> void:
	var screen: Vector2 = _pointer if _pointer.x >= 0 else get_viewport().get_mouse_position()
	var retained: bool = hud.direct_handles != null and hud.direct_handles.contains(screen, 8)
	if hovered.get("family", "") in ["opening", "prop"]:
		retained = retained or hud.direct_handles.near_group(screen)
	super._process(delta)
	if session == null or hud.direct_handles == null:
		return
	var handles: SurfaceHandles = hud.direct_handles
	if not _can_hover():
		handles.clear()
		return
	var signature: String = str(
		[screen, camera_rig.camera.global_transform, document.state["revision"], tools.mode]
	)
	if signature != _hover_signature and direct.is_empty() and surface_drag.is_empty():
		_hover_signature = signature
		if not retained:
			refresh_hover(screen)
	var target: Dictionary = _display_target()
	if target.is_empty():
		handles.clear()
		return
	var source: Dictionary = (
		session.preview if session.phase == EditSession.Phase.PREVIEW else document.state
	)
	handles.show()
	handles.surface(
		source,
		target,
		camera_rig.camera,
		hud._scale_value,
		surface_drag.get("kind", direct.get("kind", ""))
	)
	if target["family"] in ["opening", "bridge", "stair"]:
		hud.special_actions(
			(
				not surface_selected.is_empty()
				and surface_drag.is_empty()
				and session.phase == EditSession.Phase.IDLE
			)
		)


func _can_hover() -> bool:
	return (
		not camera_rig._orbiting
		and not camera_rig._panning
		and not photo_active
		and not _busy()
		and _intent.is_empty()
		and not hud.settings.visible
		and not hud.library.visible
		and not hud.context.visible
		and session.phase != EditSession.Phase.PENDING_COMMIT
	)


func refresh_hover(screen: Vector2) -> void:
	if not _can_hover() or not surface_drag.is_empty() or not direct.is_empty():
		return
	if hud.direct_handles.contains(screen, 8):
		return
	if hud.blocks_scene_at(screen) or camera_rig._orbiting or camera_rig._panning:
		hovered = {}
		return
	var ray: Vector3 = camera_rig.camera.project_ray_origin(screen)
	var direction: Vector3 = camera_rig.camera.project_ray_normal(screen)
	hovered = SurfacePicker.pick(document.state, ray, direction)
	# Use the actual wrapper collision bounds for hand placed assets, including rotation.
	for id_value: String in _instance_views:
		for shape_node: CollisionShape3D in _instance_views[id_value].find_children(
			"*", "CollisionShape3D", true, false
		):
			if not shape_node.shape is BoxShape3D:
				continue
			var pose: Transform3D = shape_node.global_transform
			var inverse: Transform3D = pose.affine_inverse()
			var size_value: Vector3 = shape_node.shape.size
			var hit: Variant = AABB(-size_value * 0.5, size_value).intersects_ray(
				inverse * ray, inverse.basis * direction
			)
			if hit is Vector3 and ray.distance_to(pose * hit) < hovered.get("distance", INF):
				hovered = {
					"family": "prop",
					"id": id_value,
					"zone": "move",
					"point": pose * hit,
					"distance": ray.distance_to(pose * hit)
				}


func _display_target() -> Dictionary:
	if not surface_drag.is_empty():
		return surface_drag["target"]
	if not direct.is_empty():
		return {"family": "house" if direct["house"] else "prop", "id": direct["id"]}
	if not hovered.is_empty() and not SurfaceEditData.resolve(document.state, hovered).is_empty():
		return hovered
	if not surface_selected.is_empty():
		if SurfaceEditData.resolve(document.state, surface_selected).is_empty():
			surface_selected = {}
		return surface_selected
	var subject: Dictionary = _subject()
	return (
		{}
		if subject.is_empty()
		else {"family": "house" if subject["house"] else "prop", "id": subject["id"]}
	)


func _choose_surface(target: Dictionary) -> void:
	hovered = target.duplicate(true)
	surface_selected = (
		target.duplicate(true) if target["family"] in ["opening", "bridge", "stair"] else {}
	)
	selected_buildings.clear()
	tools.selected.clear()
	if target["family"] == "house":
		selected_buildings.assign([target["id"]])
	elif target["family"] == "prop":
		tools.selected.assign([target["id"]])
	tools.mode = "inspect"
	hud.set_active_tool("inspect")
	hud.close_context()


func begin_direct(kind: String, screen: Vector2) -> void:
	if not _can_hover() or session.phase != EditSession.Phase.IDLE:
		return
	var target: Dictionary = _display_target()
	if target.is_empty():
		return
	_choose_surface(target)
	if target["family"] in ["house", "prop"] and kind != "roof":
		super.begin_direct(kind, screen)
		return
	if kind not in ["roof", "move", "width", "height", "end_a", "end_b"]:
		return
	if not session.begin_gesture():
		return
	var origin: Vector3 = SurfaceEditData.origin(document.state, target)
	surface_drag = {
		"target": target.duplicate(true),
		"kind": kind,
		"source": document.snapshot(),
		"screen": screen,
		"origin": origin,
		"ground": _plane_point(screen, origin.y)
	}
	if target["family"] == "opening":
		var home: Dictionary = DirectEditData.find(document.state, target["parent"], true)
		var item: Dictionary = SurfaceEditData.resolve(document.state, target)
		var normal: Vector3 = BuildingGeometry._normal(
			item["center"] * DoorRules._length(home, item.get("facade", 0)),
			item.get("facade", 0),
			home["size"][0],
			home["size"][2],
			home["shape"] == "round"
		)
		surface_drag["normal"] = normal
	update_surface(screen)


func update_surface(screen: Vector2) -> void:
	if surface_drag.is_empty() or session.phase != EditSession.Phase.PREVIEW:
		return
	var drag: Dictionary = surface_drag
	var amount: Vector3 = Vector3.ZERO
	var delta: Vector2 = screen - drag["screen"]
	if drag["kind"] in ["move", "end_a", "end_b"]:
		if drag.has("normal"):
			var plane: Plane = Plane(drag["normal"], drag["origin"])
			var start: Variant = plane.intersects_ray(
				camera_rig.camera.project_ray_origin(drag["screen"]),
				camera_rig.camera.project_ray_normal(drag["screen"])
			)
			var end: Variant = plane.intersects_ray(
				camera_rig.camera.project_ray_origin(screen),
				camera_rig.camera.project_ray_normal(screen)
			)
			if start is Vector3 and end is Vector3:
				amount = end - start
		else:
			var point: Variant = _plane_point(screen, drag["origin"].y)
			if point is Vector3 and drag["ground"] is Vector3:
				amount = point - drag["ground"]
	else:
		var axis: Vector3 = Vector3.UP
		if drag["kind"] == "width":
			axis = (
				Vector3(drag["normal"].z, 0, -drag["normal"].x)
				if drag.has("normal")
				else SurfaceEditData.width_axis(drag["source"], drag["target"])
			)
		var pixel_axis: Vector2 = (
			camera_rig.camera.unproject_position(drag["origin"] + axis)
			- camera_rig.camera.unproject_position(drag["origin"])
		)
		amount.x = (
			delta.dot(pixel_axis)
			/ maxf(pixel_axis.length_squared(), 0.01)
			* (2 if drag["kind"] == "width" else 1)
		)
	var draft: Dictionary = SurfaceEditData.transform(
		drag["source"], drag["target"], drag["kind"], amount
	)
	session.update_gesture(draft)
	_preview_token = queue.request(draft, Rect2(-24, -24, 48, 48))
	var issue: String = SurfaceEditData.issue(drag["source"], draft)
	hud.set_status(_reason(issue) if not issue.is_empty() else "拖动预览 · 松手完成 · 右键/Esc取消")


func finish_surface() -> void:
	if surface_drag.is_empty():
		return
	var pending: Dictionary = surface_drag
	surface_drag = {}
	if session.preview == document.state:
		_cancel_edit()
		return
	var issue: String = SurfaceEditData.issue(pending["source"], session.preview)
	if not issue.is_empty():
		_cancel_edit()
		hud.set_status(_reason(issue))
		return
	var item: Dictionary = SurfaceEditData.resolve(session.preview, pending["target"])
	if pending["target"]["family"] == "opening" and item.has("attachment_id"):
		surface_selected["attachment_id"] = item["attachment_id"]
		hovered = surface_selected.duplicate(true)
	_submit_async(session.preview, "表面拖拽修改")


func _cancel_edit() -> void:
	surface_drag = {}
	super._cancel_edit()


func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		_pointer = event.position
	if (
		surface_drag.is_empty()
		and direct.is_empty()
		and event is InputEventMouseButton
		and event.pressed
		and (event.alt_pressed or event.shift_pressed)
	):
		hud.direct_handles.clear()
	if not surface_drag.is_empty():
		if (
			event.is_action_pressed("cancel_edit")
			or (
				event is InputEventMouseButton
				and event.button_index == MOUSE_BUTTON_RIGHT
				and event.pressed
			)
		):
			_cancel_edit()
		elif event is InputEventMouseMotion:
			update_surface(event.position)
		elif (
			event is InputEventMouseButton
			and event.button_index == MOUSE_BUTTON_LEFT
			and not event.pressed
		):
			if hud.blocks_scene_at(event.position):
				_cancel_edit()
			else:
				update_surface(event.position)
				finish_surface()
		get_viewport().set_input_as_handled()
		return
	super._input(event)


func inspect_at(screen: Vector2) -> void:
	if not _can_hover() or session.phase != EditSession.Phase.IDLE:
		return
	hovered = {}
	refresh_hover(screen)
	if not hovered.is_empty():
		_choose_surface(hovered)
	else:
		surface_selected = {}
		super.inspect_at(screen)


func _unhandled_input(event: InputEvent) -> void:
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
		and not event.alt_pressed
		and not event.shift_pressed
		and tools.mode == "inspect"
	):
		inspect_at(event.position)
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)


func _on_action(action: StringName) -> void:
	if not surface_drag.is_empty():
		if action == &"cancel":
			_cancel_edit()
		return
	if (
		action == &"direct_delete"
		and not surface_selected.is_empty()
		and surface_selected["family"] in ["opening", "bridge", "stair"]
	):
		if _busy() or session.phase != EditSession.Phase.IDLE:
			return
		var draft: Dictionary = document.snapshot()
		var item: Dictionary = SurfaceEditData.resolve(draft, surface_selected)
		if surface_selected["family"] == "opening":
			if item.get("source", "") == "auto_path":
				hud.set_status("此门由路径生成；移动或调整后转为手工门，或修改供门路径")
				return
			DirectEditData.find(draft, surface_selected["parent"], true)["openings"].erase(item)
		else:
			draft["bridges" if surface_selected["family"] == "bridge" else "stairs"].erase(item)
		_submit_async(DoorRules.reconcile(draft)["snapshot"], "删除选中结构")
		surface_selected = {}
		hovered = {}
		return
	if (
		action in [&"finish_edit", &"select", &"undo", &"redo", &"empty", &"demo"]
		or (
			action not in [&"photography", &"direct_copy", &"direct_delete"]
			and session != null
			and session.phase == EditSession.Phase.IDLE
		)
	):
		surface_selected = {}
		hovered = {}
	super._on_action(action)


func _notification(what: int) -> void:
	super._notification(what)
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and session != null and not surface_drag.is_empty():
		_cancel_edit()


func _delivery_metrics() -> Dictionary:
	var result: Dictionary = super._delivery_metrics()
	result["ux03_hover_interface"] = true
	return result
