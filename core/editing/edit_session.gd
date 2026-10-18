class_name EditSession
extends RefCounted
## Session-local transactions. Only a fully prepared candidate may be published.

signal state_published(snapshot: Dictionary, prepared: Dictionary)

enum Phase { IDLE, PREVIEW, PENDING_COMMIT }

const MAX_SOURCE_BYTES: int = 1048576

var document: WorldDocument
var phase: Phase = Phase.IDLE
var preview: Dictionary = {}
var _history: UndoRedo = UndoRedo.new()
var _commands: Array[Dictionary] = []
var _cursor: int = 0
var _prepared_snapshot: Dictionary = {}
var _prepared_payload: Dictionary = {}
var _pending_candidate: Dictionary = {}
var _pending_label: String = ""


func _init(source: WorldDocument) -> void:
	document = source
	_history.max_steps = 50


func begin_gesture() -> bool:
	if phase != Phase.IDLE:
		return false
	phase = Phase.PREVIEW
	preview = document.snapshot()
	return true


func update_gesture(candidate: Dictionary) -> bool:
	if phase != Phase.PREVIEW:
		return false
	preview = candidate.duplicate(true)
	return true


func cancel_gesture() -> void:
	preview.clear()
	_pending_candidate.clear()
	phase = Phase.IDLE


func reserve_commit(candidate: Dictionary, label: String) -> Dictionary:
	if phase == Phase.PENDING_COMMIT:
		return {"ok": false, "error": "busy"}
	if int(candidate.get("revision", -1)) != int(document.state["revision"]):
		return {"ok": false, "error": "stale_candidate"}
	var error: String = WorldDocument.validate(candidate)
	if error.is_empty():
		error = GardenStructures.transition_error(document.state, candidate)
	if not error.is_empty():
		cancel_gesture()
		return {"ok": false, "error": error}
	_pending_candidate = candidate.duplicate(true)
	_pending_label = label
	preview = {}
	phase = Phase.PENDING_COMMIT
	return {"ok": true}


func finish_reserved(prepared: Dictionary) -> Dictionary:
	if phase != Phase.PENDING_COMMIT:
		return {"ok": false, "error": "no_pending_commit"}
	var candidate: Dictionary = _pending_candidate
	var label: String = _pending_label
	_pending_candidate = {}
	phase = Phase.IDLE
	if not prepared.get("ok", false):
		return prepared
	return commit_snapshot(
		candidate, label, func(_snapshot: Dictionary) -> Dictionary: return prepared
	)


func finish_prepared(payload: Dictionary) -> Dictionary:
	# Reserved source is an immutable validated copy; worker must return that exact source.
	if phase != Phase.PENDING_COMMIT:
		return {"ok": false, "error": "no_pending_commit"}
	var candidate: Dictionary = _pending_candidate
	var label: String = _pending_label
	if not payload.get("ok", false) or payload.get("source", {}) != candidate:
		cancel_gesture()
		return {"ok": false, "error": "prepared_source_mismatch"}
	if candidate["revision"] != document.state["revision"]:
		cancel_gesture()
		return {"ok": false, "error": "stale_candidate"}
	if JSON.stringify(candidate, "", true, true).to_utf8_buffer().size() > MAX_SOURCE_BYTES:
		cancel_gesture()
		return {"ok": false, "error": "history_source_budget"}
	var before: Dictionary = document.snapshot()
	_prepared_snapshot = candidate.duplicate(true)
	_prepared_snapshot["revision"] = before["revision"] + 1
	_prepared_payload = payload
	var after: Dictionary = _prepared_snapshot.duplicate(true)
	_pending_candidate = {}
	_publish_prepared()
	_commands = _commands.slice(0, _cursor)
	_commands.append({"before": before, "after": after})
	_cursor += 1
	if _commands.size() > 50:
		_commands.pop_front()
		_cursor -= 1
	_history.create_action(label)
	_history.add_do_method(_publish_prepared)
	_history.add_undo_method(_publish_prepared)
	_history.commit_action(false)
	return {"ok": true}


