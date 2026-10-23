class_name SceneShutdown
extends RefCounted
## Keep the exit continuation independent of the scene being destroyed.


static func release_scene(scene: Node, after_release: Callable = Callable()) -> void:
	var tree: SceneTree = scene.get_tree()
	scene.queue_free()
	# The first frame drains scene deletion and worker joins; the second lets
	# deferred deliveries and render-resource cleanup run before engine teardown.
	await tree.process_frame
	await tree.process_frame
	if after_release.is_valid():
		after_release.call()
