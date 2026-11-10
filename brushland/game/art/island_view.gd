class_name IslandView
extends Node3D
var kit=ArtKit.new()
var material_library=MaterialLibrary.new()
var frozen_instances=FrozenArtInstances.new()
var use_instancing=true
var detail_density=1.0
var use_project_batches=DisplayServer.get_name()!="headless"
var render_batches=preload("res://game/art/project_render_batches.gd").new()
const MODELS={
	"greenhouse":preload("res://game/art/models/greenhouse.glb"),"lighthouse":preload("res://game/art/models/lighthouse.glb"),
	"bench":preload("res://game/art/models/bench.glb"),"pot":preload("res://game/art/models/pot.glb")}
const RESIDENTS=[preload("res://game/art/models/resident_0.glb"),preload("res://game/art/models/resident_1.glb"),preload("res://game/art/models/resident_2.glb"),preload("res://game/art/models/resident_3.glb")]
var ground=Node3D.new()
var props=Node3D.new()
var inhabitants=Node3D.new()
var actor_nodes:Dictionary={}
var reflection: SubViewport
var sea:MeshInstance3D
var foam:Node3D
var day:bool=true
var batch_stats:Dictionary={}
var growth = preload("res://game/art/growth_transition.gd").new()
var reduced_motion := false
var growing_ids: Dictionary = {}
var new_ids: Dictionary = {}
var data:IslandData
func setup(d:IslandData) -> void:
	data=d;add_child(ground);add_child(props);add_child(inhabitants)
	ground.name="Ground";props.name="Buildings";inhabitants.name="Inhabitants"
	var plane=PlaneMesh.new();plane.size=Vector2(1200,1200)
	sea=MeshInstance3D.new();sea.mesh=plane;sea.position=Vector3(32,-0.04,32)
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sea.layers = 1 << 18
	var mat=ShaderMaterial.new();mat.shader=preload("res://game/art/shaders/bay_water.gdshader");sea.material_override=mat;add_child(sea)
	if DisplayServer.get_name() != "headless":
		reflection = preload("res://game/art/lake_reflection.gd").new()
		reflection.world_3d = get_world_3d()
		add_child(reflection)
		mat.set_shader_parameter("reflection_tex", reflection.get_texture())
var foliage_shader=preload("res://game/art/shaders/foliage.gdshader")
var foliage_nodes:Dictionary={}
var generated_foliage:Array=[]
func finish_growth() -> void:
	if growth.entries.is_empty():return
	growth.finish()
	if use_project_batches:
		render_batches.scope_cache.clear()
		render_batches.rebuild(self, props, ground)
	if reflection != null:reflection.refresh = true

func update_environment(delta:float,active:bool) -> void:
	if growth.advance(delta):
		if use_project_batches:
			render_batches.scope_cache.clear()
			render_batches.rebuild(self, props, ground)
		if reflection != null:reflection.refresh = true
	if active:environment_clock+=delta
	if reflection != null:
		reflection.reflect_view(get_viewport().get_camera_3d(), sea, environment_clock)
	IslandEffects.update(get_tree(),environment_clock)
	if use_project_batches:render_batches.update_smoke(get_viewport().get_camera_3d())
	sea.material_override.set_shader_parameter("clock",environment_clock)
	for boat in get_tree().get_nodes_in_group("island_boats"):
		boat.position.y=0.1+sin(environment_clock*0.8+boat.position.x)*0.02;boat.rotation.z=sin(environment_clock*0.7)*0.012
	for leaf in get_tree().get_nodes_in_group("island_leaf_nodes"):leaf.material_override.set_shader_parameter("clock",environment_clock)
	for nodes in foliage_nodes.values()+[render_batches.grass]:
		for node in nodes:
			node.material_override.set_shader_parameter("clock",environment_clock)
			var cam=get_viewport().get_camera_3d()
			if cam!=null:node.multimesh.visible_instance_count=int(node.multimesh.instance_count*detail_density*(0.55 if cam.size>36.0 else 1.0))
