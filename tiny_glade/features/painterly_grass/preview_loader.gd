class_name PainterlyPreviewLoader
extends Node
## Typed adaptation of godot-project-foundations/scripts/async_resource_loader.gd.

signal loading_completed(resource: Resource)
signal loading_failed(path: String)
signal progress_updated(percent: float)
var _target_path: String = ""


func request_load(path: String) -> void:
	if not _target_path.is_empty():
		return
	if not ResourceLoader.exists(path):
		loading_failed.emit(path)
		return
	_target_path = path
	if ResourceLoader.load_threaded_request(path) != OK:
		_target_path = ""
		loading_failed.emit(path)
		return
	set_process(true)


func _process(_delta: float) -> void:
	if _target_path.is_empty():
		set_process(false)
		return
	var progress: Array = []
	var state: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(
		_target_path, progress
	)
	if state == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		progress_updated.emit(float(progress[0]) * 100)
	elif state == ResourceLoader.THREAD_LOAD_LOADED:
		var resource: Resource = ResourceLoader.load_threaded_get(_target_path)
		_target_path = ""
		loading_completed.emit(resource)
	elif state in [ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE]:
		var path: String = _target_path
		_target_path = ""
		loading_failed.emit(path)
