class_name WorldTools
extends RefCounted
## W02 common gesture state for terrain, pond and grey instance tools.

var session: EditSession
var mode: String = "prop"
var selected: Array[String] = []
var start: Vector3
var _visited: Dictionary = {}
var _before: Dictionary = {}
var _move_axis: Vector3 = Vector3.ONE
var _last_cell: Vector2i = Vector2i(99999, 99999)


func _init(edit_session: EditSession) -> void:
	session = edit_session


func begin(point: Vector3, additive: bool = false) -> bool:
	if session.phase != EditSession.Phase.IDLE:
		return false
	if mode == "select":
		var found: String = pick(point)
		if not additive:
			selected.clear()
		if not found.is_empty() and found not in selected:
			selected.append(found)
		return false
	if mode == "move" and selected.is_empty():
		var found: String = pick(point)
		if not found.is_empty():
			selected.append(found)
	if mode == "move" and selected.is_empty():
		return false
	if not session.begin_gesture():
		return false
	_before = session.document.snapshot()
	_move_axis = Vector3.ONE
	if mode == "move" and not selected.is_empty():
		for item: Dictionary in _before["instances"]:
			if item["id"] != selected[0]:
				continue
			var offset: Vector2 = Vector2(
				point.x - item["position"][0], point.z - item["position"][2]
			)
			if absf(offset.x) > 0.55 and absf(offset.y) < 0.18:
				_move_axis = Vector3.RIGHT
			elif absf(offset.y) > 0.55 and absf(offset.x) < 0.18:
				_move_axis = Vector3.BACK
	_visited.clear()
	_last_cell = Vector2i(99999, 99999)
	start = point
	update(point)
	return true


func update(point: Vector3) -> void:
	if session.phase != EditSession.Phase.PREVIEW:
		return
	var candidate: Dictionary = session.preview.duplicate(true)
	var location: Vector2 = Vector2(point.x, point.z)
	if mode in ["raise", "lower", "brush", "erase"]:
		var cell: Vector2i = Vector2i((location / 0.75).floor())
		if cell == _last_cell:
			return
		_last_cell = cell
		if mode in ["raise", "lower"]:
			candidate = TerrainField.brush(candidate, location, 0.35 if mode == "raise" else -0.35)
		else:
			InstanceEdits.brush(candidate, location, _visited, mode == "erase")
	elif mode == "pool":
		candidate = TerrainField.pond(
			_before,
			Vector2(start.x, start.z),
			clampf(Vector2(point.x - start.x, point.z - start.z).length(), 1.0, 10.0)
		)
	elif mode == "prop":
		candidate = _before.duplicate(true)
		InstanceEdits.allocate(candidate, Vector3(point.x, 0, point.z))
	elif mode == "move":
		candidate = _before.duplicate(true)
		InstanceEdits.transform_selection(candidate, selected, (point - start) * _move_axis)
	session.update_gesture(candidate)


func selection_action(action: String) -> Dictionary:
	var candidate: Dictionary = session.document.snapshot()
	if action == "delete_pool":
		candidate["pool"] = {}
	elif action == "copy":
		selected = InstanceEdits.duplicate_selection(candidate, selected)
	elif action == "delete":
		for index: int in range(candidate["instances"].size() - 1, -1, -1):
			if candidate["instances"][index]["id"] in selected:
				candidate["instances"].remove_at(index)
		selected.clear()
	else:
		InstanceEdits.transform_selection(
			candidate,
			selected,
			Vector3.ZERO,
			PI / 12.0 if action == "rotate" else 0.0,
			1.1 if action == "scale_up" else (1.0 / 1.1 if action == "scale_down" else 1.0)
		)
	return candidate


func pick(point: Vector3) -> String:
	var nearest: String = ""
	var distance: float = 1.2
	for item: Dictionary in session.document.state["instances"]:
		var p: Array = item["position"]
		var current: float = Vector2(point.x - p[0], point.z - p[2]).length()
		if current < distance:
			nearest = item["id"]
			distance = current
	return nearest


func has_changes() -> bool:
	return session.phase == EditSession.Phase.PREVIEW and session.preview != _before
