extends Node3D
const CAMERAS={
	"harbor":{"center":[27,0,32],"size":19.0,"angle":0.55},
	"orbit":{"center":[27,0,32],"size":19.0,"angle":2.1207963268},
	"house":{"center":[29.5,1,30.5],"size":9.0,"angle":0.3},
	"shore":{"center":[22,0.3,33],"size":10.0,"angle":0.65},
	"whole":{"center":[31.5,0,34],"size":31.0,"angle":0.3},
	"sunset":{"center":[27,0,32],"size":19.0,"angle":0.55}}
var data=IslandData.new()
var view=IslandView.new()
var sim=ResidentSim.new()
var camera=Camera3D.new()
var sun=DirectionalLight3D.new()
var environment=Environment.new()
var args:Dictionary={}
func _ready() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Art lab requires a native GPU viewport");get_tree().quit(1);return
	get_window().content_scale_size=Vector2i.ZERO
	get_window().content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	get_window().size=Vector2i(1920,1080)
	for arg in OS.get_cmdline_user_args():
		if arg.contains("="):
			var pieces=arg.trim_prefix("--").split("=",true,1);args[pieces[0]]=pieces[1]
	var path="res://game/art_lab/fixtures/bay_baseline.json"
	if not FileAccess.file_exists(path):
		push_error("Missing committed art baseline fixture");get_tree().quit(1);return
	data.restore(JSON.parse_string(FileAccess.get_file_as_string(path)).world)
	add_child(view);view.setup(data);view.sea.material_override.set_shader_parameter("motion",0.0)
	var env=WorldEnvironment.new();environment.background_mode=Environment.BG_COLOR;environment.background_color=Color("8bbcb9")
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_color=Color.WHITE;environment.ambient_light_energy=0.5
	env.environment=environment;add_child(env)
	sun.rotation_degrees=Vector3(-48,-25,0);sun.light_color=Color("fff3de");sun.light_energy=0.9;sun.shadow_enabled=true;sun.directional_shadow_max_distance=70;add_child(sun)
	add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.current=true
	var wildlife=Wildlife.new();add_child(wildlife);wildlife.setup();wildlife.enabled=false
	for o in data.objects:
		if o.kind=="house":
			var p=RouteGraph.entrance(o);sim.people.append({"id":sim.next_id,"home":o.id,"x":float(p.x),"z":float(p.y),"state":"home","route":[],"timer":0.0,"target":0});sim.next_id+=1
	sim.paused=true;view.rebuild();view.update_actors(sim,0)
	var method=RenderingServer.get_current_rendering_method()
	var label=String(args.get("label",method));var iteration=String(args.get("iteration","art_i1"));var folder="res://snapshots/"+iteration+"/"+label
	DirAccess.make_dir_recursive_absolute(folder)
	var result={"engine":Engine.get_version_info().string,"renderer":method,"driver":RenderingServer.get_current_rendering_driver_name(),"resolution":[1920,1080],"fixture_sha256":FileAccess.get_sha256(path),"camera_specs":CAMERAS,"frozen":true,"label":label,"views":{},"batch_stats":view.batch_stats,"tiles":data.tiles.size(),"objects":data.objects.size(),"people":sim.people.size(),"scope":"Fixed bay / native renderer parity lab; not full PRD pressure scene"}
	result.focus_bounds_xz={"min":[19,24],"max_exclusive":[35,40],"unit_m":1}
	for id in CAMERAS:
		var spec=CAMERAS[id];var c=spec.center;var center=Vector3(c[0],c[1],c[2]);camera.size=spec.size
		camera.position=center+Vector3(sin(spec.angle)*38,38,cos(spec.angle)*38);camera.look_at(center)
		var sunset=id=="sunset";IslandLighting.apply(sun,environment,sunset)
		for lamp in get_tree().get_nodes_in_group("island_lanterns"):lamp.visible=sunset
		for i in range(12):await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image=get_viewport().get_texture().get_image();var err=image.save_png(folder+"/"+id+".png")
		if err!=OK:push_error("Capture failed "+id);get_tree().quit(1);return
		result.views[id]={"path":folder+"/"+id+".png","draw_calls":get_viewport().get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),"sha256":FileAccess.get_sha256(folder+"/"+id+".png")}
	# Same sample and duration for both native renderers, no simulated fixed-FPS timing.
	var samples:Array=[];var previous=Time.get_ticks_usec()
	for i in range(180):
		await get_tree().process_frame
		var now=Time.get_ticks_usec()
		if i>=30:samples.append((now-previous)/1000.0)
		previous=now
	samples.sort();result.frame_samples=samples.size();result.frame_ms_p50=samples[samples.size()/2];result.frame_ms_p95=samples[int(samples.size()*0.95)]
	var before=data.snapshot();var edits:Array=[]
	for i in range(7):
		var begin=Time.get_ticks_usec();data.paint([Vector2i(18,20+i)],"grass");view.rebuild();edits.append((Time.get_ticks_usec()-begin)/1000.0)
	data.restore(before);view.rebuild();edits.sort();result.edit_rebuild_ms_p95=edits[int(edits.size()*0.95)]
	result.engine_static_bytes=Performance.get_monitor(Performance.MEMORY_STATIC)
	result.world_unchanged=data.snapshot()==before
	DirAccess.make_dir_recursive_absolute("res://docs/reports/"+iteration)
	var f=FileAccess.open("res://docs/reports/"+iteration+"/"+label+".json",FileAccess.WRITE);f.store_string(JSON.stringify(result,"  "));f.close()
	print("ART_LAB_PASS ",label," ",JSON.stringify(result));get_tree().quit(0 if result.world_unchanged else 1)
