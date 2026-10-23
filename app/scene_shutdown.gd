class_name SceneShutdown
extends RefCounted
## Keep the exit continuation independent of the scene being destroyed.


static func wait_wallclock(tree: SceneTree, duration_seconds: float) -> void:
	# SceneTreeTimer subtracts the current whole-frame delta, including time before
	# its creation. Audio-drain delays must start when voices actually stop.
	var deadline: int = Time.get_ticks_usec() + ceili(maxf(0.0, duration_seconds) * 1000000.0)
	while Time.get_ticks_usec() < deadline:
		await tree.process_frame


static func release_scene(scene: Node, after_release: Callable = Callable()) -> void:
	var tree: SceneTree = scene.get_tree()
	scene.queue_free()
	# The first frame drains scene deletion and worker joins; the second lets
	# deferred deliveries and render-resource cleanup run before engine teardown.
	await tree.process_frame
	await tree.process_frame
	if after_release.is_valid():
		after_release.call()
