extends Node3D
var data=IslandData.new()
var view=IslandView.new()
var sim=ResidentSim.new()
var wildlife=Wildlife.new()
var camera=Camera3D.new()
var environment=Environment.new()
var sun=DirectionalLight3D.new()
var deadline_usec=0
var capture_tasks:Array=[]
var capture_paths:Array=[]
static func save_capture(image:Image,path:String) -> void:
	var error=image.save_png(path)
	if error!=OK:push_error("Benchmark capture failed: "+path)
func _process(_delta:float) -> void:
	# Keep a live render update while _ready awaits a draw callback. In an
	# unfocused preview, an unchanged frame may otherwise be skipped by the OS.
	if is_instance_valid(view.sea):view.sea.material_override.set_shader_parameter("clock",Time.get_ticks_usec()/1000000.0)
	if deadline_usec>0 and Time.get_ticks_usec()>deadline_usec:
		push_error("Benchmark timed out waiting for rendered frames; repeat without suspension");get_tree().quit(3)
func add_object(p:Vector2i,kind:String,index:int) -> bool:
	var o={"id":data.next_id,"kind":kind,"x":p.x,"z":p.y,"rotation":0,"length":3,"color":0,"locked":kind=="house","variant":["basic","garden","coast"][index%3]}
	if not BuildingRules.check(data,o).is_empty():return false
	data.objects.append(o);data.next_id+=1;return true
