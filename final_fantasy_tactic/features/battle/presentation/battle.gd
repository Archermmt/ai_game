extends Node3D

const Planner=preload("res://features/battle/ai/turn_planner.gd")
const State = preload("res://features/battle/rules/battle_state.gd")
var state = State.new()
var camera: Camera3D
var world: Node3D
var hud: VBoxContainer
var info: Label
var message: Label
var timeline: Label
var mode: String="move"
var candidate: Dictionary={}
var selected: Vector2i=Vector2i(-1,-1)
var busy: bool=false
var angle: float=0.0
var zoom: float=17.0
var actors: Dictionary={}
var tile_meshes: Dictionary={}
var generation: int=0
var paused: bool=false
var playback: Tween
var ui_font: SystemFont
var heal_button: Button
var confirm_button: Button
var target_info: Label
var path_root: Node3D
var ai_commands: Array=[]
var phase: String="title"
var overlay: PanelContainer
var flow_text: Label
var flow_button: Button
var reset_dialog: ConfirmationDialog
var action_buttons: Dictionary={}
var pending_navigation: String=""
var dialog_was_paused: bool=false
var total_commands: int=0
var elapsed: float=0.0

func _ready() -> void:
	ui_font=SystemFont.new(); ui_font.font_names=PackedStringArray(["PingFang SC", "Heiti SC"])
	var environment:=WorldEnvironment.new()
	var env:=Environment.new()
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color("192936")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("c4d7ea")
	env.ambient_light_energy=0.65
	environment.environment=env
	add_child(environment)
	var sun:=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-48,-35,0)
	sun.light_color=Color("ffe0ad")
	sun.light_energy=0.9
	sun.shadow_enabled=true
	add_child(sun)
	camera=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	add_child(camera)
	camera.current=true
	setup_hud()
	rebuild()
	show_flow("title")
	message.text="夺回灰桥前哨：击倒全部敌方。选择候选格，再按确认。"
	if "--capture" in OS.get_cmdline_user_args():
		show_flow("battle")
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/validation/first_runtime.png")
		get_tree().quit()

func material(color: Color) -> StandardMaterial3D:
	var mat:=StandardMaterial3D.new()
	mat.albedo_color=color; mat.roughness=0.85
	return mat

func box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var node:=MeshInstance3D.new()
	var mesh:=BoxMesh.new(); mesh.size=size
	node.mesh=mesh; node.position=pos; node.material_override=material(color)
	parent.add_child(node)
	return node

func point(p: Vector2i) -> Vector3:
	return Vector3(p.x+0.5,state.height(p)*0.5,p.y+0.5)

