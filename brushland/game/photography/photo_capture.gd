extends RefCounted
static func image(app:Node3D,source:Camera3D,size:Vector2i) -> Image:
	var viewport=SubViewport.new();viewport.size=size;viewport.world_3d=app.get_world_3d();viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	viewport.msaa_3d=app.get_viewport().msaa_3d;app.add_child(viewport)
	var camera=Camera3D.new();camera.cull_mask=source.cull_mask&~(1<<19);camera.projection=source.projection;camera.size=source.size;camera.fov=source.fov;camera.keep_aspect=source.keep_aspect;camera.near=source.near;camera.far=source.far;camera.transform=source.global_transform;viewport.add_child(camera);camera.current=true
	await app.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var result=viewport.get_texture().get_image();viewport.queue_free();return result
