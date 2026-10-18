class_name RebuildQueue
extends Node
## At most one worker and one merged pending request. Released commits are barriers.

signal batch_prepared(token: int, payload: Dictionary, committed: bool)

var evaluator: Callable = WorldRebuild.evaluate
var epoch: int = 0
var newest_token: int = 0
var dirty_bounds: Rect2 = Rect2()
var commit_locked: bool = false
var _active: bool = false
var _task: int = -1
var _pending: Dictionary = {}
var _closed: bool = false


func request(snapshot: Dictionary, bounds: Rect2, committed: bool = false) -> int:
	if _closed or commit_locked:
		return -1
	newest_token += 1
	dirty_bounds = bounds if dirty_bounds.size == Vector2.ZERO else dirty_bounds.merge(bounds)
	var job: Dictionary = {
		"snapshot": snapshot.duplicate(true),
		"token": newest_token,
		"epoch": epoch,
		"committed": committed
	}
	if committed:
		commit_locked = true
	if _active:
		_pending = job
	else:
		_start(job)
	return newest_token


func invalidate() -> void:
	epoch += 1
	newest_token += 1
	_pending.clear()
	commit_locked = false
	# Unpublished dirty bounds deliberately survive invalidation.


func is_busy() -> bool:
	return _active or not _pending.is_empty()


func _start(job: Dictionary) -> void:
	_active = true
	var work: Callable = evaluator
	_task = WorkerThreadPool.add_task(
		func() -> void:
			var data: Dictionary = work.call(job["snapshot"])
			_deliver.call_deferred(job, data),
		false,
		"World source evaluation"
	)


func _deliver(job: Dictionary, data: Dictionary) -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	_active = false
	if not _closed and job["epoch"] == epoch and job["token"] == newest_token:
		# Consumer must publish synchronously from this main-thread signal.
		if data.get("ok", false):
			dirty_bounds = Rect2()
		_active = true
		batch_prepared.emit(job["token"], data, job["committed"])
		_active = false
		if job["committed"]:
			commit_locked = false
	if not _closed and not _pending.is_empty():
		var next: Dictionary = _pending
		_pending = {}
		_start(next)


func _exit_tree() -> void:
	_closed = true
	invalidate()
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