func rebuild() -> void:
	if is_instance_valid(world): remove_child(world); world.queue_free()
	world=Node3D.new(); add_child(world)
	tile_meshes.clear(); actors.clear()
	for p in state.tiles:
		var h: float=state.height(p)*0.5
		var color:=Color("82927e") if h==0 else Color("a6ac9d")
		tile_meshes[p]=box(world,Vector3(0.96,h+0.55,0.96),Vector3(p.x+0.5,(h-0.55)/2,p.y+0.5),color)
		var body:=StaticBody3D.new()
		body.set_meta("tile",p)
		var collision:=CollisionShape3D.new()
		var shape:=BoxShape3D.new(); shape.size=Vector3(0.98,0.08,0.98)
		collision.shape=shape; body.position=point(p)-Vector3(0,0.04,0)
		body.add_child(collision); world.add_child(body)
		if state.tiles[p].blocked: box(world,Vector3(0.9,1,0.9),point(p)+Vector3(0,0.5,0),Color("606d70"))
	for u in state.units:
		if u.hp<=0: continue
		var actor:=Node3D.new(); world.add_child(actor); actor.position=point(u.p)
		actors[u.id]=actor
		var color:=Color("398a83") if u.team==0 else Color("b15d50")
		box(actor,Vector3(0.46,0.65,0.32),Vector3(0,0.53,0),color)
		box(actor,Vector3(0.18,0.22,0.26),Vector3(-0.13,0.11,0),Color("36414b"))
		box(actor,Vector3(0.18,0.22,0.26),Vector3(0.13,0.11,0),Color("36414b"))
		var head:=MeshInstance3D.new(); var sphere:=SphereMesh.new()
		sphere.radius=0.23; sphere.height=0.46; head.mesh=sphere
		head.position.y=1.08; head.material_override=material(Color("e7be8c")); actor.add_child(head)
		if u.job==0:
			box(actor,Vector3(0.3,0.5,0.12),Vector3(-0.35,0.6,-0.12),Color("c8d0c5"))
			box(actor,Vector3(0.06,0.7,0.08),Vector3(0.32,0.66,-0.12),Color("d9ded5"))
		elif u.job==1:
			box(actor,Vector3(0.08,0.9,0.12),Vector3(0.34,0.65,-0.08),Color("a47748"))
			box(actor,Vector3(0.4,0.12,0.4),Vector3(0,1.24,0),color)
		else:
			box(actor,Vector3(0.06,1.25,0.06),Vector3(0.35,0.66,0),Color("d6b777"))
			box(actor,Vector3(0.5,0.3,0.35),Vector3(0,0.3,0),Color("e7dfc8"))
		var label:=Label3D.new(); label.text=("P" if u.team==0 else "E")+str(u.id/2+1)+" · "+["守卫","弓手","医师"][u.job]+"\n%d HP"%u.hp
		label.font=ui_font; label.font_size=42; label.pixel_size=0.006; label.position.y=1.65
		label.billboard=BaseMaterial3D.BILLBOARD_ENABLED; label.no_depth_test=true
		actor.add_child(label)
	update_camera(); refresh()

func setup_hud() -> void:
	var canvas:=CanvasLayer.new(); add_child(canvas)
	var panel:=PanelContainer.new(); panel.position=Vector2(20,20); panel.custom_minimum_size=Vector2(390,0); canvas.add_child(panel)
	var theme:=Theme.new(); theme.default_font=ui_font; panel.theme=theme
	hud=VBoxContainer.new(); panel.add_child(hud)
	var title:=Label.new(); title.text="灰桥前哨  /  3D 战术原型"; title.add_theme_font_size_override("font_size",26); hud.add_child(title)
	info=Label.new(); hud.add_child(info)
	for entry in [["移动","move"],["普通攻击","attack"],["治疗（医师）","heal"],["结束行动","end"]]:
		var button:=Button.new(); button.text=entry[0]; button.custom_minimum_size.y=42
		button.pressed.connect(choose.bind(entry[1])); hud.add_child(button)
		action_buttons[entry[1]]=button
		if entry[1]=="heal": heal_button=button
	var confirm:=Button.new(); confirm_button=confirm; confirm.text="确认候选  Enter"; confirm.custom_minimum_size.y=46
	confirm.pressed.connect(confirm_candidate); hud.add_child(confirm)
	var reset:=Button.new(); reset.text="重新开始"; reset.pressed.connect(request_restart); hud.add_child(reset)
	var return_button:=Button.new(); return_button.text="返回标题"; return_button.pressed.connect(request_title); hud.add_child(return_button)
	var pause_button:=Button.new(); pause_button.text="暂停 / 继续  Esc"; pause_button.pressed.connect(toggle_pause); hud.add_child(pause_button)
	message=Label.new(); message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; message.custom_minimum_size=Vector2(380,100); hud.add_child(message)
	target_info=Label.new(); target_info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; target_info.custom_minimum_size=Vector2(375,0); hud.add_child(target_info)
	reset_dialog=ConfirmationDialog.new(); reset_dialog.dialog_text="放弃当前战局并重新开始？"; reset_dialog.confirmed.connect(resolve_navigation.bind(true)); reset_dialog.canceled.connect(resolve_navigation.bind(false)); canvas.add_child(reset_dialog)
	overlay=PanelContainer.new(); overlay.position=Vector2(470,230); overlay.custom_minimum_size=Vector2(650,260); overlay.theme=theme; canvas.add_child(overlay)
	var flow_box:=VBoxContainer.new(); overlay.add_child(flow_box)
	flow_text=Label.new(); flow_text.custom_minimum_size=Vector2(620,180); flow_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; flow_text.add_theme_font_size_override("font_size",24); flow_box.add_child(flow_text)
	flow_button=Button.new(); flow_button.custom_minimum_size.y=48; flow_button.pressed.connect(continue_flow); flow_box.add_child(flow_button)
	var back:=Button.new(); back.text="返回标题"; back.pressed.connect(func(): show_flow("title")); flow_box.add_child(back)
	timeline=Label.new(); timeline.add_theme_font_override("font",ui_font); timeline.position=Vector2(430,20); timeline.add_theme_font_size_override("font_size",18); canvas.add_child(timeline)
	var help:=Label.new(); help.add_theme_font_override("font",ui_font); help.position=Vector2(430,850); help.text="左键选择 · Enter确认 · 右键取消 · Q/E旋转 · 滚轮缩放 · R镜头复位"; canvas.add_child(help)