var environment_clock=0.0
var water_levels=PackedByteArray()
var water_distances=PackedFloat32Array()
var water_image:Image
var water_texture:ImageTexture
func update_water_field() -> void:
	var levels=PackedByteArray();levels.resize(4096)
	for key in surface.tiles:
		var parts=key.split(",");var x=int(parts[0]);var z=int(parts[1])
		if x>=0 and z>=0 and x<64 and z<64:levels[z*64+x]=int(surface.tiles[key].h)
	if levels==water_levels:return
	var mask_changed=water_levels.size()!=4096
	if not mask_changed:
		for i in range(4096):
			if (levels[i]>0)!=(water_levels[i]>0):mask_changed=true;break
	if mask_changed:
		water_distances.resize(4096)
		for i in range(4096):water_distances[i]=0.0 if levels[i]>0 else 8.0
		for pass_index in range(2):
			for zi in range(64):
				for xi in range(64):
					var x=xi if pass_index==0 else 63-xi;var z=zi if pass_index==0 else 63-zi
					var sign_value=1 if pass_index==0 else -1
					for d in [Vector2i(-sign_value,0),Vector2i(0,-sign_value),Vector2i(-sign_value,-sign_value),Vector2i(sign_value,-sign_value)]:
						var q=Vector2i(x,z)+d
						if q.x>=0 and q.y>=0 and q.x<64 and q.y<64:water_distances[z*64+x]=minf(water_distances[z*64+x],water_distances[q.y*64+q.x]+Vector2(d).length())
	if water_image==null:water_image=Image.create(64,64,false,Image.FORMAT_RGB8)
	for i in range(4096):
		if mask_changed or levels[i]!=water_levels[i]:
			var height=levels[i]*0.5 if levels[i]>0 else -0.15
			water_image.set_pixel(i%64,i/64,Color((height+0.15)/2.2,water_distances[i]/8.0,0))
	water_levels=levels
	if water_texture==null:
		water_texture=ImageTexture.create_from_image(water_image)
		sea.material_override.set_shader_parameter("island_field",water_texture)
	else:water_texture.update(water_image)
var surface:IslandSurface
var previous_world:Dictionary={}
var neighborhood_state := {"variants": {}, "ground": {}, "reasons": {}, "seams": {}, "halls": {}, "layouts": {}, "courts": []}

func update_neighborhood(dirty: Dictionary) -> void:
	var next := BuildingRules.neighborhood(data)
	var old_ground: Dictionary = neighborhood_state.ground
	var new_ground: Dictionary = next.ground
	for cell in old_ground.keys() + new_ground.keys():
		if old_ground.get(cell) == new_ground.get(cell):
			continue
		# Vertices at the edges of the cell can belong to a neighboring chunk.
		for z in range(cell.y - 1, cell.y + 2):
			for x in range(cell.x - 1, cell.x + 2):
				dirty[Vector2i(floori(x / 8.0), floori(z / 8.0))] = true
	for object in data.objects:
		var id := int(object.id)
		if (next.variants.get(id) != neighborhood_state.variants.get(id)
				or next.layouts.get(id) != neighborhood_state.layouts.get(id)
				or next.seams.get(id, []) != neighborhood_state.seams.get(id, [])
				or next.halls.has(id) != neighborhood_state.halls.has(id)):
			dirty[Vector2i(floori(object.x / 8.0), floori(object.z / 8.0))] = true
	neighborhood_state = next

var terrain_chunks:Dictionary={}
var decoration_chunks:Dictionary={}
var building_picker = preload("res://game/building/building_picker.gd").new()
var chunk_arrays:Dictionary={}
var changed_chunks:Array=[]
var rebuild_stats:Dictionary={}
var rebuild_profile:Dictionary={}
var focal_tree_id: int = 0
func sample_surface(xz:Vector2) -> Dictionary:
	return surface.sample_surface(xz)
