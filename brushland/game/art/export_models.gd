extends SceneTree
func _initialize() -> void:
	call_deferred("export_all")
func export_all() -> void:
	var kit=ArtKit.new()
	var models:Dictionary={}
	for variant in ["basic","coast","garden"]:models["house_"+variant]=kit.building("house",variant)
	for kind in ["tea","greenhouse","lighthouse","bench","pot","tree"]:models[kind]=kit.building(kind)
	for i in range(4):models["resident_%d"%i]=ResidentRig.create(i)
	models.cat=AnimalRig.make("cat");models.gull=AnimalRig.make("gull")
	for id in models:
		var node:Node3D=models[id];root.add_child(node)
		# glTF cannot preserve custom wind shaders; export the same leaf texture as
		# alpha-scissor material, while the runtime source retains its wind shader.
		for mesh in node.find_children("*","MeshInstance3D",true,false):
			var source=mesh.material_override
			if source is ShaderMaterial and source.get_shader_parameter("leaves")!=null:
				var mat=StandardMaterial3D.new();mat.albedo_texture=source.get_shader_parameter("leaves");mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR;mat.alpha_scissor_threshold=0.4;mat.cull_mode=BaseMaterial3D.CULL_DISABLED;mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mesh.material_override=mat
		var state=GLTFState.new();var doc=GLTFDocument.new()
		var error=doc.append_from_scene(node,state)
		if error==OK:error=doc.write_to_filesystem(state,"res://game/art/models/"+id+".glb")
		if error!=OK:push_error("Export failed: "+id);quit(1);return
		node.free();print("EXPORTED ",id)
	quit()
