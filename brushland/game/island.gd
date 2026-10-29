extends Node3D
var data=IslandData.new()
var sim=ResidentSim.new()
var view=IslandView.new()
var wildlife=Wildlife.new()
var audio=IslandAudio.new()
var reduced_motion=false
var hud=IslandHud.new()
var camera=Camera3D.new()
var sun=DirectionalLight3D.new()
var world_env=WorldEnvironment.new()
var preview=Node3D.new()
var tool:String="grass"
var radius:int=1
var span:int=3
var placement_rotation:int=0
var moving_id:int=0
var angle:float=0.3
var center=Vector3(31.5,0,33)
var stroke:Array=[]
var dragging=false
var time:float=0
var autosave_clock:float=0
var capturing=false
var photo_mode=false
var photo_previous_paused=false
var photo_hint=Label.new()
var modal:Control
var selected:Dictionary={}
func _ready() -> void:
	get_tree().auto_accept_quit=false
	capturing=OS.get_cmdline_user_args().has("--capture")
	DemoIsland.create(data)
	if OS.get_cmdline_user_args().has("--empty"):data.clear_world()
	add_child(view);view.setup(data);add_child(preview)
	add_child(wildlife);wildlife.setup()
	var env=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color("8bbcb9")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color.WHITE;env.ambient_light_energy=0.5
	world_env.environment=env;add_child(world_env)
	sun.rotation_degrees=Vector3(-48,-25,0);sun.light_color=Color("fff3de");sun.light_energy=0.9;sun.shadow_enabled=true;sun.directional_shadow_max_distance=70;add_child(sun)
	add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=30.5;camera.current=true;update_camera()
	add_child(audio)
	add_child(hud);hud.add_child(photo_hint);photo_hint.text="拍照模式 · Q/E 转向 · 滚轮缩放 · F12 保存 · Esc 返回";photo_hint.position=Vector2(30,24);photo_hint.visible=false
	hud.tool_selected.connect(select_tool);hud.action_requested.connect(action)
	for o in data.objects:
		if o.kind=="house":
			var p=RouteGraph.entrance(o)
			sim.people.append({"id":sim.next_id,"home":o.id,"x":float(p.x),"z":float(p.y),"state":"home","route":[],"timer":float(sim.next_id),"target":0,"activity":"","crossed":false});sim.next_id+=1
	rebuild();set_sunset(false)
	if capturing:
		for i in range(16):sim.tick(data,0.5)
		await get_tree().process_frame;await get_tree().process_frame
		view.update_actors(sim,time)
		await RenderingServer.frame_post_draw
		var target="res://snapshots/playable_day.png"
		if OS.get_cmdline_user_args().has("--sunset"):set_sunset(true);target="res://snapshots/playable_sunset.png"
		if OS.get_cmdline_user_args().has("--photo"):hud.root.visible=false;target="res://snapshots/playable_photo.png"
		if OS.get_cmdline_user_args().has("--welcome"):welcome();target="res://snapshots/playable_welcome.png"
		if OS.get_cmdline_user_args().has("--menu"):save_menu();target="res://snapshots/playable_menu.png"
		await RenderingServer.frame_post_draw
		var err=get_viewport().get_texture().get_image().save_png(target)
		print("CAPTURE ",target," ",error_string(err));get_tree().quit()
	else:welcome()
func select_tool(id:String) -> void:
	audio.effect("click")
	tool=id;dragging=false;stroke.clear();moving_id=0
	hud.toast({"house":"在平整的 2×2 草地上放一座小屋，门前接上小路","dock":"从一至二级海岸向海延伸；R 旋转，−/+ 调长度","bridge":"选择第一端岸边，R 转向、−/+ 调跨度，两岸须同高","flower":"在小屋外圈画三格花圃，试试它的新模样","move":"先点物件，再点新位置；右键取消","lock":"点击小屋，保留 / 解锁当前外观","color":"点击建筑，更换屋顶配色"}.get(id,"选择了"+IslandHud.NAMES[id]));refresh_preview()
func rebuild() -> void:
	sim.reconcile(data);view.day=not sim.sunset;view.rebuild();view.update_actors(sim,time);hud.refresh_journal(sim.completed);refresh_preview()
func update_camera() -> void:
	center.x=clampf(center.x,8,56);center.z=clampf(center.z,8,56)
	camera.position=center+Vector3(sin(angle)*38,38,cos(angle)*38);camera.look_at(center)
