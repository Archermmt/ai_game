class_name ArtCatalog
extends RefCounted
const CLIPS={"ANI_001":["idle"],"ANI_002":["walk"],"ANI_003":["wave"],"ANI_004":["sit_down","sit_idle","stand_up"],"ANI_005":["water"],"ANI_006":["gull_fly"],"ANI_007":["gull_stand"],"ANI_008":["cat_walk"],"ANI_009":["cat_sleep"],"ANI_011":["drink"],"ANI_012":["gull_takeoff"],"ANI_013":["gull_land"],"ANI_014":["cat_stretch"],"ANI_015":["dragcase"],"ANI_016":["carrylantern","carrypot"]}
static func create(id:String,variant:int):
	if id.begins_with("POST_"):return ArtPost.create(id,variant)
	if CLIPS.has(id):return MotionLibrary.library().get_animation(CLIPS[id][variant])
	if id.begins_with("UI_"):
		var number=int(id.trim_prefix("UI_"))
		if number in [1,2,3,4]:return "res://game/ui/vectors/%s_%02d.svg"%[id,variant]
		if number==8:return "res://game/ui/icons/"+["house_basic","house_coast","house_garden","greenhouse","tea","lighthouse"][variant]+".png"
		return ui_template(id)
	if id.begins_with("MAT_"):return material(id)
	if id=="ENV_001":
		var sun=DirectionalLight3D.new();var env=Environment.new();IslandLighting.apply(sun,env,variant==1)
		env.background_mode=Environment.BG_COLOR;env.background_color=Color("8bbcb9");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color.WHITE
		env.set_meta("sun_color",sun.light_color);env.set_meta("sun_energy",sun.light_energy);env.set_meta("sun_rotation",sun.rotation_degrees);sun.free();return env
	if id.begins_with("SCN_"):
		var d=IslandData.new();IslandCompositions.create(d,IslandCompositions.IDS[int(id.trim_prefix("SCN_"))-1]);return {"world":d.snapshot(),"recipe":IslandCompositions.IDS[int(id.trim_prefix("SCN_"))-1]}
	var root=Node3D.new();root.name=id+"_%02d"%variant;var k=ArtKit.new()
	if id.begins_with("BLD_"):
		var type=["house","house","house","greenhouse","tea","lighthouse"][int(id.trim_prefix("BLD_"))-1];root.free();var building=k.building(type,["basic","coast","garden"][int(id.trim_prefix("BLD_"))-1] if type=="house" else "basic");MaterialLibrary.new().dress(building,type);return building
	if id.begins_with("ACT_"):
		root.free()
		if id in ["ACT_004","ACT_005"]:return AnimalRig.make("gull" if id=="ACT_004" else "cat")
		var rig=ResidentRig.create(variant%4,id!="ACT_001")
		if id=="ACT_001":
			for key in rig.wearables:rig.set_wearable(key,false)
		if id=="ACT_002":
			var skeleton=rig.skeleton;rig.remove_child(skeleton);rig.free();return skeleton
		if id=="ACT_006":
			rig.body.mesh=rig.wearables[["cloak","overalls","apron","scarf","sweater"][variant]]
			for child in rig.skeleton.get_children():child.free()
			var outfit=Node3D.new();rig.remove_child(rig.body);rig.remove_child(rig.skeleton);outfit.add_child(rig.body);outfit.add_child(rig.skeleton);rig.free();return outfit
		return rig
	if id=="ANI_010":
		root.free()
		var a=Animation.new();a.length=8;a.loop_mode=Animation.LOOP_LINEAR
		var t=a.add_track(Animation.TYPE_POSITION_3D);a.track_set_path(t,NodePath("."))
		for i in range(5):a.position_track_insert_key(t,i*2.0,Vector3(0,0.1+sin(i*PI/2)*0.02,0))
		return a
	if id.begins_with("TER_"):
		if id=="TER_009":
			var mesh=MeshInstance3D.new();var plane=PlaneMesh.new();plane.size=Vector2(8,8);mesh.mesh=plane;mesh.material_override=material("MAT_003");root.add_child(mesh)
		elif id=="TER_010":k.box(root,Vector3(0,-0.25,0),Vector3(1,0.5,1),Color("b5b5a2"))
		else:root.add_child(surface_patch(id))
		return root
	if id.begins_with("INF_"):
		var number=int(id.trim_prefix("INF_"))
		if number<6:
			k.cylinder(root,Vector3(0,0.02,0),0.325,0.035,Color("d9c7a5"))
			var masks=[[0,2],[0,1],[0,1,2],[0,1,2,3],[0]][number-1]
			for direction in masks:
				var d=BuildingRules.DIRS[direction];k.box(root,Vector3(d.x*0.25,0.025,d.y*0.25),Vector3(1 if d.x!=0 else 0.65,0.04,1 if d.y!=0 else 0.65),Color("d9c7a5"))
		else:
			for z in range(3 if number==8 else 1):
				if number==8 or variant==0:
					for plank in range(4):k.box(root,Vector3(0,0.05,z+(plank-1.5)*0.23),Vector3(0.9,0.1,0.21),ArtKit.WOOD)
				if variant==1 or number==8:
					for side in [-1,1]:k.cylinder(root,Vector3(side*0.45,0.2,z),0.05,0.8,ArtKit.WOOD)
					if number!=7:
						for side in [-1,1]:k.beam(root,Vector3(side*0.45,0.55,z-0.5),Vector3(side*0.45,0.55,z+0.5),0.045,ArtKit.WOOD)
		return root
	if id.begins_with("KIT_"):
		root.free();return building_module(int(id.trim_prefix("KIT_")))
	if id in ["NAT_001","NAT_010"]:k.tree(root,Vector3.ZERO,variant if id=="NAT_001" else 2);return root
	if id=="NAT_003":FoliageLayer.publish(root,[[{"transform":Transform3D.IDENTITY,"color":Color.WHITE}],[],[]],load("res://game/art/shaders/foliage.gdshader"));return root
	if id=="NAT_004":k.flower(root,Vector3.ZERO,1);return root
	if id=="NAT_009":
		for i in range(3):k.sphere(root,Vector3(sin(i*2)*0.1,0.2,cos(i*2)*0.1),Vector3(0.18,0.3,0.18),ArtKit.GREEN)
		return root
	if id.begins_with("NAT_") or id in ["PROP_005","PROP_006","PROP_007","PROP_008","PROP_009","PROP_012","PROP_013","PROP_014","PROP_015","PROP_016"]:
		root.free();return ArtExtras.create(id,variant)
	if id=="PROP_011":
		var rig=ResidentRig.new();rig.rests=[Vector3.ZERO,Vector3.ZERO,Vector3.ZERO];rig.build_headwear(variant);var mesh=MeshInstance3D.new();var source=ArrayMesh.new();
		for st in rig.builders.values():st.commit(source)
		var arrays=source.surface_get_arrays(0);arrays[Mesh.ARRAY_BONES]=null;arrays[Mesh.ARRAY_WEIGHTS]=null;var hat=ArrayMesh.new();hat.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);hat.surface_set_material(0,ResidentRig.palette_material());mesh.mesh=hat;root.add_child(mesh);rig.skeleton.free();rig.body.free();rig.free();return root
	match id:
		"PROP_001":k.cylinder(root,Vector3(0,0.12,0),0.10,0.24,ArtKit.CORAL,0.15)
		"PROP_002":
			k.box(root,Vector3(0,0.1,0),Vector3(0.8,0.2,0.25),ArtKit.WOOD)
			for x in [-0.25,0,0.25]:k.flower(root,Vector3(x,0.2,0),1)
		"PROP_003":k.bench(root)
		"PROP_004":k.cylinder(root,Vector3(0,0.3,0),0.07,0.6,ArtKit.WOOD);k.cylinder(root,Vector3(0,0.63,0),0.43,0.08,ArtKit.WOOD)
		"PROP_010":
			k.sphere(root,Vector3.ZERO,Vector3(0.87,0.42,2.8),ArtKit.BLUE);k.sphere(root,Vector3(0,0.12,0),Vector3(0.7,0.2,2.55),ArtKit.CREAM)
			for z in [-0.65,0,0.65]:k.box(root,Vector3(0,0.25,z),Vector3(0.65,0.06,0.18),ArtKit.WOOD)
		"FX_001":IslandEffects.chimney(root)
		"FX_002":
			var water=MeshInstance3D.new();water.mesh=PlaneMesh.new();water.material_override=material("MAT_003");root.add_child(water)
		"FX_003","FX_004":IslandEffects.burst(root,Vector3.ZERO,0,id=="FX_004")
		"FX_005":IslandEffects.lighthouse(root,true)
		_:
			root.free();return null
	return root