func release_gesture(label: String, prepare: Callable = Callable()) -> Dictionary:
	if phase != Phase.PREVIEW:
		return {"ok": false, "error": "no_gesture"}
	var candidate: Dictionary = preview.duplicate(true)
	phase = Phase.IDLE
	preview.clear()
	return commit_snapshot(candidate, label, prepare)


func commit_snapshot(
	candidate: Dictionary, label: String, prepare: Callable = Callable()
) -> Dictionary:
	if phase != Phase.IDLE:
		return {"ok": false, "error": "busy"}
	var before: Dictionary = document.snapshot()
	var structural_error: String = WorldDocument.validate(candidate)
	if structural_error.is_empty():
		structural_error = GardenStructures.transition_error(before, candidate)
	if not structural_error.is_empty():
		return {"ok": false, "error": structural_error}
	if int(candidate.get("revision", -1)) != int(before["revision"]):
		return {"ok": false, "error": "stale_candidate"}
	var result: Dictionary = _prepare(candidate, prepare)
	if not result["ok"]:
		return result
	var after: Dictionary = _prepared_snapshot.duplicate(true)
	_publish_prepared()
	_commands = _commands.slice(0, _cursor)
	_commands.append({"before": before, "after": after})
	_cursor += 1
	if _commands.size() > 50:
		_commands.pop_front()
		_cursor -= 1
	_history.create_action(label)
	_history.add_do_method(_publish_prepared)
	_history.add_undo_method(_publish_prepared)
	_history.commit_action(false)
	return {"ok": true}


func request_undo(prepare: Callable = Callable()) -> Dictionary:
	if phase != Phase.IDLE or _cursor == 0:
		return {"ok": false, "error": "no_undo"}
	var result: Dictionary = _prepare(_commands[_cursor - 1]["before"], prepare)
	if result["ok"]:
		_history.undo()
		_cursor -= 1
	return result


func request_redo(prepare: Callable = Callable()) -> Dictionary:
	if phase != Phase.IDLE or _cursor >= _commands.size():
		return {"ok": false, "error": "no_redo"}
	var result: Dictionary = _prepare(_commands[_cursor]["after"], prepare)
	if result["ok"]:
		_history.redo()
		_cursor += 1
	return result


func replace_document(candidate: Dictionary, prepare: Callable = Callable()) -> Dictionary:
	if phase != Phase.IDLE:
		return {"ok": false, "error": "busy"}
	var result: Dictionary = _prepare(candidate, prepare)
	if result["ok"]:
		_publish_prepared()
		_history.clear_history()
		_commands.clear()
		_cursor = 0
	return result


func history_count() -> int:
	return _cursor


func dispose() -> void:
	# UndoRedo holds callback references: explicitly release them at session teardown.
	if _history != null:
		_history.clear_history()
		_history.free()
		_history = null
	_commands.clear()
	preview.clear()


func _prepare(candidate: Dictionary, prepare: Callable) -> Dictionary:
	# 50 commands, two snapshots each: bounded to 100 MiB of serialized source.
	if JSON.stringify(candidate, "", true, true).to_utf8_buffer().size() > MAX_SOURCE_BYTES:
		return {"ok": false, "error": "history_source_budget"}
	var validation: String = WorldDocument.validate(candidate)
	if not validation.is_empty():
		return {"ok": false, "error": validation}
	phase = Phase.PENDING_COMMIT
	var next: Dictionary = candidate.duplicate(true)
	next["revision"] = int(document.state["revision"]) + 1
	var payload: Dictionary = {"ok": true}
	if prepare.is_valid():
		payload = prepare.call(next)
	if not payload.get("ok", false):
		phase = Phase.IDLE
		return payload
	_prepared_snapshot = next
	_prepared_payload = payload
	return {"ok": true}


func _publish_prepared() -> void:
	document.state = _prepared_snapshot.duplicate(true)
	phase = Phase.IDLE
	state_published.emit(document.snapshot(), _prepared_payload)
	_prepared_payload = {}
	_prepared_snapshot = {}