func pick() -> Vector2i:
	var mouse=get_viewport().get_mouse_position();var origin=camera.project_ray_origin(mouse);var dir=camera.project_ray_normal(mouse)
	# Solve against the same derived surface used for rendering and feet.
	if view.surface!=null:
		var previous=origin
		for i in range(1,801):
			var point=origin+dir*(i*0.15)
			if point.y<=view.surface.height_at(Vector2(point.x,point.z)):
				var lo=previous;var hi=point
				for step in range(10):
					var mid=(lo+hi)*0.5
					if mid.y>view.surface.height_at(Vector2(mid.x,mid.z)):lo=mid
					else:hi=mid
				return Vector2i(roundi(hi.x),roundi(hi.z))
			previous=point
	return Vector2i(-1,-1)
func prototype(p:Vector2i) -> Dictionary:
	return {"id":0,"x":p.x,"z":p.y,"kind":tool,"rotation":placement_rotation,"length":span,"locked":false}
func refresh_preview() -> void:
	for n in preview.get_children():n.free()
	if photo_mode or modal!=null:return
	var p=pick()
	if not BuildingRules.inside(p):return
	var cells:Array=[];var valid=true
	if tool=="move" and moving_id!=0:
		var o=sim.object_by_id(data,moving_id).duplicate(true)
		if not o.is_empty():o.x=p.x;o.z=p.y;cells=BuildingRules.footprint(o);valid=BuildingRules.check(data,o,moving_id).is_empty()
	elif tool in BuildingRules.TOOLS:
		var o=prototype(p);cells=BuildingRules.footprint(o);valid=BuildingRules.check(data,o).is_empty()
	elif dragging:cells=stroke
	else:
		for x in range(-radius,radius+1):
			for z in range(-radius,radius+1):
				if x*x+z*z<=radius*radius:cells.append(p+Vector2i(x,z))
	for q in cells:
		if not BuildingRules.inside(q):continue
		var protected=BuildingRules.occupied(data,q,tool!="road") and not tool in BuildingRules.TOOLS
		var color=Color("d4b28d") if not valid or protected else Color("cdddb2")
		view.kit.box(preview,Vector3(q.x,float(data.cell(q).h)*0.5+0.045,q.y),Vector3(0.88,0.035,0.88),color)
func collect() -> void:
	var p=pick()
	for x in range(-radius,radius+1):
		for z in range(-radius,radius+1):
			var q=p+Vector2i(x,z)
			if x*x+z*z<=radius*radius and not stroke.has(q):stroke.append(q)
func commit_stroke() -> void:
	var p=pick()
	var regions=resident_regions()
	if tool in BuildingRules.TOOLS:
		var result=BuildingRules.place(data,p,tool,placement_rotation,span)
		hud.toast("已放下"+IslandHud.NAMES[tool] if result.begins_with("Placed") else result)
	elif tool=="move":move_object(p)
	elif tool in ["erase","lock","color"]:
		var found=false
		for o in data.objects:
			if p not in BuildingRules.footprint(o):continue
			found=true;data.begin()
			if tool=="erase":data.objects.erase(o);hud.toast("已移除，可随时撤销")
			elif tool=="color":o.color=(int(o.get("color",0))+1)%3;hud.toast("换了一种屋顶颜色")
			elif o.kind=="house":o.variant=BuildingRules.variant(data,o);o.locked=not o.locked;hud.toast("已保留外观" if o.locked else "外观将随周围环境变化")
			break
		if not found and tool=="erase":
			data.begin()
			for q in stroke:
				var c=data.cell(q).duplicate();c.road=false;c.flower=false;data.tiles[data.key(q)]=c
	else:
		var blocked=0
		for q in stroke:
			if BuildingRules.occupied(data,q,tool!="road"):blocked+=1
		data.paint(stroke,tool)
		if blocked>0:hud.toast("保留了 %d 格支撑 / 入口；先移动上面的物件再改地形"%blocked)
	audio.effect("place" if tool in BuildingRules.TOOLS else "paint")
	stroke.clear();protect_residents(regions);rebuild()
func _input(event:InputEvent) -> void:
	# A release over UI must end the world stroke as well; never leave a brush stuck.
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed and dragging:
		dragging=false
		if get_viewport().gui_get_hovered_control()!=null:stroke.clear();refresh_preview()
		else:commit_stroke()