func update_camera() -> void:
	var center:=Vector3(6,0.4,5)
	camera.position=center+Vector3(12*sin(angle+0.65),13,12*cos(angle+0.65))
	camera.look_at(center); camera.size=zoom
	camera.h_offset=-1.8

func refresh() -> void:
	var u: Dictionary=state.units[state.active]
	heal_button.visible=u.job==2
	confirm_button.disabled=busy or paused or phase!="battle" or not candidate.get("ok",false)
	for kind in action_buttons:
		action_buttons[kind].disabled=busy or paused or phase!="battle" or u.team!=0 or (u.moved if kind=="move" else u.acted if kind in ["attack","heal"] else false)
	info.text="%s  |  第%d tick\nHP %d/%d   MP %d   CT %d\n移动 %s  /  行动 %s\n模式：%s"%[state.unit_name(state.active),state.tick,u.hp,State.STATS[u.job][0],u.mp,u.ct,"已用" if u.moved else "可用","已用" if u.acted else "可用",{"move":"移动","attack":"攻击","heal":"治疗","end":"结束"}.get(mode,mode)]
	timeline.text="行动预测（假设随后结束）\n"+state.timeline() if state.result.is_empty() else state.result
	var reachable: Dictionary=state.paths(state.active,State.STATS[u.job][5]) if mode=="move" and not u.moved else {}
	for p in tile_meshes:
		var color:=Color("82927e") if state.height(p)==0 else Color("a6ac9d")
		if reachable.has(p): color=Color("488fa1")
		if p==selected: color=Color("f0c278")
		tile_meshes[p].material_override=material(color)
	for id in actors:
		actors[id].scale=Vector3.ONE*(1.08 if id==state.active else 1.0)

	draw_preview()

func choose(kind: String) -> void:
	if busy or paused or phase!="battle" or state.units[state.active].team!=0 or not state.result.is_empty(): return
	mode=kind; candidate={}; selected=Vector2i(-1,-1)
	if kind=="end": execute(state.request("end",Vector2i.ZERO))
	else: message.text="请选择落点或目标，然后确认。"; refresh()

func confirm_candidate() -> void:
	if busy or paused or candidate.is_empty() or not candidate.get("ok",false): return
	if state.units[state.active].team!=0: return
	execute(candidate)