static func material(id:String) -> Material:
	var library=MaterialLibrary.new()
	match id:
		"MAT_002":return library.material("white_plaster_02",ArtKit.CREAM)
		"MAT_003":
			var mat=ShaderMaterial.new();mat.shader=load("res://game/art/shaders/bay_water.gdshader");var image=Image.create(1,1,false,Image.FORMAT_RGB8);image.fill(Color(0,0.5,0));mat.set_shader_parameter("island_field",ImageTexture.create_from_image(image));return mat
		"MAT_004":
			var mat=ShaderMaterial.new();mat.shader=load("res://game/art/shaders/foliage.gdshader");mat.set_shader_parameter("tuft",load("res://game/art/generated/meadow_tuft.png"));return mat
		"MAT_005":
			var mat=StandardMaterial3D.new();mat.albedo_color=Color(0.64,0.80,0.73,0.2);mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.cull_mode=BaseMaterial3D.CULL_DISABLED;mat.roughness=0.18;return mat
		"MAT_006":return ResidentRig.palette_material()
		"MAT_007":var mat=library.window_material();mat.set_shader_parameter("night",true);return mat
	var mat=StandardMaterial3D.new();mat.roughness=1
	if id=="MAT_001":mat.vertex_color_use_as_albedo=true;mat.vertex_color_is_srgb=true
	else:mat.albedo_color=ArtKit.CREAM
	return mat
