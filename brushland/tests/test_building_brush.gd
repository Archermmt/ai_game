extends SceneTree
## Exercise the same projected mouse events as the window, including picking
## the visible roof at a shallow angle and releasing an entire brush stroke.
var app
var position := Vector2.ZERO
var buttons := 0
var output := ""
var filming := false

func _initialize() -> void:
	call_deferred("run")

func move_pointer(to: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = to - position
	position = to
	event.position = position
	event.global_position = position
	event.button_mask = buttons
	root.push_input(event, true)

func press(index: MouseButton, down: bool) -> void:
	var bit := 1 << (index - 1)
	buttons = (buttons | bit) if down else (buttons & ~bit)
	var event := InputEventMouseButton.new()
	event.button_index = index
	event.pressed = down
	event.position = position
	event.global_position = position
	event.button_mask = buttons
	root.push_input(event, true)

func click(to: Vector2) -> void:
	move_pointer(to)
	press(MOUSE_BUTTON_LEFT, true)
	press(MOUSE_BUTTON_LEFT, false)

func surface_point(x: int, z: int) -> Vector2:
	return app.camera.unproject_position(Vector3(x, app.view.surface.height_at(Vector2(x,z)), z))

func proof(name: String, frames: int = 24) -> void:
	if output.is_empty() and not filming:
		return
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	if not output.is_empty():
		assert(root.get_texture().get_image().save_png(output.path_join(name + ".png")) == OK)
	if filming:
		for frame in range(frames):
			await RenderingServer.frame_post_draw

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--demo-dir="):
			output = arg.trim_prefix("--demo-dir=")
			DirAccess.make_dir_recursive_absolute(output)
		filming = filming or arg == "--film"
	create_timer(50).timeout.connect(func(): push_error("Building brush timeout"); quit(1))
	app = load("res://game/island.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.close_modal()
	app.sim.paused = true
	app.hud.show_category("build")
	app.select_tool("house")
	app.hud.highlight("house")
	await process_frame
	await RenderingServer.frame_post_draw
	var home_id: int = app.data.objects[0].id
	var people: Array = app.sim.people.duplicate(true)
	var starting: Dictionary = app.data.snapshot()
	# The left-side perimeter cell must select the legal foundation outside
	# the old house, even though anchoring a 2x2 on that cell would overlap it.
	var snapped: Dictionary = app.prototype(Vector2i(29, 31))
	assert(Vector2i(snapped.x, snapped.z) == Vector2i(28, 31))
	var side := surface_point(32, 31)
	move_pointer(side)
	assert(app.preview_note.text.contains("合建"), "%s: world=%s roof=%s hovered=%s" % [app.preview_note.text, app.pick_at(side), app.tool_cell_at(side), root.gui_get_hovered_control()])
	await proof("01_before")
	click(side)
	assert(app.data.objects.size() == starting.objects.size() + 1)
	assert(app.view.neighborhood_state.seams[home_id].size() == 1)
	var second: Dictionary = app.data.objects.back()
	var east_id: int = second.id
	var seam: Dictionary = app.view.neighborhood_state.seams[home_id][0]
	assert(seam.width == 2 and seam.other == east_id)
	await proof("02_joined", 42)
	# At this camera angle the ground beneath the screen pointer is behind
	# the house. Reshaping must hit the roof instead of this background tile.
	var roof: Vector2 = app.camera.unproject_position(Vector3(30.5, 1.85, 31.5))
	assert(app.tool_cell_at(roof) == Vector2i(30, 31))
	assert(app.pick_at(roof) != Vector2i(30, 31))
	click(roof)
	assert(app.data.objects[0].get("form", 0) == 1 and app.data.objects.size() == starting.objects.size() + 1)
	await proof("03_loft", 38)
	click(roof)
	assert(app.data.objects[0].get("form", 0) == 2)
	assert(app.sim.people[0].id == people[0].id and app.sim.people[0].home == home_id)
	await proof("04_tower", 38)
	var angle: float = app.angle
	var start := root.get_visible_rect().size * Vector2(0.55, 0.42)
	move_pointer(start)
	press(MOUSE_BUTTON_RIGHT, true)
	for step in range(26):
		move_pointer(start + Vector2(step * 5, step * 1.2))
		if filming:
			await RenderingServer.frame_post_draw
	press(MOUSE_BUTTON_RIGHT, false)
	assert(not is_equal_approx(app.angle, angle))
	assert(app.data.objects[0].get("form", 0) == 2)
	await proof("05_orbit", 35)
	# Build across newly painted shoreline and release a multi-house extension
	# as one undoable edit. Work with the normal land and construction tools.
	app.angle = 0.16
	app.center = Vector3(34, 0.7, 32)
	app.camera.size = 20
	app.update_camera()
	app.hud.show_category("land")
	app.select_tool("grass")
	app.hud.highlight("grass")
	app.radius = 2
	var land_before: Dictionary = app.data.snapshot()
	move_pointer(surface_point(35, 32))
	press(MOUSE_BUTTON_LEFT, true)
	move_pointer(surface_point(40, 32))
	press(MOUSE_BUTTON_LEFT, false)
	assert(app.data.cell(Vector2i(40,31)).h == 1)
	var with_land: Dictionary = app.data.snapshot()
	await proof("06_shore", 32)
	app.hud.show_category("build")
	app.select_tool("house")
	app.hud.highlight("house")
	move_pointer(surface_point(34, 31))
	press(MOUSE_BUTTON_LEFT, true)
	move_pointer(surface_point(39, 31))
	assert(app.data.snapshot() == with_land and app.construction.added.size() >= 2)
	await proof("07_stroke", 38)
	press(MOUSE_BUTTON_LEFT, false)
	var built: Dictionary = app.data.snapshot()
	assert(built.objects.size() >= with_land.objects.size() + 2)
	assert(app.view.neighborhood_state.halls.size() == 1)
	await proof("08_extended", 42)
	app.action("undo")
	assert(app.data.snapshot() == with_land)
	await proof("09_undo", 30)
	app.action("undo")
	assert(app.data.snapshot() == land_before)
	app.action("redo")
	app.action("redo")
	assert(app.data.snapshot() == built)
	# Release over the toolbar discards the draft including free cells crossed.
	move_pointer(surface_point(37, 34))
	press(MOUSE_BUTTON_LEFT, true)
	move_pointer(surface_point(40, 34))
	move_pointer(app.hud.bottom.get_global_rect().get_center())
	press(MOUSE_BUTTON_LEFT, false)
	assert(app.data.snapshot() == built)
	app.hud.root.hide()
	app.preview.hide()
	app.camera.size = 13.0
	app.center = Vector3(33.2, 1.3, 31.8)
	app.angle = 0.53
	app.update_camera()
	await proof("10_houses", 42)
	var hall_id: int = app.view.neighborhood_state.halls.keys()[0]
	var hall: Dictionary = app.sim.object_by_id(app.data, hall_id)
	var hall_cell := Vector2i(hall.x, hall.z)
	app.select_tool("lock")
	app.commit_stroke_at(hall_cell)
	assert(hall.locked and hall.hall_locked and app.view.neighborhood_state.halls.has(hall_id))
	app.select_tool(hall.kind)
	var locked: Dictionary = app.data.snapshot()
	app.commit_stroke_at(hall_cell)
	assert(app.data.snapshot() == locked)
	app.select_tool("lock")
	app.commit_stroke_at(hall_cell)
	assert(not hall.locked and not hall.has("hall_locked"))
	app.free()
	await create_timer(0.2).timeout
	print("PASS viewport roof pick, side snapping, real join, repeat reshape, orbit, shoreline growth, drag construction, atomic undo and UI cancellation")
	quit()
