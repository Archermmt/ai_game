extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var app=load("res://game/island.tscn").instantiate();root.add_child(app);app.close_modal();app.sim.paused=false
	var frames:Array=[];var edits:Array=[]
	for i in range(210):
		var begin=Time.get_ticks_usec()
		await process_frame
		if i>30:frames.append((Time.get_ticks_usec()-begin)/1000.0)
		if i%30==0:
			begin=Time.get_ticks_usec();app.data.paint([Vector2i(18,i/30+20)],"grass");app.rebuild();edits.append((Time.get_ticks_usec()-begin)/1000.0)
	frames.sort();edits.sort()
	var report={"scope":"Prepared playable bay smoke profile; not PRD full pressure scene", "engine":Engine.get_version_info().string,"renderer":"Compatibility", "resolution":str(root.size),"samples":frames.size(),"frame_ms_p50":frames[frames.size()/2],"frame_ms_p95":frames[int(frames.size()*0.95)],"edit_rebuild_ms_p95":edits[int(edits.size()*0.95)],"visible_draw_calls":root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),"engine_static_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"people":app.sim.people.size(),"objects":app.data.objects.size(),"tiles":app.data.tiles.size(),"unix_time":Time.get_unix_time_from_system()}
	DirAccess.make_dir_recursive_absolute("res://docs/reports")
	var file=FileAccess.open("res://docs/reports/playable_profile.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify(report))
	app.free();quit()