func generate_chunk(index:int) -> void:
	# Each worker owns a distinct slot, using only immutable snapshot data.
	generated_arrays[index]=surface.build_chunk(changed_chunks[index])
	generated_foliage[index]=FoliageLayer.generate(surface,changed_chunks[index])
var generated_arrays:Array=[]
func rebuild() -> void:
	finish_growth()
	var old_surface: IslandSurface = surface
	var old_neighborhood := neighborhood_state.duplicate(true)
	var profile_start=Time.get_ticks_usec()
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
		# The first planted oak is the canopy focal point. Rebuild its successor
		# even across chunk boundaries after removing it or restoring an old save.
		var next_focal: int = 0
		for tree in world.objects:
			if tree.kind == "tree" and (next_focal == 0 or tree.id < next_focal):
				next_focal = int(tree.id)
		if focal_tree_id != next_focal:
			for tree in world.objects:
				if tree.id in [focal_tree_id, next_focal]:
					dirty[Vector2i(floori(tree.x / 8.0), floori(tree.z / 8.0))] = true
			focal_tree_id = next_focal
		var old:Dictionary={};var current:Dictionary={};var ids:Dictionary={}
		for object in previous_world.get("objects",[]):old[int(object.id)]=object;ids[int(object.id)]=true
		for object in world.objects:current[int(object.id)]=object;ids[int(object.id)]=true
		for id in ids:
			if old.get(id)==current.get(id):continue
			for object in [old.get(id),current.get(id)]:
				if object==null:continue
				for cell in BuildingRules.footprint(object):
					for dx in range(-2,3):
						for dz in range(-2,3):dirty[Vector2i(floori((cell.x+dx)/8.0),floori((cell.y+dz)/8.0))]=true

	update_neighborhood(dirty)
	growing_ids.clear()
	new_ids.clear()
	if old_surface != null and not reduced_motion:
		var old_objects: Dictionary = {}
		for object in previous_world.get("objects", []):old_objects[int(object.id)] = object
		for object in world.objects:
			var id := int(object.id)
			if not old_objects.has(id):new_ids[id] = true
			if old_neighborhood.get("layouts", {}).get(id) != neighborhood_state.get("layouts", {}).get(id) or old_objects.get(id) != object or old_neighborhood.variants.get(id) != neighborhood_state.variants.get(id) or old_neighborhood.get("seams", {}).get(id) != neighborhood_state.get("seams", {}).get(id) or old_neighborhood.get("halls", {}).has(id) != neighborhood_state.get("halls", {}).has(id):
				growing_ids[id] = true
	if dirty.is_empty():
		if surface==null:
			surface=IslandSurface.new(world, neighborhood_state.ground);previous_world=world;update_water_field()
		return
	if reflection != null: reflection.refresh = true
	if use_project_batches:render_batches.restore(true)
	surface=IslandSurface.new(world, neighborhood_state.ground);changed_chunks=dirty.keys();generated_arrays=[];generated_arrays.resize(changed_chunks.size());generated_foliage=[];generated_foliage.resize(changed_chunks.size())
	if not changed_chunks.is_empty():
		var task=WorkerThreadPool.add_group_task(generate_chunk,changed_chunks.size())
		WorkerThreadPool.wait_for_group_task_completion(task)
	var profile_generated=Time.get_ticks_usec()
	var mat=StandardMaterial3D.new();mat.vertex_color_use_as_albedo=true;mat.vertex_color_is_srgb=true;mat.roughness=1
	for i in range(changed_chunks.size()):
		var chunk:Vector2i=changed_chunks[i]
		if foliage_nodes.has(chunk):
			for n in foliage_nodes[chunk]:n.free()
		foliage_nodes[chunk]=FoliageLayer.publish(ground,generated_foliage[i],foliage_shader)
		if terrain_chunks.has(chunk):terrain_chunks[chunk].free();terrain_chunks.erase(chunk)
		var arrays=generated_arrays[i]
		if arrays[Mesh.ARRAY_VERTEX].is_empty():continue
		var mesh=MeshInstance3D.new();mesh.set_meta("art_terrain",chunk);mesh.mesh=ArrayMesh.new();mesh.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);mesh.material_override=mat
		ground.add_child(mesh);terrain_chunks[chunk]=mesh
		if old_surface != null and not reduced_motion:growth.terrain(mesh, arrays, old_surface, surface, mat)
	# Preserve unrelated decoration resources and imported models across terrain edits.
	var profile_terrain=Time.get_ticks_usec()
	var original_props=props
	for chunk in changed_chunks:
		building_picker.clear_chunk(chunk)
		if decoration_chunks.has(chunk):decoration_chunks[chunk].free()
		var node=Node3D.new();node.set_meta("art_chunk",chunk);original_props.add_child(node);decoration_chunks[chunk]=node;props=node
		for key in data.tiles:
			var parts=key.split(",");var p=Vector2i(int(parts[0]),int(parts[1]))
			if Vector2i(floori(p.x/8.0),floori(p.y/8.0))!=chunk:continue
			var c=data.cell(p)
			if c.h==0:continue
			var y=surface.height_at(Vector2(p))
			if c.flower:
				for j in range(4):kit.flower(props,Vector3(p.x+sin(j*2.4)*0.25,y,p.y+cos(j*2.4)*0.25),p.x+j)
			if not c.road and not c.flower and not BuildingRules.occupied(data,p):
				var noise=posmod(p.x*31+p.y*19,83)
				if noise==0 and c.surface=="grass":ArtKit.Village.tree(props,Vector3(p.x,y,p.y),p.x+p.y,true)
				elif noise in [1,2] and c.surface!="grass":
					var rock=kit.sphere(props,Vector3(p.x,y+0.14,p.y),Vector3(0.75,0.5,0.6),Color("a1a596"))
					rock.material_override=material_library.material("rocky_terrain_02",Color("c4c7b4"),0.7)
		preload("res://game/art/cove_shoreline.gd").add_to(node, surface, chunk)
		for o in data.objects:
			if Vector2i(floori(o.x/8.0),floori(o.z/8.0))==chunk:draw_object(o)
		if not use_project_batches:
			if use_instancing:frozen_instances.canonicalize(node)
			StaticBatcher.compact(node,8.0)
			if use_instancing:
				frozen_instances.instance_remaining(node)
				instance_leaf_cards(node)
	props=original_props
	var profile_props=Time.get_ticks_usec()
	if use_project_batches:render_batches.rebuild(self,props,ground)
	rebuild_stats={"dirty_chunks":changed_chunks.size(),"terrain_chunks":terrain_chunks.size(),"object_change":object_change}
	rebuild_profile={"generate_ms":(profile_generated-profile_start)/1000.0,"terrain_publish_ms":(profile_terrain-profile_generated)/1000.0,"props_ms":(profile_props-profile_terrain)/1000.0,"render_publish_ms":(Time.get_ticks_usec()-profile_props)/1000.0}
	batch_stats=rebuild_stats;previous_world=world
	if not dirty.is_empty():update_water_field()
