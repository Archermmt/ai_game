class_name IslandView
extends Node3D
var kit=ArtKit.new()
var material_library=MaterialLibrary.new()
const MODELS={
	"house_basic":preload("res://game/art/models/house_basic.glb"),"house_coast":preload("res://game/art/models/house_coast.glb"),"house_garden":preload("res://game/art/models/house_garden.glb"),
	"tea":preload("res://game/art/models/tea.glb"),"greenhouse":preload("res://game/art/models/greenhouse.glb"),"lighthouse":preload("res://game/art/models/lighthouse.glb"),
	"bench":preload("res://game/art/models/bench.glb"),"pot":preload("res://game/art/models/pot.glb"),"tree":preload("res://game/art/models/tree.glb")}
const RESIDENTS=[preload("res://game/art/models/resident_0.glb"),preload("res://game/art/models/resident_1.glb"),preload("res://game/art/models/resident_2.glb"),preload("res://game/art/models/resident_3.glb")]
var ground=Node3D.new()
var props=Node3D.new()
var inhabitants=Node3D.new()
var actor_nodes:Dictionary={}
var sea:MeshInstance3D
var foam:Node3D
var day:bool=true
var batch_stats:Dictionary={}
var data:IslandData
func setup(d:IslandData) -> void:
	data=d;add_child(ground);add_child(props);add_child(inhabitants)
	ground.name="Ground";props.name="Buildings";inhabitants.name="Inhabitants"
	var plane=PlaneMesh.new();plane.size=Vector2(180,180)
	sea=MeshInstance3D.new();sea.mesh=plane;sea.position=Vector3(32,-0.04,32)
	var mat=ShaderMaterial.new();mat.shader=preload("res://game/art/shaders/bay_water.gdshader");sea.material_override=mat;add_child(sea)
var foliage_shader=preload("res://game/art/shaders/foliage.gdshader")
var foliage_nodes:Dictionary={}
var generated_foliage:Array=[]
func update_environment(delta:float,active:bool) -> void:
	if active:environment_clock+=delta
	sea.material_override.set_shader_parameter("clock",environment_clock)
	for boat in get_tree().get_nodes_in_group("island_boats"):
		boat.position.y=0.1+sin(environment_clock*0.8+boat.position.x)*0.02;boat.rotation.z=sin(environment_clock*0.7)*0.012
	for leaf in get_tree().get_nodes_in_group("island_leaf_nodes"):leaf.material_override.set_shader_parameter("clock",environment_clock)
	for nodes in foliage_nodes.values():
		for node in nodes:
			node.material_override.set_shader_parameter("clock",environment_clock)
			var cam=get_viewport().get_camera_3d()
			if cam!=null:node.multimesh.visible_instance_count=int(node.multimesh.instance_count*(0.55 if cam.size>36.0 else 1.0))
var environment_clock=0.0
func update_water_field() -> void:
	var image=Image.create(64,64,false,Image.FORMAT_RGB8)
	var distances=PackedFloat32Array();distances.resize(4096)
	for z in range(64):
		for x in range(64):distances[z*64+x]=0.0 if int(surface.cell(Vector2i(x,z)).h)>0 else 8.0
	for pass_index in range(2):
		for zi in range(64):
			for xi in range(64):
				var x=xi if pass_index==0 else 63-xi;var z=zi if pass_index==0 else 63-zi
				var sign_value=1 if pass_index==0 else -1
				for d in [Vector2i(-sign_value,0),Vector2i(0,-sign_value),Vector2i(-sign_value,-sign_value),Vector2i(sign_value,-sign_value)]:
					var q=Vector2i(x,z)+d
					if q.x>=0 and q.y>=0 and q.x<64 and q.y<64:distances[z*64+x]=minf(distances[z*64+x],distances[q.y*64+q.x]+Vector2(d).length())
	for z in range(64):
		for x in range(64):image.set_pixel(x,z,Color((surface.height_at_cell(Vector2i(x,z))+0.15)/2.2,distances[z*64+x]/8.0,0))
	sea.material_override.set_shader_parameter("island_field",ImageTexture.create_from_image(image))
