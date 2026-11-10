extends Node3D
var data=IslandData.new()
var sim=ResidentSim.new()
var view=IslandView.new()
var wildlife=Wildlife.new()
var audio=IslandAudio.new()
var listener=AudioListener3D.new()
var preferences=preload("res://game/settings/island_settings.gd").new()
var binding_target=""
var photo_busy=false
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
var angle:float=0.22
var pitch_offset := 0.0
var orbit_tracking := false
var orbit_dragged := false
var orbit_anchor := Vector2.ZERO
var orbit_previous := Vector2.ZERO
const ORBIT_THRESHOLD := 6.0
var center=Vector3(29.9,1.85,32.5)
var welcoming := false
const ConstructionBrush = preload("res://game/building/construction_brush.gd")
const FORM_NAMES := {
	"house": ["原式", "阁楼", "望楼"], "tea": ["原式", "阁楼", "望楼"],
	"greenhouse": ["原式", "育苗阁", "八角花房"], "lighthouse": ["原式", "巡灯廊", "双塔灯楼"]
}
var construction: ConstructionBrush
var stroke_start_screen := Vector2.ZERO
var last_stroke_cell := Vector2i(-1, -1)
var sweeping := false
var stroke:Array=[]
var dragging=false
var time:float=0
var autosave_clock:float=0
var capturing=false
var photo_mode=false
var photo_previous_paused=false
var photo_hint=Label.new()
var modal:Control
var modal_panel:PanelContainer
var selected:Dictionary={}
var preview_note=Label.new()
func _ready() -> void:
	get_tree().auto_accept_quit=false
	capturing=OS.get_cmdline_user_args().has("--capture")
	preload("res://game/world/cottage_cove.gd").create(data)
	if OS.get_cmdline_user_args().has("--empty"):data.clear_world()
	add_child(view);view.setup(data);add_child(preview)
	add_child(wildlife);wildlife.setup()
	var env=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color("8bbcb9")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color.WHITE;env.ambient_light_energy=0.5
	world_env.environment=env;add_child(world_env)
	sun.rotation_degrees=Vector3(-48,-25,0);sun.light_color=Color("fff3de");sun.light_energy=0.9;sun.shadow_enabled=true;sun.directional_shadow_max_distance=70;add_child(sun)
	add_child(camera);camera.projection=Camera3D.PROJECTION_PERSPECTIVE;camera.fov=28.0;camera.size=12.0;camera.current=true;update_camera()
	add_child(audio);add_child(listener);listener.make_current()
	add_child(hud);preferences.read();apply_preferences(false);hud.add_child(photo_hint);photo_hint.mouse_filter=Control.MOUSE_FILTER_IGNORE;photo_hint.position=Vector2(30,24);photo_hint.visible=false
	hud.root.add_child(preview_note)
	preview_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_note.add_theme_font_size_override("font_size", 15)
	preview_note.add_theme_color_override("font_color", Color("463c31"))
	var note_style := hud.style(Color("fff3def2"), Color("cdbd9e"))
	note_style.set_content_margin_all(7)
	preview_note.add_theme_stylebox_override("normal", note_style)
	hud.tool_selected.connect(select_tool);hud.action_requested.connect(action)
	hud.wish_toggled.connect(func(id):
		if id in sim.hidden_wishes:sim.hidden_wishes.erase(id)
		else:sim.hidden_wishes.append(id)
		hud.refresh_journal(sim.completed,sim.hidden_wishes))
	settle_existing_homes()
	rebuild();set_sunset(false)
	if capturing:
		for i in range(16):sim.tick(data,0.5)
		await get_tree().process_frame;await get_tree().process_frame
		view.update_actors(sim,time)
		await RenderingServer.frame_post_draw
		var target="res://snapshots/playable_day.png"
		if OS.get_cmdline_user_args().has("--sunset"):set_sunset(true);target="res://snapshots/playable_sunset.png"
		if OS.get_cmdline_user_args().has("--photo"):
			hud.root.hide()
			preview.hide()
			target="res://snapshots/playable_photo.png"
		if OS.get_cmdline_user_args().has("--welcome"):welcome();target="res://snapshots/playable_welcome.png"
		if OS.get_cmdline_user_args().has("--menu"):save_menu();target="res://snapshots/playable_menu.png"
		for arg in OS.get_cmdline_user_args():
			if arg=="--orbit-view":angle+=PI/2;update_camera()
			if arg.begins_with("--capture-target="):target=arg.trim_prefix("--capture-target=")
		await RenderingServer.frame_post_draw
		var err=get_viewport().get_texture().get_image().save_png(target)
		print("CAPTURE ",target," ",error_string(err));get_tree().quit()
	else:welcome()
