extends Node3D
const PAGES={
	"buildings":["BLD_001:0","BLD_002:0","BLD_003:0","BLD_004:0","BLD_005:0","BLD_006:0"],
	"modules":["KIT_001:0","KIT_002:0","KIT_003:0","KIT_004:0","KIT_005:0","KIT_006:0","KIT_007:0","KIT_008:0","KIT_009:0","KIT_010:0","KIT_011:0","KIT_012:0"],
	"nature":["NAT_001:0","NAT_001:1","NAT_001:2","NAT_002:0","NAT_002:1","NAT_003:0","NAT_004:0","NAT_005:0","NAT_006:0","NAT_007:0","NAT_007:1","NAT_007:2","NAT_008:0","NAT_009:0","NAT_010:0"],
	"props":["PROP_001:0","PROP_002:0","PROP_003:0","PROP_004:0","PROP_005:0","PROP_006:0","PROP_007:0","PROP_008:0","PROP_009:0","PROP_010:0","PROP_012:0","PROP_012:1","PROP_013:0","PROP_014:0","PROP_014:1","PROP_015:0","PROP_015:1","PROP_016:0","PROP_016:1"],
	"actors":["ACT_003:0","ACT_003:1","ACT_003:2","ACT_003:3","ACT_004:0","ACT_005:0","ACT_006:0","ACT_006:1","ACT_006:2","ACT_006:3","ACT_006:4","PROP_011:0","PROP_011:1","PROP_011:2","PROP_011:3"],
	"terrain":["TER_001:0","TER_002:0","TER_003:0","TER_004:0","TER_005:0","TER_006:0","TER_007:0","TER_008:0","TER_009:0","TER_010:0","INF_001:0","INF_002:0","INF_003:0","INF_004:0","INF_005:0","INF_006:0","INF_006:1","INF_007:0","INF_007:1","INF_008:0","INF_008:1"],
	"optional":["POST_001:0","POST_001:1","POST_002:0","POST_003:0","POST_004:0","FX_001:0","FX_002:0","FX_003:0","FX_004:0","FX_005:0"]}
func _ready() -> void:
	if DisplayServer.get_name()=="headless":get_tree().quit(1);return
	get_window().content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;get_window().content_scale_size=Vector2i.ZERO;get_window().size=Vector2i(1920,1080)
	var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("d4dbca");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;add_child(env)
	var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-48,-25,0);sun.shadow_enabled=true;add_child(sun);IslandLighting.apply(sun,env.environment,false)
	var camera=Camera3D.new();add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.current=true
	var gallery=Node3D.new();add_child(gallery)
	DirAccess.make_dir_recursive_absolute("res://snapshots/art_i6/catalog")
	for page in PAGES:
		for child in gallery.get_children():child.free()
		var entries=PAGES[page];var columns=3 if page=="buildings" else 5;var spacing=4.5 if page in ["buildings","modules","terrain"] else 2.5 if page=="actors" else 3.5
		var rows=ceili(entries.size()/float(columns));var width=(columns-1)*spacing;var depth=(rows-1)*spacing
		for i in range(entries.size()):
			var parts=entries[i].split(":");var id=parts[0];var variant=int(parts[1]);var node=ArtCatalog.create(id,variant)
			if not node is Node3D:push_error("Gallery requires model "+entries[i]);get_tree().quit(1);return
			var pivot=Node3D.new();pivot.position=Vector3((i%columns)*spacing,0,(i/columns)*spacing);gallery.add_child(pivot);pivot.add_child(node)
			if node is AnimalRig:node.animate("stand" if node.species=="gull" else "walk",false,0.25)
			elif node is ResidentRig:node.animate("home",false,3.0)
			if id=="KIT_006":node.position.y=-4.2
			var label=Label3D.new();label.text=entries[i];label.font_size=40;label.pixel_size=0.008;label.modulate=Color("405c54");label.no_depth_test=true;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.position=Vector3(0,-0.05,spacing*0.37);pivot.add_child(label)
			ArtKit.new().box(gallery,pivot.position-Vector3.UP*0.08,Vector3(spacing*0.9,0.08,spacing*0.9),Color("e4e5d6"))
		var target=Vector3(width/2,0.7,depth/2);camera.size=maxf(width*0.70+spacing,depth*0.75+spacing*1.5);camera.position=target+Vector3(9,18,22);camera.look_at(target)
		IslandEffects.update(get_tree(),0.5)
		for i in range(12):await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://snapshots/art_i6/catalog/"+page+".png")
	print("PASS native art catalog gallery, seven sheets");get_tree().quit()
