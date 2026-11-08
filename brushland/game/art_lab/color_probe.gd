extends Node3D
const COLORS=[Color("767676"),Color("efe4c9"),Color("a4b98a"),Color("c67c65")]
const COLUMNS=["standard","manual_linear","vertex_srgb","vertex_linear","texture","source_uniform","glb_roundtrip"]
var camera=Camera3D.new()
var centers:Array=[]
func add_quad(pos:Vector3,material:Material,color:Color=Color.WHITE) -> MeshInstance3D:
	var n=MeshInstance3D.new();n.mesh=QuadMesh.new();n.mesh.size=Vector2(1.45,1.0);n.position=pos;n.material_override=material;add_child(n)
	return n
func standard(color:Color) -> StandardMaterial3D:
	var mat=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_color=color;return mat
func vertex_quad(pos:Vector3,color:Color,srgb:bool) -> void:
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in [Vector3(-0.725,-0.5,0),Vector3(-0.725,0.5,0),Vector3(0.725,0.5,0),Vector3(-0.725,-0.5,0),Vector3(0.725,0.5,0),Vector3(0.725,-0.5,0)]:
		st.set_normal(Vector3.FORWARD);st.set_color(color);st.add_vertex(v)
	var mat=standard(Color.WHITE);mat.vertex_color_use_as_albedo=true;mat.vertex_color_is_srgb=srgb;mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	var n=MeshInstance3D.new();n.mesh=st.commit();n.material_override=mat;n.position=pos;add_child(n)
func _ready() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Color probe requires a native GPU viewport");get_tree().quit(1);return
	get_window().content_scale_size=Vector2i.ZERO;get_window().content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;get_window().size=Vector2i(1600,900)
	var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("25302c");add_child(env)
	add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=7.2;camera.position=Vector3(0,0,12);camera.look_at(Vector3.ZERO);camera.current=true
	var roundtrip=Node3D.new();roundtrip.name="ColorRoundtrip";add_child(roundtrip)
	for row in range(4):
		var color:Color=COLORS[row];var y=2.4-row*1.6
		for column in range(7):
			var pos=Vector3(-5.4+column*1.8,y,0);centers.append(pos)
			match column:
				0:add_quad(pos,standard(color))
				1:add_quad(pos,standard(color.srgb_to_linear()))
				2:vertex_quad(pos,color,true)
				3:vertex_quad(pos,color.srgb_to_linear(),false)
				4:
					var image=Image.create(8,8,false,Image.FORMAT_RGBA8);image.fill(color)
					var mat=standard(Color.WHITE);mat.albedo_texture=ImageTexture.create_from_image(image);add_quad(pos,mat)
				5:
					var shader=Shader.new();shader.code="shader_type spatial; render_mode unshaded; uniform vec4 tint : source_color; void fragment(){ALBEDO=tint.rgb;}"
					var mat=ShaderMaterial.new();mat.shader=shader;mat.set_shader_parameter("tint",color);add_quad(pos,mat)
				6:
					var n=MeshInstance3D.new();n.name="Color%d"%row;n.mesh=QuadMesh.new();n.mesh.size=Vector2(1.45,1.0);n.material_override=standard(color);n.position=pos;roundtrip.add_child(n)
	# Test a real export/import without relying on stale editor imports.
	var doc=GLTFDocument.new();var state=GLTFState.new();var path="user://art_i1_color_roundtrip.glb"
	if doc.append_from_scene(roundtrip,state)!=OK or doc.write_to_filesystem(state,path)!=OK:push_error("GLB export failed");get_tree().quit(1);return
	roundtrip.free();var imported=GLTFState.new()
	if doc.append_from_file(path,imported)!=OK:push_error("GLB import failed");get_tree().quit(1);return
	add_child(doc.generate_scene(imported))
	for i in range(15):await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image=get_viewport().get_texture().get_image();var method=RenderingServer.get_current_rendering_method()
	var folder="res://snapshots/art_i1/colors";DirAccess.make_dir_recursive_absolute(folder);image.save_png(folder+"/"+method+".png")
	var report={"renderer":method,"driver":RenderingServer.get_current_rendering_driver_name(),"mode":"unshaded/no exposure changes","columns":COLUMNS,"rows":[],"tolerance":0.035,"passed":true}
	for row in range(4):
		var measured:Dictionary={};var reference:Color=COLORS[row]
		for column in range(7):
			var pixel=camera.unproject_position(centers[row*7+column]);var sample=image.get_pixel(int(pixel.x),int(pixel.y))
			var delta=maxf(absf(sample.r-reference.r),maxf(absf(sample.g-reference.g),absf(sample.b-reference.b)))
			measured[COLUMNS[column]]={"hex":sample.to_html(false),"max_channel_error":delta}
			if COLUMNS[column] in ["standard","vertex_srgb","texture","source_uniform","glb_roundtrip"] and delta>report.tolerance:report.passed=false
			# An intentionally double-converted column must visibly fail the reference.
			if COLUMNS[column]=="manual_linear" and delta<0.15:report.passed=false
		report.rows.append({"srgb":reference.to_html(false),"measured":measured})
	DirAccess.make_dir_recursive_absolute("res://docs/reports/art_i1");var f=FileAccess.open("res://docs/reports/art_i1/colors_"+method+".json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close();print("COLOR_PROBE ",JSON.stringify(report));get_tree().quit(0 if report.passed else 1)