func settle_existing_homes() -> void:
	for o in data.objects:
		if o.kind=="house":
			var p=RouteGraph.entrance(o)
			sim.people.append({"id":sim.next_id,"home":o.id,"x":float(p.x),"z":float(p.y),"state":"home","route":[],"timer":float(sim.next_id),"target":0,"activity":"","crossed":false});sim.next_id+=1

func select_tool(id:String) -> void:
	audio.effect("click")
	tool=id;discard_stroke();moving_id=0
	hud.toast({"house":"贴着旧屋加建，拖动连建；再点屋顶换形","dock":"从一至二级海岸向海延伸；R 旋转，−/+ 调长度","bridge":"选择第一端岸边，R 转向、−/+ 调跨度，两岸须同高","flower":"在小屋外圈画三格花圃，试试它的新模样","move":"先点物件，再点新位置；右键取消","lock":"点击建筑，保留或解锁当前外观","color":"点击建筑，更换屋顶配色"}.get(id,"选择了"+IslandHud.NAMES[id]));refresh_preview()
func rebuild() -> void:
	sim.reconcile(data);view.day=not sim.sunset;view.rebuild();view.update_actors(sim,time);hud.refresh_journal(sim.completed,sim.hidden_wishes);refresh_preview()
func default_pitch_degrees() -> float:
	return lerpf(12.0, 43.0, smoothstep(13.0, 31.0, camera.size))

func turn_camera(yaw_delta: float, pitch_delta: float) -> void:
	angle = fposmod(angle + yaw_delta, TAU)
	var base_pitch := default_pitch_degrees()
	pitch_offset = clampf(pitch_offset + pitch_delta, 8.0 - base_pitch, 72.0 - base_pitch)
	update_camera()
	refresh_preview()

func update_camera() -> void:
	center.x=clampf(center.x,8,56);center.z=clampf(center.z,8,56)
	# Close framing shows the façades and their reflections. Pulling back gradually
	# returns to a steeper angle for editing the far side of a large island.
	var pitch := deg_to_rad(clampf(default_pitch_degrees() + pitch_offset, 8.0, 72.0))
	var distance_to_focus := float(camera.size) * 0.5 / tan(deg_to_rad(camera.fov * 0.5))
	var eye_direction := Vector3(sin(angle) * cos(pitch), sin(pitch), cos(angle) * cos(pitch))
	camera.position = center + eye_direction * distance_to_focus
	camera.look_at(center)
func pick() -> Vector2i:
	return tool_cell_at(get_viewport().get_mouse_position())

func tool_cell_at(mouse: Vector2) -> Vector2i:
	var origin := camera.project_ray_origin(mouse)
	var direction := camera.project_ray_normal(mouse)
	var ground = ground_intersection(origin, direction)
	if tool in BuildingRules.BUILDINGS or tool in ["lock", "color", "erase"] or (tool == "move" and moving_id == 0):
		var limit: float = origin.distance_to(ground) + 0.015 if ground != null else camera.far
		var anchor: Vector2i = view.building_picker.closest(origin, direction, limit)
		if anchor.x >= 0:
			return anchor
	return Vector2i(roundi(ground.x), roundi(ground.z)) if ground != null else Vector2i(-1, -1)

func pick_at(mouse: Vector2) -> Vector2i:
	var ground = ground_intersection(camera.project_ray_origin(mouse), camera.project_ray_normal(mouse))
	return Vector2i(roundi(ground.x), roundi(ground.z)) if ground != null else Vector2i(-1, -1)

func ground_intersection(origin: Vector3, dir: Vector3) -> Variant:
	# Solve against the same derived surface used for rendering and feet.
	if view.surface != null and dir.y < -0.001:
		var begin := maxf(0.0, (2.2 - origin.y) / dir.y)
		var finish := (-0.16 - origin.y) / dir.y
		# Clip the shallow sight line to the editable board before marching.
		for axis in [0, 2]:
			if absf(dir[axis]) < 0.00001:
				if origin[axis] < -0.5 or origin[axis] > 63.5:
					return null
				continue
			var near_t: float = (-0.5 - origin[axis]) / dir[axis]
			var far_t: float = (63.5 - origin[axis]) / dir[axis]
			begin = maxf(begin, minf(near_t, far_t))
			finish = minf(finish, maxf(near_t, far_t))
		if finish < begin:
			return null
		var previous: Vector3 = origin + dir * begin
		var step_count := ceili((finish - begin) / 0.15)
		for i in range(0, step_count + 1):
			var point: Vector3 = origin + dir * minf(finish, begin + i * 0.15)
			if point.y <= view.surface.height_at(Vector2(point.x, point.z)):
				var lo := previous
				var hi := point
				for step in range(10):
					var mid := (lo + hi) * 0.5
					if mid.y > view.surface.height_at(Vector2(mid.x, mid.z)):
						lo = mid
					else:
						hi = mid
				return hi
			previous = point
	return null

