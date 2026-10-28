extends Node3D
var data = IslandData.new()
var terrain = Node3D.new()
var camera = Camera3D.new()
var tool: String = "grass"
var radius: int = 1
var stroke: Array = []
var dragging: bool = false
var angle: float = 0.65
var center=Vector3(32,0,32)
var hint=Label.new()
var preview=Node3D.new()
var stage: int = 3
var sim=ResidentSim.new()
var actors=Node3D.new()
var autosave_clock:float=0
var feedback=Label.new()
var moving_id:int=0
var placement_rotation: int = 0
var span: int = 3
func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--week="): stage=int(arg.trim_prefix("--week="))
	data.seed_island()
	if OS.get_cmdline_user_args().has("--capture") and stage>=2: seed_village()
	add_child(terrain); add_child(preview); add_child(actors)
	var env=WorldEnvironment.new(); var e=Environment.new()
	e.background_mode=Environment.BG_COLOR; e.background_color=Color("b8d5d0")
	e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color=Color("fff0d6"); e.ambient_light_energy=0.35
	env.environment=e; add_child(env)
	var sun=DirectionalLight3D.new(); sun.rotation_degrees=Vector3(-50,-25,0); sun.light_color=Color("fff0d6"); sun.light_energy=0.65; sun.shadow_enabled=true; add_child(sun)
	add_child(camera); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=36; camera.current=true; update_camera()
	box(self,Vector3(32,-0.3,32),Vector3(150,0.2,150),Color("86bdbb"))
	build_ui(); rebuild()
	if stage>=3 and OS.get_cmdline_user_args().has("--capture"):
		for i in range(36):sim.tick(data,1.0)
		draw_residents()
	if OS.get_cmdline_user_args().has("--capture"):
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var err=get_viewport().get_texture().get_image().save_png("res://snapshots/week_%02d.png"%stage)
		print("SNAPSHOT ",err); get_tree().quit()
func box(parent: Node3D,pos: Vector3,size: Vector3,color: Color) -> MeshInstance3D:
	var n=MeshInstance3D.new(); var m=BoxMesh.new(); m.size=size; n.mesh=m; n.position=pos
	var mat=StandardMaterial3D.new(); mat.albedo_color=color; mat.roughness=0.9; n.material_override=mat; parent.add_child(n); return n
func ball(parent:Node3D,pos:Vector3,size:float,color:Color) -> void:
	var n=MeshInstance3D.new(); var m=SphereMesh.new(); m.radius=size; m.height=size*2; m.radial_segments=12; m.rings=6; n.mesh=m; n.position=pos
	var mat=StandardMaterial3D.new(); mat.albedo_color=color; n.material_override=mat; parent.add_child(n)
func rebuild() -> void:
	if stage>=3:sim.reconcile(data)
	for n in terrain.get_children(): n.free()
	for k in data.tiles:
		var p=k.split(","); var x=int(p[0]); var z=int(p[1]); var c:Dictionary=data.tiles[k]
		if c.h==0: continue
		var h=float(c.h)*0.5
		var color=Color("aec393") if c.surface=="grass" else Color("e4d4b1") if c.surface=="sand" else Color("b4b5a4")
		box(terrain,Vector3(x,h/2-0.2,z),Vector3(1,h,1),color)
		if c.road: box(terrain,Vector3(x,h-0.17,z),Vector3(0.68,0.08,0.68),Color("d9c7a3"))
		if c.flower:
			for i in range(3): ball(terrain,Vector3(x+sin(i*2)*0.25,h-0.05,z+cos(i*2)*0.25),0.12,Color("edc980"))
		if (x*19+z*7)%47==0 and c.surface=="grass" and not BuildingRules.occupied(data,Vector2i(x,z)):
			box(terrain,Vector3(x,h+0.3,z),Vector3(0.18,1,0.18),Color("9a8065")); ball(terrain,Vector3(x,h+1.2,z),0.8,Color("809d77"))
	for o in data.objects: draw_building(o)
	hint.text="WEEK %02d  •  %s  •  Brush %d  |  %d edits"%[stage,tool.to_upper(),radius,data.history.size()]
func update_camera() -> void:
	camera.position=center+Vector3(sin(angle)*35,35,cos(angle)*35); camera.look_at(center)
