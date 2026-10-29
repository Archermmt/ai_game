class_name IslandCompositions
extends RefCounted
const IDS=["harbor","garden","lighthouse"]
static func create(data:IslandData,id:String) -> void:
	DemoIsland.create(data)
	if id=="garden":
		for x in range(29,35):
			for z in range(24,29):
				var p=Vector2i(x,z)
				if Vector2(p-Vector2i(32,26)).length()<1.65:data.paint([p],"water")
		for x in range(23,38):
			for z in range(24,39):
				var p=Vector2i(x,z)
				if posmod(x*7+z*11,13)==0:data.paint([p],"flower")
		for z in range(34,39):data.paint([Vector2i(32,z)],"road")
		data.paint([Vector2i(31,38)],"road");BuildingRules.place(data,Vector2i(31,37),"bench")
	elif id=="lighthouse":
		for x in range(35,44):
			for z in range(23,32):
				var p=Vector2i(x,z);var distance=Vector2(p-Vector2i(39,28)).length()
				if distance>4.5 or BuildingRules.occupied(data,p):continue
				data.tiles[data.key(p)]={"h":4 if distance<2.3 else 3 if distance<3.4 else 2,"surface":"rock","road":false,"flower":false}
		for x in [38,39]:
			for z in [29,30]:data.tiles[data.key(Vector2i(x,z))]={"h":4,"surface":"rock","road":false,"flower":false}
		for pair in [[31,4],[32,3],[33,2]]:data.tiles[data.key(Vector2i(38,pair[0]))]={"h":pair[1],"surface":"rock","road":true,"flower":false}
	data.history.clear();data.future.clear();data.revision+=1
