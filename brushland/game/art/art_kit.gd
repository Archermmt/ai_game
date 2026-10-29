class_name ArtKit
extends RefCounted
const CREAM=Color("efe4c9")
const WOOD=Color("aa8060")
const CORAL=Color("c67c65")
const BLUE=Color("6e919e")
const GREEN=Color("789579")
var materials:Dictionary={}
static var leaf_meshes:Dictionary={}
static var leaf_material:ShaderMaterial
static var flower_material:StandardMaterial3D
func material(color:Color) -> StandardMaterial3D:
	var k=color.to_html()
	if not materials.has(k):
		# StandardMaterial3D accepts sRGB colors and performs its own conversion.
		# See the native renderer/GLB color probe in game/art_lab.
		var m=StandardMaterial3D.new();m.albedo_color=color;m.roughness=0.95
		materials[k]=m
	return materials[k]
func mesh(parent:Node3D,geo:Mesh,pos:Vector3,color:Color) -> MeshInstance3D:
	var n=MeshInstance3D.new();n.mesh=geo;n.position=pos;n.material_override=material(color);parent.add_child(n);return n
func box(parent:Node3D,pos:Vector3,size:Vector3,color:Color) -> MeshInstance3D:
	var geo=BoxMesh.new();geo.size=size;return mesh(parent,geo,pos,color)
func sphere(parent:Node3D,pos:Vector3,size:Vector3,color:Color) -> MeshInstance3D:
	var geo=SphereMesh.new();geo.radius=0.5;geo.height=1
	var extent=maxf(size.x,maxf(size.y,size.z))
	geo.radial_segments=4 if extent<0.12 else 6 if extent<0.2 else 8 if extent<0.55 else 12
	geo.rings=1 if extent<0.2 else 2 if extent<0.55 else 6
	var n=mesh(parent,geo,pos,color);n.scale=size;return n
func cylinder(parent:Node3D,pos:Vector3,radius:float,height:float,color:Color,top:float=-1) -> MeshInstance3D:
	var geo=CylinderMesh.new();geo.bottom_radius=radius;geo.top_radius=radius if top<0 else top;geo.height=height;geo.rings=0;geo.radial_segments=6 if radius<0.035 else 8 if radius<0.1 else 16
	return mesh(parent,geo,pos,color)
func beam(parent:Node3D,a:Vector3,b:Vector3,width:float,color:Color) -> void:
	var n=box(parent,(a+b)/2,Vector3(width,a.distance_to(b),width),color)
	if a.distance_to(b)>0.001:n.quaternion=Quaternion(Vector3.UP,(b-a).normalized())
func roof(parent:Node3D,y:float,color:Color,width:float=2.05,depth:float=2.05,rise:float=0.95) -> void:
	var w=width/2;var d=depth/2
	var v=[Vector3(-w,y,-d),Vector3(w,y,-d),Vector3(0,y+rise,-d),Vector3(-w,y,d),Vector3(w,y,d),Vector3(0,y+rise,d)]
	var indices=[0,2,1,3,4,5,0,3,5,0,5,2,1,2,5,1,5,4]
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for offset in range(0,indices.size(),3):
		for i in [indices[offset],indices[offset+2],indices[offset+1]]:
			st.set_uv(Vector2(v[i].x,v[i].z));st.add_vertex(v[i])
	st.generate_normals();st.generate_tangents();mesh(parent,st.commit(),Vector3.ZERO,color)
	beam(parent,Vector3(0,y+rise+0.03,-d-0.04),Vector3(0,y+rise+0.03,d+0.04),0.12,color.lightened(0.1))
	for side in [-1,1]:
		beam(parent,Vector3(side*w,y,-d),Vector3(side*w,y,d),0.12,CREAM)
		for z in [-0.7,0.0,0.7]:beam(parent,Vector3(side*w,y+0.02,z),Vector3(0,y+rise+0.02,z),0.025,color.darkened(0.08))
