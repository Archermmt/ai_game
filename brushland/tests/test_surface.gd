extends SceneTree
var checks=0
var failed=false
func check(value:bool) -> void:
	checks+=1
	if not value:failed=true;push_error("surface check failed %d"%checks);quit(1)
func original_height(s:IslandSurface,v:Vector2) -> float:
	for foundation in s.foundations:
		if foundation.bounds.has_point(v):return foundation.height
	var p=Vector2i(floori(v.x),floori(v.y));var t=v-Vector2(p);var heights:Array=[]
	t=Vector2(smoothstep(0,1,t.x),smoothstep(0,1,t.y))
	for q in [p,p+Vector2i.RIGHT,p+Vector2i.DOWN,p+Vector2i.ONE]:
		var h=int(s.cell(q).h);heights.append(h*0.5 if h>0 else -0.15)
	if heights.max()-heights.min()>0.66:
		var h=int(s.cell(Vector2i(roundi(v.x),roundi(v.y))).h);return h*0.5 if h>0 else -0.15
	return lerpf(lerpf(heights[0],heights[1],t.x),lerpf(heights[2],heights[3],t.x),t.y)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var data=IslandData.new();DemoIsland.create(data)
	var before=data.snapshot();var s=IslandSurface.new(before)
	for x in range(-1,66):
		for z in range(-1,66):
			for offset in [Vector2.ZERO,Vector2(0.5,0.5),Vector2(0.12,-0.12)]:
				assert(s.height_at(Vector2(x,z)+offset)==original_height(s,Vector2(x,z)+offset))
	check(s.height_at(Vector2(29.5,30.5))==1.0)
	check(s.sample_surface(Vector2(29.5,30.5)).normal.is_normalized())
	check(s.height_at(Vector2(0,0))<0.0)
	check(absf(s.height_at(Vector2(22.99,33))-s.height_at(Vector2(23.01,33)))<0.05)
	var view=IslandView.new();root.add_child(view);view.setup(data);view.rebuild()
	# The cached water field must match the original full two-pass field exactly.
	check(view.water_levels.size()==4096)
	var water_bytes=view.water_image.get_data();var water_id=view.water_texture.get_instance_id()
	data.paint([Vector2i(28,33)],"road");view.rebuild()
	check(view.water_image.get_data()==water_bytes and view.water_texture.get_instance_id()==water_id)
	data.undo();view.rebuild()
	data.paint([Vector2i(20,32)],"raise");view.rebuild()
	check(view.water_texture.get_instance_id()==water_id)
	var pixel=view.water_image.get_pixel(20,32)
	check(absf(pixel.r-(view.surface.height_at_cell(Vector2i(20,32))+0.15)/2.2)<1.0/255.0)
	data.undo();view.rebuild();check(view.water_image.get_data()==water_bytes)
	var saved_ids:Dictionary={}
	for key in view.terrain_chunks:saved_ids[key]=view.terrain_chunks[key].get_instance_id()
	data.paint([Vector2i(5,5)],"grass");view.rebuild()
	check(view.rebuild_stats.dirty_chunks==1)
	for key in saved_ids:check(view.terrain_chunks[key].get_instance_id()==saved_ids[key])
	data.undo();view.rebuild();check(data.snapshot()==before)
	var snapshot=data.snapshot();data.paint([Vector2i(6,6)],"raise");data.restore(snapshot);view.rebuild()
	check(data.snapshot()==before)
	var serialized=JSON.parse_string(JSON.stringify(snapshot));var loaded=IslandSurface.new(serialized)
	check(loaded.build_chunk(Vector2i(2,4))==s.build_chunk(Vector2i(2,4)))
	data.clear_world();view.rebuild();check(view.terrain_chunks.is_empty())
	view.free();check_garden_border();print("PASS surface consistency, undo/reload, unchanged chunk identity, empty cleanup (",checks," checks)");quit(1 if failed else 0)

# The second cottage is in a different 8 m chunk from its greenhouse. Both the
# painted soil and its pebbles must be rebuilt when the influence reaches it.
func check_garden_border() -> void:
	var garden := IslandData.new()
	var cells := []
	for z in range(8, 16):
		for x in range(8, 24):
			cells.append(Vector2i(x, z))
	garden.paint(cells, "grass")
	for x in [15, 18]:
		check(BuildingRules.place(garden, Vector2i(x, 11), "house").begins_with("Placed"))
	var island := IslandView.new()
	root.add_child(island)
	island.setup(garden)
	island.rebuild()
	var edge := Vector2i(2, 1)
	var remote_cell := Vector2i(20, 11)
	var before: Array = island.terrain_chunks[edge].mesh.surface_get_arrays(0)
	check(island.surface.garden_ground[remote_cell] == "courtyard")
	check(BuildingRules.place(garden, Vector2i(12, 11), "greenhouse").begins_with("Placed"))
	island.rebuild()
	check(island.surface.garden_ground[remote_cell] == "meadow")
	var after: Array = island.terrain_chunks[edge].mesh.surface_get_arrays(0)
	check(after[Mesh.ARRAY_COLOR] != before[Mesh.ARRAY_COLOR])
	garden.undo()
	island.rebuild()
	island.finish_growth()
	check(island.terrain_chunks[edge].mesh.surface_get_arrays(0) == before)
	island.free()
