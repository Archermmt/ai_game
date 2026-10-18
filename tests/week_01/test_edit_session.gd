extends GutTest

var session: EditSession
var publications: int = 0


func before_each() -> void:
	session = EditSession.new(WorldDocument.new())
	publications = 0
	session.state_published.connect(
		func(_state: Dictionary, _payload: Dictionary) -> void: publications += 1
	)


func after_each() -> void:
	session.dispose()
	session = null


func _candidate() -> Dictionary:
	var draft: Dictionary = session.document.snapshot()
	WorldDocument.allocate_building(draft, Vector3.ZERO, Vector3(4, 3, 4))
	return draft


func test_initial_publication_does_not_execute_do_twice() -> void:
	assert_true(session.commit_snapshot(_candidate(), "build")["ok"])
	assert_eq(publications, 1)
	assert_eq(session.history_count(), 1)
	assert_eq(session.document.state["buildings"].size(), 1)


func test_preview_and_cancel_do_not_touch_live_state_or_identity() -> void:
	assert_true(session.begin_gesture())
	assert_true(session.update_gesture(_candidate()))
	assert_eq(session.document.state["buildings"].size(), 0)
	session.cancel_gesture()
	assert_eq(session.history_count(), 0)
	assert_eq(session.document.state["next_id"], 1)


func test_one_gesture_is_one_history_entry() -> void:
	session.begin_gesture()
	for index: int in range(20):
		var candidate: Dictionary = _candidate()
		candidate["buildings"][0]["size"][0] = 3.0 + float(index) * 0.1
		session.update_gesture(candidate)
	assert_true(session.release_gesture("drag")["ok"])
	assert_eq(session.history_count(), 1)


func test_failed_preparation_does_not_publish_or_advance_history() -> void:
	var before: Dictionary = session.document.snapshot()
	var failed: Callable = func(_draft: Dictionary) -> Dictionary:
		return {"ok": false, "error": "injected"}
	assert_false(session.commit_snapshot(_candidate(), "bad", failed)["ok"])
	assert_eq(session.document.state, before)
	assert_eq(session.history_count(), 0)
	assert_eq(publications, 0)


func test_failed_undo_keeps_cursor_then_successful_undo_redo_restores_identity() -> void:
	session.commit_snapshot(_candidate(), "build")
	var identity: String = session.document.state["buildings"][0]["id"]
	var failed: Callable = func(_draft: Dictionary) -> Dictionary: return {"ok": false}
	assert_false(session.request_undo(failed)["ok"])
	assert_eq(session.history_count(), 1)
	assert_true(session.request_undo()["ok"])
	assert_eq(session.document.state["buildings"].size(), 0)
	assert_true(session.request_redo()["ok"])
	assert_eq(session.document.state["buildings"][0]["id"], identity)


func test_stale_candidates_are_not_rebased_silently() -> void:
	var stale: Dictionary = _candidate()
	session.commit_snapshot(_candidate(), "first")
	assert_eq(session.commit_snapshot(stale, "stale")["error"], "stale_candidate")
	assert_eq(session.history_count(), 1)


func test_pending_commit_refuses_reentrant_second_gesture() -> void:
	var prepare: Callable = func(_state: Dictionary) -> Dictionary:
		assert_eq(session.phase, EditSession.Phase.PENDING_COMMIT)
		assert_false(session.begin_gesture())
		return {"ok": true}
	assert_true(session.commit_snapshot(_candidate(), "first", prepare)["ok"])
	assert_eq(session.phase, EditSession.Phase.IDLE)


func test_fifty_actions_undo_redo_and_branch_truncation() -> void:
	for index: int in range(50):
		var draft: Dictionary = session.document.snapshot()
		draft["terrain"]["height_deltas"].append([index, 0, float(index) * 0.1])
		assert_true(session.commit_snapshot(draft, "brush")["ok"])
	for index: int in range(50):
		assert_true(session.request_undo()["ok"])
	assert_eq(session.document.state["terrain"]["height_deltas"].size(), 0)
	for index: int in range(50):
		assert_true(session.request_redo()["ok"])
	assert_eq(session.document.state["terrain"]["height_deltas"].size(), 50)
	session.request_undo()
	session.commit_snapshot(session.document.snapshot(), "branch")
	assert_false(session.request_redo()["ok"])


func test_invalid_load_preserves_world_and_history() -> void:
	session.commit_snapshot(_candidate(), "build")
	var before: Dictionary = session.document.snapshot()
	assert_false(session.replace_document({})["ok"])
	assert_eq(session.document.state, before)
	assert_eq(session.history_count(), 1)
