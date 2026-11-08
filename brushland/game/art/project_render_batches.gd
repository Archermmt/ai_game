extends RefCounted
## Render-only LOD0 proxies for this project's low-poly art. Authoring nodes,
## imported LODs and shadow resources remain untouched and can be restored.
var hidden:Array=[]
var hidden_ids:Dictionary={}
var output:Node3D
var grass:Array=[]
var smoke:Array=[]
var materials=FrozenArtInstances.new()
var palette:Dictionary={}
var instance_materials:Dictionary={}
var grass_cache:Dictionary={}
var geometry_cache:Dictionary={}
var mesh_references:Dictionary={}
var batch_mesh_cache:Dictionary={}
var scope_cache:Dictionary={}
var material_snapshots:Dictionary={}
var instance_snapshots:Dictionary={}
var mesh_nodes:Dictionary={}
var instance_nodes:Dictionary={}
var grass_nodes:Dictionary={}
var smoke_nodes:Dictionary={}
func material_signature(mat:Material) -> Array:
	var signature:Array=[mat.get_class()]
	for property in mat.get_property_list():
		var name=String(property.name)
		if not int(property.usage)&PROPERTY_USAGE_STORAGE or name.begins_with("resource_") or name=="script" or name.begins_with("metadata/"):continue
		var value=mat.get(name);signature.append([name,typeof(value),value.get_instance_id() if value is Resource else value])
	return signature
func invalidate_geometry() -> void:
	geometry_cache.clear();mesh_references.clear();batch_mesh_cache.clear();scope_cache.clear()
func restore(keep_sources_hidden:bool=false) -> void:
	if not keep_sources_hidden:
		for node in hidden:
			if is_instance_valid(node):node.visible=true
		hidden_ids.clear()
	hidden.clear();grass.clear();smoke.clear()
	if not keep_sources_hidden:
		if is_instance_valid(output):output.free()
		mesh_nodes.clear();instance_nodes.clear();grass_nodes.clear();smoke_nodes.clear()
func draw_material(mat:Material) -> Array:
	if mat is StandardMaterial3D:
		if not materials.opaque_material(mat):return []
		var id=mat.get_instance_id()
		if palette.has(id):return palette[id]
		var signature=material_signature(mat)
		if material_snapshots.has(signature):palette[id]=material_snapshots[signature];return palette[id]
		var tint=Color.WHITE;var bake=false
		if mat.albedo_texture==null and not mat.vertex_color_use_as_albedo:
			tint=mat.albedo_color;bake=true
			var copy=mat.duplicate();copy.albedo_color=Color.WHITE;copy.vertex_color_use_as_albedo=true;copy.vertex_color_is_srgb=true
			mat=materials.canonical_material(copy)
		else:mat=materials.canonical_material(mat.duplicate())
		palette[id]=[mat,tint,bake];material_snapshots[signature]=palette[id];return palette[id]
	if mat is ShaderMaterial and bool(mat.get_meta("static_batch_safe",false)) and mat.next_pass==null:return [mat,Color.WHITE,false]
	return []
