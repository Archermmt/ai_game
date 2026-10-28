extends SceneTree
func _initialize() -> void:
	var d=IslandData.new()
	for x in range(8,20):
		if x in [12,13]:continue
		for z in range(8,15):d.paint([Vector2i(x,z)],"grass")
	for x in range(8,20):
		if not x in [12,13]:d.paint([Vector2i(x,12)],"road")
	assert(BuildingRules.place(d,Vector2i(11,12),"bridge",0,2).begins_with("Placed"))
	assert(BuildingRules.place(d,Vector2i(8,9),"house").begins_with("Placed"))
	d.paint([Vector2i(8,11)],"road")
	assert(BuildingRules.place(d,Vector2i(16,13),"bench",0).begins_with("Placed"))
	d.paint([Vector2i(16,14),Vector2i(15,14),Vector2i(15,13)],"road")
	var sim=ResidentSim.new();sim.people=[{"id":1,"home":d.objects[1].id,"x":8.0,"z":11.0,"state":"home","route":[],"timer":0.0,"target":0,"activity":"","crossed":false}]
	for i in range(500):sim.tick(d,0.1)
	assert("bridge" in sim.completed)
	assert("bench" in sim.completed)
	print("PASS bridge traversal generates a journal event and reaches far-shore activity")
	quit()