func _unhandled_input(event:InputEvent) -> void:
	if modal!=null:return
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP:camera.size=maxf(13,camera.size-1.5)
		if event.button_index==MOUSE_BUTTON_WHEEL_DOWN:camera.size=minf(58,camera.size+1.5)
		if event.button_index==MOUSE_BUTTON_RIGHT:stroke.clear();dragging=false;moving_id=0;hud.toast("已取消")
		if event.button_index==MOUSE_BUTTON_LEFT and event.pressed and not photo_mode:dragging=true;stroke.clear();collect()
	if event is InputEventMouseMotion:
		if dragging:collect()
		refresh_preview()
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R:placement_rotation=(placement_rotation+1)%4
			KEY_MINUS:span=maxi(2,span-1)
			KEY_EQUAL:span=mini(6,span+1)
			KEY_SPACE:action("pause")
			KEY_Q:angle-=PI/2
			KEY_E:angle+=PI/2
			KEY_W:center.z-=1.5
			KEY_S:center.z+=1.5
			KEY_A:center.x-=1.5
			KEY_D:center.x+=1.5
			KEY_BRACKETLEFT:radius=maxi(1,radius-1)
			KEY_BRACKETRIGHT:radius=mini(3,radius+1)
			KEY_TAB:hud.card.visible=not hud.card.visible
			KEY_P:action("photo")
			KEY_F12:action("capture")
			KEY_ESCAPE:
				if photo_mode:action("photo")
				else:stroke.clear();dragging=false;moving_id=0
			KEY_Z:
				if event.ctrl_pressed or event.meta_pressed:action("redo" if event.shift_pressed else "undo")
		update_camera();refresh_preview()
func _process(dt:float) -> void:
	wildlife.enabled=not sim.paused and not reduced_motion
	view.update_environment(dt,not sim.paused and not reduced_motion and not photo_mode)
	if not sim.paused:time+=dt
	sim.tick(data,dt);view.update_actors(sim,time);autosave_clock+=dt
	if not sim.events.is_empty():
		for key in sim.events:hud.toast("收录了新的日常："+IslandHud.JOURNAL[key][0])
		audio.effect("journal");sim.events.clear();hud.refresh_journal(sim.completed)
	hud.refresh_status(sim.people.size(),tool,radius,span,sim.paused)
	if autosave_clock>=60 and not dragging and modal==null:
		autosave_clock=0
		var err=SaveStore.save_game(data,sim)
		if err!=OK:hud.toast("自动保存失败，请打开存档面板重试："+error_string(err))
func action(id:String) -> void:
	audio.effect("undo" if id in ["undo","redo"] else "click")
	match id:
		"undo":
			var regions=resident_regions();data.undo();protect_residents(regions);rebuild();hud.toast("已撤销")
		"redo":
			var regions=resident_regions();data.redo();protect_residents(regions);rebuild();hud.toast("已重做")
		"pause":sim.paused=not sim.paused
		"sunset":set_sunset(not sim.sunset)
		"photo":
			dragging=false;stroke.clear();moving_id=0
			if not photo_mode:photo_previous_paused=sim.paused
			photo_mode=not photo_mode;hud.root.visible=not photo_mode;sim.paused=true if photo_mode else photo_previous_paused;photo_hint.visible=photo_mode
			refresh_preview()
			if photo_mode:action("capture")
		"capture":save_photo()
		"menu":save_menu()
func set_sunset(value:bool) -> void:
	if is_instance_valid(audio) and audio.is_inside_tree():audio.set_evening(value)
	view.day=not value
	for lamp in get_tree().get_nodes_in_group("island_lanterns"):lamp.visible=value
	sim.sunset=value;IslandLighting.apply(sun,world_env.environment,value)
func move_object(p:Vector2i) -> void:
	if moving_id==0:
		for o in data.objects:
			if p in BuildingRules.footprint(o):moving_id=int(o.id);hud.toast("再点击新位置；右键取消");return
		return
	for o in data.objects:
		if o.id!=moving_id:continue
		var replacement=o.duplicate(true);replacement.x=p.x;replacement.z=p.y
		var error=BuildingRules.check(data,replacement,moving_id)
		if not error.is_empty():hud.toast(error);return
		data.begin();o.x=p.x;o.z=p.y;moving_id=0;hud.toast("已移动");return
func save_photo() -> void:
	var was_visible=hud.root.visible;var hint_visible=photo_hint.visible;hud.root.visible=false;photo_hint.visible=false
	for n in preview.get_children():n.hide()
	await RenderingServer.frame_post_draw
	var folder="user://photos";DirAccess.make_dir_recursive_absolute(folder)
	var path=folder+"/island_%d.png"%Time.get_unix_time_from_system()
	var err=get_viewport().get_texture().get_image().save_png(path)
	hud.root.visible=not photo_mode;photo_hint.visible=photo_mode
	for n in preview.get_children():n.show()
	hud.toast("照片已保存："+ProjectSettings.globalize_path(path) if err==OK else "保存照片失败："+error_string(err))
