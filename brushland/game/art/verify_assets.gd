extends SceneTree
func _initialize() -> void:
	var count=0
	for file in DirAccess.get_files_at("res://game/art/models"):
		if not file.ends_with(".glb"):continue
		var scene=load("res://game/art/models/"+file) as PackedScene
		assert(scene!=null,file)
		var n=scene.instantiate();var meshes=0;var queue:Array=[n]
		while not queue.is_empty():
			var item=queue.pop_back()
			if item is MeshInstance3D:meshes+=1
			for child in item.get_children():queue.append(child)
		assert(meshes>0,file);n.free();count+=1
	assert(count==15)
	print("PASS 15 GLB models imported with mesh content")
	quit()
