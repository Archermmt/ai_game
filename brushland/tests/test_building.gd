extends SceneTree
func _initialize() -> void:
	var d=IslandData.new()
	for x in range(10,16):
		for z in range(10,16):d.paint([Vector2i(x,z)],"grass")
	assert(BuildingRules.place(d,Vector2i(11,11),"house").begins_with("Placed"))
	var o=d.objects[0]
	d.paint([Vector2i(11,11)],"water");assert(d.cell(Vector2i(11,11)).h==1)
	d.paint([Vector2i(10,10),Vector2i(11,10),Vector2i(12,10)],"flower")
	assert(BuildingRules.variant(d,o)=="garden")
	assert(not BuildingRules.place(d,Vector2i(11,11),"house").begins_with("Placed"))
	for x in range(10,16):d.paint([Vector2i(x,14)],"road")
	assert(RouteGraph.path(d,Vector2i(10,14),Vector2i(15,14)).size()==6)
	d.paint([Vector2i(12,14)],"water")
	assert(RouteGraph.path(d,Vector2i(10,14),Vector2i(15,14)).is_empty())
	print("PASS week 2: occupied protection, garden, overlap, connected/disconnected route")
	quit()