static func surface_patch(id:String) -> MeshInstance3D:
	if id in ["TER_002","TER_003","TER_004"]:
		var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in range(1 if id=="TER_002" else 4):
			var a=Vector2(float(i),0) if id=="TER_002" else Vector2(cos(i*PI/8),sin(i*PI/8))*0.5
			var b=Vector2(float(i+1),0) if id=="TER_002" else Vector2(cos((i+1)*PI/8),sin((i+1)*PI/8))*0.5
			var normal=Vector3(a.x+b.x,0,a.y+b.y).normalized()*( -1 if id=="TER_004" else 1)
			var points=[Vector3(a.x,0,a.y),Vector3(b.x,0,b.y),Vector3(b.x,0.5,b.y),Vector3(a.x,0.5,a.y)]
			for index in ([0,2,1,0,3,2] if id=="TER_004" else [0,1,2,0,2,3]):st.set_normal(normal);st.set_uv(Vector2(points[index].x,points[index].y));st.add_vertex(points[index])
		var result=MeshInstance3D.new();result.mesh=st.commit();var mat=StandardMaterial3D.new();mat.albedo_color=Color("b7b6a3");result.material_override=mat;return result
	var tiles:Dictionary={};var num=int(id.trim_prefix("TER_"))
	for x in range(-1,3):
		for z in range(-1,3):
			var h=2
			if num in [2,3,4]:h=4 if x<=0 else 1
			if num==5:h=1 if x<=0 else 0
			if num==6:h=1 if x<=0 and z<=0 else 0
			if num==7:h=0 if x>0 and z>0 else 1
			if num==8:h=1 if x<=0 else 2
			tiles["%d,%d"%[x,z]]={"h":h,"surface":"sand" if num in [5,6,7] else "rock" if num in [2,3,4] else "grass"}
	var surface=IslandSurface.new({"tiles":tiles,"objects":[]});var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(2):
		for x in range(2):
			var base=Vector2(x,z)*0.5;var points=[base,base+Vector2(0,0.5),base+Vector2(0.5,0.5),base+Vector2(0.5,0)]
			for index in [0,2,1,0,3,2]:
				var v=points[index];var sample=surface.sample_surface(v);st.set_normal(sample.normal);st.set_color(Color("d7c9a5") if num in [5,6,7] else Color("a4b98a"));st.add_vertex(Vector3(v.x,sample.height,v.y))
	var mesh=MeshInstance3D.new();mesh.mesh=st.commit();mesh.material_override=material("MAT_001");return mesh
static func ui_template(id:String) -> Control:
	var hud=IslandHud.new();hud._ready()
	if id in ["UI_005","UI_006"]:
		var component=hud.root.find_child("ToolBar",true,false) if id=="UI_005" else hud.card
		component.get_parent().remove_child(component);component.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);component.position=Vector2.ZERO;component.theme=hud.root.theme;component.custom_minimum_size=Vector2(740,124) if id=="UI_005" else Vector2(244,356);component.visible=true;hud.free();return component
	var panel=PanelContainer.new();panel.custom_minimum_size=Vector2(320,120);panel.add_theme_stylebox_override("panel",hud.style(Color("f7f1df")))
	var col=VBoxContainer.new();panel.add_child(col)
	var rows={"UI_005":["地貌 · 建造 · 花草 · 整理","草地  沙滩  岩台  海水"],"UI_006":["岛上的小心愿","0 / 6 个日常片段 · 没有期限","海风座位  ·  第一簇花"],"UI_007":["按住左键涂画","右键取消 · 抬手提交"],"UI_009":["设置","声音 · 减少环境动画","返回建造"],"UI_010":["存档与恢复","槽位 1   槽位 2   槽位 3","自动备份 · 照片文件夹"],"UI_011":["拍照模式","Q/E 转向 · 滚轮缩放","F12 保存照片 · Esc 返回"]}
	for text in rows[id]:col.add_child(hud.label(text))
	hud.free();return panel