func open_modal(title:String) -> VBoxContainer:
	if modal!=null:modal.queue_free()
	modal=Control.new();hud.root.add_child(modal);modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade=ColorRect.new();shade.color=Color(0.15,0.27,0.25,0.35);modal.add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel=PanelContainer.new();modal.add_child(panel);panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER);panel.offset_left=-220;panel.offset_right=220;panel.offset_top=-210;panel.offset_bottom=210
	panel.add_theme_stylebox_override("panel",hud.style(Color("f7f1df")))
	var col=VBoxContainer.new();col.add_theme_constant_override("separation",10);panel.add_child(col);col.add_child(hud.label(title,27));return col
func close_modal() -> void:
	if modal!=null:modal.queue_free();modal=null
func welcome() -> void:
	sim.paused=true
	var col=open_modal("欢迎来到风屿")
	var text=hud.label("画一段海岸，留一盏灯。\n\n工具全部免费，喜欢的风景可以随时改。\n小屋旁添三格花，试试它的新模样。\n\n先走进准备好的海湾，或从一片海开始。",17);col.add_child(text)
	hud.button(col,"走进海湾",func():close_modal();sim.paused=false;hud.toast("先添一片花圃，或在建造栏放下一间新屋"))
	if FileAccess.file_exists("user://island.json"):hud.button(col,"继续上次的岛",func():load_slot("user://island.json");close_modal())
	hud.button(col,"空白海面",func():data.clear_world();sim=ResidentSim.new();close_modal();rebuild())
func load_slot(path:String) -> void:
	var err=SaveStore.load_game(data,sim,path)
	if err==OK:set_sunset(sim.sunset);rebuild();hud.toast("岛屿已恢复");sim.paused=false
	else:hud.toast("无法读取，当前作品保持不变："+error_string(err))
func save_menu() -> void:
	var col=open_modal("岛屿存档")
	for slot in range(1,4):
		var row=HBoxContainer.new();col.add_child(row);row.add_child(hud.label("手动槽 %d"%slot))
		var path="user://slot_%d.json"%slot
		hud.button(row,"保存",func():hud.toast("保存："+error_string(SaveStore.save_game(data,sim,path))))
		hud.button(row,"读取",func():load_slot(path))
	hud.button(col,"读取最近自动保存",func():load_slot("user://island.json"))
	hud.button(col,"恢复自动保存的上一备份",func():load_slot("user://island.json.bak"))
	hud.button(col,"打开照片文件夹",func():DirAccess.make_dir_recursive_absolute("user://photos");OS.shell_open(ProjectSettings.globalize_path("user://photos")))
	hud.button(col,"声音（当前："+("开" if audio.enabled else "关")+"）",func():audio.toggle();close_modal();save_menu())
	hud.button(col,"减少环境动画（当前："+("开" if reduced_motion else "关")+"）",func():reduced_motion=not reduced_motion;view.sea.material_override.set_shader_parameter("motion",0.0 if reduced_motion else 1.0);close_modal();save_menu())
	hud.button(col,"返回海湾",close_modal)
func _notification(what:int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST:
		var err=SaveStore.save_game(data,sim)
		if err!=OK:hud.toast("退出保存失败，请重试："+error_string(err));return
		get_tree().quit()

func resident_regions() -> Dictionary:
	var regions:Dictionary={}
	for person in sim.people:
		var p=Vector2i(roundi(person.x),roundi(person.z));var todo:Array=[p];var visited:Dictionary={p:true};var at=0
		if data.cell(p).h==0:
			for o in data.objects:
				if o.kind=="bridge" and p in BuildingRules.footprint(o):todo=[Vector2i(o.x,o.z)];visited={todo[0]:true};break
		while at<todo.size():
			var cell:Vector2i=todo[at];at+=1
			for q in RouteGraph.neighbors(data,cell):
				if not visited.has(q):visited[q]=true;todo.append(q)
		regions[int(person.id)]=visited
	return regions
func protect_residents(regions:Dictionary) -> void:
	for person in sim.people:
		var p=Vector2i(roundi(person.x),roundi(person.z))
		if data.cell(p).h>0:continue
		var on_bridge=false
		for o in data.objects:
			if o.kind=="bridge" and p in BuildingRules.footprint(o):on_bridge=true;break
		if on_bridge:continue
		var nearest=Vector2i(-1,-1);var distance=INF
		for q in regions.get(int(person.id),{}):
			if data.cell(q).h>0 and data.cell(q).road and Vector2(q).distance_to(Vector2(person.x,person.z))<distance:
				nearest=q;distance=Vector2(q).distance_to(Vector2(person.x,person.z))
		person.route=[];person.target=0
		if nearest.x>=0:person.x=float(nearest.x);person.z=float(nearest.y);person.state="waiting"
		else:person.state="resting"
