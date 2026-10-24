extends SceneTree
## Independent real-GUI diagnostic. The legacy terrain benchmark remains unchanged.
## frame_post_draw observes Godot rendering completion, not physical display scanout.

const EDIT_COUNT: int = 20
const TIMEOUT_MS: int = 15000

var playground: Node3D
var output: String = "reports/perf_02/visible_input.json"
var started_usec: int = 0
var first_draw_usec: int = 0
var first_input_usec: int = 0
var first_grass_quiet_usec: int = 0
var last_draw_usec: int = 0
var frame_intervals_ms: Array[float] = []
var samples: Array[Dictionary] = []
var current: Dictionary = {}
var target_id: String = ""
var failed: bool = false
var discovery: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _require(value: bool, reason: String) -> bool:
	if not value:
		failed = true
		push_error("PERF02 visible-input: " + reason)
		quit(1)
	return value


func _on_draw() -> void:
	var now: int = Time.get_ticks_usec()
	if first_draw_usec == 0:
		first_draw_usec = now
	if last_draw_usec > 0:
		frame_intervals_ms.append(float(now - last_draw_usec) / 1000.0)
	last_draw_usec = now
	if playground == null or playground.meadow == null:
		return
	var grass_quiet: bool = (
		not playground.meadow.is_busy() and playground.meadow._pending.is_empty()
	)
	if grass_quiet and first_grass_quiet_usec == 0:
		first_grass_quiet_usec = now
	if current.is_empty() or current["publish_usec"] == 0:
		return
	if int(playground.document.state["revision"]) != int(current["revision_after"]):
		return
	if current["draw_usec"] == 0:
		current["draw_usec"] = now
	if grass_quiet and current["grass_settle_draw_usec"] == 0:
		current["grass_settle_draw_usec"] = now
		current["grass_visible"] = playground.meadow.visible_count()
		current["grass_total"] = playground.meadow.total


func _on_published(snapshot: Dictionary, _prepared: Dictionary) -> void:
	if current.is_empty():
		return
	current["publication_count"] += 1
	current["publish_usec"] = Time.get_ticks_usec()
	current["revision_after"] = int(snapshot["revision"])
	current["meadow_token_at_publish"] = playground.meadow._token


func _motion(point: Vector2, relative: Vector2 = Vector2.ZERO, held: bool = false) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	Input.parse_input_event(event)
	await process_frame
	await RenderingServer.frame_post_draw


func _mouse(point: Vector2, pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(event)
	await process_frame
	await RenderingServer.frame_post_draw


func _roof_screen(home: Dictionary) -> Vector2:
	var p: Array = home["position"]
	var size: Array = home["size"]
	return playground.camera_rig.camera.unproject_position(
		Vector3(p[0] + size[0] * 0.22, p[1] + size[1] + RoofProfile.rise(home) * 0.6, p[2])
	)


func _find_roof() -> bool:
	var candidates: Array[Dictionary] = []
	var center: Vector2 = Vector2(root.size) * 0.5
	for home: Dictionary in playground.document.state["buildings"]:
		if not target_id.is_empty() and home["id"] != target_id:
			continue
		var screen: Vector2 = _roof_screen(home)
		if Rect2(Vector2(32, 32), Vector2(root.size) - Vector2(64, 180)).has_point(screen):
			candidates.append(
				{"home": home, "screen": screen, "distance": screen.distance_to(center)}
			)
	candidates.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool: return a.distance < b.distance
	)
	for candidate: Dictionary in candidates:
		if current["motion_usec"] == 0:
			current["motion_usec"] = Time.get_ticks_usec()
			if first_input_usec == 0:
				first_input_usec = current["motion_usec"]
		await _motion(candidate["screen"])
		var deadline: int = Time.get_ticks_msec() + 250
		while not _roof_ready(candidate["home"]["id"]) and Time.get_ticks_msec() < deadline:
			await process_frame
			await RenderingServer.frame_post_draw
		discovery.append(
			{
				"index": current["index"],
				"id": candidate["home"]["id"],
				"screen": str(candidate["screen"]),
				"pointer": str(playground._pointer),
				"hovered": playground.hovered.duplicate(true),
				"handle_visible":
				playground.hud.direct_handles.handles["roof"].is_visible_in_tree(),
				"can_hover": playground._can_hover(),
				"blocked": playground.hud.blocks_scene_at(candidate["screen"])
			}
		)
		if "--perf-debug-input" in OS.get_cmdline_user_args():
			print("PERF02_DISCOVERY ", JSON.stringify(discovery.back()))
		if _roof_ready(candidate["home"]["id"]):
			target_id = candidate["home"]["id"]
			return true
	root.get_texture().get_image().save_png(output.trim_suffix(".json") + "_discovery.png")
	return _require(false, "No visible roof could be reached by pointer input")


func _roof_ready(id_value: String) -> bool:
	var hovered: Dictionary = playground.hovered
	return (
		hovered.get("family", "") == "house"
		and hovered.get("zone", "") == "roof"
		and hovered.get("id", "") == id_value
		and playground.hud.direct_handles.handles["roof"].is_visible_in_tree()
	)