func prototype(p:Vector2i) -> Dictionary:
	if tool in BuildingRules.BUILDINGS:
		return ConstructionBrush.foundation(data, p, tool, placement_rotation)
	return {"id":0,"x":p.x,"z":p.y,"kind":tool,"rotation":placement_rotation,"length":span,"locked":false}
var preview_reaction_key: Array = []
var preview_reaction_text := ""

func placement_preview(object: Dictionary, moving: bool = false) -> String:
	var prefix := "移至此处" if moving else "可放置"
	if object.kind not in BuildingRules.BUILDINGS:
		return prefix + " · " + IslandHud.NAMES[object.kind]
	var key := [data.revision, object.kind, object.id, object.x, object.z, object.rotation, moving]
	if key == preview_reaction_key:
		return preview_reaction_text
	var proposal := BuildingRules.neighborhood(data, object)
	var label_text: String = IslandHud.NAMES[object.kind]
	if object.kind == "house":
		label_text = {"basic": "普通居所", "coast": "海岸居所", "garden": "花园居所"}[proposal.variants[int(object.id)]]
	var changed := 0
	for id in view.neighborhood_state.variants:
		if id != int(object.id) and view.neighborhood_state.variants[id] != proposal.variants.get(id):
			changed += 1
	var detail: String = proposal.reasons.get(int(object.id), "")
	var seams: Array = proposal.seams.get(int(object.id), [])
	if not seams.is_empty():
		detail += (" · " if not detail.is_empty() else "") + "与 %d 栋邻屋合建" % seams.size()
	var existing_halls: Dictionary = view.neighborhood_state.get("halls", {})
	for id in proposal.get("halls", {}):
		if not existing_halls.has(id):
			detail += (" · " if not detail.is_empty() else "") + "形成共用主厅"
			break
	if changed > 0:
		detail += (" · " if not detail.is_empty() else "") + "%d 间邻屋会换外观" % changed
	preview_reaction_text = prefix + " · " + label_text
	if not detail.is_empty():
		preview_reaction_text += "\n" + detail
	preview_reaction_key = key
	return preview_reaction_text

func refresh_preview(cursor: Variant = null) -> void:
	preview_note.visible=false
	for n in preview.get_children():n.free()
	if photo_mode or modal!=null or view.surface == null or get_viewport().gui_get_hovered_control() != null:return
	var screen: Vector2 = cursor if cursor != null else get_viewport().get_mouse_position()
	var p := tool_cell_at(screen)
	if not BuildingRules.inside(p):return
	var cells:Array=[];var valid=true;var reason=""
	if tool=="move" and moving_id!=0:
		var o=sim.object_by_id(data,moving_id).duplicate(true)
		if not o.is_empty():
			o.x = p.x
			o.z = p.y
			cells = BuildingRules.footprint(o)
			reason = BuildingRules.check(data, o, moving_id)
			valid = reason.is_empty()
			if valid:
				reason = placement_preview(o, true)
	elif dragging and sweeping and construction != null:
		for item in construction.added:
			cells.append_array(BuildingRules.footprint(item))
		reason = "连建 %d 栋 · 松开落笔" % construction.added.size() if not cells.is_empty() else "沿同高空地拖动可加建"
	elif tool in BuildingRules.TOOLS:
		var target := BuildingRules.reshape_target(data, p, tool)
		if not target.is_empty():
			cells = BuildingRules.footprint(target)
			valid = not target.get("locked", false)
			reason = "点按改为" + FORM_NAMES[tool][BuildingRules.next_form(target)] if valid else "外观已锁定，用定形工具解锁"
		else:
			var o := prototype(p)
			cells = BuildingRules.footprint(o)
			reason = BuildingRules.check(data, o)
			valid = reason.is_empty()
			if valid:
				reason = placement_preview(o)
	elif dragging:cells=stroke
	else:
		for x in range(-radius,radius+1):
			for z in range(-radius,radius+1):
				if x*x+z*z<=radius*radius:cells.append(p+Vector2i(x,z))
	var marked: Dictionary = {}
	for q in cells:
		if not BuildingRules.inside(q):
			continue
		var protected: bool = not tool in BuildingRules.TOOLS and (not BuildingRules.road_paintable(data, q) if tool == "road" else BuildingRules.occupied(data, q, true))
		marked[q] = protected or not valid
		if protected:
			reason = "支撑 / 入口会保留"
	preload("res://game/art/cove_brush.gd").outline(preview, view.surface, marked, valid)
	if not reason.is_empty():
		preview_note.text=reason;preview_note.reset_size();preview_note.visible=true
		var mouse: Vector2 = hud.root.get_global_transform_with_canvas().affine_inverse() * screen;preview_note.position=Vector2(clampf(mouse.x+20,10,maxf(10,hud.root.size.x-380)),clampf(mouse.y-40,140,maxf(140,hud.root.size.y-160)))
