extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	create_timer(30).timeout.connect(func():push_error("Product UI timeout");quit(1))
	var app=load("res://game/island.tscn").instantiate();app.preferences.path="user://test_completion_ui.cfg";root.add_child(app)
	await process_frame;app.close_modal();app.sim.paused=true
	app.center=Vector3(25,0,31);app.angle=0.8;app.camera.size=24;app.update_camera()
	assert(app.save_current("user://test_completion_camera.json")==OK)
	app.center=Vector3(32,0,33);app.angle=0.3;app.camera.size=30.5;app.update_camera();app.load_slot("user://test_completion_camera.json")
	assert(app.center==Vector3(25,0,31) and is_equal_approx(app.angle,0.8) and app.camera.size==24)
	app.sim.paused=true
	var before=app.data.snapshot();var transform=app.camera.global_transform;var size=app.camera.size
	for marker in app.preview.get_children():assert(marker.layers==1<<19 and marker.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	var image=await preload("res://game/photography/photo_capture.gd").image(app,app.camera,Vector2i(1920,1080))
	assert(image.get_size()==Vector2i(1920,1080));assert(app.camera.global_transform==transform and app.camera.size==size and app.data.snapshot()==before)
	image.save_png("res://snapshots/completion/photo_1080p.png")
	app.preferences.bind("rotate",KEY_G);var key=InputEventKey.new();key.keycode=KEY_G;key.pressed=true;app._unhandled_input(key);assert(app.placement_rotation==1)
	app.preferences.values.quality="low";app.apply_preferences(false);assert(not app.sun.shadow_enabled and app.view.detail_density==0.6)
	app.preferences.values.quality="medium";app.preferences.values.ui_scale=1.5;app.apply_preferences(false);assert(app.sun.shadow_enabled)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(1280,720)
	for i in range(6):await process_frame
	preload("res://game/settings/settings_panel.gd").build(app)
	for i in range(5):await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://snapshots/completion/settings_150.png")
	app.close_modal()
	for i in range(5):await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://snapshots/completion/hud_150.png")
	var rect=app.hud.bottom.get_global_rect();assert(rect.end.x<=1281 and rect.end.y<=721)
	app.hud.card.visible=true
	for i in range(3):await process_frame
	assert(app.hud.card.get_global_rect().end.y<=721)
	app.free();DirAccess.remove_absolute("user://test_completion_ui.cfg")
	for suffix in ["",".tmp",".bak",".bak2",".bak3"]:DirAccess.remove_absolute("user://test_completion_camera.json"+suffix)
	print("PASS independent 1080p photo, camera/settings reload, unchanged world, rebound input and 150% UI");quit()