func build_ui() -> void:
	var layer=CanvasLayer.new(); add_child(layer)
	var panel=PanelContainer.new(); panel.position=Vector2(28,26); panel.size=Vector2(430,110); layer.add_child(panel)
	var col=VBoxContainer.new(); panel.add_child(col)
	var title=Label.new(); title.text="  B R E E Z E L Y   I S L E S"; title.add_theme_font_size_override("font_size",24); col.add_child(title)
	var sub=Label.new(); sub.text="  A little island, one gentle brushstroke at a time."; col.add_child(sub)
	col.add_child(hint)
	var bar=HFlowContainer.new(); bar.position=Vector2(28,748); bar.size=Vector2(1380,110); layer.add_child(bar)
	for name in ["grass","sand","rock","water","raise","lower","flower","road","house","bridge","dock","move","erase","lock"]:
		add_button(bar,name.capitalize(),func(): tool=name)
	add_button(bar,"Undo",func():data.undo();rebuild())
	add_button(bar,"Redo",func():data.redo();rebuild())
	if stage>=3:
		add_button(bar,"Save",func():feedback.text="Save: " + error_string(SaveStore.save_game(data,sim)))
		add_button(bar,"Recover",func():feedback.text="Recovery: " + error_string(SaveStore.load_game(data,sim,"user://island.json.bak"));rebuild())
		add_button(bar,"Load",func():feedback.text="Load: " + error_string(SaveStore.load_game(data,sim));rebuild())
		add_button(bar,"Pause",func():sim.paused=not sim.paused)
	feedback.position=Vector2(28,708);layer.add_child(feedback)
	var help=Label.new(); help.position=Vector2(30,864); help.text="LMB paint • RMB cancel • WASD pan • Q/E orbit • R rotate • -/+ span • Wheel zoom • [ / ] brush • Ctrl/Cmd Z undo"; layer.add_child(help)
func add_button(parent:Node,label:String,action:Callable) -> void:
	var b=Button.new(); b.text=label; b.custom_minimum_size=Vector2(92,42); b.pressed.connect(action); parent.add_child(b)
func pick() -> Vector2i:
	var mouse=get_viewport().get_mouse_position()
	var from=camera.project_ray_origin(mouse); var dir=camera.project_ray_normal(mouse)
	var hit=Plane(Vector3.UP,0.5).intersects_ray(from,dir)
	if hit==null:return Vector2i(-1,-1)
	return Vector2i(roundi(hit.x),roundi(hit.z))