func discard_stroke() -> void:
	dragging = false
	sweeping = false
	construction = null
	stroke.clear()

func begin_build_stroke(mouse: Vector2) -> void:
	construction = ConstructionBrush.new(data, tool, placement_rotation) if tool in BuildingRules.BUILDINGS else null
	stroke_start_screen = mouse
	last_stroke_cell = Vector2i(-1, -1)
	sweeping = false

func collect(mouse: Vector2) -> void:
	collect_cell(tool_cell_at(mouse), mouse)

func collect_cell(cell: Vector2i, mouse: Vector2) -> void:
	if not BuildingRules.inside(cell):
		last_stroke_cell = Vector2i(-1, -1)
		return
	if construction != null and last_stroke_cell != cell and mouse.distance_to(stroke_start_screen) >= 6:
		sweeping = true
	if last_stroke_cell == cell:
		return
	var start := last_stroke_cell if BuildingRules.inside(last_stroke_cell) else cell
	var delta := cell - start
	var steps := maxi(absi(delta.x), absi(delta.y))
	for step in range(steps + 1):
		var point := Vector2(start).lerp(Vector2(cell), float(step) / maxi(1, steps)).round()
		if construction != null:
			construction.sample(Vector2i(point))
		else:
			for x in range(-radius, radius+1):
				for z in range(-radius, radius+1):
					var q := Vector2i(point) + Vector2i(x, z)
					if x*x+z*z <= radius*radius and not stroke.has(q):
						stroke.append(q)
	last_stroke_cell = cell

func commit_stroke(mouse: Vector2) -> void:
	var cell := tool_cell_at(mouse)
	collect_cell(cell, mouse)
	if sweeping and construction != null:
		if construction.apply(data):
			var old_halls: Dictionary = view.neighborhood_state.get("halls", {})
			audio.effect("place")
			rebuild()
			var message := "已连建 %d 栋" % construction.added.size()
			for id in view.neighborhood_state.get("halls", {}):
				if not old_halls.has(id):
					message += " · 屋群长出了共用主厅"
					break
			hud.toast(message + " · 可整笔撤销")
		else:
			hud.toast("没有可加建的地基")
		stroke.clear()
		refresh_preview()
	else:
		commit_stroke_at(cell)
	construction = null
	sweeping = false
	refresh_preview(mouse)

func commit_stroke_at(p: Vector2i) -> void:
	var before=data.snapshot()
	var regions=resident_regions()
	var added_building: Dictionary = {}
	if tool in BuildingRules.TOOLS:
		var target := BuildingRules.reshape_target(data, p, tool)
		if not target.is_empty():
			var error := BuildingRules.reshape(data, p, tool)
			if not error.is_empty():
				hud.toast(error)
				stroke.clear()
				return
			hud.toast("%s · %s" % [IslandHud.NAMES[tool], FORM_NAMES[tool][int(target.get("form", 0))]])
		else:
			var o := prototype(p)
			var result := BuildingRules.place(data, Vector2i(o.x, o.z), tool, placement_rotation, span)
			if not result.begins_with("Placed"):
				hud.toast(result)
				stroke.clear()
				return
			var placed: Dictionary = data.objects.back()
			if tool in BuildingRules.BUILDINGS:
				added_building = placed
			if tool == "house":
				hud.toast("小屋建好了 · " + sim.arrival_info(data, placed).reason)
			else:
				hud.toast("已放下" + IslandHud.NAMES[tool])
	elif tool=="move":move_object(p)
	elif tool in ["erase","lock","color"]:
		var found=false
		for o in data.objects:
			if p not in BuildingRules.footprint(o):continue
			if tool == "lock" and o.kind not in BuildingRules.BUILDINGS:
				hud.toast("选一栋建筑保留外观")
				return
			found=true;data.begin()
			if tool=="erase":data.objects.erase(o);hud.toast("已移除，可随时撤销")
			elif tool=="color":o.color=(int(o.get("color",0))+1)%3;hud.toast("换了一种屋顶颜色")
			elif o.kind in BuildingRules.BUILDINGS:
				if o.kind == "house":
					o.variant = BuildingRules.variant(data, o)
				if not o.locked and view.neighborhood_state.get("halls", {}).has(int(o.id)):
					o.hall_locked = true
				else:
					o.erase("hall_locked")
				o.locked = not o.locked
				hud.toast("已保留外观" if o.locked else "已解锁外观")
			break
		if not found and tool=="erase":
			data.begin()
			for q in stroke:
				var c=data.cell(q).duplicate();c.road=false;c.flower=false;data.tiles[data.key(q)]=c
	else:
		var blocked=0
		for q in stroke:
			if not BuildingRules.road_paintable(data,q) if tool=="road" else BuildingRules.occupied(data,q,true):blocked+=1
		data.paint(stroke,tool)
		if blocked>0:hud.toast("保留了 %d 格支撑 / 入口；先移动上面的物件再改地形"%blocked)
	audio.effect("move" if tool=="move" else "remove" if tool=="erase" else "road" if tool=="road" else "place" if tool in BuildingRules.TOOLS else "paint")
	stroke.clear();protect_residents(regions);rebuild()
	if not added_building.is_empty():
		var joins: Array = view.neighborhood_state.seams.get(int(added_building.id), [])
		if not joins.is_empty():
			hud.toast("与 %d 栋邻屋合建 · 再点屋顶可换形" % joins.size())
	if preferences.values.flash and data.snapshot()!=before and BuildingRules.inside(p):IslandEffects.burst(view,Vector3(p.x,view.surface.height_at(Vector2(p))+0.1,p.y),view.environment_clock)