func collect(boundary:Node3D,nodes:Array,inverse:Transform3D,context:Dictionary) -> Dictionary:
	var result={"meshes":[],"instances":[],"hide":[],"smoke":[]}
	for node in nodes:
		if node.is_in_group("island_smoke"):result.smoke.append(node);continue
		if not static_branch(node,boundary) or node.mesh==null or node.skin!=null or node.material_overlay!=null:continue
		if node.global_transform.basis.determinant()<=0.000001 or node.custom_aabb!=AABB() or not node.visibility_parent.is_empty() or node.visibility_range_begin!=0 or node.visibility_range_end!=0 or node.transparency!=0 or node.lod_bias!=1 or node.visibility_range_begin_margin!=0 or node.visibility_range_end_margin!=0:continue
		if RenderingServer.mesh_get_blend_shape_count(node.mesh.get_rid())>0:continue
		var settings:Array=[]
		for key in StaticBatcher.INSTANCE_PROPERTIES:settings.append(node.get(key))
		var transform=inverse*node.global_transform
		var instance_only=node.is_in_group("island_leaf_nodes");var scale=node.global_transform.basis.get_scale().abs()
		if not instance_only and node.mesh.get_surface_count()==1 and maxf(scale.x,maxf(scale.y,scale.z))-minf(scale.x,minf(scale.y,scale.z))>0.00001:
			var id=node.mesh.get_instance_id()
			if not context.curves.has(id):
				context.curves[id]=false;var arrays=node.mesh.surface_get_arrays(0);var normals=arrays[Mesh.ARRAY_NORMAL];var indices=arrays[Mesh.ARRAY_INDEX]
				if normals!=null and indices!=null:
					for i in range(0,indices.size(),3):
						if normals[indices[i]].distance_squared_to(normals[indices[i+1]])>0.000001 or normals[indices[i]].distance_squared_to(normals[indices[i+2]])>0.000001:context.curves[id]=true;break
			instance_only=context.curves[id]
		if instance_only and node.mesh.get_surface_count()==1:
			var mat=node.get_active_material(0)
			if mat is StandardMaterial3D:
				if not materials.opaque_material(mat):continue
				var id=mat.get_instance_id()
				if not instance_materials.has(id):
					var signature=material_signature(mat)
					if not instance_snapshots.has(signature):instance_snapshots[signature]=materials.canonical_material(mat.duplicate())
					instance_materials[id]=instance_snapshots[signature]
				mat=instance_materials[id]
			elif not node.is_in_group("island_leaf_nodes") and not (mat is ShaderMaterial and bool(mat.get_meta("static_batch_safe",false))):continue
			var id=node.mesh.get_instance_id()
			if not context.meshes.has(id):
				var key=materials.geometry_key(node.mesh)
				if not materials.mesh_pool.has(key):materials.mesh_pool[key]=node.mesh
				context.meshes[id]=materials.mesh_pool[key]
			var mesh=context.meshes[id];var key=[mesh.get_instance_id(),mat.get_instance_id(),settings,node.is_in_group("island_leaf_nodes")]
			result.instances.append({"key":key,"mesh":mesh,"material":mat,"settings":settings,"leaves":node.is_in_group("island_leaf_nodes"),"transform":transform})
			result.hide.append(node);continue
		var surfaces:Array=[];var valid=true;var shadow=node.mesh.shadow_mesh if node.mesh is ArrayMesh else null
		if shadow!=null and shadow.get_surface_count()!=node.mesh.get_surface_count():continue
		for i in range(node.mesh.get_surface_count()):
			var mesh_key=[node.mesh.get_instance_id(),i]
			if not geometry_cache.has(mesh_key):geometry_cache[mesh_key]=[RenderingServer.mesh_get_surface(node.mesh.get_rid(),i),node.mesh.surface_get_arrays(i)];mesh_references[mesh_key]=weakref(node.mesh)
			var descriptor=geometry_cache[mesh_key][0]
			if descriptor.get("primitive",-1)!=Mesh.PRIMITIVE_TRIANGLES or int(descriptor.get("format",0))&StaticBatcher.CUSTOM_ARRAYS:valid=false;break
			var material=draw_material(node.get_active_material(i));var arrays=geometry_cache[mesh_key][1]
			if material.is_empty() or arrays[Mesh.ARRAY_VERTEX]==null:valid=false;break
			arrays=arrays.duplicate()
			if material[2]:
				var colors=PackedColorArray();colors.resize(arrays[Mesh.ARRAY_VERTEX].size());colors.fill(material[1]);arrays[Mesh.ARRAY_COLOR]=colors
			var channels:Array=[]
			for channel in arrays:channels.append(typeof(channel) if channel!=null else 0)
			var shadow_arrays:Array=[]
			if shadow!=null:
				var key=[shadow.get_instance_id(),i]
				if not context.shadows.has(key):context.shadows[key]=StaticBatcher._read_surface_arrays(shadow,i,RenderingServer.mesh_get_surface(shadow.get_rid(),i),true)
				shadow_arrays=context.shadows[key]
				if shadow_arrays.is_empty() or shadow_arrays[Mesh.ARRAY_VERTEX]==null:valid=false;break
			var spatial=Vector2i(floori(node.global_position.x/32.0),floori(node.global_position.z/32.0))
			if node.has_meta("art_terrain"):
				var chunk=node.get_meta("art_terrain");spatial=Vector2i(floori(chunk.x/4.0),floori(chunk.y/4.0))
			var key=[material[0].get_instance_id(),channels,settings,shadow!=null,spatial]
			surfaces.append({"key":key,"material":material[0],"arrays":arrays,"shadow":shadow_arrays,"settings":settings,"transform":transform,"signature":[node.get_instance_id(),node.mesh.get_instance_id(),node.mesh.get_aabb(),i,material[1],transform]})
		if valid:result.meshes.append_array(surfaces);result.hide.append(node)
	return result
func transform_buffer(t:Transform3D) -> PackedFloat32Array:
	return PackedFloat32Array([t.basis.x.x,t.basis.y.x,t.basis.z.x,t.origin.x,t.basis.x.y,t.basis.y.y,t.basis.z.y,t.origin.y,t.basis.x.z,t.basis.y.z,t.basis.z.z,t.origin.z])
