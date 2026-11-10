extends SceneTree
var app
var folder := ""
func _initialize() -> void:call_deferred("run")

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	if not folder.is_empty():
		assert(root.get_texture().get_image().save_png(folder.path_join(name+".png")) == OK)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			folder=arg.trim_prefix("--shots=")
			DirAccess.make_dir_recursive_absolute(folder)
	create_timer(55).timeout.connect(func():push_error("Miniature timeout");quit(1))
	app=load("res://game/island.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.close_modal()
	app.set_process(false)
	app.sim.paused=true
	app.hud.root.hide()
	app.preview.hide()
	app.view.finish_growth()
	var initial: Dictionary=app.data.snapshot()
	var terrain := IslandData.new()
	terrain.paint([Vector2i(40,40)], "grass")
	var isolated := IslandSurface.new(terrain.snapshot())
	var edge_height := isolated.height_at(Vector2(40.5,40))
	terrain.paint([Vector2i(41,40)], "grass")
	var united := IslandSurface.new(terrain.snapshot())
	assert(united.height_at(Vector2(40.5,40)) > edge_height + 0.2)
	terrain.undo()
	assert(IslandSurface.new(terrain.snapshot()).height_at(Vector2(40.5,40)) == edge_height)
	app.preferences.values.flash = false
	app.select_tool("grass")
	app.begin_build_stroke(Vector2.ZERO)
	app.collect_cell(Vector2i(39,33),Vector2.ZERO)
	assert(app.stroke.size()==9)
	assert(app.stroke.has(Vector2i(38,32)) and app.stroke.has(Vector2i(40,34)))
	app.commit_stroke_at(Vector2i(39,33))
	assert(not app.view.growth.entries.is_empty())
	await shot("land_start")
	app.view.update_environment(0.17,false)
	await shot("land_mid")
	app.view.update_environment(0.4,false)
	assert(app.view.growth.entries.is_empty())
	await shot("land_settled")
	app.action("undo")
	assert(app.data.snapshot()==initial)
	app.select_tool("house")
	app.commit_stroke_at(Vector2i(32,31))
	assert(not app.view.growth.entries.is_empty())
	await shot("house_start")
	app.view.update_environment(0.18,false)
	await shot("house_mid")
	app.view.update_environment(0.4,false)
	assert(app.view.growth.entries.is_empty())
	await shot("house_settled")
	var form_snapshot: Dictionary=app.data.snapshot()
	app.action("undo")
	app.view.finish_growth()
	assert(app.data.snapshot()==initial)
	app.preferences.values.reduced_motion=true
	app.apply_preferences(false)
	app.select_tool("house")
	app.commit_stroke_at(Vector2i(32,31))
	assert(app.view.growth.entries.is_empty() and app.data.snapshot()==form_snapshot)
	if RenderingServer.get_current_rendering_method()=="forward_plus":
		assert(app.camera.attributes.dof_blur_far_enabled)
		assert(app.world_env.environment.ssao_enabled and app.world_env.environment.ssil_enabled)
	app.free()
	await create_timer(0.3).timeout
	print("PASS square stroke, terrain emergence, house/neighbor emergence, settled rebatching, undo, reduced motion and miniature focus")
	quit()