func flower(parent:Node3D,pos:Vector3,index:int=0) -> void:
	cylinder(parent,pos+Vector3(0,0.15,0),0.018,0.3,GREEN)
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for petal in range(6):
		var angle=petal*TAU/5;var center=pos+Vector3(cos(angle)*0.07,0.31,sin(angle)*0.07) if petal<5 else pos+Vector3(0,0.325,0)
		var radius=0.05 if petal<5 else 0.035;var color=(Color("f7eac5") if index%2==0 else Color("d89e89")) if petal<5 else Color("d7b365")
		for i in range(6):
			for point in [center,center+Vector3(cos(i*TAU/6)*radius,0,sin(i*TAU/6)*radius),center+Vector3(cos((i+1)*TAU/6)*radius,0,sin((i+1)*TAU/6)*radius)]:st.set_normal(Vector3.UP);st.set_color(color);st.add_vertex(point)
	if flower_material==null:
		flower_material=StandardMaterial3D.new();flower_material.vertex_color_use_as_albedo=true;flower_material.vertex_color_is_srgb=true;flower_material.cull_mode=BaseMaterial3D.CULL_DISABLED;flower_material.roughness=1.0
	var node=MeshInstance3D.new();node.mesh=st.commit();node.material_override=flower_material;parent.add_child(node)
func pot(parent:Node3D,pos:Vector3) -> void:
	cylinder(parent,pos+Vector3(0,0.12,0),0.1,0.24,CORAL,0.15)
	for a in range(3):sphere(parent,pos+Vector3(cos(a*2)*0.1,0.32,sin(a*2)*0.1),Vector3(0.18,0.25,0.18),GREEN)
func tree(parent:Node3D,pos:Vector3,seed_value:int=0) -> void:
	var root=Node3D.new();root.position=pos;root.rotation.y=seed_value*0.71;parent.add_child(root)
	var shape=posmod(seed_value,3)
	var slender=shape==2
	cylinder(root,Vector3(0,0.9,0),0.12,1.8,WOOD,0.065)
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for cluster in range(5 if shape==1 else 7):
		var angle=cluster*2.399963
		var center=Vector3(cos(angle)*(0.3 if slender else 0.65),(1.45+cluster*0.10+sin(angle)*0.10) if shape==1 else (1.6+cluster*0.15),sin(angle)*(0.3 if slender else 0.65))
		beam(root,Vector3(0,0.9,0),center,0.065,WOOD)
		if leaf_meshes.has(shape):continue
		for plane in range(4):
			var yaw=plane*PI/3;var side=Vector3(cos(yaw),0,sin(yaw))*0.65
			var up=Vector3.UP*(0.85 if slender else 0.65)
			if plane==3:side=Vector3(0.6,0,0);up=Vector3(0,0,0.6)
			var points=[center-side-up,center+side-up,center+side+up,center-side+up]
			var uv=[Vector2(0,1),Vector2(1,1),Vector2(1,0),Vector2(0,0)]
			for i in [0,1,2,0,2,3]:st.set_uv(uv[i]);st.add_vertex(points[i])
	if not leaf_meshes.has(shape):leaf_meshes[shape]=st.commit()
	var leaves=MeshInstance3D.new();leaves.mesh=leaf_meshes[shape]
	if leaf_material==null:
		leaf_material=ShaderMaterial.new();leaf_material.shader=load("res://game/art/shaders/leaves.gdshader");leaf_material.set_shader_parameter("leaves",load("res://game/art/generated/leaf_cluster.png"))
	leaves.material_override=leaf_material;root.add_child(leaves);leaves.add_to_group("island_leaf_nodes")
func bench(parent:Node3D) -> void:
	for x in [-0.38,0.38]:
		for z in [-0.16,0.16]:box(parent,Vector3(x,0.19,z),Vector3(0.08,0.38,0.08),WOOD.darkened(0.1))
	for z in [-0.16,0,0.16]:box(parent,Vector3(0,0.4,z),Vector3(1,0.07,0.13),WOOD)
	for y in [0.65,0.84]:box(parent,Vector3(0,y,-0.2),Vector3(1,0.12,0.08),WOOD)
func table(parent:Node3D,pos:Vector3) -> void:
	cylinder(parent,pos+Vector3(0,0.3,0),0.07,0.6,WOOD)
	cylinder(parent,pos+Vector3(0,0.63,0),0.43,0.08,WOOD)
	for x in [-0.18,0.18]:
		cylinder(parent,pos+Vector3(x,0.73,0),0.06,0.12,CREAM)