func execute(request: Dictionary) -> void:
	if busy: return
	var old_active: int=state.active
	var outcome: Dictionary=state.commit(request)
	candidate={}; selected=Vector2i(-1,-1)
	if not outcome.ok: message.text=outcome.reason; return
	busy=true
	total_commands+=1
	refresh()
	var token: int=generation
	message.text=state.unit_name(old_active)+" · "+outcome.kind
	if outcome.kind=="move" and actors.has(old_active):
		for p in outcome.path:
			if token!=generation: return
			playback=create_tween(); playback.tween_property(actors[old_active],"position",point(p),0.15)
			await playback.finished
	else:
		playback=create_tween(); playback.tween_interval(0.35)
		await playback.finished
	if token!=generation: return
	busy=false; rebuild()
	if not state.result.is_empty():
		message.text=state.result
		show_flow("result")

func restart() -> void:
	generation+=1
	if busy and is_instance_valid(playback):
		playback.kill()
		playback.finished.emit()
	playback=null
	ai_commands.clear(); total_commands=0; elapsed=0
	state=State.new(); candidate={}; busy=false; paused=false
	get_tree().paused=false; angle=0; zoom=17; mode="move"; selected=Vector2i(-1,-1); rebuild()
	show_flow("battle")
	message.text="新战局已开始。"

func toggle_pause() -> void:
	if phase!="battle": return
	paused=not paused
	if busy and is_instance_valid(playback) and playback.is_valid():
		if paused: playback.pause()
		else: playback.play()
	message.text="已暂停" if paused else "继续战斗"
	refresh()

func _input(event: InputEvent) -> void:
	if reset_dialog.visible: return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				if not candidate.is_empty(): candidate={}; selected=Vector2i(-1,-1); refresh()
				else: toggle_pause()
			KEY_Q: angle-=PI/2; update_camera()
			KEY_E: angle+=PI/2; update_camera()
			KEY_R: angle=0; zoom=17; update_camera()
			KEY_ENTER: confirm_candidate()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP: zoom=clampf(zoom-1,12,22); update_camera(); return
		if event.button_index==MOUSE_BUTTON_WHEEL_DOWN: zoom=clampf(zoom+1,12,22); update_camera(); return
		if event.button_index==MOUSE_BUTTON_RIGHT: candidate={}; selected=Vector2i(-1,-1); refresh(); return
		if event.button_index!=MOUSE_BUTTON_LEFT or busy or paused or phase!="battle" or state.units[state.active].team!=0: return
		var origin: Vector3=camera.project_ray_origin(event.position)
		var query:=PhysicsRayQueryParameters3D.create(origin,origin+camera.project_ray_normal(event.position)*100)
		var hit: Dictionary=get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty(): return
		selected=hit.collider.get_meta("tile")
		candidate=state.request(mode,selected)
		message.text=("预计%s %d · Enter确认"%["恢复" if mode=="heal" else "伤害",candidate.get("amount",0)]) if candidate.ok and mode!="move" else ("移动%d步 · Enter确认"%candidate.path.size() if candidate.ok else candidate.reason)
		refresh()

func _process(delta: float) -> void:
	if phase=="battle" and not paused: elapsed+=delta
	if phase=="battle" and not busy and not paused and state.result.is_empty() and state.units[state.active].team==1:
		ai_step()

func ai_step() -> void:
	if ai_commands.is_empty():
		var planner=Planner.new()
		ai_commands=planner.plan(state)
	if not ai_commands.is_empty():
		var command: Dictionary=ai_commands.pop_front()
		var request_data: Dictionary=state.request(command.kind,command.p)
		if request_data.ok: execute(request_data)
		else:
			ai_commands.clear()
			execute(state.request("end",Vector2i.ZERO))

func request_restart() -> void:
	if phase=="battle" and state.result.is_empty(): ask_navigation("restart")
	else: restart()

func request_title() -> void:
	if phase=="battle" and state.result.is_empty(): ask_navigation("title")
	else: show_flow("title")

func ask_navigation(destination: String) -> void:
	pending_navigation=destination
	dialog_was_paused=paused
	if not paused: toggle_pause()
	reset_dialog.dialog_text="放弃当前战局并%s？"%("重新开始" if destination=="restart" else "返回标题")
	reset_dialog.popup_centered()