static func building_module(number:int) -> Node3D:
	var root=Node3D.new();var k=ArtKit.new()
	match number:
		1:k.box(root,Vector3(0,0.9,0),Vector3(0.8,1.8,0.08),ArtKit.CREAM)
		2,3:
			var hole_w=0.55 if number==2 else 0.65;var hole_h=0.65 if number==2 else 1.4;var bottom=0.65 if number==2 else 0.0
			for side in [-1,1]:k.box(root,Vector3(side*(0.8+hole_w)/4,0.9,0),Vector3((0.8-hole_w)/2,1.8,0.08),ArtKit.CREAM)
			if bottom>0:k.box(root,Vector3(0,bottom/2,0),Vector3(hole_w,bottom,0.08),ArtKit.CREAM)
			var top=1.8-bottom-hole_h;k.box(root,Vector3(0,1.8-top/2,0),Vector3(hole_w,top,0.08),ArtKit.CREAM)
			k.box(root,Vector3(0,bottom+hole_h/2,0.025),Vector3(hole_w,hole_h,0.035),ArtKit.BLUE)
			if number==2:
				for x in [-hole_w/2,0,hole_w/2]:k.box(root,Vector3(x,0.975,0.06),Vector3(0.025,0.7,0.025),ArtKit.WOOD)
				for y in [0.65,0.975,1.3]:k.box(root,Vector3(0,y,0.06),Vector3(0.6,0.025,0.025),ArtKit.WOOD)
		4,5:k.roof(root,1.8,ArtKit.CORAL,2,2,1.0 if number==4 else 0.6)
		6:k.cylinder(root,Vector3(0,4.6,0),0.9,0.8,ArtKit.CORAL,0.015)
		7:
			for x in [-0.9,0.9]:
				for z in [-0.9,0,0.9]:k.beam(root,Vector3(x,0,z),Vector3(x,1.8,z),0.05,ArtKit.CREAM)
			for z in [-0.9,0,0.9]:
				k.beam(root,Vector3(-0.9,1.8,z),Vector3(0,2.8,z),0.05,ArtKit.CREAM);k.beam(root,Vector3(0,2.8,z),Vector3(0.9,1.8,z),0.05,ArtKit.CREAM)
			k.beam(root,Vector3(0,2.8,-0.9),Vector3(0,2.8,0.9),0.05,ArtKit.CREAM)
			for x in [-0.9,0.9]:
				var glass=k.box(root,Vector3(x,0.9,0),Vector3(0.02,1.8,1.8),Color.WHITE);glass.material_override=material("MAT_005")
		8:
			k.box(root,Vector3(0,0.06,0),Vector3(1.5,0.12,0.35),ArtKit.WOOD)
			for x in [-0.7,0.7]:k.box(root,Vector3(x,0.9,0),Vector3(0.06,1.8,0.06),ArtKit.WOOD)
		9:
			k.box(root,Vector3(0,0.05,0),Vector3(1.2,0.1,0.3),ArtKit.WOOD)
			for x in [-0.55,0,0.55]:k.box(root,Vector3(x,0.375,0.12),Vector3(0.045,0.65,0.045),ArtKit.WOOD)
			k.box(root,Vector3(0,0.7,0.12),Vector3(1.2,0.05,0.05),ArtKit.WOOD)
		10:k.cylinder(root,Vector3(0,1.85,0),0.75,3.7,ArtKit.CREAM,0.55);k.cylinder(root,Vector3(0,3.95,0),0.55,0.5,ArtKit.BLUE)
		11:k.box(root,Vector3(0,0.225,0),Vector3(0.25,0.45,0.25),ArtKit.CREAM);k.box(root,Vector3(0,0.45,0),Vector3(0.3,0.05,0.3),ArtKit.WOOD)
		12:k.box(root,Vector3(0,0.06,0),Vector3(2,0.12,2),Color("c7bfa9"))
	for name in ["LeftSnap","RightSnap","Origin"]:
		var marker=Marker3D.new();marker.name=name;marker.position.x=-0.4 if name=="LeftSnap" else 0.4 if name=="RightSnap" else 0.0;root.add_child(marker)
	if number==3:
		var entry=Marker3D.new();entry.name="Entrance";entry.position.z=0.5;root.add_child(entry)
	return root
