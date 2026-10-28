extends SceneTree
func _initialize() -> void:
	call_deferred("export_all")
func export_all() -> void:
	var kit=ArtKit.new()
	var models:Dictionary={}
	for variant in ["basic","coast","garden"]:models["house_"+variant]=kit.building("house",variant)
	for kind in ["tea","greenhouse","lighthouse","bench","pot","tree"]:models[kind]=kit.building(kind)
	for i in range(4):models["resident_%d"%i]=kit.character(i)
	models.cat=kit.animal("cat");models.gull=kit.animal("gull")
	for id in models:
		var node:Node3D=models[id];root.add_child(node)
		var state=GLTFState.new();var doc=GLTFDocument.new()
		var error=doc.append_from_scene(node,state)
		if error==OK:error=doc.write_to_filesystem(state,"res://game/art/models/"+id+".glb")
		if error!=OK:push_error("Export failed: "+id);quit(1);return
		node.free();print("EXPORTED ",id)
	quit()
