extends SceneTree
const Layout = preload("res://game/building/settlement_layout.gd")
var app
var folder := ""
func _initialize() -> void:call_deferred("run")

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	if not folder.is_empty():
		assert(root.get_texture().get_image().save_png(folder.path_join(name+".png"))==OK)

func check_first_arrival() -> void:
	var data := IslandData.new()
	var cells := []
	for x in range(4,15):
		for z in range(10,15):cells.append(Vector2i(x,z))
	data.paint(cells,"grass")
	for x in range(4,15):data.paint([Vector2i(x,12)],"road")
	assert(BuildingRules.place(data,Vector2i(4,12),"dock",1,3).begins_with("Placed"))
	assert(BuildingRules.place(data,Vector2i(10,10),"house").begins_with("Placed"))
	var sim := ResidentSim.new()
	var state := BuildingRules.neighborhood(data)
	var guide = preload("res://game/life/creative_discovery.gd")
	assert(not guide.describe(data,sim,state).done.arrival)
	sim.tick(data,8.1)
	assert(sim.people.size()==1 and guide.describe(data,sim,state).done.arrival)
	data.begin()
	data.objects.pop_back()
	sim.reconcile(data)
	assert(not guide.describe(data,sim,BuildingRules.neighborhood(data)).done.arrival)
	data.undo()
	sim.reconcile(data)
	assert(sim.people.size()==1 and guide.describe(data,sim,BuildingRules.neighborhood(data)).done.arrival)

func make_world(shape: String) -> IslandData:
	var data := IslandData.new()
	var cells := []
	for x in range(20,46):
		for z in range(20,39):cells.append(Vector2i(x,z))
	data.paint(cells,"grass")
	var plots := []
	if shape == "court":
		plots = [[26,26,2],[28,26,2],[30,26,2],[26,28,1],[30,28,3],[26,30,0],[28,30,0],[30,30,0]]
	elif shape == "corner":
		plots = [[26,26,2],[28,26,2],[30,26,2],[32,26,3],[32,28,3],[32,30,3],[32,32,3],[32,34,3]]
	else:
		for x in range(8):plots.append([23+x*2,28,0])
	for plot in plots:
		var result := BuildingRules.place(data,Vector2i(plot[0],plot[1]),"house",plot[2])
		assert(result.begins_with("Placed"),result)
	data.history.clear()
	return data

