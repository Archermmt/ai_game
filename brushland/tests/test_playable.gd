extends SceneTree
var failed=false
func check(value:bool,message:String) -> void:
	if not value:push_error(message);failed=true
func _initialize() -> void:
	var d=IslandData.new();DemoIsland.create(d)
	var counts:Dictionary={}
	for o in d.objects:counts[o.kind]=int(counts.get(o.kind,0))+1
	check(counts.get("house",0)==3,"demo needs 3 houses")
	for kind in ["dock","tea","greenhouse","lighthouse","bench"]:check(counts.get(kind,0)>=1,"missing demo object: "+kind)
	var sim=ResidentSim.new();sim.sunset=true
	for i in range(1000):sim.tick(d,0.25)
	check(sim.people.size()==3,"three reachable homes must receive residents")
	print("COMPLETED ",sim.completed)
	for key in ["garden","tea","greenhouse","bench","lighthouse"]:check(key in sim.completed,"activity never completed: "+key)
	check(SaveStore.save_game(d,sim,"user://test_playable.json")==OK,"save failed")
	var loaded=IslandData.new();var resumed=ResidentSim.new()
	check(SaveStore.load_game(loaded,resumed,"user://test_playable.json")==OK,"load failed")
	check(resumed.completed==sim.completed,"journal did not survive load")
	# Invalid payload must not overwrite the current world.
	var before=loaded.snapshot();var file=FileAccess.open("user://test_invalid.json",FileAccess.WRITE);file.store_string('{"schema_version":1}');file.close()
	check(SaveStore.load_game(loaded,resumed,"user://test_invalid.json")==ERR_FILE_CORRUPT,"invalid save accepted")
	check(loaded.snapshot()==before,"invalid save changed world")
	# Deleting a reserved activity target releases it on reconciliation.
	for person in sim.people:
		if person.target!=0:
			var o=sim.object_by_id(d,int(person.target))
			d.begin();d.objects.erase(o);sim.reconcile(d)
			check(person.target==0,"deleted target retained a reservation")
			break
	print("PASS playable integration" if not failed else "FAIL playable integration")
	quit(1 if failed else 0)