func building(kind:String,variant:String="basic",roof_index:int=0) -> Node3D:
	var root=Node3D.new();root.name=kind.capitalize()
	var roof_color=[CORAL,BLUE,Color("8f9d7d")][roof_index%3]
	if variant=="coast" and roof_index==0:roof_color=BLUE
	if kind=="bench":bench(root);return root
	if kind=="pot":pot(root,Vector3.ZERO);return root
	if kind=="tree":tree(root,Vector3.ZERO);return root
	if kind=="lighthouse":
		cylinder(root,Vector3(0,1.85,0),0.65,3.7,CREAM,0.47)
		for y in [0.2,2.7,3.5]:cylinder(root,Vector3(0,y,0),0.69,0.12,WOOD if y>3 else Color("d4cab2"))
		cylinder(root,Vector3(0,3.98,0),0.5,0.8,Color("b4c8bd"))
		cylinder(root,Vector3(0,4.48,0),0.72,0.5,CORAL,0.02)
		sphere(root,Vector3(0,4.82,0),Vector3.ONE*0.16,WOOD)
		for i in range(12):
			var a=i*TAU/12;box(root,Vector3(cos(a)*0.7,3.77,sin(a)*0.7),Vector3(0.045,0.45,0.045),WOOD)
		cylinder(root,Vector3(0,3.98,0),0.22,0.5,Color("efce85"))
		box(root,Vector3(0,0.6,0.64),Vector3(0.48,1.2,0.08),BLUE)
		for y in [1.9,2.8]:box(root,Vector3(0,y,0.57),Vector3(0.22,0.36,0.08),BLUE)
		pot(root,Vector3(0.65,0,0.55));return root
	if kind=="tea":
		cylinder(root,Vector3(0,0.08,0),1,0.16,CREAM)
		for x in [-0.75,0.75]:
			for z in [-0.75,0.75]:box(root,Vector3(x,0.95,z),Vector3(0.1,1.8,0.1),CREAM)
		roof(root,1.8,roof_color,2.0,2.0,0.6);table(root,Vector3.ZERO)
		for x in [-0.65,0.65]:
			cylinder(root,Vector3(x,0.25,0),0.18,0.5,WOOD)
		pot(root,Vector3(-0.8,0,0.8));return root
	if kind=="greenhouse":
		box(root,Vector3(0,0.15,0),Vector3(1.85,0.3,1.85),CREAM)
		for x in [-0.8,0.8]:
			for z in [-0.8,0,0.8]:beam(root,Vector3(x,0.3,z),Vector3(x,1.8,z),0.06,CREAM)
		for z in [-0.8,0,0.8]:
			beam(root,Vector3(-0.8,1.8,z),Vector3(0,2.8,z),0.07,CREAM)
			beam(root,Vector3(0,2.8,z),Vector3(0.8,1.8,z),0.07,CREAM)
			pot(root,Vector3(-0.4,0.3,z*0.7));pot(root,Vector3(0.4,0.3,z*0.7))
		# Separate transparent panels keep frame, panes and interior readable.
		for x in [-0.8,0.8]:
			var panel=box(root,Vector3(x,1.05,0),Vector3(0.025,1.35,1.55),Color("b4ccbd"))
			var glass=StandardMaterial3D.new();glass.albedo_color=Color(0.64,0.80,0.73,0.2);glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;glass.roughness=0.18;glass.cull_mode=BaseMaterial3D.CULL_DISABLED;panel.material_override=glass
		beam(root,Vector3(0,2.8,-0.9),Vector3(0,2.8,0.9),0.08,CREAM)
		return root
	box(root,Vector3(0,0.12,0),Vector3(1.9,0.24,1.9),Color("c7bfa9"))
	box(root,Vector3(0,1,0),Vector3(1.65,1.7,1.65),CREAM)
	roof(root,1.85,roof_color)
	for z in [-0.84,0.84]:
		for x in [-0.84,0,0.84]:box(root,Vector3(x,1,z),Vector3(0.06,1.72,0.045),WOOD)
		for y in [0.28,1.55]:box(root,Vector3(0,y,z),Vector3(1.72,0.07,0.045),WOOD)
	box(root,Vector3(0,0.63,0.84),Vector3(0.45,1.12,0.08),BLUE)
	sphere(root,Vector3(0,1.2,0.84),Vector3(0.45,0.45,0.08),BLUE)
	sphere(root,Vector3(0.13,0.65,0.91),Vector3.ONE*0.05,Color("e3c487"))
	for side in [-1,1]:
		box(root,Vector3(side*0.55,1.08,0.84),Vector3(0.32,0.42,0.08),BLUE)
		for dx in [-0.21,0.21]:box(root,Vector3(side*0.55+dx,1.08,0.86),Vector3(0.08,0.48,0.07),GREEN)
		box(root,Vector3(side*0.55,1.08,0.9),Vector3(0.025,0.42,0.03),CREAM)
		box(root,Vector3(side*0.55,1.08,0.9),Vector3(0.32,0.025,0.03),CREAM)
	box(root,Vector3(0.5,2.2,-0.4),Vector3(0.24,0.8,0.28),CREAM)
	box(root,Vector3(0.5,2.63,-0.4),Vector3(0.32,0.09,0.36),WOOD)
	box(root,Vector3(0,0.1,1),Vector3(0.6,0.2,0.25),Color("c6b89e"))
	if variant=="garden":
		for x in [-0.56,0.56]:
			box(root,Vector3(x,0.79,0.98),Vector3(0.42,0.15,0.2),WOOD)
			for i in range(3):flower(root,Vector3(x-0.13+i*0.13,0.8,0.98),i)
		pot(root,Vector3(-0.65,0,0.98))
	if variant=="coast":
		box(root,Vector3(0,1.45,1.05),Vector3(1.45,0.09,0.4),BLUE)
		for x in [-0.7,0.7]:box(root,Vector3(x,0.8,1.12),Vector3(0.06,1.6,0.06),WOOD)
	return root
