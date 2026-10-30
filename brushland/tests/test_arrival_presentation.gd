extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	create_timer(30).timeout.connect(func():push_error("Arrival presentation timeout");quit(1))
	var app=load("res://game/island.tscn").instantiate();app.preferences.path="user://test_arrival_preferences.cfg";root.add_child(app);await process_frame;app.close_modal()
	app.sim=ResidentSim.new();app.sim.tick(app.data,8.1);app.sim.paused=true
	assert(app.sim.people.size()==1);var person=app.sim.people[0];var id=int(person.id)
	assert(person.arrival_dock>0 and person.timer==4.0);assert(app.sim.preference_of(person)=="tea")
	app.view.update_actors(app.sim,0);var actor=app.view.actor_nodes[id];var position=actor.position
	assert(actor.visible and position.y<0.6)
	var boat:Node3D
	for node in get_nodes_in_group("island_boats"):
		if int(node.get_meta("dock_id"))==int(person.arrival_dock):boat=node
	assert(boat!=null);var mooring:Vector3=boat.get_meta("mooring");var distance=boat.position.distance_to(mooring)
	app.sim.tick(app.data,1);assert(person.timer==4.0)
	app.sim.paused=false;app.sim.tick(app.data,1);app.sim.paused=true;app.view.update_actors(app.sim,1)
	assert(person.timer==3.0 and boat.position.distance_to(mooring)<distance)
	assert(actor.position==boat.position+Vector3.UP*0.35)
	assert(app.save_current("user://test_arrival_shore.json")==OK)
	var loaded=IslandData.new();var resumed=ResidentSim.new();assert(SaveStore.load_game(loaded,resumed,"user://test_arrival_shore.json")==OK)
	assert(resumed.people.size()==1 and resumed.people[0].id==id and resumed.people[0].arrival_dock==0 and not resumed.people[0].route.is_empty())
	app.center=Vector3(22,0,33);app.angle=0.55;app.camera.size=19;app.update_camera();app.hud.root.visible=false
	for i in range(3):await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://snapshots/completion/arrival_boat.png")
	app.data.begin()
	for object in app.data.objects.duplicate():
		if object.kind=="house":app.data.objects.erase(object)
	app.sim.reconcile(app.data);app.view.update_actors(app.sim,1)
	assert(person.id==id and person.home==0 and person.arrival_dock==0 and not actor.visible and boat.position.distance_to(mooring)<0.1)
	app.data.undo();app.sim.reconcile(app.data);assert(person.home!=0 and app.sim.people.size()==1)
	app.free()
	for suffix in ["",".tmp",".bak",".bak2",".bak3"]:DirAccess.remove_absolute("user://test_arrival_shore.json"+suffix)
	for i in range(3):await process_frame
	print("PASS single arrival boat/seat approach, pause, stable preference, shore reload and inflight home recovery");quit()
