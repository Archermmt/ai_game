extends SceneTree
var checks=0
var failed=false
func check(value:bool) -> void:
	checks+=1
	if not value:failed=true;push_error("surface check failed %d"%checks);quit(1)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var data=IslandData.new();DemoIsland.create(data)
	var before=data.snapshot();var s=IslandSurface.new(before)
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
	view.free();print("PASS surface consistency, undo/reload, unchanged chunk identity, empty cleanup (",checks," checks)");quit(1 if failed else 0)