func set_night(value:bool) -> void:
	day=not value;material_library.set_night(value)
	ArtKit.Village.set_dusk(value)
	if reflection != null: reflection.refresh = true
	if sea != null:
		sea.material_override.set_shader_parameter("dusk", 1.0 if value else 0.0)
func instance_leaf_cards(parent:Node3D) -> void:
	var groups:Dictionary={}
	for leaf in parent.find_children("*","MeshInstance3D",true,false):
		if not leaf.is_in_group("island_leaf_nodes"):continue
		if not frozen_instances.static_branch(leaf,parent):continue
		var settings:Array=[]
		for property in StaticBatcher.INSTANCE_PROPERTIES:settings.append(leaf.get(property))
		var key=[leaf.mesh.get_instance_id(),leaf.material_override.get_instance_id(),settings]
		if not groups.has(key):groups[key]=[]
		groups[key].append(leaf)
	for sources in groups.values():
		if sources.size()<2:continue
		var multi=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.mesh=sources[0].mesh;multi.instance_count=sources.size()
		for i in range(sources.size()):multi.set_instance_transform(i,parent.global_transform.affine_inverse()*sources[i].global_transform)
		var node=MultiMeshInstance3D.new();node.multimesh=multi;node.material_override=sources[0].material_override
		for property in StaticBatcher.INSTANCE_PROPERTIES:node.set(property,sources[0].get(property))
		parent.add_child(node);node.add_to_group("island_leaf_nodes")
		for source in sources:source.free()