var surface:IslandSurface
var previous_world:Dictionary={}
var terrain_chunks:Dictionary={}
var decoration_chunks:Dictionary={}
var chunk_arrays:Dictionary={}
var changed_chunks:Array=[]
var rebuild_stats:Dictionary={}
func sample_surface(xz:Vector2) -> Dictionary:
	return surface.sample_surface(xz)
func generate_chunk(index:int) -> void:
	# Each worker owns a distinct slot, using only immutable snapshot data.
	generated_arrays[index]=surface.build_chunk(changed_chunks[index])
	generated_foliage[index]=FoliageLayer.generate(surface,changed_chunks[index])
var generated_arrays:Array=[]
func rebuild() -> void:
	var world=data.snapshot();var dirty:Dictionary={}
	var keys=world.tiles.keys()
	for key in previous_world.get("tiles",{}):
		if not key in world.tiles:keys.append(key)
	for key in keys:
		if world.tiles.get(key)==previous_world.get("tiles",{}).get(key):continue
		var parts=key.split(",");var p=Vector2i(int(parts[0]),int(parts[1]))
		for dx in range(-2,3):
			for dz in range(-2,3):dirty[Vector2i(floori((p.x+dx)/8.0),floori((p.y+dz)/8.0))]=true
	var object_change=world.objects!=previous_world.get("objects",[])
	if object_change:
		for o in world.objects+previous_world.get("objects",[]):
			for dx in range(-2,4):
				for dz in range(-2,4):dirty[Vector2i(floori((o.x+dx)/8.0),floori((o.z+dz)/8.0))]=true
	surface=IslandSurface.new(world);changed_chunks=dirty.keys();generated_arrays=[];generated_arrays.resize(changed_chunks.size());generated_foliage=[];generated_foliage.resize(changed_chunks.size())
	if not changed_chunks.is_empty():
		var task=WorkerThreadPool.add_group_task(generate_chunk,changed_chunks.size())
		WorkerThreadPool.wait_for_group_task_completion(task)
	var mat=StandardMaterial3D.new();mat.vertex_color_use_as_albedo=true;mat.vertex_color_is_srgb=true;mat.roughness=1
	for i in range(changed_chunks.size()):
		var chunk:Vector2i=changed_chunks[i]
		if foliage_nodes.has(chunk):
			for n in foliage_nodes[chunk]:n.free()
		foliage_nodes[chunk]=FoliageLayer.publish(ground,generated_foliage[i],foliage_shader)
		if terrain_chunks.has(chunk):terrain_chunks[chunk].free();terrain_chunks.erase(chunk)
		var arrays=generated_arrays[i]
		if arrays[Mesh.ARRAY_VERTEX].is_empty():continue
		var mesh=MeshInstance3D.new();mesh.mesh=ArrayMesh.new();mesh.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);mesh.material_override=mat
		ground.add_child(mesh);terrain_chunks[chunk]=mesh
	# Preserve unrelated decoration resources and imported models across terrain edits.
	var original_props=props
	for chunk in changed_chunks:
		if decoration_chunks.has(chunk):decoration_chunks[chunk].free()
		var node=Node3D.new();original_props.add_child(node);decoration_chunks[chunk]=node;props=node
		for key in data.tiles:
			var parts=key.split(",");var p=Vector2i(int(parts[0]),int(parts[1]))
			if Vector2i(floori(p.x/8.0),floori(p.y/8.0))!=chunk:continue
			var c=data.cell(p)
			if c.h==0:continue
			var y=surface.height_at(Vector2(p))
			if c.road:draw_road(p,y)
			if c.flower:
				for j in range(4):kit.flower(props,Vector3(p.x+sin(j*2.4)*0.25,y,p.y+cos(j*2.4)*0.25),p.x+j)
			if not c.road and not c.flower and not BuildingRules.occupied(data,p):
				var noise=posmod(p.x*31+p.y*19,83)
				if noise==0 and c.surface=="grass":kit.tree(props,Vector3(p.x,y,p.y),p.x+p.y)
				elif noise in [1,2] and c.surface!="grass":
					var rock=kit.sphere(props,Vector3(p.x,y+0.14,p.y),Vector3(0.75,0.5,0.6),Color("a1a596"))
					rock.material_override=material_library.material("rocky_terrain_02",Color("c4c7b4"),0.7)
		for o in data.objects:
			if Vector2i(floori(o.x/8.0),floori(o.z/8.0))==chunk:draw_object(o)
		StaticBatcher.compact(node,8.0)
	props=original_props
	rebuild_stats={"dirty_chunks":changed_chunks.size(),"terrain_chunks":terrain_chunks.size(),"object_change":object_change}
	batch_stats=rebuild_stats;previous_world=world
	if not dirty.is_empty():update_water_field()
