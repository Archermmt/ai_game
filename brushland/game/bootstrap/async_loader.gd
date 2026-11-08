extends Node
## Scene-local adaptation of the foundations skill's async_resource_loader.
signal completed(resource:Resource)
signal failed(path:String)
signal progress_changed(percent:float)
var target=""
func request(path:String) -> void:
	target=path
	if ResourceLoader.load_threaded_request(path,"PackedScene",false)!=OK:failed.emit(path);target=""
func _process(_delta:float) -> void:
	if target.is_empty():return
	var progress:Array=[];var status=ResourceLoader.load_threaded_get_status(target,progress)
	if status==ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		if not progress.is_empty():progress_changed.emit(progress[0]*100)
	elif status==ResourceLoader.THREAD_LOAD_LOADED:
		var resource=ResourceLoader.load_threaded_get(target);target="";completed.emit(resource)
	elif status in [ResourceLoader.THREAD_LOAD_FAILED,ResourceLoader.THREAD_LOAD_INVALID_RESOURCE]:
		var path=target;target="";failed.emit(path)