func tri(st:SurfaceTool,a:Vector3,b:Vector3,c:Vector3,color:Color) -> void:
	st.set_normal((b-a).cross(c-a).normalized());st.set_color(color);st.add_vertex(a);st.add_vertex(b);st.add_vertex(c)
func create_building_model(object: Dictionary, state: Dictionary) -> Node3D:
	var kind: String = object.kind
	var variant: String = state.variants.get(int(object.id), "basic")
	var seams: Array = state.seams.get(int(object.id), [])
	var hall: bool = state.halls.has(int(object.id))
	if hall or int(object.get("form", 0)) != 0 or not seams.is_empty():
		return preload("res://game/art/healing/joined_buildings.gd").make(kit, object, variant, seams, material_library.window_material(), hall, state.get("layouts", {}).get(int(object.id), {}))
	if kind in ["house","tea"] or int(object.get("color",0)) != 0:
		return kit.building(kind, variant, int(object.get("color",0)))
	return MODELS[kind].instantiate()

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
	var house_variant: String = neighborhood_state.variants.get(int(o.id), "basic")
	var seams: Array = neighborhood_state.seams.get(int(o.id), [])
	var is_hall: bool = neighborhood_state.halls.has(int(o.id))
	var node:Node3D
	if kind=="tree":
		node=Node3D.new()
		ArtKit.Village.tree(node,Vector3.ZERO,int(o.id),false,int(o.id)==focal_tree_id)
	elif kind in BuildingRules.BUILDINGS:
		node = create_building_model(o, neighborhood_state)
	elif int(o.get("color", 0)) != 0:
		node = kit.building(kind, house_variant, int(o.color))
	else:
		node = MODELS[kind].instantiate()
	node.position=Vector3(p.x+0.5 if kind in ["house","tea","greenhouse","lighthouse"] else p.x,y,p.y+0.5 if kind in ["house","tea","greenhouse","lighthouse"] else p.y)
	material_library.dress(node,kind)
	if kind=="house":
		IslandEffects.chimney(node,node.get_meta("smoke_mouth",Vector3(-0.52,2.62,-0.43)))
		var mailbox=ArtExtras.create("PROP_008");mailbox.position=Vector3(0.9,0,0.8);node.add_child(mailbox)
		if house_variant=="garden":
			var ivy=ArtExtras.create("NAT_006");ivy.position=Vector3(-0.84,0,0.8);node.add_child(ivy)
	if kind=="tea":
		var teapot=ArtExtras.create("PROP_016");teapot.position=Vector3(0.17,0.68,0.66);node.add_child(teapot)
	node.rotation.y=-float(o.rotation)*PI/2;props.add_child(node)
	if kind in BuildingRules.BUILDINGS:
		building_picker.register(Vector2i(floori(p.x / 8.0), floori(p.y / 8.0)), p, node)
	if growing_ids.has(int(o.id)):growth.building(node, not new_ids.has(int(o.id)))
	if kind=="lighthouse":
		IslandEffects.lighthouse(node,not day)
		var lamp=OmniLight3D.new();lamp.position=Vector3(0,4,0);lamp.light_color=Color("ffd08a");lamp.light_energy=0.6;lamp.omni_range=6;lamp.visible=not day;node.add_child(lamp);lamp.add_to_group("island_lanterns")