func _measure_edit(index: int) -> bool:
	current = {
		"index": index,
		"revision_before": int(playground.document.state["revision"]),
		"history_before": playground.session.history_count(),
		"motion_usec": 0,
		"press_usec": 0,
		"change_usec": 0,
		"release_usec": 0,
		"publish_usec": 0,
		"draw_usec": 0,
		"grass_settle_draw_usec": 0,
		"publication_count": 0,
		"grass_busy_at_input": playground.meadow.is_busy(),
		"meadow_token_at_input": playground.meadow._token
	}
	if not await _find_roof():
		return false
	var home: Dictionary = DirectEditData.find(playground.document.state, target_id, true)
	var before_rise: float = RoofProfile.rise(home)
	var handle: Control = playground.hud.direct_handles.handles["roof"]
	var start: Vector2 = handle.get_global_rect().get_center()
	await _motion(start)
	current["press_usec"] = Time.get_ticks_usec()
	await _mouse(start, true)
	if not _require(
		not playground.surface_drag.is_empty(), "GUI roof handle did not capture press"
	):
		return false
	var delta: Vector2 = Vector2(0, -12 if index % 2 == 0 else 12)
	current["change_usec"] = Time.get_ticks_usec()
	await _motion(start + delta, delta, true)
	current["release_usec"] = Time.get_ticks_usec()
	await _mouse(start + delta, false)
	var deadline: int = Time.get_ticks_msec() + TIMEOUT_MS
	while current["grass_settle_draw_usec"] == 0 and Time.get_ticks_msec() < deadline:
		await process_frame
	if not _require(
		current["grass_settle_draw_usec"] > 0, "Committed frame/grass settle timed out"
	):
		return false
	var after: Dictionary = DirectEditData.find(playground.document.state, target_id, true)
	if not _require(
		(
			current["publication_count"] == 1
			and current["revision_after"] == current["revision_before"] + 1
			and playground.session.history_count() == current["history_before"] + 1
			and not is_equal_approx(before_rise, RoofProfile.rise(after))
		),
		"Each actual drag must publish exactly one changed roof and one undo entry"
	):
		return false
	current["roof_before"] = before_rise
	current["roof_after"] = RoofProfile.rise(after)
	current["target_id"] = target_id
	for beginning: String in ["motion", "press", "change", "release"]:
		for ending: String in ["publish", "draw", "grass_settle_draw"]:
			current[beginning + "_to_" + ending + "_ms"] = (
				float(current[ending + "_usec"] - current[beginning + "_usec"]) / 1000.0
			)
	samples.append(current.duplicate(true))
	current = {}
	return true


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--perf-report="):
			output = argument.trim_prefix("--perf-report=")
	if not _require(
		"--edit-benchmark" not in OS.get_cmdline_user_args(), "Legacy edits must run separately"
	):
		return
	started_usec = Time.get_ticks_usec()
	RenderingServer.frame_post_draw.connect(_on_draw)
	playground = load("res://app/hover_root.tscn").instantiate()
	playground.qa_mode = true
	root.add_child(playground)
	playground.session.state_published.connect(_on_published)
	var initial_revision: int = int(playground.document.state["revision"])
	var initial_history: int = playground.session.history_count()
	await RenderingServer.frame_post_draw
	for index: int in range(EDIT_COUNT):
		if not await _measure_edit(index):
			return
	if not _require(
		(
			samples.size() == EDIT_COUNT
			and int(playground.document.state["revision"]) == initial_revision + EDIT_COUNT
			and playground.session.history_count() == initial_history + EDIT_COUNT
		),
		"Missing successful edits, first rendered revisions, or undo entries"
	):
		return
	var summary: Dictionary = {}
	for beginning: String in ["motion", "press", "change", "release"]:
		for ending: String in ["publish", "draw", "grass_settle_draw"]:
			var key: String = beginning + "_to_" + ending + "_ms"
			var values: Array[float] = []
			for sample: Dictionary in samples:
				values.append(sample[key])
			summary[key] = {"p95": PerformanceSamples.percentile(values), "max": values.max()}
	var result: Dictionary = {
		"protocol": "first_visible_real_gui_roof_input",
		"render_completion_note": "Godot frame_post_draw; not physical scanout or GPU timing",
		"warmup_edits": 0,
		"initial_grass_wait": false,
		"wait_for_grass_between_edits": true,
		"legacy_terrain_probe_replaced": false,
		"started_usec": started_usec,
		"first_draw_usec": first_draw_usec,
		"first_input_usec": first_input_usec,
		"startup_first_draw_ms": float(first_draw_usec - started_usec) / 1000.0,
		"first_draw_to_input_ms": float(first_input_usec - first_draw_usec) / 1000.0,
		"first_grass_quiet_usec": first_grass_quiet_usec,
		"initial_grass_quiet_before_input":
		first_grass_quiet_usec > 0 and first_grass_quiet_usec <= first_input_usec,
		"samples": samples,
		"discovery": discovery,
		"summary": summary,
		"render_frame_intervals_ms": frame_intervals_ms,
		"render_frame_interval_p95_ms": PerformanceSamples.percentile(frame_intervals_ms),
		"render_frame_interval_max_ms": frame_intervals_ms.max(),
		"runtime_metrics": playground._delivery_metrics(),
		"viewport_size": [root.size.x, root.size.y],
		"buildings": playground.document.state["buildings"].size(),
		"instances": playground.document.state["instances"].size(),
		"functional_passed": not failed
	}
	var file: FileAccess = FileAccess.open(output, FileAccess.WRITE)
	if not _require(file != null, "Cannot write visible-input evidence"):
		return
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	var image: Image = root.get_texture().get_image()
	if not _require(
		image.save_png(output.trim_suffix(".json") + ".png") == OK, "Cannot write final frame"
	):
		return
	RenderingServer.frame_post_draw.disconnect(_on_draw)
	playground._request_quit()
