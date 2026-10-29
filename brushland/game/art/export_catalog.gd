extends SceneTree
var records:Array=[]
func _initialize() -> void:call_deferred("run")
func own_children(node:Node,root_node:Node) -> void:
	for child in node.get_children():child.owner=root_node;own_children(child,root_node)
func run() -> void:
	MotionLibrary.prefer_resource=false;MotionLibrary.cached=null
	DirAccess.make_dir_recursive_absolute("res://game/art/catalog_sources");DirAccess.make_dir_recursive_absolute("res://game/art/animations")
	var input=FileAccess.open("res://docs/art_asset_manifest.csv",FileAccess.READ);var header=input.get_csv_line();header[0]=header[0].trim_prefix("\ufeff")
	while not input.eof_reached():
		var line=input.get_csv_line()
		if line.size()!=header.size():continue
		var row:Dictionary={}
		for i in range(header.size()):row[header[i]]=line[i]

		for variant in range(int(row.total_deliverables)):
			var result=ArtCatalog.create(row.asset_id,variant)
			if result==null:push_error("Missing catalog source: "+row.asset_id);quit(1);return
			var path="res://game/art/catalog_sources/%s_%02d"%[row.asset_id,variant];var error=OK
			var representation=""
			if result is String:
				path=result;representation="svg" if path.ends_with(".svg") else "raster_thumbnail"
				if not FileAccess.file_exists(path):push_error("Missing artwork "+path);quit(1);return
			elif result is Dictionary:
				path+=".json";var f=FileAccess.open(path,FileAccess.WRITE);f.store_string(JSON.stringify(result,"  "));f.close();representation="scene_recipe"
			elif result is Resource:
				path+=".tres";error=ResourceSaver.save(result,path);representation=result.get_class()
			else:
				root.add_child(result)
				if result is ResidentRig:
					result.set_meta("controller","res://game/art/resident_rig.gd" if not result is AnimalRig else "res://game/art/animal_rig.gd")
					var player=AnimationPlayer.new();player.name="AnimationPlayer";player.add_animation_library("",MotionLibrary.library());player.autoplay="idle" if not result is AnimalRig else "cat_walk" if result.species=="cat" else "gull_fly";result.add_child(player)
					result.set_script(null)
				result.name=row.asset_id+"_%02d"%variant;result.set_meta("asset_id",row.asset_id);result.set_meta("variant",variant)
				own_children(result,result);var packed=PackedScene.new();error=packed.pack(result)
				path+=".tscn"
				if error==OK:error=ResourceSaver.save(packed,path)
				representation="PackedScene";result.free()
			if error!=OK:push_error("Catalog save failed "+path);quit(1);return
			records.append({"asset_id":row.asset_id,"variant":variant,"path":path,"representation":representation,"sha256":FileAccess.get_sha256(path),"phase":row.phase,"production_status":"source_available","acceptance":"pending_visual_and_spec_review"})
	var error=ResourceSaver.save(MotionLibrary.library(),"res://game/art/animations/motions.tres")
	if error!=OK:quit(1);return
	var f=FileAccess.open("res://docs/art_i6/source_catalog.json",FileAccess.WRITE);f.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"records":records,"scope":"Art sources; not automatic acceptance of original budgets, topology or visual criteria"},"  "));f.close()
	print("PASS source catalog: ",records.size()," source variants");quit()
