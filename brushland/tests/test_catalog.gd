extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var catalog=JSON.parse_string(FileAccess.get_file_as_string("res://docs/art_i6/source_catalog.json"));var ids:Dictionary={};var total=0
	for item in catalog.records:
		assert(FileAccess.file_exists(item.path));assert(FileAccess.get_sha256(item.path)==item.sha256)
		ids[item.asset_id]=true;total+=1
		if item.path.ends_with(".json"):
			assert(JSON.parse_string(FileAccess.get_file_as_string(item.path))!=null);continue
		var resource=load(item.path);assert(resource!=null)
		if resource is PackedScene:
			var node=resource.instantiate();assert(node!=null);node.free()
	assert(ids.size()==117 and total==170)
	for clips in ArtCatalog.CLIPS.values():
		for clip in clips:assert(MotionLibrary.library().has_animation(clip))
	for limit_pair in [["cloak",400],["overalls",350],["apron",250],["scarf",100],["sweater",350]]:
		var rig=ResidentRig.create(0);assert(rig.wearables[limit_pair[0]].get_faces().size()/3<=limit_pair[1]);rig.free()
	print("PASS catalog 117 IDs / 170 source variants, hashes and resource loads")
	quit()
