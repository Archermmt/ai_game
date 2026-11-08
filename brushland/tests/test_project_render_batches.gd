extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	create_timer(15).timeout.connect(func():push_error("Project proxy timeout");quit(1))
	var view=Node3D.new();root.add_child(view);var props=Node3D.new();var ground=Node3D.new();view.add_child(props);view.add_child(ground)
	var kit=ArtKit.new();var a=kit.box(props,Vector3.ZERO,Vector3.ONE,ArtKit.CORAL);var b=kit.box(props,Vector3(3,0,0),Vector3.ONE,ArtKit.BLUE)
	var hidden=kit.box(props,Vector3(6,0,0),Vector3.ONE,Color.WHITE);hidden.visible=false
	var glass=kit.box(props,Vector3(8,0,0),Vector3.ONE,Color.WHITE);glass.material_override=glass.material_override.duplicate();glass.material_override.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	var dynamic=Node3D.new();props.add_child(dynamic);dynamic.add_to_group("dynamic_visual");var moving=kit.box(dynamic,Vector3(10,0,0),Vector3.ONE,Color.WHITE)
	for block in [0,100]:
		var multi=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.use_colors=true;multi.mesh=QuadMesh.new();multi.instance_count=10
		for i in range(10):multi.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3(block+i,0,0)));multi.set_instance_color(i,Color.WHITE)
		var node=MultiMeshInstance3D.new();node.multimesh=multi;node.material_override=ShaderMaterial.new();node.set_meta("foliage_layer",0);ground.add_child(node)
	var renderer=preload("res://game/art/project_render_batches.gd").new();renderer.rebuild(view,props,ground)
	assert(not a.visible and not b.visible and not hidden.visible and glass.visible and moving.visible)
	var batches=renderer.output.find_children("*","MeshInstance3D",true,false);assert(batches.size()==1)
	assert(batches[0].mesh.get_faces().size()==72);assert(batches[0].mesh.get_aabb().size.x==4)
	var grass=renderer.grass[0].multimesh;var west=false;var east=false
	for i in range(10):
		var x=grass.get_instance_transform(i).origin.x;west=west or x<50;east=east or x>50
	assert(west and east)
	var output_id=renderer.output.get_instance_id();var batch_id=batches[0].get_instance_id();var grass_id=renderer.grass[0].get_instance_id()
	renderer.restore(true);renderer.rebuild(view,props,ground)
	assert(renderer.output.get_instance_id()==output_id and renderer.output.find_children("*","MeshInstance3D",true,false)[0].get_instance_id()==batch_id and renderer.grass[0].get_instance_id()==grass_id)
	renderer.restore();assert(a.visible and b.visible and not hidden.visible)
	a.material_override.roughness=0.4;a.material_override.emit_changed();renderer.rebuild(view,props,ground)
	assert(renderer.output.find_children("*","MeshInstance3D",true,false).size()==2)
	renderer.restore();view.free();print("PASS project proxies: geometry/colors, source restore, hidden/dynamic/alpha, whole-island grass LOD and material invalidation");quit()
