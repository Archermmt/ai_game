extends SceneTree

var playground: Node3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	playground = load("res://app/garden_root.tscn").instantiate()
	playground.qa_mode = true
	root.add_child(playground)
	var started: int = Time.get_ticks_msec()
	while playground.meadow.is_busy() and Time.get_ticks_msec() - started < 15000:
		await process_frame
	playground._preference_changed("ui_scale", 1.5)
	playground.hud.open_group("water")
	playground.hud.set_status("bridge_missing_pond")
	for i: int in range(10):
		await process_frame
	await RenderingServer.frame_post_draw
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var target: String = args[-1]
	root.get_texture().get_image().save_png(target + ".png")
	var file: FileAccess = FileAccess.open(target + ".json", FileAccess.WRITE)
	file.store_string(
		JSON.stringify(
			{
				"context_visible": playground.hud.context.is_visible_in_tree(),
				"legacy_status_visible": playground.hud.status_label.is_visible_in_tree(),
				"breadcrumb_visible": playground.hud.breadcrumbs.is_visible_in_tree(),
				"context_status_visible":
				(
					playground.hud.get("context_status") != null
					and playground.hud.context_status.is_visible_in_tree()
				),
				"source_revision": playground.document.state["revision"]
			},
			"\t"
		)
	)
	file.close()
	playground.queue_free()
	for i: int in range(5):
		await process_frame
	quit()
