class_name DemoIsland
extends RefCounted
static func create(d:IslandData) -> void:
	d.clear_world()
	for x in range(19,45):
		for z in range(22,43):
			var v=Vector2((x-32.0)/12.0,(z-32.0)/9.0);var dist=v.length()
			if dist>1.0:continue
			var h=1 if dist>0.84 else 2
			d.tiles[d.key(Vector2i(x,z))]={"h":h,"surface":"sand" if h==1 else "grass","road":false,"flower":false}
	# A small curved arrival beach on the western rim.
	for p in [Vector2i(21,33),Vector2i(22,33)]:d.tiles[d.key(p)]={"h":1,"surface":"sand","road":false,"flower":false}
	for x in range(21,42):d.paint([Vector2i(x,33)],"road")
	for p in [Vector2i(25,30),Vector2i(29,30),Vector2i(34,30)]:
		BuildingRules.place(d,p,"house");d.paint([Vector2i(p.x,32)],"road")
	for q in [Vector2i(20,32),Vector2i(19,32),Vector2i(18,32)]:d.paint([q],"water")
	BuildingRules.place(d,Vector2i(21,33),"dock",1,3)
	d.paint([Vector2i(28,29),Vector2i(29,29),Vector2i(30,29),Vector2i(31,29)],"flower")
	for item in [[Vector2i(29,35),"tea",2],[Vector2i(33,35),"greenhouse",2],[Vector2i(38,29),"lighthouse",0]]:
		var p:Vector2i=item[0]
		for x in range(-1,3):
			for z in range(-1,3):
				var q=p+Vector2i(x,z)
				if not BuildingRules.occupied(d,q):d.tiles[d.key(q)]={"h":2,"surface":"grass","road":false,"flower":false}
		BuildingRules.place(d,p,item[1],item[2]);d.paint([RouteGraph.entrance({"x":p.x,"z":p.y,"rotation":item[2]})],"road")
	# Connect the public buildings to the principal village lane.
	for p in [Vector2i(29,34),Vector2i(33,34),Vector2i(38,32),Vector2i(38,31)]:d.paint([p],"road")
	d.tiles[d.key(Vector2i(26,38))]={"h":1,"surface":"sand","road":false,"flower":false}
	BuildingRules.place(d,Vector2i(26,38),"bench",0)
	for z in range(34,40):d.paint([Vector2i(27,z)],"road")
	d.paint([Vector2i(26,39)],"road")
	d.paint([Vector2i(32,34),Vector2i(35,35),Vector2i(35,36)],"flower")
	for p in [Vector2i(28,35),Vector2i(32,35),Vector2i(34,37),Vector2i(37,30)]:BuildingRules.place(d,p,"pot")
	for p in [Vector2i(24,27),Vector2i(28,25),Vector2i(33,25),Vector2i(37,26),Vector2i(25,37),Vector2i(38,37)]:BuildingRules.place(d,p,"tree")
	for p in [Vector2i(27,28),Vector2i(32,28),Vector2i(28,37),Vector2i(32,37)]:d.paint([p],"flower")
	# A coast cottage and a short bridge make every basic visual family visible.
	for x in range(41,43):
		for z in range(31,33):d.tiles[d.key(Vector2i(x,z))]={"h":1,"surface":"sand","road":false,"flower":false}
	d.tiles[d.key(Vector2i(41,33))]={"h":1,"surface":"sand","road":true,"flower":false}
	BuildingRules.place(d,Vector2i(41,31),"house")
	for x in range(35,38):
		for z in range(43,46):d.tiles[d.key(Vector2i(x,z))]={"h":1,"surface":"sand","road":false,"flower":false}
	for z in range(33,41):d.paint([Vector2i(36,z)],"road")
	d.paint([Vector2i(36,43),Vector2i(35,43)],"road")
	BuildingRules.place(d,Vector2i(36,40),"bridge",2,2)
	BuildingRules.place(d,Vector2i(35,44),"bench",2)
	d.history.clear();d.future.clear();d.revision+=1