func tri(st:SurfaceTool,a:Vector3,b:Vector3,c:Vector3,color:Color) -> void:
	st.set_normal((b-a).cross(c-a).normalized());st.set_color(color);st.add_vertex(a);st.add_vertex(b);st.add_vertex(c)
func draw_road(p:Vector2i,y:float) -> void:
	kit.cylinder(props,Vector3(p.x,y+0.015,p.y),0.36,0.035,Color("d9c7a5"))
	for dir in BuildingRules.DIRS:
		var next=data.cell(p+dir)
		if next.road and absi(int(next.h)-int(data.cell(p).h))<=1:
			var a=Vector3(p.x,y+0.025,p.y);var b=Vector3(p.x+dir.x,surface.height_at(Vector2(p+dir))+0.025,p.y+dir.y)
			var piece=kit.box(props,(a+b)/2,Vector3(0.57,0.04,a.distance_to(b)),Color("d9c7a5"))
			piece.look_at_from_position((a+b)/2,b,Vector3.UP)
func draw_object(o:Dictionary) -> void:
	var p=Vector2i(o.x,o.z);var y=float(data.cell(p).h)*0.5
	if o.kind in ["bridge","dock"]:
		var dir:Vector2i=BuildingRules.DIRS[int(o.rotation)%4];var side=Vector2i(-dir.y,dir.x)
		var count=int(o.length)+2 if o.kind=="bridge" else int(o.length)+1
		for i in range(count):
			var pos=Vector3(p.x+dir.x*i,y+0.06,p.y+dir.y*i)
			for plank in range(4):
				var v=pos+Vector3(dir.x*(plank-1.5)*0.23,0,dir.y*(plank-1.5)*0.23)
				kit.box(props,v,Vector3(0.21 if dir.x!=0 else 0.9,0.1,0.21 if dir.y!=0 else 0.9),ArtKit.WOOD.lightened((plank%2)*0.04))
			for sign_value in [-1,1]:
				var v=pos+Vector3(side.x*0.47*sign_value,0,side.y*0.47*sign_value)
				kit.cylinder(props,v+Vector3(0,-0.1,0),0.06,1.25,ArtKit.WOOD.darkened(0.12))
				if o.kind=="bridge" and i<count-1:
					kit.beam(props,v+Vector3(0,0.45,0),v+Vector3(dir.x,0.45,dir.y),0.055,ArtKit.WOOD)
		if o.kind=="dock":draw_boat(o,y)
		return
	var kind=String(o.kind)
	var model_id="house_"+BuildingRules.variant(data,o) if kind=="house" else kind
	var node:Node3D
	if kind=="tree":
		node=Node3D.new();kit.tree(node,Vector3.ZERO,int(o.id))
	else:node=MODELS[model_id].instantiate() if int(o.get("color",0))==0 else kit.building(kind,BuildingRules.variant(data,o) if kind=="house" else "basic",int(o.get("color",0)))
	node.position=Vector3(p.x+0.5 if kind in ["house","tea","greenhouse","lighthouse"] else p.x,y,p.y+0.5 if kind in ["house","tea","greenhouse","lighthouse"] else p.y)
	material_library.dress(node,kind)
	node.rotation.y=-float(o.rotation)*PI/2;props.add_child(node)
	if kind=="lighthouse":
		var lamp=OmniLight3D.new();lamp.position=Vector3(0,4,0);lamp.light_color=Color("ffd08a");lamp.light_energy=0.6;lamp.omni_range=6;lamp.visible=not day;node.add_child(lamp);lamp.add_to_group("island_lanterns")
