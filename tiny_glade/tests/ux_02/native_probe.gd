extends SceneTree

var playground: Node3D
var folder: String
var evidence: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _settle() -> void:
	var started: int = Time.get_ticks_msec()
	while (
		playground._busy()
		or playground.queue.is_busy()
		or playground.stage.is_busy()
		or playground.meadow.is_busy()
	):
		if Time.get_ticks_msec() - started > 15000:
			push_error("UX02 native settle timeout")
			quit(1)
			return
		await process_frame
	for i: int in range(5):
		await process_frame


func _frame(name: String) -> void:
	for i: int in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(folder.path_join(name + ".png")) == OK)


func _mouse(point: Vector2, pressed: bool, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = button
	event.pressed = pressed
	event.button_mask = (
		(MOUSE_BUTTON_MASK_LEFT if button == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT)
		if pressed
		else 0
	)
	Input.parse_input_event(event)
	await process_frame


func _motion(point: Vector2, delta: Vector2, held: MouseButton = MOUSE_BUTTON_NONE) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.relative = delta
	event.button_mask = (
		MOUSE_BUTTON_MASK_LEFT
		if held == MOUSE_BUTTON_LEFT
		else (MOUSE_BUTTON_MASK_RIGHT if held == MOUSE_BUTTON_RIGHT else 0)
	)
	Input.parse_input_event(event)
	await process_frame


func _run() -> void:
	folder = OS.get_cmdline_user_args()[-1]
	DirAccess.make_dir_recursive_absolute(folder)
	playground = load("res://app/simple_root.tscn").instantiate()
	playground.qa_mode = true
	root.add_child(playground)
	await _settle()
	var source: Dictionary = playground.document.snapshot()
	await _frame("browse")
	playground.hud.open_group("build")
	await _frame("build")
	playground.hud.open_group("plants")
	playground._preference_changed("ui_scale", 1.5)
	await _frame("plants_150")
	evidence["quick_150_inside"] = Rect2(Vector2.ZERO, Vector2(root.size)).encloses(
		playground.hud.quick.get_global_rect()
	)
	playground._preference_changed("ui_scale", 1.0)
	playground.hud.close_context()
	var home: Dictionary = source["buildings"][0]
	var p: Array = home["position"]
	var click: Vector2 = playground.camera_rig.camera.unproject_position(
		Vector3(p[0], p[1] + 1.5, p[2])
	)
	await _motion(click, Vector2.ZERO)
	var yaw: float = playground.camera_rig.yaw
	await _mouse(click, true, MOUSE_BUTTON_RIGHT)
	await _motion(click + Vector2(40, 0), Vector2(40, 0), MOUSE_BUTTON_RIGHT)
	evidence["right_drag_rotated"] = not is_equal_approx(playground.camera_rig.yaw, yaw)
	await _mouse(click + Vector2(40, 0), false, MOUSE_BUTTON_RIGHT)
	evidence["right_drag_no_selection"] = playground.selected_buildings.is_empty()
	assert(evidence["right_drag_rotated"] and evidence["right_drag_no_selection"])
	playground.camera_rig.yaw = yaw
	playground.camera_rig.refresh()
	await _motion(click, Vector2(-40, 0))
	await _mouse(click, true, MOUSE_BUTTON_RIGHT)
	await _mouse(click, false, MOUSE_BUTTON_RIGHT)
	await _settle()
	evidence["right_click_selected"] = not playground.selected_buildings.is_empty()
	assert(evidence["right_click_selected"])
	await _frame("house_handles")
	var handle: Control = playground.hud.direct_handles.handles["height"]
	assert(handle.is_visible_in_tree())
	var start: Vector2 = handle.get_global_rect().get_center()
	var before: Dictionary = playground.document.snapshot()
	await _motion(start, start - click)
	await _mouse(start, true)
	evidence["gui_handle_began"] = not playground.direct.is_empty()
	assert(evidence["gui_handle_began"])
	await _motion(start + Vector2(0, -14), Vector2(0, -14), MOUSE_BUTTON_LEFT)
	await _frame("height_preview")
	await _mouse(start + Vector2(0, -14), false)
	await _settle()
	evidence["handle_one_history"] = playground.session.history_count() == 1
	evidence["height_changed"] = (
		playground.document.state["buildings"][0]["size"] != before["buildings"][0]["size"]
	)
	assert(evidence["height_changed"] and evidence["handle_one_history"])
	await _frame("height_after")
	playground._on_action(&"undo")
	await _settle()
	var restored: Dictionary = playground.document.snapshot()
	restored["revision"] = before["revision"]
	evidence["undo_exact_source"] = restored == before
	assert(evidence["undo_exact_source"])
	playground._preference_changed("ui_scale", 1.5)
	await _frame("handles_150")
	evidence["selected_photo_entered"] = playground.enter_photo()
	assert(evidence["selected_photo_entered"])
	await _frame("photo")
	for size: Vector2i in [Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		var path: String = folder.path_join("photo_%dx%d.png" % [size.x, size.y])
		var result: Dictionary = await playground.photography.capture(
			playground.camera_rig.camera, size, path
		)
		var picture: Image = Image.load_from_file(path)
		assert(result["ok"] and picture.get_size() == size)
	evidence["photo_sizes_decoded"] = true
	playground.exit_photo()
	await process_frame
	evidence["photo_restore"] = (
		playground.hud.object_bar.visible and playground.hud.direct_handles.visible
	)
	assert(evidence["photo_restore"])
	var file: FileAccess = FileAccess.open(folder.path_join("native_report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence, "\t"))
	file.close()
	playground.queue_free()
	for i: int in range(5):
		await process_frame
	quit()