func _input(event:InputEvent) -> void:
	if not binding_target.is_empty() and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_SHIFT,KEY_CTRL,KEY_ALT,KEY_META]:return
		var error="" if event.keycode==KEY_ESCAPE else preferences.bind(binding_target,int(event.get_keycode_with_modifiers()))
		if not error.is_empty():hud.toast(error)
		else:binding_target="";apply_preferences();preload("res://game/settings/settings_panel.gd").show_keys(self)
		get_viewport().set_input_as_handled();return
	# Only track a drag which began on the island. Once started, receive its
	# motion and release here even when the pointer crosses the toolbar.
	if orbit_tracking and event is InputEventMouseMotion:
		if not (event.button_mask & MOUSE_BUTTON_MASK_RIGHT):
			orbit_tracking = false
			return
		if not orbit_dragged and orbit_anchor.distance_to(event.position) >= ORBIT_THRESHOLD:
			orbit_dragged = true
		if orbit_dragged:
			var travel: Vector2 = event.position - orbit_previous
			turn_camera(-travel.x * 0.006, travel.y * 0.19)
			orbit_previous = event.position
		get_viewport().set_input_as_handled()
		return
	if orbit_tracking and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
			orbit_tracking = false
			if not orbit_dragged and orbit_anchor.distance_to(event.position) < ORBIT_THRESHOLD:
				moving_id = 0
				if not photo_mode:
					hud.toast("已取消")
			orbit_dragged = false
			refresh_preview()
		get_viewport().set_input_as_handled()
		return
	# A release over UI must end the world stroke as well; never leave a brush stuck.
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed and dragging:
		dragging=false
		if get_viewport().gui_get_hovered_control()!=null:discard_stroke();refresh_preview()
		else:commit_stroke(event.position)
func _unhandled_input(event:InputEvent) -> void:
	if photo_busy:return
	if modal!=null:
		if event is InputEventKey and event.pressed and not event.echo and preferences.matches(event,"cancel"):close_modal();get_viewport().set_input_as_handled()
		return
	if event is InputEventGesture:
		if dragging or get_viewport().gui_get_hovered_control() != null:
			return
		if event is InputEventPanGesture and event.delta.is_finite():
			turn_camera(-event.delta.x * 0.025, event.delta.y * 0.75)
		elif event is InputEventMagnifyGesture and is_finite(event.factor) and event.factor > 0:
			camera.size = clampf(camera.size / event.factor, 8.0, 58.0)
			update_camera()
			refresh_preview()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			if get_viewport().gui_get_hovered_control() == null:
				orbit_tracking = true
				orbit_dragged = false
				orbit_anchor = event.position
				orbit_previous = event.position
				discard_stroke()
				get_viewport().set_input_as_handled()
			return
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
			var sign_x := 1.0 if event.button_index == MOUSE_BUTTON_WHEEL_RIGHT else -1.0
			if not dragging:
				turn_camera(sign_x * 0.10 * event.factor, 0.0)
			get_viewport().set_input_as_handled()
			return
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			discard_stroke()
			var direction := 1.0 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1.0
			camera.size = clampf(camera.size + direction * 1.5 * event.factor, 8.0, 58.0)
			update_camera()
			refresh_preview()
			get_viewport().set_input_as_handled()
			return
		if event.button_index==MOUSE_BUTTON_LEFT and event.pressed and not photo_mode:dragging=true;stroke.clear();begin_build_stroke(event.position);collect(event.position)
	if event is InputEventMouseMotion:
		if dragging:collect(event.position)
		refresh_preview(event.position)
	if event is InputEventKey and event.pressed and not event.echo:
		if dragging:
			for binding in ["rotate", "orbit_left", "orbit_right", "north", "south", "west", "east", "undo", "redo", "photo"]:
				if preferences.matches(event, binding):
					discard_stroke()
					break
		if preferences.matches(event,"rotate"):placement_rotation=(placement_rotation+1)%4
		elif preferences.matches(event,"shorten"):span=maxi(2,span-1)
		elif preferences.matches(event,"lengthen"):span=mini(6,span+1)
		elif preferences.matches(event,"pause"):action("pause")
		elif preferences.matches(event,"orbit_left"):angle=fposmod(angle-PI/2,TAU)
		elif preferences.matches(event,"orbit_right"):angle=fposmod(angle+PI/2,TAU)
		elif preferences.matches(event,"north"):center.z-=1.5
		elif preferences.matches(event,"south"):center.z+=1.5
		elif preferences.matches(event,"west"):center.x-=1.5
		elif preferences.matches(event,"east"):center.x+=1.5
		elif preferences.matches(event,"brush_down"):radius=maxi(1,radius-1)
		elif preferences.matches(event,"brush_up"):radius=mini(3,radius+1)
		elif preferences.matches(event,"journal"):action("journal")
		elif preferences.matches(event,"photo"):action("photo")
		elif preferences.matches(event,"capture"):action("capture")
		elif preferences.matches(event,"undo"):action("undo")
		elif preferences.matches(event,"redo"):action("redo")
		elif preferences.matches(event,"cancel"):
			orbit_tracking = false
			if photo_mode:action("photo")
			else:discard_stroke();moving_id=0
		update_camera();refresh_preview()
