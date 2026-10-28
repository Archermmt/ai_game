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
var stage: int = 1
func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--week="): stage=int(arg.trim_prefix("--week="))
	data.seed_island()
	add_child(terrain); add_child(preview)
	var env=WorldEnvironment.new(); var e=Environment.new()
	e.background_mode=Environment.BG_COLOR; e.background_color=Color("b8d5d0")
	e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color=Color("fff0d6"); e.ambient_light_energy=0.35
	env.environment=e; add_child(env)
	var sun=DirectionalLight3D.new(); sun.rotation_degrees=Vector3(-50,-25,0); sun.light_color=Color("fff0d6"); sun.light_energy=0.65; sun.shadow_enabled=true; add_child(sun)
	add_child(camera); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=36; camera.current=true; update_camera()
	box(self,Vector3(32,-0.3,32),Vector3(150,0.2,150),Color("86bdbb"))
	build_ui(); rebuild()
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
	for n in terrain.get_children(): n.free()
	for k in data.tiles:
		var p=k.split(","); var x=int(p[0]); var z=int(p[1]); var c:Dictionary=data.tiles[k]
		if c.h==0: continue
		var h=float(c.h)*0.5
		var color=Color("aec393") if c.surface=="grass" else Color("e4d4b1") if c.surface=="sand" else Color("b4b5a4")
		box(terrain,Vector3(x,h/2-0.2,z),Vector3(1,h,1),color)
		if c.flower:
			for i in range(3): ball(terrain,Vector3(x+sin(i*2)*0.25,h-0.05,z+cos(i*2)*0.25),0.12,Color("edc980"))
		if (x*19+z*7)%47==0 and c.surface=="grass":
			box(terrain,Vector3(x,h+0.3,z),Vector3(0.18,1,0.18),Color("9a8065")); ball(terrain,Vector3(x,h+1.2,z),0.8,Color("809d77"))
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
	var bar=HBoxContainer.new(); bar.position=Vector2(28,810); layer.add_child(bar)
	for name in ["grass","sand","rock","water","raise","lower","flower"]:
		add_button(bar,name.capitalize(),func(): tool=name)
	add_button(bar,"Undo",func():data.undo();rebuild())
	add_button(bar,"Redo",func():data.redo();rebuild())
	var help=Label.new(); help.position=Vector2(30,864); help.text="LMB paint • RMB cancel • WASD pan • Q/E orbit • Wheel zoom • [ / ] brush • Ctrl/Cmd Z undo"; layer.add_child(help)
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
			elif dragging:dragging=false;data.paint(stroke,tool);stroke.clear();rebuild()
	if event is InputEventMouseMotion:
		if dragging:collect()
		for n in preview.get_children():n.free()
		var p=pick();box(preview,Vector3(p.x,float(data.cell(p).h)*0.5+0.03,p.y),Vector3(radius*2+1,0.035,radius*2+1),Color("f4e8c2"))
	if event is InputEventKey and event.pressed:
		match event.keycode:
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
