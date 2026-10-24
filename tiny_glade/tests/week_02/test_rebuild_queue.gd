extends GutTest

var queue: RebuildQueue
var released: Array[Dictionary] = []
var gate: Semaphore
var started: Semaphore


func before_each() -> void:
	queue = RebuildQueue.new()
	add_child_autofree(queue)
	released = []
	queue.batch_prepared.connect(
		func(token: int, payload: Dictionary, committed: bool) -> void:
			released.append({"token": token, "payload": payload, "committed": committed})
	)


func _wait_finished() -> void:
	for frame: int in range(600):
		if not queue.is_busy():
			return
		await get_tree().process_frame
	fail_test("worker did not finish within 600 frames")


static func _evaluate(snapshot: Dictionary) -> Dictionary:
	return {
		"ok": true,
		"value": snapshot["value"],
		"worker": OS.get_thread_caller_id() != OS.get_main_thread_id()
	}


func test_old_worker_cannot_overwrite_newest_commit_and_dirty_bounds_are_merged() -> void:
	gate = Semaphore.new()
	started = Semaphore.new()
	var worker_gate: Semaphore = gate
	var worker_started: Semaphore = started
	queue.evaluator = func(snapshot: Dictionary) -> Dictionary:
		if snapshot["value"] == 1:
			worker_started.post()
			worker_gate.wait()
		return _evaluate(snapshot)
	queue.request({"value": 1}, Rect2(0, 0, 2, 2))
	started.wait()
	queue.request({"value": 2}, Rect2(10, 0, 2, 2))
	var final_token: int = queue.request({"value": 3}, Rect2(20, 0, 2, 2), true)
	assert_eq(queue.dirty_bounds, Rect2(0, 0, 22, 2))
	assert_eq(queue.request({"value": 4}, Rect2(30, 0, 2, 2)), -1)
	gate.post()
	await _wait_finished()
	assert_eq(released.size(), 1)
	assert_eq(released[0]["token"], final_token)
	assert_eq(released[0]["payload"]["value"], 3)
	assert_true(released[0]["payload"]["worker"])
	assert_true(released[0]["committed"])
	assert_false(queue.commit_locked)
	assert_eq(queue.dirty_bounds.size, Vector2.ZERO)


func test_epoch_invalidates_in_flight_result_without_dropping_dirty_region() -> void:
	queue.evaluator = _evaluate
	queue.request({"value": 1}, Rect2(0, 0, 2, 2))
	queue.invalidate()
	await _wait_finished()
	assert_true(released.is_empty())
	assert_eq(queue.dirty_bounds, Rect2(0, 0, 2, 2))
	queue.request({"value": 2}, Rect2(10, 0, 2, 2))
	await _wait_finished()
	assert_eq(released.size(), 1)
	assert_eq(released[0]["payload"]["value"], 2)


func test_failed_core_preparation_unlocks_commit_and_retains_unpublished_dirty_area() -> void:
	queue.evaluator = func(_snapshot: Dictionary) -> Dictionary:
		return {"ok": false, "error": "injected core failure"}
	queue.request({}, Rect2(0, 0, 3, 3), true)
	await _wait_finished()
	assert_eq(released.size(), 1)
	assert_false(released[0]["payload"]["ok"])
	assert_false(queue.commit_locked)
	assert_eq(queue.dirty_bounds, Rect2(0, 0, 3, 3))


func test_signal_consumer_can_enqueue_next_request_without_losing_its_dirty_bounds() -> void:
	queue.evaluator = _evaluate
	queue.batch_prepared.connect(
		func(_token: int, payload: Dictionary, _commit: bool) -> void:
			if payload["value"] == 1:
				queue.request({"value": 2}, Rect2(10, 0, 2, 2))
	)
	queue.request({"value": 1}, Rect2(0, 0, 2, 2))
	await _wait_finished()
	assert_eq(released.size(), 2)
	assert_eq(released[1]["payload"]["value"], 2)