func _process(dt:float) -> void:
	layout_modal()
	wildlife.enabled=not sim.paused and not reduced_motion
	wildlife.surface=view.surface
	view.update_environment(dt,not sim.paused and not reduced_motion and not photo_mode)
	if not sim.paused:time+=dt
	sim.tick(data,dt);view.update_actors(sim,time);autosave_clock+=dt
	listener.position=center+Vector3.UP*3;audio.update_residents(data,sim,dt,not sim.paused and not photo_mode)
	if not sim.events.is_empty():
		for key in sim.events:hud.toast("收录了新的日常："+IslandHud.JOURNAL[key][0])
		audio.effect("journal")
		if preferences.values.flash:IslandEffects.burst(view,center+Vector3.UP*2,view.environment_clock,true)
		sim.events.clear();hud.refresh_journal(sim.completed,sim.hidden_wishes)
	hud.refresh_status(sim.people.size(),tool,radius,span,sim.paused)
	if autosave_clock>=60 and not dragging and modal==null:
		autosave_clock=0
		var err=save_current()
		if err!=OK:hud.toast("自动保存失败，请打开存档面板重试："+error_string(err))
func action(id:String) -> void:
	if photo_busy:return
	audio.effect("undo" if id in ["undo","redo"] else "click")
	match id:
		"journal":hud.card.visible=not hud.card.visible
		"residents":show_residents()
		"undo":
			var regions=resident_regions();data.undo();protect_residents(regions);rebuild();hud.toast("已撤销")
		"redo":
			var regions=resident_regions();data.redo();protect_residents(regions);rebuild();hud.toast("已重做")
		"pause":sim.paused=not sim.paused
		"sunset":set_sunset(not sim.sunset)
		"photo":
			discard_stroke();moving_id=0
			if not photo_mode:photo_previous_paused=sim.paused
			photo_mode=not photo_mode;hud.root.visible=not photo_mode;sim.paused=true if photo_mode else photo_previous_paused;photo_hint.visible=photo_mode
			refresh_preview()
			if photo_mode:action("capture")
		"capture":save_photo()
		"menu":save_menu()
func set_sunset(value:bool) -> void:
	if is_instance_valid(audio) and audio.is_inside_tree():audio.set_evening(value)
	view.set_night(value)
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
	if photo_busy:return
	orbit_tracking = false
	photo_busy=true
	var paused=sim.paused;sim.paused=true
	for n in preview.get_children():n.hide()
	var resolution=Vector2i(1920,1080) if preferences.values.photo_resolution=="1080p" else Vector2i(get_viewport().get_visible_rect().size)
	var image=await preload("res://game/photography/photo_capture.gd").image(self,camera,resolution)
	var folder="user://photos";DirAccess.make_dir_recursive_absolute(folder)
	var path=folder+"/island_%d_%d.png"%[Time.get_unix_time_from_system(),Time.get_ticks_usec()]
	var err=image.save_png(path) if image!=null else ERR_CANT_CREATE
	if err==OK:audio.effect("photo")
	sim.paused=paused;photo_busy=false
	refresh_preview()
	hud.toast("照片已保存："+ProjectSettings.globalize_path(path) if err==OK else "保存照片失败，可重试："+error_string(err))