func _ready() -> void:
	if DisplayServer.get_name()=="headless":push_error("Native GPU required");get_tree().quit(1);return
	get_window().content_scale_size=Vector2i.ZERO;get_window().content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;get_window().size=Vector2i(1920,1080)
	var compact=OS.get_cmdline_user_args().has("--compact")
	if compact:
		get_window().content_scale_size=Vector2i(1920,1080);get_window().content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT;get_window().size=Vector2i(640,360);get_window().always_on_top=true;get_window().unfocusable=true
		get_window().position=DisplayServer.screen_get_usable_rect().end-get_window().size-Vector2i(16,16)
	get_tree().auto_accept_quit=false
	get_window().close_requested.connect(func():print("BENCHMARK_INTERRUPTED window closed before completion");get_tree().quit(2))
	var seconds=300.0;var label="pressure"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--duration="):seconds=float(arg.trim_prefix("--duration="));label="pressure_smoke"
	var iteration="exported_benchmark";var destination="user://benchmarks/run_%d"%Time.get_ticks_usec();var quality="medium"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--iteration="):iteration=arg.trim_prefix("--iteration=")
	for arg in OS.get_cmdline_user_args():
		if arg=="--quality=low":quality="low"
	seconds=clampf(seconds,10,600);deadline_usec=Time.get_ticks_usec()+int((seconds+60)*1000000)
	var start=Time.get_ticks_usec()
	for x in range(12,52):
		for z in range(17,47):data.tiles[data.key(Vector2i(x,z))]={"h":1 if x in [12,51] or z in [17,46] else 2,"surface":"sand" if x in [12,51] or z in [17,46] else "grass","road":(z>=21 and z<=41 and (z-21)%5==0) or (x>=16 and x<=48 and (x-16)%4==0),"flower":false}
	var building_count=0
	for row in range(5):
		for col in range(8):
			var kind="house" if building_count<12 else ["tea","greenhouse","lighthouse"][(building_count-12)%3]
			if not add_object(Vector2i(14+col*4,19+row*5),kind,building_count):push_error("Benchmark building fixture is invalid");get_tree().quit(1);return
			building_count+=1
	var candidates:Array=[]
	for x in range(13,51):
		for z in range(18,46):
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
	if data.tiles.size()!=1200 or data.objects.size()!=440 or sim.people.size()!=12:push_error("Benchmark must contain exactly 1200 land cells, 440 objects and 12 residents");get_tree().quit(1);return
	add_child(view);view.setup(data);view.detail_density=0.6 if quality=="low" else 1.0;view.rebuild();add_child(wildlife);wildlife.setup(6);wildlife.surface=view.surface
	var env=WorldEnvironment.new();env.environment=environment;environment.background_mode=Environment.BG_COLOR;environment.background_color=Color("8bbcb9");environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_color=Color.WHITE;add_child(env)
	sun.rotation_degrees=Vector3(-48,-25,0);sun.shadow_enabled=true;sun.directional_shadow_max_distance=100;add_child(sun);IslandLighting.apply(sun,environment,false);sun.shadow_enabled=quality!="low"
	add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=42;camera.current=true
	camera.position=Vector3(32,0,32)+Vector3(sin(0.55)*50,50,cos(0.55)*50);camera.look_at(Vector3(32,0,32));view.update_actors(sim,0)
	var build_ms=(Time.get_ticks_usec()-start)/1000.0
	for i in range(60):await get_tree().process_frame
	var samples:Array=[];var phase_samples:Array=[[],[]];var edit_samples:Array=[];var edit_cpu:Array=[];var edit_profiles:Array=[]
	var begin=Time.get_ticks_usec();var previous=begin;var previous_night=false;var last_edit=0;var last_title_second=-1
	var observed={"last_draw":0,"frames":0,"draw_peak":0,"primitive_peak":0,"pending_edit":0,"capture_request":-1,"last_capture":-1,"capture_error":false}
	DirAccess.make_dir_recursive_absolute(destination+"/captures")
	print("PRESSURE_READY 40 buildings / 400 decorations / 12 residents / 6 animals");print("BENCHMARK_DIRECTORY ",ProjectSettings.globalize_path(destination))
	var layer=CanvasLayer.new();add_child(layer);var status=Label.new();status.position=Vector2(20,20);status.add_theme_font_override("font",preload("res://game/ui/fonts/noto_sans_cjk_sc_regular.otf"));status.add_theme_font_size_override("font_size",22);layer.add_child(status)
	# Observe completed draws without suspending simulation at that signal.
	var on_render=func():
		var now=Time.get_ticks_usec();var elapsed=(now-begin)/1000000.0
		if observed.last_draw>0:
			var frame_ms=(now-int(observed.last_draw))/1000.0;samples.append(frame_ms);phase_samples[1 if elapsed>=seconds/2 else 0].append(frame_ms)
		observed.last_draw=now;observed.frames+=1
		observed.draw_peak=maxi(observed.draw_peak,get_viewport().get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME));observed.primitive_peak=maxi(observed.primitive_peak,get_viewport().get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME))
		if observed.pending_edit>0:edit_samples.append((now-int(observed.pending_edit))/1000.0);observed.pending_edit=0
		var minute=int(observed.capture_request)
		if minute>=0 and minute!=int(observed.last_capture):
			var capture=get_viewport().get_texture().get_image()
			if capture.get_size()!=Vector2i(1920,1080):observed.capture_error=true;return
			var path=destination+"/captures/minute_%d.png"%minute;capture_paths.append(path);capture_tasks.append(WorkerThreadPool.add_task(save_capture.bind(capture,path)))
			observed.last_capture=minute;print("PRESSURE_PROGRESS ",minute," minutes; frames=",observed.frames," edits=",edit_samples.size())
	RenderingServer.frame_post_draw.connect(on_render)
	while Time.get_ticks_usec()-begin<int(seconds*1000000):
		var now=Time.get_ticks_usec();var elapsed=(now-begin)/1000000.0;var delta=(now-previous)/1000000.0;previous=now
		status.text="性能验证 · %s · 40建筑 / 400装饰 / 12岛民 / 6动物\n%.0f / %.0f 秒 · 每2秒编辑一次 · 完成后自动退出"%[quality,elapsed,seconds]
		if int(elapsed)!=last_title_second:
			last_title_second=int(elapsed);get_window().title="风屿性能测试 · %d / %d 秒 · 完成自动关闭"%[int(elapsed),int(seconds)]
		var edit_tick=int(elapsed/2.0)
		if edit_tick!=last_edit and int(observed.pending_edit)==0:
			var edit_start=Time.get_ticks_usec();observed.pending_edit=edit_start
			data.paint([Vector2i(12,17)],"raise" if int(data.cell(Vector2i(12,17)).h)==1 else "lower");view.rebuild();edit_cpu.append((Time.get_ticks_usec()-edit_start)/1000.0);edit_profiles.append(view.rebuild_profile.duplicate());last_edit=edit_tick
		var night=elapsed>=seconds/2
		if night!=previous_night:
			IslandLighting.apply(sun,environment,night);view.set_night(night)
			for lamp in get_tree().get_nodes_in_group("island_lanterns"):lamp.visible=night
			previous_night=night
		var angle=0.55+elapsed/seconds*TAU;camera.position=Vector3(32,0,32)+Vector3(sin(angle)*50,50,cos(angle)*50);camera.look_at(Vector3(32,0,32))
		view.update_environment(delta,true);sim.tick(data,delta);view.update_actors(sim,elapsed)
		observed.capture_request=int(elapsed/60)
		await get_tree().process_frame
	RenderingServer.frame_post_draw.disconnect(on_render)
	var frame_count=int(observed.frames);var draw_peak=int(observed.draw_peak);var primitive_peak=int(observed.primitive_peak)
	for task in capture_tasks:WorkerThreadPool.wait_for_task_completion(task)
	var land_count=0
	for cell in data.tiles.values():
		if int(cell.h)>0:land_count+=1
	var coverage={"edit_cpu_ms":edit_cpu,"edit_samples_ms":edit_samples,"pending_edit_usec":observed.pending_edit,"capture_error":observed.capture_error,"land_cells":land_count,"frames":frame_count,"edits":edit_samples.size(),"day_frames":phase_samples[0].size(),"night_frames":phase_samples[1].size(),"elapsed_wall_seconds":(Time.get_ticks_usec()-begin)/1000000.0,"last_edit_tick":last_edit,"captures":capture_paths.size()}
	var diagnostic=FileAccess.open(destination+"/diagnostic.json",FileAccess.WRITE);diagnostic.store_string(JSON.stringify(coverage,"  "));diagnostic.close();print("BENCHMARK_COVERAGE ",JSON.stringify(coverage))
	for path in capture_paths:
		if not FileAccess.file_exists(path):push_error("Missing benchmark capture: "+path);get_tree().quit(1);return
	if int(observed.pending_edit)>0 or bool(observed.capture_error) or land_count!=1200 or samples.is_empty() or phase_samples[0].is_empty() or phase_samples[1].is_empty() or edit_samples.size()<maxi(1,int(seconds/2)-10):
		push_error("Benchmark interrupted: missing day/night/frame/edit samples; repeat without suspension");get_tree().quit(1);return
	samples.sort();edit_samples.sort();edit_cpu.sort();for phase in phase_samples:phase.sort()
	var report={"preview_mode":"compact" if compact else "full","render_resolution":[1920,1080],"edit_samples_ms":edit_samples,"edit_cpu_ms_p95":edit_cpu[int(edit_cpu.size()*0.95)] if not edit_cpu.is_empty() else 0.0,"edit_profiles":edit_profiles,"edit_measurement":"paint + rebuild through RenderingServer.frame_post_draw; excludes OS compositor/display latency","land_cells":land_count,"source_tile_records":data.tiles.size(),"quality":quality,"platform":OS.get_name(),"cpu":OS.get_processor_name(),"device":RenderingServer.get_video_adapter_name(),"edit_samples":edit_samples.size(),"edit_ms_p95":edit_samples[int(edit_samples.size()*0.95)] if not edit_samples.is_empty() else 0.0,"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"duration_wall_seconds":(Time.get_ticks_usec()-begin)/1000000.0,"build_ms":build_ms,"buildings":building_count,"decorations":decoration_count,"residents":sim.people.size(),"animals":wildlife.animals.size(),"frame_count":frame_count,"frame_ms_p50":samples[samples.size()/2],"frame_ms_p95":samples[int(samples.size()*0.95)],"day_frame_ms_p95":phase_samples[0][int(phase_samples[0].size()*0.95)],"night_frame_ms_p95":phase_samples[1][int(phase_samples[1].size()*0.95)],"draw_calls_peak":draw_peak,"visible_primitives_peak":primitive_peak,"engine_static_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"camera_orthographic_size":42,"grass_density_lod":0.55*view.detail_density,"target_device_tested":false,"scope":("Five minute" if seconds>=300 else "Short smoke sample, not five minute")+" exported benchmark on this device; not acceptance on any other device"}
	DirAccess.make_dir_recursive_absolute(destination);var f=FileAccess.open(destination+"/report.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close();print("BENCHMARK_REPORT ",ProjectSettings.globalize_path(destination+"/report.json"));print("PRESSURE_PASS ",JSON.stringify(report));var tree=get_tree();queue_free();tree.create_timer(0.2).timeout.connect(tree.quit)
