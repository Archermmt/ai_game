class_name ArtExtras
extends RefCounted
static func create(id:String,variant:int=0) -> Node3D:
	var root=Node3D.new();root.name=id+"_%02d"%variant;var k=ArtKit.new()
	match id:
		"NAT_002":
			if ArtKit.leaf_material==null:
				var temporary=Node3D.new();k.tree(temporary,Vector3.ZERO);temporary.free()
			var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for plane in range(4):
				var angle=plane*PI/3;var side=Vector3(cos(angle),0,sin(angle))*0.42;var up=Vector3.UP*0.27
				if plane==3:side=Vector3(0.38,0,0);up=Vector3(0,0,0.38)
				var points=[Vector3.UP*0.3-side-up,Vector3.UP*0.3+side-up,Vector3.UP*0.3+side+up,Vector3.UP*0.3-side+up];var uv=[Vector2(0,1),Vector2(1,1),Vector2(1,0),Vector2(0,0)]
				for i in [0,1,2,0,2,3]:st.set_uv(uv[i]);st.add_vertex(points[i])
			var node=MeshInstance3D.new();node.mesh=st.commit();node.material_override=ArtKit.leaf_material;root.add_child(node);node.add_to_group("island_leaf_nodes")
			if variant==1:k.flower(root,Vector3(0,0.4,0),1)
		"NAT_005":
			for i in range(5):
				var p=Vector3(sin(i*2.4)*0.16,0,cos(i*2.4)*0.16);var h=0.5+(i%3)*0.1
				var stem=CylinderMesh.new();stem.bottom_radius=0.012;stem.top_radius=0.012;stem.height=h;stem.radial_segments=4;stem.rings=0;stem.cap_top=false;stem.cap_bottom=false
				k.mesh(root,stem,p+Vector3.UP*h/2,ArtKit.GREEN);k.box(root,p+Vector3.UP*h,Vector3(0.045,0.13,0.045),Color("9b8058"))
		"NAT_006":
			var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for i in range(6):
				var p=Vector3(sin(i*0.9)*0.12,i*0.18,0);k.beam(root,p,p+Vector3(0.03,0.2,0),0.015,ArtKit.GREEN)
				for side in [-1,1]:
					var center=p+Vector3(side*0.07,0.1,0.015);var points=[center+Vector3.UP*0.07,center+Vector3(side*0.09,0,0),center-Vector3.UP*0.06,center-Vector3(side*0.04,0,0)]
					for index in [0,1,2,0,2,3]:st.set_normal(Vector3.BACK);st.add_vertex(points[index])
			var node=k.mesh(root,st.commit(),Vector3.ZERO,ArtKit.GREEN.lightened(0.08));node.material_override.cull_mode=BaseMaterial3D.CULL_DISABLED
		"NAT_007","NAT_008":
			var mesh=SphereMesh.new();mesh.radial_segments=8;mesh.rings=3;mesh.radius=0.5;mesh.height=1
			var arrays=mesh.surface_get_arrays(0);var points=arrays[Mesh.ARRAY_VERTEX];var indices=arrays[Mesh.ARRAY_INDEX];var uv=arrays[Mesh.ARRAY_TEX_UV]
			var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for i in range(0,indices.size(),3):
				var triangle:Array=[]
				for j in range(3):
					var v=points[indices[i+j]];var irregular=1.0+0.15*sin(v.x*13+variant*2)*cos(v.z*17+variant)
					triangle.append(v*irregular*Vector3(0.7,0.45,0.65)+Vector3.UP*0.18)
				var normal=(triangle[1]-triangle[0]).cross(triangle[2]-triangle[0]).normalized()
				for j in range(3):st.set_normal(normal);st.set_uv(uv[indices[i+j]]);st.add_vertex(triangle[j])
			var n=MeshInstance3D.new();n.mesh=st.commit();n.material_override=MaterialLibrary.new().material("rocky_terrain_02",Color("c4c7b4"),0.7);root.add_child(n)
			if id=="NAT_008":root.scale=Vector3(1.3,0.45,1.15);root.position.y=-0.04
		"PROP_005":
			k.box(root,Vector3(0,0.38,0),Vector3(0.4,0.05,0.4),ArtKit.WOOD)
			for x in [-0.16,0.16]:
				for z in [-0.16,0.16]:k.box(root,Vector3(x,0.19,z),Vector3(0.04,0.38,0.04),ArtKit.WOOD)
			for x in [-0.16,0.16]:k.box(root,Vector3(x,0.61,-0.16),Vector3(0.04,0.48,0.04),ArtKit.WOOD)
			k.box(root,Vector3(0,0.78,-0.16),Vector3(0.38,0.1,0.04),ArtKit.WOOD)
		"PROP_006":
			k.cylinder(root,Vector3(0,0.12,0),0.1,0.24,ArtKit.WOOD)
			var glass=k.sphere(root,Vector3(0,0.17,0),Vector3(0.16,0.22,0.16),Color("efd69b"))
			var mat=StandardMaterial3D.new();mat.albedo_color=Color("efd69b");mat.emission_enabled=true;mat.emission=Color("e8b45c");glass.material_override=mat
		"PROP_007":
			k.cylinder(root,Vector3(0,0.4,0),0.04,0.8,ArtKit.WOOD)
			k.box(root,Vector3(0.14,0.65,0),Vector3(0.5,0.18,0.07),ArtKit.CREAM)
			for x in [-0.02,0.12,0.24]:k.box(root,Vector3(x,0.65,0.04),Vector3(0.07,0.025,0.01),ArtKit.GREEN)
		"PROP_008":
			k.cylinder(root,Vector3(0,0.3,0),0.04,0.6,ArtKit.WOOD)
			k.box(root,Vector3(0,0.64,0),Vector3(0.32,0.23,0.24),ArtKit.BLUE)
			k.sphere(root,Vector3(0,0.77,0),Vector3(0.32,0.14,0.24),ArtKit.BLUE)
			k.box(root,Vector3(0,0.66,0.125),Vector3(0.20,0.025,0.015),ArtKit.WOOD.darkened(0.3))
		"PROP_009":
			k.cylinder(root,Vector3(0,0.9,0),0.035,1.8,ArtKit.WOOD)
			k.cylinder(root,Vector3(0,1.8,0),0.72,0.35,Color("d7b89e"),0.02)
		"PROP_012":
			if variant==0:
				k.box(root,Vector3(0,0.17,0),Vector3(0.28,0.34,0.16),ArtKit.WOOD)
				for x in [-0.09,0.09]:k.box(root,Vector3(x,0.17,0.085),Vector3(0.025,0.3,0.015),ArtKit.CREAM)
				k.beam(root,Vector3(-0.06,0.34,0),Vector3(-0.06,0.40,0),0.025,ArtKit.WOOD);k.beam(root,Vector3(-0.06,0.4,0),Vector3(0.06,0.4,0),0.025,ArtKit.WOOD)
			else:
				k.cylinder(root,Vector3(0,0.10,0),0.10,0.20,ArtKit.BLUE)
				k.beam(root,Vector3(0,0.12,0),Vector3(0,0.17,0.25),0.035,ArtKit.BLUE)
		"PROP_013":
			k.box(root,Vector3(0,0.15,0),Vector3(0.3,0.3,0.3),ArtKit.WOOD)
			for x in [-0.13,0,0.13]:k.box(root,Vector3(x,0.15,0.155),Vector3(0.025,0.29,0.02),ArtKit.CREAM.darkened(0.1))
		"PROP_014":
			if variant==0:k.cylinder(root,Vector3(0,0.18,0),0.065,0.36,ArtKit.WOOD)
			else:
				for i in range(12):k.beam(root,Vector3(cos(i*TAU/12)*0.12,0.02,sin(i*TAU/12)*0.12),Vector3(cos((i+1)*TAU/12)*0.12,0.02,sin((i+1)*TAU/12)*0.12),0.025,Color("c9b899"))
		"PROP_015":
			for x in [-0.45,0.45]:k.box(root,Vector3(x,0.35,0),Vector3(0.07,0.7,0.07),ArtKit.WOOD)
			for y in [0.3,0.55]:k.box(root,Vector3(0,y,0),Vector3(0.95,0.055,0.055),ArtKit.WOOD)
			if variant==1:
				for y in [0.3,0.55]:k.box(root,Vector3(-0.45,y,0.45),Vector3(0.055,0.055,0.9),ArtKit.WOOD)
		"PROP_016":
			if variant==0:
				k.sphere(root,Vector3(0,0.09,0),Vector3(0.18,0.18,0.18),ArtKit.CREAM);k.cylinder(root,Vector3(0,0.19,0),0.04,0.025,ArtKit.WOOD)
				k.beam(root,Vector3(0.07,0.10,0),Vector3(0.19,0.15,0),0.035,ArtKit.CREAM)
			else:
				k.cylinder(root,Vector3(0,0.05,0),0.055,0.10,ArtKit.CREAM);k.cylinder(root,Vector3(0,0.105,0),0.04,0.005,ArtKit.WOOD)
		_:
			root.free();return null
	var anchors:Dictionary={}
	if id=="PROP_006":anchors={"Grip":Vector3(0,0.35,0)}
	elif id=="PROP_012":anchors={"Grip":Vector3(0,0.39,0) if variant==0 else Vector3(0,0.16,0),"Ground":Vector3.ZERO}
	elif id=="PROP_016":anchors={"Grip":Vector3(0,0.08,0)}
	for key in anchors:
		var marker=Marker3D.new();marker.name=key;marker.position=anchors[key];root.add_child(marker)
	if id=="PROP_008":
		var flag=Node3D.new();flag.name="Flag";flag.position=Vector3(0.19,0.72,0);root.add_child(flag);k.box(flag,Vector3(0,0.04,0),Vector3(0.03,0.15,0.08),ArtKit.CORAL)
	return root