func character(index:int) -> Node3D:
	var root=Node3D.new();root.name="Resident"
	var cloth=[Color("d3b461"),GREEN,CORAL,BLUE][index%4]
	for x in [-0.12,0.12]:
		box(root,Vector3(x,0.13,0),Vector3(0.12,0.25,0.16),WOOD.darkened(0.2))
		box(root,Vector3(x,0.035,0.06),Vector3(0.14,0.07,0.23),WOOD.darkened(0.25))
	sphere(root,Vector3(0,0.46,0),Vector3(0.43,0.54,0.32),cloth)
	sphere(root,Vector3(0,0.86,0),Vector3(0.43,0.43,0.41),Color("dcb892"))
	for x in [-0.09,0.09]:sphere(root,Vector3(x,0.87,0.193),Vector3(0.027,0.04,0.015),Color("4f4b40"))
	cylinder(root,Vector3(0,1.04,0),0.28 if index%2 else 0.22,0.05,cloth)
	sphere(root,Vector3(0,1.08,-0.02),Vector3(0.34,0.2,0.33),cloth)
	for x in [-0.27,0.27]:sphere(root,Vector3(x,0.48,0),Vector3(0.14,0.36,0.16),cloth)
	return root
func animal(kind:String) -> Node3D:
	var root=Node3D.new();root.name=kind.capitalize()
	if kind=="cat":
		sphere(root,Vector3(0,0.23,0),Vector3(0.38,0.43,0.65),Color("d9c8a6"))
		sphere(root,Vector3(0,0.46,0.25),Vector3(0.36,0.32,0.32),CREAM)
		for x in [-0.12,0.12]:
			cylinder(root,Vector3(x,0.65,0.23),0.09,0.18,Color("c79b78"),0.0)
			sphere(root,Vector3(x*0.6,0.48,0.4),Vector3(0.028,0.045,0.02),WOOD.darkened(0.5))
		beam(root,Vector3(0,0.2,-0.2),Vector3(0.3,0.45,-0.4),0.12,Color("c79b78"))
	else:
		sphere(root,Vector3(0,0.18,0),Vector3(0.23,0.25,0.44),CREAM)
		sphere(root,Vector3(0,0.3,0.17),Vector3.ONE*0.22,CREAM)
		box(root,Vector3(0,0.28,0.33),Vector3(0.08,0.06,0.18),Color("d4b162"))
		for x in [-1,1]:
			var wing=sphere(root,Vector3(x*0.25,0.2,-0.02),Vector3(0.5,0.05,0.24),Color("abb8b4"));wing.name="WingLeft" if x<0 else "WingRight"
	return root
