extends SceneTree
var failures: int=0
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var battle=load("res://features/battle/presentation/battle.tscn").instantiate()
	root.add_child(battle); battle.set_process(false)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/validation/title_runtime.png")
	battle.restart()
	await physics_frame
	for direction in range(4):
		battle.angle=direction*PI/2; battle.update_camera()
		await physics_frame
		await RenderingServer.frame_post_draw
		var selectable: int=0
		for u in battle.state.units:
			var screen: Vector2=battle.camera.unproject_position(battle.point(u.p))
			var origin: Vector3=battle.camera.project_ray_origin(screen)
			var query=PhysicsRayQueryParameters3D.create(origin,origin+battle.camera.project_ray_normal(screen)*100)
			var hit: Dictionary=battle.get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty() and hit.collider.get_meta("tile")==u.p: selectable+=1
		print("View ",direction,": ",selectable,"/6 unit feet selectable")
		if selectable!=6: failures+=1
		root.get_texture().get_image().save_png("res://docs/validation/view_%d.png"%direction)
	battle.angle=0; battle.update_camera(); battle.selected=Vector2i(3,8)
	battle.candidate=battle.state.request("move",battle.selected); battle.refresh()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/validation/path_preview.png")

	# A midbattle adjacent attack uses the real preview card and forecast.
	battle.restart()
	battle.state.commit(battle.state.request("end",Vector2i.ZERO))
	battle.state.commit(battle.state.request("end",Vector2i.ZERO))
	battle.state.units[0].p=Vector2i(3,7)
	battle.state.units[3].p=Vector2i(3,6)
	battle.mode="attack"; battle.selected=Vector2i(3,6)
	battle.candidate=battle.state.request("attack",battle.selected)
	var units_before: Array=battle.state.units.duplicate(true)
	battle.rebuild()
	if not battle.target_info.text.contains("85 → 59") or battle.state.units!=units_before: failures+=1
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/validation/attack_preview.png")
	root.size=Vector2i(1280,720)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/validation/attack_720p.png")
	print("Viewport: ",failures," failures (four initial directions, all six unit feet)")
	battle.queue_free(); quit(1 if failures else 0)