func draw_boat(o:Dictionary,_y:float) -> void:
	var dir:Vector2i=BuildingRules.DIRS[int(o.rotation)%4];var side=Vector2i(-dir.y,dir.x)
	var node=Node3D.new();props.add_child(node);node.name="Boat";node.add_to_group("island_boats");node.add_to_group("dynamic_visual")
	node.position=Vector3(o.x+dir.x*2+side.x,0.1,o.z+dir.y*2+side.y)
	node.set_meta("dock_id",int(o.id));node.set_meta("mooring",node.position);node.set_meta("direction",Vector3(dir.x,0,dir.y))
	# The imported hull points along +Z. Keep its bow facing the mooring.
	node.rotation.y = atan2(-float(dir.x), -float(dir.y))
	var hull = preload("res://game/art/healing/boat/rowboat.glb").instantiate()
	hull.scale = Vector3(0.61, 0.70, 0.75)
	hull.position.y = -0.292
	node.add_child(hull)
	# Raise the central thwart to the existing arrival passenger anchor (0.35 m).
	for side_x in [-0.25, 0.25]:
		kit.box(node, Vector3(side_x, 0.17, 0), Vector3(0.08, 0.28, 0.18), ArtKit.WOOD)
	kit.box(node, Vector3(0, 0.315, 0), Vector3(0.72, 0.07, 0.23), ArtKit.WOOD)
func update_actors(sim:ResidentSim,time:float) -> void:
	var passengers:Dictionary={}
	for boat in get_tree().get_nodes_in_group("island_boats"):
		if not boat.has_meta("mooring"):continue
		var mooring:Vector3=boat.get_meta("mooring");boat.position.x=mooring.x;boat.position.z=mooring.z
		for person in sim.people:
			if int(person.get("arrival_dock",0))!=int(boat.get_meta("dock_id")) or person.state!="arriving" or float(person.timer)<=0:continue
			var direction:Vector3=boat.get_meta("direction");var distance=0.0
			# Check the complete hull's forward clearance before the short approach.
			for step in range(1,9):
				var probe=mooring+direction*(step*0.5+1.5);var cell=Vector2i(roundi(probe.x),roundi(probe.z))
				if not BuildingRules.inside(cell) or int(data.cell(cell).h)>0 or BuildingRules.occupied(data,cell):break
				distance=step*0.5
			boat.position += direction * distance * clampf(float(person.timer) / 4.0, 0, 1)
			passengers[int(person.id)] = {"seat": boat.position + Vector3.UP * 0.35, "yaw": boat.rotation.y}
	var active:Dictionary={}
	for person in sim.people:
		var id=int(person.id);active[id]=true
		if not actor_nodes.has(id):
			var n=ResidentRig.create((id-1)%4);inhabitants.add_child(n);actor_nodes[id]=n
		var n:Node3D=actor_nodes[id];n.visible=person.state!="resting"
		var p=Vector2i(roundi(person.x),roundi(person.z));var y=surface.height_at(Vector2(person.x,person.z))
		for o in data.objects:
			if o.kind=="bridge" and p in BuildingRules.footprint(o):y=float(data.cell(Vector2i(o.x,o.z)).h)*0.5+0.08
		if passengers.has(id):
			var passenger: Dictionary = passengers[id]
			n.position = passenger.seat
			n.rotation.y = passenger.yaw
			n.animate("bench", false, time + id * 0.2)
			# The rig origin is at its feet. Set the hips onto the thwart.
			n.skeleton.set_bone_pose_position(0, Vector3.UP * 0.05)
			continue
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
