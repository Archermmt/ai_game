extends Node3D
var data=IslandData.new()
var view=IslandView.new()
var sim=ResidentSim.new()
var wildlife=Wildlife.new()
var camera=Camera3D.new()
var environment=Environment.new()
var sun=DirectionalLight3D.new()
func add_object(p:Vector2i,kind:String,index:int) -> bool:
	var o={"id":data.next_id,"kind":kind,"x":p.x,"z":p.y,"rotation":0,"length":3,"color":0,"locked":kind=="house","variant":["basic","garden","coast"][index%3]}
	if not BuildingRules.check(data,o).is_empty():return false
	data.objects.append(o);data.next_id+=1;return true
func _ready() -> void:
	if DisplayServer.get_name()=="headless":push_error("Native GPU required");get_tree().quit(1);return
	get_window().content_scale_size=Vector2i.ZERO;get_window().content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;get_window().size=Vector2i(1920,1080)
	var seconds=300.0;var label="pressure"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--duration="):seconds=float(arg.trim_prefix("--duration="));label="pressure_smoke"
	var iteration="completion_r2"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--iteration="):iteration=arg.trim_prefix("--iteration=")
	var start=Time.get_ticks_usec()
	for x in range(12,52):
		for z in range(12,52):data.tiles[data.key(Vector2i(x,z))]={"h":1 if x in [12,51] or z in [12,51] else 2,"surface":"sand" if x in [12,51] or z in [12,51] else "grass","road":(z>=17 and z<=37 and (z-17)%5==0) or (x>=16 and x<=48 and (x-16)%4==0),"flower":false}
	var building_count=0
	for row in range(5):
		for col in range(8):
			var kind=["house","house","tea","greenhouse","lighthouse","house","house","house"][col]
			if not add_object(Vector2i(14+col*4,15+row*5),kind,building_count):push_error("Pressure building fixture is invalid");get_tree().quit(1);return
			building_count+=1
	var candidates:Array=[]
	for x in range(13,51):
		for z in range(13,51):
			var p=Vector2i(x,z)
			if not data.cell(p).road and not BuildingRules.occupied(data,p):candidates.append(p)
	candidates.sort_custom(func(a,b):return posmod(a.x*73856093+a.y*19349663,65521)<posmod(b.x*73856093+b.y*19349663,65521))
	var decoration_count=0
	for p in candidates:
		var kind="tree" if decoration_count%10<6 else "pot" if decoration_count%10<9 else "bench"
		if add_object(p,kind,decoration_count):decoration_count+=1
		if decoration_count==400:break
	if building_count!=40 or decoration_count!=400:push_error("Benchmark object counts differ from the fixture");get_tree().quit(1);return
	for o in data.objects:
		if o.kind=="house" and sim.people.size()<12:
			var p=RouteGraph.entrance(o);sim.people.append({"id":sim.next_id,"home":o.id,"x":float(p.x),"z":float(p.y),"state":"home","route":[],"timer":float(sim.next_id),"target":0,"activity":"","crossed":false});sim.next_id+=1
	add_child(view);view.setup(data);view.rebuild();add_child(wildlife);wildlife.setup(6);wildlife.surface=view.surface
	var env=WorldEnvironment.new();env.environment=environment;environment.background_mode=Environment.BG_COLOR;environment.background_color=Color("8bbcb9");environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_color=Color.WHITE;add_child(env)
	sun.rotation_degrees=Vector3(-48,-25,0);sun.shadow_enabled=true;sun.directional_shadow_max_distance=100;add_child(sun);IslandLighting.apply(sun,environment,false)
	add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=42;camera.current=true
	camera.position=Vector3(32,0,32)+Vector3(sin(0.55)*50,50,cos(0.55)*50);camera.look_at(Vector3(32,0,32));view.update_actors(sim,0)
	var build_ms=(Time.get_ticks_usec()-start)/1000.0
	for i in range(60):await get_tree().process_frame
	var samples:Array=[];var phase_samples:Array=[[],[]];var draw_peak=0;var primitive_peak=0;var frame_count=0
	var begin=Time.get_ticks_usec();var previous=begin;var last_capture=-1;var previous_night=false;var last_edit=0;var edit_samples:Array=[];var edit_phases:Array=[]
	print("PRESSURE_READY 40 buildings / 400 decorations / 12 residents / 6 animals")
	DirAccess.make_dir_recursive_absolute("res://snapshots/"+iteration+"/"+label)
	while Time.get_ticks_usec()-begin<int(seconds*1000000):
		var now=Time.get_ticks_usec();var elapsed=(now-begin)/1000000.0;var delta=(now-previous)/1000000.0;previous=now
		if frame_count>0:samples.append(delta*1000);phase_samples[1 if elapsed>=seconds/2 else 0].append(delta*1000)
		var edit_tick=int(elapsed/2.0)
		if edit_tick!=last_edit:
			var edit_start=Time.get_ticks_usec();data.paint([Vector2i(12,12)],"raise" if edit_tick%2==1 else "lower");view.rebuild();edit_phases.append(view.rebuild_profile.duplicate());edit_samples.append((Time.get_ticks_usec()-edit_start)/1000.0);last_edit=edit_tick
		var night=elapsed>=seconds/2
		if night!=previous_night:
			IslandLighting.apply(sun,environment,night);view.set_night(night)
			for lamp in get_tree().get_nodes_in_group("island_lanterns"):lamp.visible=night
			previous_night=night
		var angle=0.55+elapsed/seconds*TAU;camera.position=Vector3(32,0,32)+Vector3(sin(angle)*50,50,cos(angle)*50);camera.look_at(Vector3(32,0,32))
		view.update_environment(delta,true);sim.tick(data,delta);view.update_actors(sim,elapsed)
		await get_tree().process_frame
		draw_peak=maxi(draw_peak,get_viewport().get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME));primitive_peak=maxi(primitive_peak,get_viewport().get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME));frame_count+=1
		var minute=int(elapsed/60)
		if minute!=last_capture:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://snapshots/"+iteration+"/"+label+"/minute_%d.png"%minute);last_capture=minute;print("PRESSURE_PROGRESS ",minute," minutes; frames=",frame_count)
	samples.sort();edit_samples.sort();for phase in phase_samples:phase.sort()
	var report={"edit_phases":edit_phases,"edit_samples":edit_samples.size(),"edit_ms_p95":edit_samples[int(edit_samples.size()*0.95)] if not edit_samples.is_empty() else 0.0,"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"duration_wall_seconds":(Time.get_ticks_usec()-begin)/1000000.0,"build_ms":build_ms,"buildings":40,"decorations":400,"residents":sim.people.size(),"animals":wildlife.animals.size(),"frame_count":frame_count,"frame_ms_p50":samples[samples.size()/2],"frame_ms_p95":samples[int(samples.size()*0.95)],"day_frame_ms_p95":phase_samples[0][int(phase_samples[0].size()*0.95)],"night_frame_ms_p95":phase_samples[1][int(phase_samples[1].size()*0.95)],"draw_calls_peak":draw_peak,"visible_primitives_peak":primitive_peak,"engine_static_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"camera_orthographic_size":42,"grass_density_lod":0.55,"target_device_tested":false,"scope":("Five minute" if seconds>=300 else "Short smoke sample, not five minute")+" native M4 Pro pressure run; M1/8GB and Windows remain unverified"}
	DirAccess.make_dir_recursive_absolute("res://docs/reports/"+iteration);var f=FileAccess.open("res://docs/reports/"+iteration+"/"+label+".json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close();print("PRESSURE_PASS ",JSON.stringify(report));var tree=get_tree();queue_free();tree.create_timer(0.2).timeout.connect(tree.quit)
