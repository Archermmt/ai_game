extends SceneTree
## Diagnostic only: retain both the pre-draw legacy benchmark and first-visible-input case.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var output: String = "reports/perf_01/phases.json"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--perf-report="):
			output = argument.trim_prefix("--perf-report=")
	var started: int = Time.get_ticks_usec()
	var scene: Node3D = load("res://app/hover_root.tscn").instantiate()
	scene.qa_mode = true
	root.add_child(scene)
	var initial_revision: int = scene.document.state["revision"]
	await RenderingServer.frame_post_draw
	var first_draw_usec: int = Time.get_ticks_usec()
	var first_draw_ms: float = float(first_draw_usec - started) / 1000.0
	var in_flight_at_first_draw: bool = scene._submitted_usec > 0
	if "--perf-visible-input" in OS.get_cmdline_user_args():
		scene._exercise_edits()
	var deadline: int = Time.get_ticks_msec() + 15000
	while scene._probe_edits < 20 and Time.get_ticks_msec() < deadline:
		await process_frame
	if (
		scene._probe_edits != 20
		or scene._commit_latencies.size() != 20
		or scene._phase_timings.size() != 20
		or scene.session.history_count() != 20
		or scene.document.state["revision"] != initial_revision + 20
	):
		push_error("Performance probe did not finish all 20 edits")
		quit(1)
		return
	var result: Dictionary = {
		"first_draw_ms": first_draw_ms,
		"submission_before_first_draw": scene._phase_timings[0]["submitted_usec"] < first_draw_usec,
		"commit_in_flight_at_first_draw": in_flight_at_first_draw,
		"warmup_edits": 0,
		"commits_ms": scene._commit_latencies.duplicate(),
		"metrics": scene._delivery_metrics(),
		"protocol":
		(
			"first_visible_input"
			if "--perf-visible-input" in OS.get_cmdline_user_args()
			else "legacy_pre_draw"
		)
	}
	var file: FileAccess = FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	scene._request_quit()