func resolve_navigation(confirmed: bool) -> void:
	if confirmed:
		if pending_navigation=="restart": restart()
		else: show_flow("title")
	elif paused!=dialog_was_paused: toggle_pause()
	pending_navigation=""

func show_flow(next: String) -> void:
	phase=next
	overlay.visible=phase!="battle"
	if phase=="battle":
		paused=false
		if busy and is_instance_valid(playback) and playback.is_valid(): playback.play()
	if phase=="title":
		paused=true
		if busy and is_instance_valid(playback) and playback.is_valid(): playback.pause()
		flow_text.text="灰桥前哨\n三人小队 · 高差战棋\n夺回山道前哨，让撤离的村民安全通过。"
		flow_button.text="开始前哨战"
	elif phase=="briefing":
		flow_text.text="目标：击倒全部对方。全员倒地则失败。\n每次激活可移动一次、行动一次，先后任意。\n弓手距离2–4格，高位更远；医师有4次治疗。\n左键选择候选，确认后不可撤销，最后结束行动。"
		flow_button.text="进入战场"
	elif phase=="result":
		flow_text.text=state.result+"\n命令数：%d  ·  用时：%d秒\n队员倒地：%d / 3"%[total_commands,int(elapsed),state.units.filter(func(u): return u.team==0 and u.hp<=0).size()]
		flow_button.text="重新开始"
	refresh()

func continue_flow() -> void:
	if phase=="title": show_flow("briefing")
	else: restart()

func draw_preview() -> void:
	if is_instance_valid(path_root): path_root.queue_free()
	path_root=Node3D.new(); world.add_child(path_root)
	target_info.text=""
	if selected.x<0: return
	var target: int=state.occupant(selected)
	var description: String="格子 (%d,%d) · h%d"%[selected.x,selected.y,state.height(selected)]
	if target>=0:
		var unit: Dictionary=state.units[target]
		description+="\n%s  HP %d/%d  MP %d"%[state.unit_name(target),unit.hp,State.STATS[unit.job][0],unit.mp]
	if state.tiles.has(selected):
		var center: Vector3=point(selected)+Vector3(0,0.08,0)
		for x_sign in [-1,1]:
			for z_sign in [-1,1]:
				box(path_root,Vector3(0.22,0.035,0.035),center+Vector3(x_sign*0.34,0,z_sign*0.43),Color("fff4da"))
				box(path_root,Vector3(0.035,0.035,0.22),center+Vector3(x_sign*0.43,0,z_sign*0.34),Color("fff4da"))
	if not candidate.get("ok",false):
		target_info.text=description+"\n"+candidate.get("reason","")
		return
	if mode=="move":
		var path: Array=candidate.path
		var previous: Vector3=point(state.units[state.active].p)+Vector3(0,0.07,0)
		for p in path:
			var current: Vector3=point(p)+Vector3(0,0.07,0)
			var segment=box(path_root,Vector3(0.07,0.07,previous.distance_to(current)),(previous+current)/2,Color("ffe3a2"))
			segment.look_at(current)
			previous=current
		var after=state.snapshot(); after.units[after.active].p=selected
		for enemy in after.units:
			if after.preview("attack",enemy.p).ok:
				box(path_root,Vector3(0.8,0.04,0.8),point(enemy.p)+Vector3(0,0.04,0),Color("efa359"))
		target_info.text=description+"\n路径%d步，确认后移动不可撤销"%path.size()
	else:
		var before: int=state.units[candidate.target].hp
		var after_hp: int=before+candidate.amount*(1 if mode=="heal" else -1)
		target_info.text=description+"\n%s %d · HP %d → %d\n%s"%["治疗" if mode=="heal" else "伤害",candidate.amount,before,after_hp,"消耗6 MP" if mode=="heal" else "命中确定" ]
		var forecast=state.snapshot()
		forecast.commit(forecast.preview(mode,selected))
		timeline.text="确认后预测（假设随后结束）\n"+forecast.timeline()
