class_name FoliageLayer
extends RefCounted
const SEED=4271
static func generate(surface:IslandSurface,chunk:Vector2i) -> Array:
	var layers:Array=[[],[],[]]
	var occupied=surface.occupied
	for z in range(8):
		for x in range(8):
			var p=chunk*8+Vector2i(x,z);var cell=surface.cell(p)
			if cell.surface!="grass" or cell.get("road",false) or occupied.has(p):continue
			for i in range(36):
				var h=posmod(p.x*73856093+p.y*19349663+i*83492791+SEED,65521)
				var v=Vector2(p)+Vector2((i%6+float(h%91)/91.0)/6.0-0.5,(i/6+float(h%79)/79.0)/6.0-0.5)
				var density=0.62+0.26*sin(v.x*0.71+v.y*0.39)*cos(v.y*0.56)
				if float(h%101)/101.0>density:continue
				var sample=surface.sample_surface(v)
				if sample.normal.y<0.82 or sample.height<0.35:continue
				var road_near=false
				for d in BuildingRules.DIRS:
					if surface.cell(p+d).get("road",false) and (v-Vector2(p+d)).length()<0.77:road_near=true
				if road_near:continue
				var layer=0
				if h%11<2:layer=1
				if h%113==0:layer=2
				var scale=0.7+float(h%31)/40.0
				var transform=Transform3D(Basis(Vector3.UP,float(h)*0.1).scaled(Vector3.ONE*scale),Vector3(v.x,sample.height-0.015,v.y))
				layers[layer].append({"rank":h,"transform":transform,"color":Color("94ad64").lightened(float(h%7)*0.025) if layer==0 else Color("b8c977") if layer==1 else [Color("e8c99d"),Color("d7aec9"),Color("ece1b3")][h%3]})
	for layer in layers:layer.sort_custom(func(a,b):return a.rank<b.rank)
	return layers
static func publish(parent:Node3D,layers:Array,shader:Shader) -> Array:
	var nodes:Array=[]
	for layer in range(3):
		if layers[layer].is_empty():continue
		var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var height=[0.20,0.38,0.30][layer];var width=0.17 if layer==0 else 0.25
		for angle in [0.0,PI/3,2*PI/3]:
			var side=Vector3(cos(angle),0,sin(angle))*width
			var vertices=[-side,side,side+Vector3.UP*height,-side+Vector3.UP*height]
			var uv=[Vector2(0,1),Vector2(1,1),Vector2(1,0),Vector2(0,0)]
			for i in [0,1,2,0,2,3]:st.set_uv(uv[i]);st.add_vertex(vertices[i])
		var multi=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.use_colors=true;multi.mesh=st.commit();multi.instance_count=layers[layer].size()
		for i in range(layers[layer].size()):multi.set_instance_transform(i,layers[layer][i].transform);multi.set_instance_color(i,layers[layer][i].color)
		var node=MultiMeshInstance3D.new();node.multimesh=multi
		var mat=ShaderMaterial.new();mat.shader=shader;mat.set_shader_parameter("flower",layer==2);mat.set_shader_parameter("tuft",load("res://game/art/generated/meadow_tuft.png"));node.material_override=mat
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(node);nodes.append(node)
	return nodes
