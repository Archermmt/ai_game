extends SceneTree
## Paired roofs must meet in three dimensions even across a chunk boundary,
## when plots have different rotations, heights of building form or materials.
const Joined = preload("res://game/art/healing/joined_buildings.gd")
var kit := ArtKit.new()
var windows := MaterialLibrary.new().window_material()
var app
var output := ""

func _initialize() -> void:
	call_deferred("run")

func ridge_vertices(o: Dictionary, seams: Array) -> Dictionary:
	var model: Node3D = Joined.make(kit,o,"basic",seams,windows)
	var roof = model.get_node("JoinedRoof")
	var transform := Transform3D(Basis(Vector3.UP,-o.rotation*PI*0.5),Vector3(o.x+0.5,0,o.z+0.5))
	var seam: Dictionary = seams[0]
	var points := {}
	for v: Vector3 in roof.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		var world := transform * v
		var xz := Vector2(world.x,world.z)
		if absf((xz-Vector2(seam.center)).dot(Vector2(seam.direction))) < 0.0001:
			points[Vector3i((world*10000).round())] = true
	model.free()
	return points

func boundary(a: Dictionary, b: Dictionary, span: int) -> void:
	var d := IslandData.new()
	var cells := []
	for x in range(12,23):
		for z in range(8,19):
			cells.append(Vector2i(x,z))
	d.paint(cells,"grass")
	d.objects = [a,b]
	var seams: Dictionary = BuildingRules.neighborhood(d).seams
	assert(seams[a.id][0].width == span)
	var first := ridge_vertices(a,seams[a.id])
	var second := ridge_vertices(b,seams[b.id])
	assert(first.size() == 3 and first == second)

func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output.path_join(name + ".png")) == OK)

func run() -> void:
	create_timer(25).timeout.connect(func(): push_error("Joined roof test timed out");quit(1))
	var a := {"id":1,"kind":"house","x":14,"z":12,"rotation":0,"form":2}
	var b := {"id":2,"kind":"tea","x":16,"z":12,"rotation":2,"form":1}
	boundary(a,b,2)
	b.z=13
	b.kind="greenhouse"
	boundary(a,b,1)
	a.rotation=3
	b.x=15
	b.z=14
	b.kind="lighthouse"
	b.rotation=1
	boundary(a,b,1)
	for key in OS.get_cmdline_user_args():
		if key.begins_with("--snapshots="):
			output=key.trim_prefix("--snapshots=")
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		app=load("res://game/island.tscn").instantiate()
		root.add_child(app)
		await process_frame
		app.close_modal()
		app.sim.paused=true
		app.preview.hide()
		app.hud.root.hide()
		app.angle=0.32
		app.center=Vector3(31.5,1.65,31.5)
		app.camera.size=8.1
		app.update_camera()
		await capture("before")
		var d: IslandData = app.data
		assert(BuildingRules.place(d,Vector2i(32,31),"house").begins_with("Placed"))
		app.rebuild()
		await capture("joined")
		for form in [1,2]:
			assert(BuildingRules.reshape(d,Vector2i(32,31),"house").is_empty())
			app.rebuild()
			await capture("form%d" % form)
		assert(BuildingRules.place(d,Vector2i(28,31),"house").begins_with("Placed"))
		app.rebuild()
		assert(app.view.neighborhood_state.halls.size() == 1)
		await capture("hall")
		app.free()
		await create_timer(0.2).timeout
	print("PASS complete ridge, left eave and right eave coincide across plots for aligned, staggered and rotated mixed-use pairs")
	quit()