func rebuild(view:Node3D,props:Node3D,ground:Node3D) -> void:
	palette.clear();instance_materials.clear()
	for key in mesh_references.keys():
		if mesh_references[key].get_ref()==null:geometry_cache.erase(key);mesh_references.erase(key)
	if not is_instance_valid(output):
		output=Node3D.new();output.name="RenderProxies";view.add_child(output)
	var inverse=output.global_transform.affine_inverse();var context={"curves":{},"meshes":{},"shadows":{}}
	var groups:Dictionary={};var instances:Dictionary={};var to_hide:Array=[];var smoke_sources:Array=[];var new_scopes:Dictionary={};var new_grass_cache:Dictionary={};var new_batch_mesh_cache:Dictionary={}
	for boundary in [props,ground]:
		var scopes=boundary.get_children()
		scopes.sort_custom(func(a,b):
			var x=a.get_meta("art_chunk",a.get_meta("art_terrain",Vector2i.ZERO));var y=b.get_meta("art_chunk",b.get_meta("art_terrain",Vector2i.ZERO))
			return x.y<y.y if x.y!=y.y else x.x<y.x)
		for scope in scopes:
			if scope is MultiMeshInstance3D:continue
			var cached=scope.has_meta("art_chunk") or scope.has_meta("art_terrain");var key=scope.get_instance_id();var record:Dictionary
			if cached and scope_cache.has(key):record=scope_cache[key]
			else:
				var nodes:Array=[scope] if scope is MeshInstance3D else scope.find_children("*","MeshInstance3D",true,false)
				record=collect(boundary,nodes,inverse,context)
			if cached:new_scopes[key]=record
			to_hide.append_array(record.hide);smoke_sources.append_array(record.smoke)
			for item in record.meshes:
				if not groups.has(item.key):groups[item.key]={"arrays":[],"shadows":[],"signature":[],"material":item.material,"settings":item.settings}
				groups[item.key].signature.append(item.signature);groups[item.key].arrays.append([item.arrays,item.transform])
				if not item.shadow.is_empty():groups[item.key].shadows.append([item.shadow,item.transform])
			for item in record.instances:
				if not instances.has(item.key):instances[item.key]={"transforms":[],"mesh":item.mesh,"material":item.material,"settings":item.settings,"leaves":item.leaves}
				instances[item.key].transforms.append(item.transform)
	scope_cache=new_scopes
	for key in groups:
		var group=groups[key];var mesh:ArrayMesh
		if batch_mesh_cache.has(key) and batch_mesh_cache[key].signature==group.signature:mesh=batch_mesh_cache[key].mesh
		else:
			var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX)
			for record in group.arrays:StaticBatcher._append_surface(arrays,record[0],record[1])
			mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			if not group.shadows.is_empty():
				var arrays_shadow:Array=[];arrays_shadow.resize(Mesh.ARRAY_MAX)
				for record in group.shadows:StaticBatcher._append_surface(arrays_shadow,record[0],record[1])
				var shadow=ArrayMesh.new();shadow.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays_shadow);mesh.shadow_mesh=shadow
		new_batch_mesh_cache[key]={"signature":group.signature,"mesh":mesh}
		if not mesh_nodes.has(key):
			var node=MeshInstance3D.new();output.add_child(node);mesh_nodes[key]=node;node.material_override=group.material
			for i in range(StaticBatcher.INSTANCE_PROPERTIES.size()):node.set(StaticBatcher.INSTANCE_PROPERTIES[i],group.settings[i])
		if mesh_nodes[key].mesh!=mesh:mesh_nodes[key].mesh=mesh
	for key in mesh_nodes.keys():
		if not groups.has(key):mesh_nodes[key].free();mesh_nodes.erase(key)
	for key in instances:
		var group=instances[key]
		if not instance_nodes.has(key):
			var multi=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.mesh=group.mesh
			var node=MultiMeshInstance3D.new();node.multimesh=multi;node.material_override=group.material;output.add_child(node)
			if group.leaves:node.add_to_group("island_leaf_nodes")
			for i in range(StaticBatcher.INSTANCE_PROPERTIES.size()):node.set(StaticBatcher.INSTANCE_PROPERTIES[i],group.settings[i])
			instance_nodes[key]={"node":node,"transforms":[]}
		var entry=instance_nodes[key]
		if entry.transforms!=group.transforms:
			var buffer=PackedFloat32Array()
			for t in group.transforms:buffer.append_array(transform_buffer(t))
			if entry.node.multimesh.instance_count!=group.transforms.size():entry.node.multimesh.instance_count=group.transforms.size()
			entry.node.multimesh.buffer=buffer;entry.transforms=group.transforms
	for key in instance_nodes.keys():
		if not instances.has(key):instance_nodes[key].node.free();instance_nodes.erase(key)
	# Grass cards share an authored layer even when their per-chunk Mesh differs.
	var foliage:Dictionary={}
	for node in ground.find_children("*","MultiMeshInstance3D",true,false):
		if not node.has_meta("foliage_layer"):continue
		var layer=int(node.get_meta("foliage_layer"))
		if not foliage.has(layer):foliage[layer]=[]
		foliage[layer].append(node)
	for layer in foliage:
		var sources=foliage[layer]
		var count=0
		for node in sources:count+=node.multimesh.instance_count
		if not grass_nodes.has(layer):
			var multi=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.use_colors=true;multi.mesh=sources[0].multimesh.mesh
			var node=MultiMeshInstance3D.new();node.multimesh=multi;node.material_override=sources[0].material_override;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;output.add_child(node);grass_nodes[layer]=node
		var node=grass_nodes[layer];var multi=node.multimesh
		if multi.instance_count!=count:multi.instance_count=count
		var records:Array=[]
		for source in sources:
			var transform=output.global_transform.affine_inverse()*source.global_transform;var key=[source.get_instance_id(),transform]
			if not grass_cache.has(key):
				var items:Array=[]
				for i in range(source.multimesh.instance_count):
					var t=transform*source.multimesh.get_instance_transform(i);var color=source.multimesh.get_instance_color(i);var buffer=transform_buffer(t);buffer.append_array(PackedFloat32Array([color.r,color.g,color.b,color.a]))
					items.append({"rank":float(i)/source.multimesh.instance_count,"buffer":buffer})
				grass_cache[key]=items
			new_grass_cache[key]=grass_cache[key];records.append_array(grass_cache[key]);to_hide.append(source)
		# Interleave local rank prefixes: lower density must cover the whole island,
		# rather than dropping every card in the last half of its source chunks.
		var buckets:Array=[];buckets.resize(256)
		for record in records:
			var bucket=mini(255,int(record.rank*256))
			if buckets[bucket]==null:buckets[bucket]=[]
			buckets[bucket].append(record)
		records=[]
		for bucket in buckets:
			if bucket!=null:records.append_array(bucket)
		var buffer=PackedFloat32Array()
		for record in records:buffer.append_array(record.buffer)
		multi.buffer=buffer
		grass.append(node)
	for layer in grass_nodes.keys():
		if not foliage.has(layer):grass_nodes[layer].free();grass_nodes.erase(layer)
	# Only the project-authored unshaded smoke uses this transparent path.
	# Spatial groups retain local ordering relative to greenhouse glass.
	var smoke_groups:Dictionary={}
	for source in smoke_sources:
		var position=source.global_position;var key=Vector2i(floori(position.x/8),floori(position.z/8))
		if not smoke_groups.has(key):smoke_groups[key]=[]
		smoke_groups[key].append(source);to_hide.append(source)
	for key in smoke_groups:
		var sources=smoke_groups[key]
		if not smoke_nodes.has(key):
			var multi=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.use_colors=true;multi.mesh=sources[0].mesh
			var mat=sources[0].material_override.duplicate();mat.albedo_color=Color.WHITE;mat.vertex_color_use_as_albedo=true;mat.vertex_color_is_srgb=true
			var node=MultiMeshInstance3D.new();node.multimesh=multi;node.material_override=mat;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;output.add_child(node);smoke_nodes[key]=node
		var node=smoke_nodes[key]
		if node.multimesh.instance_count!=sources.size():node.multimesh.instance_count=sources.size()
		smoke.append({"node":node,"sources":sources})
	for key in smoke_nodes.keys():
		if not smoke_groups.has(key):smoke_nodes[key].free();smoke_nodes.erase(key)
	update_smoke(view.get_viewport().get_camera_3d())
	grass_cache=new_grass_cache;batch_mesh_cache=new_batch_mesh_cache
	hidden_ids.clear()
	for node in to_hide:node.visible=false;hidden.append(node);hidden_ids[node.get_instance_id()]=true

func update_smoke(camera:Camera3D) -> void:
	if not is_instance_valid(output):return
	var inverse=output.global_transform.affine_inverse()
	for group in smoke:
		var sources=group.sources
		if camera!=null:sources.sort_custom(func(a,b):return (-camera.global_basis.z).dot(a.global_position-camera.global_position)>(-camera.global_basis.z).dot(b.global_position-camera.global_position))
		for i in range(sources.size()):
			group.node.multimesh.set_instance_transform(i,inverse*sources[i].global_transform)
			group.node.multimesh.set_instance_color(i,sources[i].material_override.albedo_color)

func static_branch(node:Node,boundary:Node) -> bool:
	var current=node
	while current!=null and current!=boundary:
		if current.is_in_group("dynamic_visual") or bool(current.get_meta("batch_exclude",false)) or current.get_script()!=null:return false
		if current is Node3D and not current.visible and not hidden_ids.has(current.get_instance_id()):return false
		for child in current.get_children():
			if child is AnimationMixer:return false
		current=current.get_parent()
	return true