func run() -> void:
	check_first_arrival()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):folder=arg.trim_prefix("--shots=");DirAccess.make_dir_recursive_absolute(folder)
	var court := make_world("court")
	var state := BuildingRules.neighborhood(court)
	assert(state.courts.size()==1 and state.courts[0].size()==4)
	assert(state.ground[Vector2i(28,28)]=="meadow")
	var decorated := 0
	for layout in state.layouts.values():
		if not layout.courts.is_empty():decorated+=1
	assert(decorated>=4)
	var before := court.snapshot()
	court.begin()
	court.objects.remove_at(1)
	assert(BuildingRules.neighborhood(court).courts.is_empty())
	court.undo()
	assert(court.snapshot()==before and BuildingRules.neighborhood(court)==state)
	var reordered := IslandData.new()
	reordered.restore(before)
	reordered.objects.reverse()
	assert(BuildingRules.neighborhood(reordered).layouts==state.layouts)
	var corner := BuildingRules.neighborhood(make_world("corner"))
	var has_corner := false
	for layout in corner.layouts.values():has_corner=has_corner or layout.role=="corner"
	assert(has_corner and corner.courts.is_empty())
	var junction := make_world("street")
	junction.objects.clear()
	for plot in [[26,26,0],[24,26,1],[28,26,3],[26,24,2]]:
		assert(BuildingRules.place(junction,Vector2i(plot[0],plot[1]),"house",plot[2]).begins_with("Placed"))
	assert(BuildingRules.neighborhood(junction).layouts[junction.objects[0].id].role=="junction")
	if DisplayServer.get_name()=="headless":
		print("PASS space grammar: equal-count street/corner/court, enclosed garden, opening, undo and order-independent details")
		quit()
		return
	create_timer(60).timeout.connect(func():push_error("Experience timeout");quit(1))
	app=load("res://game/island.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.close_modal()
	app.set_process(false)
	app.sim.paused=true
	app.preferences.values.flash=false
	app.select_tool("house")
	app.hud.show_category("build")
	await process_frame
	app.hud.card.show()
	await shot("journal")
	for child in app.hud.journal.get_children():
		if child is Button and child.text.begins_with("试一笔"):
			child.pressed.emit()
			assert(app.tool == app.hud.discoveries.next[3])
	app.hud.card.hide()
	app.select_tool("house")
	var source: Dictionary=app.data.snapshot()
	app.begin_build_stroke(Vector2.ZERO)
	app.collect_cell(Vector2i(32,31),Vector2.ZERO)
	app.collect_cell(Vector2i(34,31),Vector2(25,0))
	app.dragging=true
	app.refresh_preview(app.camera.unproject_position(Vector3(34,0.5,31)))
	assert(app.brush_volume.visible and app.brush_volume.get_child_count()>0)
	assert(app.data.snapshot()==source)
	await shot("preview")
	app.discard_stroke()
	app.refresh_preview()
	assert(app.data.snapshot()==source)
	app.commit_stroke_at(Vector2i(32,31))
	var old_home := int(source.objects[0].id)
	var new_home := int(app.data.objects.back().id)
	assert(app.view.new_ids.has(new_home) and not app.view.new_ids.has(old_home))
	for entry in app.view.growth.entries:
		if entry.has("existing"):
			assert(entry.node.scale.y>=0.97 if entry.existing else entry.node.scale.y<0.03)
	app.action("undo")
	assert(app.data.snapshot()==source)
	app.select_tool("raise")
	app.hud.show_category("land")
	app.hud.highlight("raise")
	app.refresh_preview(app.camera.unproject_position(Vector3(35,0.5,33)))
	assert(app.brush_volume.visible and app.brush_volume.get_child_count()>0)
	assert(app.data.snapshot()==source)
	await shot("terrain_preview")
	app.select_tool("lower")
	app.refresh_preview(app.camera.unproject_position(Vector3(35,0.5,33)))
	assert(app.brush_volume.get_child(0).material_override.no_depth_test)
	assert(app.data.snapshot()==source)
	app.preview.hide()
	app.hud.root.hide()
	for shape in ["street","corner","court"]:
		app.data.restore(make_world(shape).snapshot())
		app.rebuild()
		app.view.finish_growth()
		app.center=Vector3(30,1.2,29.5)
		app.camera.size=21
		app.angle=0.65
		app.pitch_offset=12
		app.update_camera()
		await shot(shape)
	assert(app.hud.discoveries.done.court)
	# Opening one side must rebuild even a distant gallery across a chunk edge.
	var crossing := make_world("court")
	for object in crossing.objects:
		object.x += 5
		object.z += 5
	app.data.restore(crossing.snapshot())
	app.rebuild()
	app.view.finish_growth()
	app.data.begin()
	app.data.objects.remove_at(1)
	app.rebuild()
	assert(app.view.changed_chunks.has(Vector2i(3,4)))
	assert(app.view.neighborhood_state.courts.is_empty())
	app.action("undo")
	assert(app.view.neighborhood_state.courts.size()==1)
	app.data.restore(source)
	app.sim = ResidentSim.new()
	app.rebuild()
	app.sim.elapsed = 8.0
	app._process(0.1)
	assert(app.sim.people.size()==1)
	assert(app.hud.toast_label.text.contains("小屋 %d" % app.sim.people[0].home))
	assert(app.hud.discoveries.done.arrival)
	app.free()
	await create_timer(0.3).timeout
	print("PASS live volume preview without mutation, three spatial compositions, court discovery and cleanup")
	quit()
