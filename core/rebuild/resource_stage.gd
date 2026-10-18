class_name ResourceStage
extends Node
## Main-thread-only incremental preparation. No candidate is visible before completion.

signal completed(token: int, payload: Dictionary)

var budget_usec: int = 1800
var slices_ms: Array[float] = []
var token: int = -1
var _jobs: Array[Callable] = []
var _payload: Dictionary = {}
var _running: bool = false
var _owned: Array[Node] = []


func begin(next_token: int, jobs: Array[Callable], payload: Dictionary) -> void:
	cancel()
	token = next_token
	_jobs = jobs
	_payload = payload
	_running = true


func own(node: Node) -> Node:
	_owned.append(node)
	return node


func cancel() -> void:
	for node: Node in _owned:
		if is_instance_valid(node) and node.get_parent() == null:
			node.free()
	_owned.clear()
	_jobs.clear()
	_payload.clear()
	_running = false


func is_busy() -> bool:
	return _running


func _process(_delta: float) -> void:
	if not _running:
		return
	var start: int = Time.get_ticks_usec()
	while not _jobs.is_empty():
		var job: Callable = _jobs.pop_front()
		job.call()
		if Time.get_ticks_usec() - start >= budget_usec:
			break
	slices_ms.append(float(Time.get_ticks_usec() - start) / 1000)
	if _jobs.is_empty():
		_running = false
		_owned.clear()
		completed.emit(token, _payload)
		_payload = {}


func _exit_tree() -> void:
	cancel()
