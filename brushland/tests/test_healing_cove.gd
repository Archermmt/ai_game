extends SceneTree

const SITE := Vector2i(33, 31)
var app
var output_dir := ""
var filming := false
func _initialize() -> void:
	call_deferred("run")

func snapshot(name: String) -> void:
	if output_dir.is_empty():
		return
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	assert(image != null and image.save_png(output_dir.path_join(name + ".png")) == OK)

func hold(frames: int) -> void:
	if filming:
		for frame in range(frames):
			await RenderingServer.frame_post_draw

func run() -> void:
	filming = OS.get_cmdline_user_args().has("--film")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--snapshots="):
			output_dir = arg.trim_prefix("--snapshots=")
			DirAccess.make_dir_recursive_absolute(output_dir)
	create_timer(240 if filming else 40).timeout.connect(func(): push_error("Cove integration timeout"); quit(1))
	app = load("res://game/island.tscn").instantiate()
	root.add_child(app)
	await process_frame
	assert(app.welcoming and app.modal.visible)
	await snapshot("welcome")
	await hold(25)
	app.close_modal()
	app.sim.paused = not filming
	app.preview.hide()
	app.hud.root.visible = filming
	assert(app.data.objects.size() == 4)
	assert(BuildingRules.variant(app.data, app.data.objects[0]) == "basic")
	assert(RouteGraph.open_sea(app.data, app.data.objects[2]))
	assert(not RouteGraph.path(app.data, Vector2i(25, 33), Vector2i(30, 33)).is_empty())
	await snapshot("cove")
	await hold(40)
	var before: Dictionary = app.data.snapshot()
	var garden_height: float = app.view.surface.height_at(Vector2(30, 30))
	var door_height: float = app.view.surface.height_at(Vector2(30, 33))
	app.hud.show_category("build")
	app.select_tool("greenhouse")
	app.hud.highlight("greenhouse")
	var location := Vector3(SITE.x, app.view.surface.height_at(Vector2(SITE)), SITE.y)
	var cell: Vector2i = app.pick_at(app.camera.unproject_position(location))
	assert(cell == SITE)
	var hint: String = app.placement_preview(app.prototype(cell))
	assert(hint.contains("1 间邻屋"))
	if filming:
		app.hud.toast(hint)
	await hold(40)
	app.commit_stroke_at(cell)
	assert(app.data.objects.size() == 5 and app.view.neighborhood_state.variants[1] == "garden")
	assert(app.data.tiles == before.tiles)
	assert(app.view.surface.garden_ground.get(Vector2i(30, 30)) == "meadow")
	assert(app.view.surface.height_at(Vector2(30, 30)) > garden_height + 0.08)
	assert(is_equal_approx(app.view.surface.height_at(Vector2(30, 33)), door_height))
	await snapshot("with_greenhouse")
	await hold(65)
	app.action("undo")
	assert(app.data.snapshot() == before and app.view.neighborhood_state.variants[1] == "basic")
	assert(is_equal_approx(app.view.surface.height_at(Vector2(30, 30)), garden_height))
	await hold(35)
	app.action("redo")
	assert(app.view.neighborhood_state.variants[1] == "garden")
	app.action("undo")
	app.set_sunset(true)
	app.hud.root.hide()
	await snapshot("dusk")
	await hold(45)
	app.angle += PI / 2
	app.update_camera()
	await snapshot("orbit")
	app.free()
	await create_timer(0.2).timeout
	print("PASS playable cottage cove, dock path, camera picking, preview/placement, garden ground, undo and redo")
	quit()
