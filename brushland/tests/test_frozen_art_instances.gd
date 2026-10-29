extends SceneTree
func _initialize() -> void:
	create_timer(5).timeout.connect(func():push_error("Frozen-art check did not complete");quit(1))
	call_deferred("run")
func source(parent:Node3D,position:Vector3,material:Material) -> MeshInstance3D:
	var node=MeshInstance3D.new();node.mesh=BoxMesh.new();node.material_override=material;node.position=position;parent.add_child(node);return node
func run() -> void:
	var stage=Node3D.new();root.add_child(stage);var optimizer=FrozenArtInstances.new()
	var mat=StandardMaterial3D.new();mat.albedo_color=Color("789579");mat.roughness=0.63
	var a=source(stage,Vector3.ZERO,mat);var b=source(stage,Vector3(2,0,0),mat.duplicate())
	var other=mat.duplicate();other.uv1_scale=Vector3(2,1,1);var c=source(stage,Vector3(4,0,0),other)
	var hidden=source(stage,Vector3(6,0,0),mat);hidden.visible=false
	var bounds=source(stage,Vector3(8,0,0),mat);bounds.custom_aabb=AABB(Vector3(-2,-2,-2),Vector3(4,4,4))
	optimizer.canonicalize(stage)
	assert(a.mesh==b.mesh and a.get_active_material(0)==b.get_active_material(0))
	assert(c.get_active_material(0)!=a.get_active_material(0))
	var stats=optimizer.instance_remaining(stage);assert(stats.instanced_sources==2)
	assert(is_instance_valid(hidden) and not hidden.visible and is_instance_valid(bounds))
	var multis=stage.find_children("*","MultiMeshInstance3D",true,false);assert(multis.size()==1 and multis[0].multimesh.instance_count==2)
	assert(multis[0].multimesh.get_instance_transform(1).origin.is_equal_approx(Vector3(2,0,0)))
	var lod=ArrayMesh.new();var cube=BoxMesh.new();var arrays=cube.surface_get_arrays(0)
	lod.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{4.0:PackedInt32Array([0,1,2])});var shadow=ArrayMesh.new();shadow.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);lod.shadow_mesh=shadow
	var lod_a=source(stage,Vector3(10,0,0),mat);lod_a.mesh=lod
	var lod_b=source(stage,Vector3(12,0,0),mat);lod_b.mesh=lod.duplicate()
	optimizer.canonicalize(stage);optimizer.instance_remaining(stage)
	var found=false
	for node in stage.find_children("*","MultiMeshInstance3D",true,false):
		if node.multimesh.mesh is ArrayMesh and node.multimesh.mesh.shadow_mesh!=null:
			found=true;assert(not RenderingServer.mesh_get_surface(node.multimesh.mesh.get_rid(),0).get("lods",[]).is_empty())
	assert(found)
	stage.free();print("PASS frozen art: full materials, geometry reuse, hidden/custom bounds, transforms, LOD and shadow retention");quit()
