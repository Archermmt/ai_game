extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	create_timer(45).timeout.connect(func():push_error("Acceptance core timeout");quit(1))
	var d=IslandData.new();var sim=ResidentSim.new()
	var cells:Array=[]
	for x in range(4,24):
		for z in range(4,18):cells.append(Vector2i(x,z))
	d.paint(cells,"grass");d.history.clear();var states:Array=[d.snapshot()]
	for i in range(50):
		match i%10:
			0:assert(BuildingRules.place(d,Vector2i(12+(i/10)*2,12),"pot").begins_with("Placed"))
			1:d.begin();d.objects[-1].x+=1
			2:d.begin();d.objects[-1].rotation=(d.objects[-1].rotation+1)%4
			3:d.begin();d.objects[-1].color=1
			4:d.begin();d.objects[-1].locked=true
			_:d.paint([Vector2i(4+i%10,4+i/10)],["road","flower","raise","lower","sand"][i%10-5])
		states.append(d.snapshot())
	assert(d.history.size()==50);sim.record("garden");sim.hidden_wishes=["tea"]
	for i in range(50):d.undo();assert(d.snapshot()==states[49-i])
	for i in range(50):
		d.redo();assert(d.snapshot()==states[i+1]);var used:Dictionary={}
		for object in d.objects:
			for cell in BuildingRules.footprint(object):assert(not used.has(cell));used[cell]=true
	assert(sim.completed==["garden"] and sim.hidden_wishes==["tea"])
	# AC05: reasons follow the actual arrival gate, rather than generic hints.
	d=IslandData.new();cells=[]
	for x in range(4,15):
		for z in range(10,15):cells.append(Vector2i(x,z))
	d.paint(cells,"grass");assert(BuildingRules.place(d,Vector2i(10,10),"house").begins_with("Placed"));var house=d.objects[-1]
	assert(sim.arrival_info(d,house).reason=="门前还没接上小路")
	d.paint([Vector2i(10,12)],"road");assert(sim.arrival_info(d,house).reason=="需要一座通海码头")
	assert(BuildingRules.place(d,Vector2i(4,12),"dock",1,3).begins_with("Placed"));assert(sim.arrival_info(d,house).reason=="码头入口还没接路")
	d.paint([Vector2i(4,12)],"road");assert(sim.arrival_info(d,house).reason=="码头与小屋尚未连通")
	for x in range(5,10):d.paint([Vector2i(x,12)],"road")
	assert(not sim.arrival_info(d,house).route.is_empty())
	var lake=IslandData.new();cells=[]
	for x in range(5,21):
		for z in range(8,17):cells.append(Vector2i(x,z))
	lake.paint(cells,"grass");cells=[]
	for x in range(6,12):
		for z in range(9,16):cells.append(Vector2i(x,z))
	lake.paint(cells,"water");assert(BuildingRules.place(lake,Vector2i(15,10),"house").begins_with("Placed"));var lake_home=lake.objects[-1]
	assert(BuildingRules.place(lake,Vector2i(12,12),"dock",1,3).begins_with("Placed"))
	for x in range(12,16):lake.paint([Vector2i(x,12)],"road")
	assert(sim.arrival_info(lake,lake_home).reason=="泊位通道未通向外海")
	var lake_sim=ResidentSim.new();lake_sim.tick(lake,8.1);assert(lake_sim.people.is_empty())
	lake.paint([Vector2i(5,12)],"water");assert(not sim.arrival_info(lake,lake_home).route.is_empty())
	lake_sim.tick(lake,8.1);assert(lake_sim.people.size()==1)
	var arriving=ResidentSim.new();arriving.tick(d,8.1);assert(arriving.people.size()==1 and arriving.people[0].state=="arriving")
	var id=arriving.people[0].id;d.begin();d.objects.erase(house);arriving.reconcile(d)
	assert(arriving.people[0].home==0 and arriving.people[0].state=="resting")
	var path="user://test_completion_inflight.json";assert(SaveStore.save_game(d,arriving,path)==OK)
	var restored=IslandData.new();var resumed=ResidentSim.new();assert(SaveStore.load_game(restored,resumed,path)==OK)
	assert(resumed.people.size()==1 and resumed.people[0].id==id and resumed.people[0].home==0)
	assert(BuildingRules.place(restored,Vector2i(10,10),"house").begins_with("Placed"));resumed.reconcile(restored)
	assert(resumed.people[0].home==restored.objects[-1].id and resumed.people.size()==1)
	for suffix in ["",".tmp",".bak",".bak2",".bak3"]:DirAccess.remove_absolute(path+suffix)
	print("PASS AC05 exact arrival reasons, AC08 permanent wishes, AC09 50 mixed undo/redo, AC13 inflight house removal/reload/priority recovery");quit()
