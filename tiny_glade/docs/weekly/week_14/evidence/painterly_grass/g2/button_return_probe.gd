extends SceneTree
## Run with --g2-fhd; verifies the toolbar exit branch on final G2 code.

var patch: PainterlyGrassPatch


func _initialize() -> void:
	_run.call_deferred()


func _click(control: Control) -> void:
	var point: Vector2 = control.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		Input.parse_input_event(event)
	await process_frame
	await process_frame


func _run() -> void:
	patch = preload("res://app/painterly_grass_patch.tscn").instantiate()
	root.add_child(patch)
	var deadline: int = Time.get_ticks_msec() + 40000
	while not patch.patch_ready and not patch.patch_failed and Time.get_ticks_msec() < deadline:
		await process_frame
	assert(patch.patch_ready)
	var source: Dictionary = patch.document.snapshot()
	await _click(patch.pause_button)
	assert(patch.patch_paused and patch._climate_frozen)
	await _click(patch.walk_button)
	assert(patch.walk_controller.active and patch._climate_frozen)
	await _click(patch.walk_button)
	assert(not patch.walk_controller.active and patch._climate_frozen and patch.patch_paused)
	assert(patch.photo_active and patch.document.snapshot() == source)
	var result: Dictionary = {
		"passed": true,
		"checks": 4,
		"ui": "actual viewport button press/release",
		"source_unchanged": true,
		"paused_after_toolbar_walk_exit": true,
		"viewport": [1920, 1080]
	}
	var output: FileAccess = FileAccess.open(
		"res://reports/week_14/g2/button_return_checks.json", FileAccess.WRITE
	)
	output.store_string(JSON.stringify(result, "\t"))
	output.close()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/week_14/g2/button_return.png")
	patch.seasonal_music.shutdown()
	patch.soundscape.shutdown()
	await SceneShutdown.wait_wallclock(self, 0.4)
	await SceneShutdown.release_scene(patch)
	for i: int in 8:
		await process_frame
	quit()
