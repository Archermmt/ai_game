class_name SaveService
extends Node
## One IO worker, immutable jobs, completion polled on the main thread.

signal completed(operation: String, result: Dictionary)
var directory: String = "user://week_08/saves"
var _thread: Thread
var _operation: String = ""


func is_busy() -> bool:
	return _thread != null


func request(
	operation: String,
	index: int = 0,
	snapshot: Dictionary = {},
	title: String = "",
	presentation: Dictionary = {}
) -> bool:
	if is_busy() or operation not in ["save", "load", "catalog"]:
		return false
	var source: Dictionary = snapshot.duplicate(true)
	var metadata: Dictionary = presentation.duplicate(true)
	var location: String = directory
	_operation = operation
	_thread = Thread.new()
	var error: Error = _thread.start(
		func() -> Dictionary:
			var start: int = Time.get_ticks_usec()
			var result: Dictionary
			if operation == "save":
				result = SlotStore.write_slot(location, index, source, title, metadata)
			elif operation == "load":
				result = SlotStore.read_slot(location, index)
				if result["ok"]:
					result["generated"] = LocalRebuild.evaluate(result["snapshot"], {})
			else:
				result = {"ok": true, "slots": SlotStore.catalog(location)}
			result["worker_ms"] = float(Time.get_ticks_usec() - start) / 1000
			return result
	)
	if error != OK:
		_thread = null
	return error == OK


func _process(_delta: float) -> void:
	if _thread == null or _thread.is_alive():
		return
	var result: Dictionary = _thread.wait_to_finish()
	_thread = null
	completed.emit(_operation, result)


func _exit_tree() -> void:
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null