func draw_boat(o:Dictionary,_y:float) -> void:
	var dir:Vector2i=BuildingRules.DIRS[int(o.rotation)%4];var side=Vector2i(-dir.y,dir.x)
	var node=Node3D.new();props.add_child(node);node.name="Boat";node.add_to_group("island_boats");node.add_to_group("dynamic_visual")
	node.position=Vector3(o.x+dir.x*2+side.x,0.1,o.z+dir.y*2+side.y)
	node.rotation.y=PI/2 if dir.x!=0 else 0
	kit.sphere(node,Vector3.ZERO,Vector3(0.87,0.42,2.8),ArtKit.BLUE)
	kit.sphere(node,Vector3(0,0.12,0),Vector3(0.7,0.2,2.55),ArtKit.CREAM)
	for z in [-0.65,0,0.65]:kit.box(node,Vector3(0,0.25,z),Vector3(0.65,0.06,0.18),ArtKit.WOOD)
	kit.beam(node,Vector3(-0.5,0.25,-0.1),Vector3(0.55,0.25,-0.1),0.04,ArtKit.WOOD)
func update_actors(sim:ResidentSim,time:float) -> void:
	var active:Dictionary={}
	for person in sim.people:
		var id=int(person.id);active[id]=true
		if not actor_nodes.has(id):
			var n=ResidentRig.create((id-1)%4);inhabitants.add_child(n);actor_nodes[id]=n
		var n:Node3D=actor_nodes[id];n.visible=person.state!="resting"
		var p=Vector2i(roundi(person.x),roundi(person.z));var y=surface.height_at(Vector2(person.x,person.z))
		for o in data.objects:
			if o.kind=="bridge" and p in BuildingRules.footprint(o):y=float(data.cell(Vector2i(o.x,o.z)).h)*0.5+0.08
		var moving=not person.route.is_empty()
		n.animate(String(person.state),moving,time+id*0.2)
		n.position=Vector3(person.x,y+(absf(sin(time*8+id))*0.045 if moving else 0),person.z)
		if moving:
			var target:Vector2i=person.route[0];var facing=Vector3(target.x,0,target.y)-Vector3(person.x,0,person.z)
			if facing.length()>0.02:n.rotation.y=atan2(facing.x,facing.z)
		if person.state=="tea":
			var target=sim.object_by_id(data,int(person.target))
			if not target.is_empty():
				var seat=0
				for other in sim.people:
					if other.target==person.target and int(other.id)<id:seat+=1
				var offset=Basis(Vector3.UP,-float(target.rotation)*PI/2)*Vector3(-0.65 if seat%2==0 else 0.65,0,0)
				n.position=Vector3(target.x+0.5,y+0.16,target.z+0.5)+offset
				n.rotation.y=PI/2 if seat%2==0 else -PI/2
				n.rotation.z=sin(time*0.7+id)*0.025
		if person.state=="bench":
			var bench=sim.object_by_id(data,int(person.target))
			if not bench.is_empty():
				n.position=Vector3(bench.x,y+0.06,bench.z);n.rotation.y=-float(bench.rotation)*PI/2
	for id in actor_nodes.keys():
		if not active.has(id):actor_nodes[id].free();actor_nodes.erase(id)
func compact_props() -> void:
	# Keep custom/transparent/animated surfaces intact; batch only proven static inputs.
	batch_stats=StaticBatcher.compact(props,8.0)
	if batch_stats.has("error"):push_error(String(batch_stats.error))
