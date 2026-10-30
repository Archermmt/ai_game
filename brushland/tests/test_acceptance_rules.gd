extends SceneTree
func _initialize() -> void:
	var d=IslandData.new();var p=Vector2i(10,10)
	d.paint([p,p,Vector2i(-1,0),Vector2i(64,0)],"raise");assert(d.cell(p).h==1 and d.tiles.size()==1)
	d.undo();assert(d.tiles.is_empty());d.redo();assert(d.cell(p).h==1)
	var cells:Array=[]
	for x in range(5,17):
		for z in range(5,17):cells.append(Vector2i(x,z))
	d.paint(cells,"grass");assert(BuildingRules.place(d,p,"house").begins_with("Placed"));var house=d.objects[-1]
	var before=d.snapshot()
	for tool in ["water","raise","lower"]:d.paint(BuildingRules.footprint(house),tool);assert(d.snapshot()==before)
	d.paint([Vector2i(9,9),Vector2i(10,9)],"flower");assert(BuildingRules.variant(d,house)=="basic")
	d.paint([Vector2i(11,9)],"flower");assert(BuildingRules.variant(d,house)=="garden")
	d.undo();assert(BuildingRules.variant(d,house)=="basic")
	house=d.objects[-1];d.paint([Vector2i(9,10)],"water");assert(BuildingRules.variant(d,house)=="coast")
	d.paint([Vector2i(11,9)],"flower");assert(BuildingRules.variant(d,house)=="garden")
	house.variant="garden";house.locked=true;d.paint([Vector2i(11,9)],"sand");assert(BuildingRules.variant(d,house)=="garden")
	house.locked=false;assert(BuildingRules.variant(d,house)=="coast")
	assert(not BuildingRules.place(d,RouteGraph.entrance(house),"pot").begins_with("Placed"))
	# A two-cell channel, legal bridge, rejected overlong or mismatched bank.
	d=IslandData.new();cells=[]
	for x in range(8,20):
		if x in [12,13]:continue
		for z in range(8,15):cells.append(Vector2i(x,z))
	d.paint(cells,"grass")
	for x in range(8,20):
		if not x in [12,13]:d.paint([Vector2i(x,12)],"road")
	assert(not BuildingRules.place(d,Vector2i(11,12),"bridge",0,7).begins_with("Placed"))
	d.paint([Vector2i(14,12)],"raise");assert(not BuildingRules.place(d,Vector2i(11,12),"bridge",0,2).begins_with("Placed"));d.undo()
	assert(BuildingRules.place(d,Vector2i(11,12),"bridge",0,2).begins_with("Placed"))
	assert(not RouteGraph.path(d,Vector2i(10,12),Vector2i(16,12)).is_empty())
	assert(BuildingRules.place(d,Vector2i(8,9),"house").begins_with("Placed"));var home=d.objects[-1];d.paint([Vector2i(8,11)],"road")
	assert(BuildingRules.place(d,Vector2i(16,9),"tea").begins_with("Placed"));var tea=d.objects[-1];d.paint([Vector2i(16,11)],"road")
	var sim=ResidentSim.new();sim.people=[{"id":1,"home":home.id,"x":8.0,"z":11.0,"state":"home","route":[],"timer":0.0,"target":0,"activity":"","crossed":false}]
	sim.tick(d,0.1);assert(sim.people[0].target==tea.id)
	d.begin();d.objects.erase(tea);sim.reconcile(d);assert(sim.people[0].target==0 and sim.people[0].route.is_empty())
	print("PASS AC01 unique stroke/bounds, AC02 foundations, AC03/04 variant priority/lock/undo, AC06 bridges/entry and AC07 reservation release");quit()
