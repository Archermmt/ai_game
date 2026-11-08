class_name FrozenArtInstances
extends RefCounted
## Project-owned immutable opaque props only. Never use on mutable/user shaders.
var material_pool:Dictionary={}
var material_ids:Dictionary={}
var mesh_pool:Dictionary={}
var mesh_ids:Dictionary={}
func static_branch(node:Node,boundary:Node) -> bool:
	var n=node
	while n!=null and n!=boundary:
		if n.is_in_group("dynamic_visual") or bool(n.get_meta("batch_exclude",false)) or n.get_script()!=null:return false
		if n is Node3D and not n.visible:return false
		for child in n.get_children():
			if child is AnimationMixer:return false
		n=n.get_parent()
	return true
func opaque_material(mat:Material) -> bool:
	return mat is StandardMaterial3D and mat.get_script()==null and mat.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED and mat.next_pass==null and mat.billboard_mode==BaseMaterial3D.BILLBOARD_DISABLED and not mat.grow and not mat.uv1_triplanar and not mat.uv2_triplanar and not mat.proximity_fade_enabled and mat.distance_fade_mode==BaseMaterial3D.DISTANCE_FADE_DISABLED
func canonical_material(mat:Material) -> Material:
	var id=mat.get_instance_id()
	if material_ids.has(id):return material_ids[id]
	var signature:Array=[mat.get_class()]
	for property in mat.get_property_list():
		var name=String(property.name)
		if not int(property.usage)&PROPERTY_USAGE_STORAGE or name.begins_with("resource_") or name=="script" or name.begins_with("metadata/"):continue
		var value=mat.get(name)
		signature.append([name,typeof(value),value.get_instance_id() if value is Resource else value])
	if not material_pool.has(signature):material_pool[signature]=mat
	material_ids[id]=material_pool[signature];return material_ids[id]
func geometry_key(mesh:Mesh) -> Array:
	var key:Array=[]
	for i in range(mesh.get_surface_count()):
		var descriptor=RenderingServer.mesh_get_surface(mesh.get_rid(),i).duplicate()
		descriptor.erase("material");key.append(descriptor)
	if mesh is ArrayMesh:
		key.append(mesh.custom_aabb)
		if mesh.shadow_mesh!=null:
			var shadow:Array=[]
			for i in range(mesh.shadow_mesh.get_surface_count()):
				var descriptor=RenderingServer.mesh_get_surface(mesh.shadow_mesh.get_rid(),i).duplicate();descriptor.erase("material");shadow.append(descriptor)
			key.append(shadow)
		else:key.append(null)
	else:key.append(AABB());key.append(null)
	return key
func canonicalize(parent:Node3D) -> void:
	for node in parent.find_children("*","MeshInstance3D",true,false):
		if node.global_transform.basis.determinant()<=0.000001:continue
		if node.mesh==null or node.skin!=null or RenderingServer.mesh_get_blend_shape_count(node.mesh.get_rid())>0 or not static_branch(node,parent):continue
		var valid=true;var materials:Array=[]
		for surface in range(node.mesh.get_surface_count()):
			var mat=node.get_active_material(surface)
			if not opaque_material(mat):valid=false;break
			materials.append(canonical_material(mat))
		if not valid:continue
		var id=node.mesh.get_instance_id()
		if not mesh_ids.has(id):
			var signature=geometry_key(node.mesh)
			if not mesh_pool.has(signature):mesh_pool[signature]=node.mesh
			mesh_ids[id]=mesh_pool[signature]
		node.mesh=mesh_ids[id]
		# A node-level override takes precedence over surface overrides. Transfer
		# its full effective material before clearing it, so deduplication applies.
		node.material_override=null
		for surface in range(materials.size()):node.set_surface_override_material(surface,materials[surface])
func instance_remaining(parent:Node3D) -> Dictionary:
	var groups:Dictionary={};var merged=0
	for node in parent.find_children("*","MeshInstance3D",true,false):
		if node.global_transform.basis.determinant()<=0.000001:continue
		if node.mesh==null or node.mesh.get_surface_count()!=1 or node.skin!=null or node.material_overlay!=null or not static_branch(node,parent):continue
		if node.custom_aabb!=AABB() or node.visibility_parent!=NodePath("") or node.visibility_range_end!=0 or node.visibility_range_begin!=0 or node.transparency!=0 or node.lod_bias!=1:continue
		if RenderingServer.mesh_get_blend_shape_count(node.mesh.get_rid())>0:continue
		var mat=node.get_active_material(0)
		if not opaque_material(mat):continue
		var properties:Array=[]
		for name in StaticBatcher.INSTANCE_PROPERTIES:properties.append(node.get(name))
		var key=[node.mesh.get_instance_id(),mat.get_instance_id(),properties]
		if not groups.has(key):groups[key]=[]
		groups[key].append(node)
	for sources in groups.values():
		if sources.size()<2:continue
		var source:MeshInstance3D=sources[0];var multi=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.mesh=source.mesh;multi.instance_count=sources.size()
		for i in range(sources.size()):multi.set_instance_transform(i,parent.global_transform.affine_inverse()*sources[i].global_transform)
		var node=MultiMeshInstance3D.new();node.multimesh=multi;node.material_override=source.get_active_material(0)
		for property in StaticBatcher.INSTANCE_PROPERTIES:node.set(property,source.get(property))
		parent.add_child(node)
		for item in sources:
			if item.get_child_count()==0:item.free()
			else:item.mesh=null
		merged+=sources.size()
	return {"instanced_sources":merged}