func apply_preferences(persist:bool=true) -> void:
	reduced_motion=preferences.values.reduced_motion
	view.detail_density=0.6 if preferences.values.quality=="low" else 1.0
	sun.shadow_enabled=preferences.values.quality!="low"
	audio.apply_settings(preferences.values)
	hud.ui_scale=preferences.values.ui_scale;hud.layout()
	photo_hint.text="拍照 · 右键拖动或双指滑动环绕 · 滚轮或捏合缩放 · %s 保存 · %s 返回"%[preferences.key_text("capture"),preferences.key_text("cancel")]
	hud.help.text="左键落笔 · 右键拖动或双指滑动环绕 · 轻点右键取消 · %s%s%s%s 平移 · %s/%s 转向 · %s 转物件 · 滚轮缩放 · %s 手记"%[preferences.key_text("north"),preferences.key_text("west"),preferences.key_text("south"),preferences.key_text("east"),preferences.key_text("orbit_left"),preferences.key_text("orbit_right"),preferences.key_text("rotate"),preferences.key_text("journal")]
	if persist:
		var error=preferences.write()
		if error!=OK:hud.toast("设置未能保存，可重试："+error_string(error))
func open_modal(title:String) -> VBoxContainer:
	orbit_tracking=false
	discard_stroke();moving_id=0
	if modal!=null:modal.queue_free()
	modal=Control.new();hud.root.add_child(modal);modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade=ColorRect.new();shade.color=Color(0.15,0.19,0.16,0.04 if welcoming else 0.35);modal.add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel=PanelContainer.new();modal_panel=panel;modal.add_child(panel);panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER);layout_modal()
	panel.add_theme_stylebox_override("panel",hud.style(Color("f7f1df")))
	var scroll=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;panel.add_child(scroll)
	var col=VBoxContainer.new();col.size_flags_horizontal=Control.SIZE_EXPAND_FILL;col.add_theme_constant_override("separation",10);scroll.add_child(col);col.add_child(hud.label(title,27));return col
func layout_modal() -> void:
	if not is_instance_valid(modal_panel):return
	if welcoming:
		var margin := minf(36, hud.root.size.x * 0.035)
		var width := minf(330, hud.root.size.x - margin * 2)
		modal_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
		modal_panel.offset_left = margin
		modal_panel.offset_right = width + margin
		var content := modal_panel.get_child(0).get_child(0) as Control if modal_panel.get_child_count() else null
		var desired := content.get_combined_minimum_size().y + 32 if content != null else 370.0
		var height := minf(desired, hud.root.size.y - 2 * margin)
		modal_panel.offset_top = -height / 2
		modal_panel.offset_bottom = height / 2
		var view_width: float = camera.size * get_viewport().get_visible_rect().size.aspect()
		camera.h_offset = -view_width * minf(0.16, (width + margin) / hud.root.size.x * 0.34)
		return
	var extent=(hud.root.size-Vector2(48,48)).min(Vector2(640,680))*0.5
	modal_panel.offset_left=-extent.x;modal_panel.offset_right=extent.x;modal_panel.offset_top=-extent.y;modal_panel.offset_bottom=extent.y
func close_modal() -> void:
	if welcoming:
		welcoming = false
		preview.show()
		camera.h_offset = 0
		hud.set_build_controls_visible(true)
		sim.paused = false
	binding_target=""
	if modal!=null:modal.queue_free();modal=null
func welcome() -> void:
	sim.paused=true
	welcoming = true
	preview.hide()
	preview_note.hide()
	hud.set_build_controls_visible(false)
	var col = open_modal("风屿手记")
	var message = hud.label("暖树湾\n树荫下有间小屋，门前的小路通向湖边。", 16)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(message)
	var enter = hud.button(col, "走进暖树湾", func():
		close_modal()
		hud.toast("选小屋，沿旧屋的侧墙加建；再点屋顶换形。"))
	enter.add_theme_stylebox_override("normal", hud.style(Color("58624d")))
	enter.add_theme_color_override("font_color", Color("fff4df"))
	if FileAccess.file_exists("user://island.json"):
		hud.button(col, "继续上次的岛", func(): close_modal(); load_slot("user://island.json"))
	hud.button(col, "新建海湾（无建筑）", visit_island.bind("new"))
	var places := VBoxContainer.new()
	var more = hud.button(col, "其他海湾  ▾", func(): places.visible = not places.visible)
	more.tooltip_text = "月牙湾、花园池畔、灯塔岩岬和空白海面"
	col.add_child(places)
	for item in [["harbor", "参观月牙湾"], ["garden", "去花园池畔"], ["lighthouse", "去灯塔岩岬"], ["empty", "空白海面"]]:
		hud.button(places, item[1], visit_island.bind(item[0]))
	places.hide()

