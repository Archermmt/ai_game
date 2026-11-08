class_name IslandEffects
extends RefCounted
static func chimney(parent:Node3D) -> void:
	var group=Node3D.new();group.name="ChimneySmoke";group.position=Vector3(0.5,2.72,-0.4);group.set_meta("batch_exclude",true);parent.add_child(group)
	var kit=ArtKit.new()
	for i in range(3):
		var puff=kit.sphere(group,Vector3(0,i*0.15,0),Vector3.ONE*0.16,Color.WHITE)
		var mat=StandardMaterial3D.new();mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_color=Color(0.9,0.92,0.85,0.15)
		puff.material_override=mat;puff.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;puff.set_meta("phase",float(i)/3);puff.add_to_group("island_smoke")
static func lighthouse(parent:Node3D,night:bool) -> void:
	var sweep=Node3D.new();sweep.name="LighthouseSweep";sweep.position=Vector3(0,3.98,0);sweep.visible=night;sweep.set_meta("batch_exclude",true);parent.add_child(sweep);sweep.add_to_group("island_lanterns");sweep.add_to_group("island_sweeps")
	var light=SpotLight3D.new();light.rotation.y=PI;light.spot_range=14;light.spot_angle=16;light.light_energy=0.7;light.light_color=Color("efcf91");sweep.add_child(light)
	var cone=CylinderMesh.new();cone.top_radius=0.03;cone.bottom_radius=1.7;cone.height=12;cone.radial_segments=16
	var beam=MeshInstance3D.new();beam.mesh=cone;beam.position.z=6;beam.rotation.x=-PI/2;beam.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shader=Shader.new();shader.code="shader_type spatial; render_mode unshaded,cull_disabled,blend_add,depth_draw_never; void fragment(){ALBEDO=vec3(0.95,0.80,0.48);ALPHA=0.025*(1.0-UV.y)*pow(sin(UV.x*3.14159),2.0);}"
	var mat=ShaderMaterial.new();mat.shader=shader;beam.material_override=mat;sweep.add_child(beam)
static func burst(parent:Node3D,position:Vector3,clock:float,wish:bool=false) -> void:
	var kit=ArtKit.new();var group=Node3D.new();group.position=position;group.set_meta("born",clock);group.set_meta("wish",wish);parent.add_child(group);group.add_to_group("island_bursts")
	for i in range(7):
		var p=kit.sphere(group,Vector3.ZERO,Vector3.ONE*(0.08 if wish else 0.045),Color("e8c97f") if wish else Color("c5dbb0"));p.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
static func update(tree:SceneTree,clock:float) -> void:
	for visual in tree.get_nodes_in_group("island_clock_materials"):visual.material_override.set_shader_parameter("clock",clock)
	for sweep in tree.get_nodes_in_group("island_sweeps"):sweep.rotation.y=clock*0.12
	for puff in tree.get_nodes_in_group("island_smoke"):
		var phase=fposmod(clock*0.12+float(puff.get_meta("phase")),1.0)
		puff.position=Vector3(phase*0.16,phase*0.75,0);puff.scale=Vector3.ONE*(0.12+phase*0.22)
		puff.material_override.albedo_color.a=(1.0-phase)*0.16
	for group in tree.get_nodes_in_group("island_bursts"):
		var age=clock-float(group.get_meta("born"))
		if age>1.2:group.queue_free();continue
		var wish=bool(group.get_meta("wish"))
		for i in range(group.get_child_count()):
			var angle=i*TAU/7;group.get_child(i).position=Vector3(cos(angle)*age*0.25,age*(0.7 if wish else 0.4)-age*age*0.15,sin(angle)*age*0.25);group.get_child(i).scale=Vector3.ONE*maxf(0.0,1.0-age/1.2)
