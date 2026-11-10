class_name ArtKit
extends RefCounted
const Village = preload("res://game/art/healing/village_models.gd")
const CREAM=Color("efe4c9")
const WOOD=Color("aa8060")
const CORAL=Color("c67c65")
const BLUE=Color("6e919e")
const GREEN=Color("789579")
var materials:Dictionary={}
static var leaf_material:ShaderMaterial
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
	Village.flowers(parent,pos,index)
func pot(parent:Node3D,pos:Vector3) -> void:
	cylinder(parent,pos+Vector3(0,0.12,0),0.1,0.24,CORAL,0.15)
	for a in range(3):sphere(parent,pos+Vector3(cos(a*2)*0.1,0.32,sin(a*2)*0.1),Vector3(0.18,0.25,0.18),GREEN)
func tree(parent:Node3D,pos:Vector3,seed_value:int=0) -> void:
	Village.tree(parent,pos,seed_value)
static func shrub_material() -> ShaderMaterial:
	if leaf_material==null:
		leaf_material=ShaderMaterial.new()
		leaf_material.shader=load("res://game/art/shaders/leaves.gdshader")
		leaf_material.set_shader_parameter("leaves",load("res://game/art/generated/leaf_cluster.png"))
	return leaf_material
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
	if kind in ["house", "tea"]:
		return Village.cottage(self,variant,roof_index,kind=="tea")
	var root=Node3D.new();root.name=kind.capitalize()
	var roof_color=Village.ROOF_TINTS[posmod(roof_index, Village.ROOF_TINTS.size())]
	if kind=="bench":bench(root);return root
	if kind=="pot":pot(root,Vector3.ZERO);return root
	if kind=="tree":tree(root,Vector3.ZERO);return root
	if kind=="lighthouse":
		var stone = Color("d7bea0")
		var brick = Color("b08a67")
		var trim = Color("875f49")
		cylinder(root, Vector3(0,1.85,0), 0.65, 3.7, stone, 0.48)
		cylinder(root, Vector3(0,0.12,0), 0.76, 0.24, brick, 0.70)
		cylinder(root, Vector3(0,2.45,0), 0.56, 0.38, roof_color, 0.54)
		cylinder(root, Vector3(0,3.54,0), 0.69, 0.15, trim)
		cylinder(root, Vector3(0,3.98,0), 0.46, 0.78, Color("d0c39b"))
		cylinder(root, Vector3(0,4.48,0), 0.72, 0.50, roof_color, 0.03)
		sphere(root, Vector3(0,4.82,0), Vector3.ONE*0.14, trim)
		for i in range(12):
			var a = i * TAU/12
			var b = (i+1) * TAU/12
			var post = Vector3(cos(a)*0.64,3.79,sin(a)*0.64)
			box(root, post, Vector3(0.042,0.42,0.042), trim)
			beam(root, post+Vector3.UP*0.20, Vector3(cos(b)*0.64,3.99,sin(b)*0.64), 0.045, trim)
			if i % 2 == 0:
				box(root, Vector3(cos(a)*0.47,4.0,sin(a)*0.47), Vector3(0.048,0.8,0.048), trim)
		for side in [-1,1]:
			for i in range(4):
				box(root, Vector3(side*0.28,0.16+i*0.25,0.61), Vector3(0.10,0.20,0.11), brick)
		box(root, Vector3(0,0.59,0.64), Vector3(0.46,1.08,0.08), Color("697d79"))
		box(root, Vector3(0,1.16,0.65), Vector3(0.68,0.13,0.14), trim)
		for y in [1.68,2.81]:
			box(root, Vector3(0,y,0.56), Vector3(0.27,0.39,0.08), trim)
			box(root, Vector3(0,y,0.61), Vector3(0.19,0.31,0.035), BLUE)
		pot(root, Vector3(0.65,0,0.55))
		return root
	if kind=="greenhouse":
		var frame = [Color("a28b65"), Color("74918d"), Color("91a07b")][posmod(roof_index, 3)]
		box(root, Vector3(0,0.17,0), Vector3(1.85,0.34,1.85), Color("c5b79a"))
		for x in [-0.83,0.83]:
			for z in [-0.80,0,0.80]:
				beam(root, Vector3(x,0.31,z), Vector3(x,1.68,z), 0.065, frame)
			for y in [0.60,1.18,1.68]:
				box(root, Vector3(x,y,0), Vector3(0.065,0.055,1.7), frame)
		for z in [-0.80,0,0.80]:
			beam(root, Vector3(-0.84,1.68,z), Vector3(0,2.48,z), 0.07, frame)
			beam(root, Vector3(0,2.48,z), Vector3(0.84,1.68,z), 0.07, frame)
			for side in [-1,1]:
				pot(root, Vector3(0.47*side,0.34,z*0.78))
		# Translucent sage glass leaves the front aisle and plants readable.
		var glass=StandardMaterial3D.new()
		glass.albedo_color=Color(0.70,0.85,0.83,0.37)
		glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		glass.roughness=0.35
		glass.cull_mode=BaseMaterial3D.CULL_DISABLED
		var surfaces = SurfaceTool.new()
		surfaces.begin(Mesh.PRIMITIVE_TRIANGLES)
		for side in [-1,1]:
			var x = 0.81*side
			glass_quad(surfaces, Vector3(x,0.34,-0.80), Vector3(x,1.68,-0.80),
					Vector3(x,1.68,0.80), Vector3(x,0.34,0.80))
			glass_quad(surfaces, Vector3(x,1.68,-0.80), Vector3(0,2.48,-0.80),
					Vector3(0,2.48,0.80), Vector3(x,1.68,0.80))
			beam(root,Vector3(side*0.36,0.32,0.82),Vector3(side*0.36,1.77,0.82),0.057,frame)
		for z in [-0.80,0.80]:
			glass_quad(surfaces,Vector3(-0.81,0.34,z),Vector3(-0.81,1.68,z),
					Vector3(0.81,1.68,z),Vector3(0.81,0.34,z))
			for side in [-1,1]:
				box(root,Vector3(side*0.60,1.18,z+0.016),Vector3(0.46,0.052,0.04),frame)
			for v in [Vector3(-0.76,1.71,z),Vector3(0,2.43,z),Vector3(0.76,1.71,z)]:
				surfaces.set_normal(Vector3.BACK if z>0 else Vector3.FORWARD)
				surfaces.add_vertex(v)
			beam(root,Vector3(0,1.68,z),Vector3(0,2.43,z),0.045,frame)
		for side in [-1,1]:
			var shelf_x=0.53*side
			box(root,Vector3(shelf_x,0.81,-0.03),Vector3(0.45,0.07,1.38),Color("9a7755"))
			for z in [-0.55,0.55]:
				box(root,Vector3(shelf_x,0.58,z),Vector3(0.07,0.45,0.07),frame)
				pot(root,Vector3(shelf_x,0.85,z))
		var glazing = MeshInstance3D.new()
		glazing.name = "SageGlass"
		glazing.mesh = surfaces.commit()
		glazing.material_override = glass
		glazing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(glazing)
		box(root,Vector3(0,0.76,0.815),Vector3(0.68,0.07,0.04),frame)
		box(root,Vector3(0.24,0.99,0.85),Vector3(0.12,0.048,0.05),Color("846042"))
		beam(root,Vector3(0,2.48,-0.91),Vector3(0,2.48,0.91),0.095,frame)
		beam(root,Vector3(-0.82,1.68,0.82),Vector3(0.82,1.68,0.82),0.065,frame)
		return root
	return root
func glass_quad(builder: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	var normal = (b-a).cross(c-a).normalized()
	for v in [a,c,b,a,d,c]:
		builder.set_normal(normal)
		builder.add_vertex(v)
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