func visit_island(id: String) -> void:
	close_modal()
	sim = ResidentSim.new()
	if id in ["empty", "new"]:
		data.clear_world()
		if id == "new":
			data.seed_island()
			data.paint([Vector2i(28,33),Vector2i(29,33),Vector2i(30,33)], "road")
			data.history.clear()
	else:
		IslandCompositions.create(data, id)
		if id == "harbor":
			settle_existing_homes()
	center = Vector3(31.5, 0, 33)
	camera.size = 30.5
	angle = 0.3
	pitch_offset = 0.0
	update_camera()
	rebuild()

func save_current(path:String="user://island.json") -> Error:
	var presentation={"camera":{"center":[center.x,center.y,center.z],"size":camera.size,"angle":fposmod(angle,TAU),"pitch_offset":pitch_offset},"settings":preferences.values.duplicate(true)}
	return SaveStore.save_game(data,sim,path,presentation)
func load_slot(path:String) -> void:
	var presentation:Dictionary={}
	var err=SaveStore.load_game(data,sim,path,presentation)
	if err==OK:
		if presentation.has("camera"):
			var saved=presentation.camera;center=Vector3(saved.center[0],saved.center[1],saved.center[2]);angle=saved.angle;camera.size=saved.size;pitch_offset=float(saved.get("pitch_offset",0.0));update_camera()
		if presentation.has("settings"):preferences.merge_values(presentation.settings);apply_preferences()
		set_sunset(sim.sunset);rebuild();hud.toast("岛屿已恢复");sim.paused=false
	else:hud.toast("无法读取，当前作品保持不变："+error_string(err))
func save_menu() -> void:
	var col=open_modal("岛屿存档")
	for slot in range(1,4):
		var row=HBoxContainer.new();col.add_child(row)
		var name=LineEdit.new();name.text=preferences.values.slot_names[slot-1];name.placeholder_text="手动槽 %d"%slot;name.max_length=40;name.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(name)
		name.text_changed.connect(func(value):
			preferences.values.slot_names[slot-1]=value;var error=preferences.write()
			if error!=OK:hud.toast("存档名称未能保存，可重试"))
		var path="user://slot_%d.json"%slot
		hud.button(row,"保存",func():hud.toast("保存："+error_string(save_current(path))))
		hud.button(row,"读取",func():load_slot(path))
	hud.button(col,"读取最近自动保存",func():load_slot("user://island.json"))
	for suffix in ["bak","bak2","bak3"]:hud.button(col,"恢复自动备份 "+str(["bak","bak2","bak3"].find(suffix)+1),func():load_slot("user://island.json."+suffix))
	hud.button(col,"打开照片文件夹",func():DirAccess.make_dir_recursive_absolute("user://photos");OS.shell_open(ProjectSettings.globalize_path("user://photos")))
	hud.button(col,"声音（当前："+("开" if audio.enabled else "关")+"）",func():preferences.values.muted=not preferences.values.muted;apply_preferences();close_modal();save_menu())
	hud.button(col,"减少环境动画（当前："+("开" if reduced_motion else "关")+"）",func():preferences.values.reduced_motion=not reduced_motion;apply_preferences();close_modal();save_menu())
	hud.button(col,"设置与按键",func():preload("res://game/settings/settings_panel.gd").build(self))
	hud.button(col,"返回海湾",close_modal)
func _notification(what:int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		orbit_tracking = false
		discard_stroke()
	if what==NOTIFICATION_WM_CLOSE_REQUEST:
		var err=save_current()
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

func show_credits() -> void:
	var col=open_modal("制作与许可")
	var text=hud.label(FileAccess.get_file_as_string("res://THIRD_PARTY_NOTICES.md"),18);text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;col.add_child(text)
	text=hud.label(Engine.get_license_text(),16);text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;col.add_child(text)
	text=hud.label(FileAccess.get_file_as_string("res://game/ui/fonts/OFL.txt"),16);text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;col.add_child(text)
	hud.button(col,"返回设置",func():preload("res://game/settings/settings_panel.gd").build(self))

func show_residents() -> void:
	var col=open_modal("岛民与入住")
	var houses=0
	for object in data.objects:
		if object.kind!="house":continue
		houses+=1;var occupant=0
		for person in sim.people:
			if int(person.home)==int(object.id):occupant=int(person.id);break
		var reason="岛民 %d 的家"%occupant if occupant>0 else sim.arrival_info(data,object).reason
		for person in sim.people:
			if int(person.id)==occupant:reason+=" · 喜欢"+{"tea":"喝茶","greenhouse":"花草","bench":"看海","lighthouse":"灯塔"}[sim.preference_of(person)]
		var label=hud.label("小屋 %d · %s"%[object.id,reason]);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;col.add_child(label)
	if houses==0:col.add_child(hud.label("先在陆地上放一间小屋，再从门口接路。"))
	hud.button(col,"返回建造",close_modal)
