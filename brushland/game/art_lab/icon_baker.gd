extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var vp=SubViewport.new();vp.size=Vector2i(128,128);vp.own_world_3d=true;vp.transparent_bg=true;vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(vp)
	var scene=Node3D.new();vp.add_child(scene)
	var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=3.5;camera.position=Vector3(3,3.5,4);scene.add_child(camera);camera.look_at(Vector3(0,0.6,0));camera.current=true
	var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-45,-30,0);light.light_energy=0.7;scene.add_child(light)
	var kit=ArtKit.new();var library=MaterialLibrary.new()
	DirAccess.make_dir_recursive_absolute("res://game/ui/icons")
	var ids=IslandHud.NAMES.keys()+["house_basic","house_coast","house_garden"]
	for id in ids:
		var prop=Node3D.new();scene.add_child(prop)
		kit.box(prop,Vector3(0,-0.1,0),Vector3(2,0.2,2),Color("8ca57b"))
		if id.begins_with("house_"):
			prop.add_child(kit.building("house",id.trim_prefix("house_")))
		elif id in ["house","tea","greenhouse","lighthouse","bench","pot","tree"]:
			var model=kit.building(id,"garden" if id=="house" else "basic");prop.add_child(model);library.dress(model,id)
			if id=="lighthouse":model.scale=Vector3.ONE*0.5
		elif id=="flower":
			for x in [-0.45,0,0.45]:kit.flower(prop,Vector3(x,0,0),1)
		elif id in ["water","sand","rock","grass"]:
			kit.box(prop,Vector3(0,0.05,0),Vector3(1.9,0.2,1.9),{"water":Color("5d9f9e"),"sand":Color("e2d1a8"),"rock":Color("aaa997"),"grass":Color("a5b983")}[id])
		elif id in ["road","bridge","dock"]:
			for z in range(5):kit.box(prop,Vector3(0,0.16,-0.8+z*0.4),Vector3(0.8,0.1,0.3),ArtKit.WOOD if id!="road" else Color("d9c7a5"))
		else:
			kit.box(prop,Vector3(0,0.35,0),Vector3(0.6,0.5 if id=="lower" else 0.9,0.6),ArtKit.CORAL if id=="erase" else ArtKit.CREAM)
		for i in range(3):await process_frame
		await RenderingServer.frame_post_draw
		var error=vp.get_texture().get_image().save_png("res://game/ui/icons/"+id+".png")
		if error!=OK:quit(1);return
		prop.free()
	vp.free();print("PASS baked ",ids.size()," tool thumbnails");quit()