func _unhandled_input(event:InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP:camera.size=maxf(12,camera.size-2)
		if event.button_index==MOUSE_BUTTON_WHEEL_DOWN:camera.size=minf(65,camera.size+2)
		if event.button_index==MOUSE_BUTTON_RIGHT:stroke.clear(); dragging=false
		if event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed:dragging=true;stroke.clear();collect()
			elif dragging:
				dragging=false
				if tool in ["house","bridge","dock"]: feedback.text=BuildingRules.place(data,pick(),tool,placement_rotation,span)
				elif tool=="move":move_object(pick())
				elif tool in ["erase","lock"]:
					for o in data.objects:
						if pick() in BuildingRules.footprint(o):
							data.begin()
							if tool=="erase":data.objects.erase(o)
							else:o.variant=BuildingRules.variant(data,o);o.locked=not o.locked
							break
				else:data.paint(stroke,tool)
				stroke.clear();rebuild()
	if event is InputEventMouseMotion:
		if dragging:collect()
		for n in preview.get_children():n.free()
		var p=pick();box(preview,Vector3(p.x,float(data.cell(p).h)*0.5+0.03,p.y),Vector3(radius*2+1,0.035,radius*2+1),Color("f4e8c2"))
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_R:placement_rotation=(placement_rotation+1)%4
			KEY_MINUS:span=maxi(2,span-1)
			KEY_EQUAL:span=mini(6,span+1)
			KEY_SPACE:sim.paused=not sim.paused
			KEY_Q:angle-=PI/2
			KEY_E:angle+=PI/2
			KEY_W:center.z-=2
			KEY_S:center.z+=2
			KEY_A:center.x-=2
			KEY_D:center.x+=2
			KEY_BRACKETLEFT:radius=maxi(1,radius-1)
			KEY_BRACKETRIGHT:radius=mini(3,radius+1)
			KEY_ESCAPE:stroke.clear();dragging=false
			KEY_Z:
				if event.ctrl_pressed or event.meta_pressed:
					if event.shift_pressed:data.redo()
					else:data.undo()
					rebuild()
		update_camera()
func collect() -> void:
	var p=pick()
	for x in range(-radius,radius+1):
		for z in range(-radius,radius+1):
			var q=p+Vector2i(x,z)
			if x*x+z*z<=radius*radius and not stroke.has(q):stroke.append(q)

func draw_building(o:Dictionary) -> void:
	var x=float(o.x);var z=float(o.z);var h=float(data.cell(Vector2i(o.x,o.z)).h)*0.5-0.2
	if o.kind in ["dock","bridge"]:
		var dir=BuildingRules.DIRS[int(o.rotation)%4]
		for i in range(int(o.length)+1):
			var pos=Vector3(x+dir.x*i,h,z+dir.y*i)
			box(terrain,pos,Vector3(0.9,0.16,0.9),Color("ae8965"))
			box(terrain,pos+Vector3(0.35,-0.4,0.35),Vector3(0.12,1,0.12),Color("927257"))
		if o.kind=="dock" and stage>=3:
			var side=Vector2i(-dir.y,dir.x);var p=Vector3(x+dir.x*2+side.x,0,z+dir.y*2+side.y)
			var ship=box(terrain,p,Vector3(0.85,0.35,2.8),Color("ad8862"))
			ship.rotation.y=PI/2 if dir.x!=0 else 0
			box(terrain,p+Vector3(0,0.2,0),Vector3(0.6,0.12,0.7),Color("eadcc0"))
		return
	var first=terrain.get_child_count()
	var variant=BuildingRules.variant(data,o)
	box(terrain,Vector3(x+0.5,h+0.85,z+0.5),Vector3(1.65,1.7,1.65),Color("eadfc5"))
	var roof=box(terrain,Vector3(x+0.5,h+1.95,z+0.5),Vector3(1.5,1.5,1.9),Color("849fac") if variant=="coast" else Color("cb8c76"))
	roof.rotation.z=PI/4;roof.scale.y=0.7
	box(terrain,Vector3(x+0.5,h+0.5,z+1.34),Vector3(0.42,1,0.05),Color("688e8e"))
	for dx in [-0.05,1.05]:box(terrain,Vector3(x+dx,h+1,z+1.34),Vector3(0.3,0.4,0.06),Color("c0d4d1"))
	if variant=="garden":
		for dx in [0,1]:ball(terrain,Vector3(x+dx,h+0.4,z+1.4),0.25,Color("a4b37b"))
	var pivot=Vector3(x+0.5,0,z+0.5);var turn=Basis(Vector3.UP,-float(o.rotation)*PI/2)
	for i in range(first,terrain.get_child_count()):
		var piece=terrain.get_child(i) as Node3D
		piece.position=pivot+turn*(piece.position-pivot);piece.basis=turn*piece.basis
func seed_village() -> void:
	for x in range(23,41):
		var p=Vector2i(x,33);var c=data.cell(p).duplicate();c.road=true;data.tiles[data.key(p)]=c
	for p in [Vector2i(26,30),Vector2i(30,30),Vector2i(35,30)]:BuildingRules.place(data,p,"house")
	data.paint([Vector2i(29,29),Vector2i(30,29),Vector2i(31,29)],"flower")
	# Anchor at the west shore, extending towards the open sea.
	var anchor=Vector2i(21,33)
	data.tiles[data.key(anchor)]={"h":1,"surface":"sand","road":true,"flower":false}
	data.paint([Vector2i(22,33)],"road")
	BuildingRules.place(data,anchor,"dock",1,3)
	for o in data.objects:
		if o.kind=="house":data.paint([Vector2i(o.x,32)],"road")
	data.history.clear()

func _process(dt:float) -> void:
	if stage<3:return
	sim.tick(data,dt);draw_residents();autosave_clock+=dt
	if autosave_clock>=60 and not dragging:
		autosave_clock=0;feedback.text="Autosave: "+error_string(SaveStore.save_game(data,sim))
func draw_residents() -> void:
	for n in actors.get_children():n.free()
	for person in sim.people:
		if person.state=="resting":continue
		var p=Vector2i(roundi(person.x),roundi(person.z));var h=float(data.cell(p).h)*0.5-0.2
		box(actors,Vector3(person.x,h+0.38,person.z),Vector3(0.3,0.5,0.25),Color("dcba69"))
		ball(actors,Vector3(person.x,h+0.85,person.z),0.22,Color("e4c59c"))
func move_object(p:Vector2i) -> void:
	if moving_id==0:
		for o in data.objects:
			if p in BuildingRules.footprint(o):moving_id=int(o.id);feedback.text="Choose a new flat foundation";return
		return
	for o in data.objects:
		if o.id!=moving_id:continue
		var old=o.duplicate(true);var before=data.snapshot();data.objects.erase(o)
		var message=BuildingRules.place(data,p,old.kind,int(old.rotation),int(old.length))
		if not message.begins_with("Placed"):data.restore(before);feedback.text=message;return
		data.history.pop_back();data.history.append(before)
		var replacement=data.objects.back();replacement.id=old.id;replacement.locked=old.locked
		if old.has("variant"):replacement.variant=old.variant
		moving_id=0;feedback.text="Moved";return
func _notification(what:int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST and stage>=3:SaveStore.save_game(data,sim)
