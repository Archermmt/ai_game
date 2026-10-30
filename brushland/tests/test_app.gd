extends SceneTree
var app:Node
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	create_timer(35).timeout.connect(func():push_error("App timeout");quit(1))
	app=load("res://game/island.tscn").instantiate();root.add_child(app)
	await process_frame
	app.close_modal();app.sim.paused=false
	app.hud.tool_selected.emit("tea");assert(app.tool=="tea")
	app.data.paint([Vector2i(18,20)],"grass");app.rebuild();assert(app.data.cell(Vector2i(18,20)).h==1)
	app.hud.action_requested.emit("undo");assert(app.data.cell(Vector2i(18,20)).h==0)
	app.hud.action_requested.emit("redo");assert(app.data.cell(Vector2i(18,20)).h==1)
	app.sim.paused=true;app.action("photo")
	await RenderingServer.frame_post_draw
	await process_frame
	assert(app.photo_mode and not app.hud.root.visible)
	while app.photo_busy:await process_frame
	app.action("photo");assert(app.sim.paused and app.hud.root.visible)
	app.sim.paused=false
	# Painting water beneath an actor chooses a surviving road in its prior region.
	var person=app.sim.people[0];var p=Vector2i(roundi(person.x),roundi(person.z));var regions=app.resident_regions()
	# A home's entry is protected, so use a public road tile for this fixture.
	person.x=28.0;person.z=33.0;regions=app.resident_regions()
	app.data.paint([Vector2i(28,33)],"water");app.protect_residents(regions)
	assert(app.data.cell(Vector2i(roundi(person.x),roundi(person.z))).h>0 or person.state=="resting")
	app.save_menu();await process_frame
	assert(app.modal!=null);app.close_modal()
	# AC07: a resident halfway across a removed bridge is moved to its prior
	# reachable bank, releases its reservation and retains identity/home.
	var bridge:Dictionary={}
	for object in app.data.objects:
		if object.kind=="bridge":bridge=object;break
	assert(not bridge.is_empty());var home_id=person.home;var person_id=person.id
	person.x=36.0;person.z=41.5;person.state="walking";person.target=app.data.objects[0].id;person.route=[Vector2i(36,43)]
	regions=app.resident_regions();app.data.begin();app.data.objects.erase(bridge);app.protect_residents(regions);app.rebuild()
	assert(person.id==person_id and person.home==home_id and person.target==0 and person.route.is_empty())
	assert(app.data.cell(Vector2i(roundi(person.x),roundi(person.z))).h>0)
	app.action("undo");assert(not RouteGraph.path(app.data,Vector2i(36,40),Vector2i(36,43)).is_empty())
	print("PASS UI signals, undo/redo, photo pause restore, safe actor relocation, mid-bridge removal/recovery and save menu")
	app.free();quit()
