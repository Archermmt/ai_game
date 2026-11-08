class_name ArtPost
extends RefCounted
## Optional art pack. These sources do not enable weather or photo-frame gameplay.
static func create(id:String,variant:int):
	if id=="POST_005":return "res://game/ui/vectors/POST_005_%02d.svg"%variant
	if id=="POST_006":return MotionLibrary.library().get_animation("sea_seated")
	var root=Node3D.new();root.name=id+"_%02d"%variant;var kit=ArtKit.new()
	match id:
		"POST_001":
			kit.tree(root,Vector3.ZERO,variant)
			for node in root.find_children("*","MeshInstance3D",true,false):
				if node.material_override is ShaderMaterial:
					node.material_override=node.material_override.duplicate();node.material_override.set_shader_parameter("tint",Color("e1a25d") if variant==0 else Color("c97d64"))
		"POST_002":
			var multi=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D
			var quad=QuadMesh.new();quad.size=Vector2(0.012,0.25);multi.mesh=quad;multi.instance_count=80
			for i in range(80):multi.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3(sin(i*14.7)*3, fposmod(i*0.371,3),cos(i*7.3)*3)))
			var rain=MultiMeshInstance3D.new();rain.multimesh=multi;rain.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var shader=Shader.new();shader.code="shader_type spatial; render_mode unshaded,cull_disabled; uniform float clock=0.0; void vertex(){VERTEX.y-=mod(clock*1.7,3.0);} void fragment(){ALBEDO=vec3(0.74,0.85,0.84);ALPHA=0.24;}"
			var mat=ShaderMaterial.new();mat.shader=shader;rain.material_override=mat;rain.add_to_group("island_clock_materials");root.add_child(rain)
			for i in range(8):
				var ripple=MeshInstance3D.new();var plane=PlaneMesh.new();plane.size=Vector2(0.4,0.4);ripple.mesh=plane;ripple.position=Vector3(sin(i*2.7)*2,0.015,cos(i*1.4)*2);ripple.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				var ring=Shader.new();ring.code="shader_type spatial; render_mode unshaded,cull_disabled; uniform float clock=0.0; uniform float phase=0.0; void fragment(){float t=fract(clock*0.6+phase);float d=length(UV-vec2(0.5));ALBEDO=vec3(0.77,0.86,0.82);ALPHA=(1.0-smoothstep(0.015,0.03,abs(d-t*0.45)))*(1.0-t)*0.35;}"
				var ring_mat=ShaderMaterial.new();ring_mat.shader=ring;ring_mat.set_shader_parameter("phase",i*0.137);ripple.material_override=ring_mat;ripple.add_to_group("island_clock_materials");root.add_child(ripple)
		"POST_003":
			for i in range(8):
				var x=i*0.25;var y=1.7-0.25*sin(float(i)/7*PI)
				if i<7:kit.beam(root,Vector3(x,y,0),Vector3(x+0.25,1.7-0.25*sin(float(i+1)/7*PI),0),0.012,ArtKit.WOOD)
				var bulb=kit.box(root,Vector3(x,y-0.05,0),Vector3(0.06,0.09,0.06),Color("e3c590"));var mat=StandardMaterial3D.new();mat.albedo_color=Color("e3c590");mat.emission_enabled=true;mat.emission=Color("d6a665");bulb.material_override=mat
		"POST_004":
			kit.beam(root,Vector3(0,0.2,0),Vector3(0,1.75,0),0.04,ArtKit.WOOD)
			var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for v in [Vector3(0,0.45,0),Vector3(0,1.7,0),Vector3(0,0.45,0.85)]:st.set_normal(Vector3.RIGHT);st.add_vertex(v)
			var mesh=MeshInstance3D.new();mesh.mesh=st.commit();var mat=StandardMaterial3D.new();mat.albedo_color=ArtKit.CREAM;mat.cull_mode=BaseMaterial3D.CULL_DISABLED;mat.roughness=1;mesh.material_override=mat;root.add_child(mesh)
	return root
