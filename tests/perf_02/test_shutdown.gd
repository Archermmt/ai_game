extends GutTest


class ClosingMeadow:
	extends MeadowRenderer
	var events: Array[String] = []

	func _exit_tree() -> void:
		events.append("meadow_closed")
		super._exit_tree()


class ClosingQueue:
	extends RebuildQueue
	var events: Array[String] = []

	func _exit_tree() -> void:
		events.append("queue_closed")
		super._exit_tree()


func test_exit_continuation_runs_after_two_frames_and_scene_children_are_released() -> void:
	var scene: Node3D = Node3D.new()
	var child: MeshInstance3D = MeshInstance3D.new()
	child.mesh = BoxMesh.new()
	scene.add_child(child)
	add_child(scene)
	var scene_ref: WeakRef = weakref(scene)
	var child_ref: WeakRef = weakref(child)
	var callbacks: Array[int] = [0]
	SceneShutdown.release_scene(
		scene,
		func() -> void:
			callbacks[0] += 1
			assert_null(scene_ref.get_ref())
			assert_null(child_ref.get_ref())
	)
	assert_true(scene.is_queued_for_deletion())
	assert_eq(callbacks[0], 0)
	await get_tree().process_frame
	assert_eq(callbacks[0], 0, "One frame is insufficient to run the exit continuation")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(callbacks[0], 1)
	assert_false(is_instance_valid(scene))
	assert_false(is_instance_valid(child))


func test_active_workers_close_before_continuation_and_cannot_publish_after_release() -> void:
	var scene: Node3D = Node3D.new()
	var events: Array[String] = []
	var meadow: ClosingMeadow = ClosingMeadow.new()
	meadow.events = events
	scene.add_child(meadow)
	var queue: ClosingQueue = ClosingQueue.new()
	queue.events = events
	scene.add_child(queue)
	add_child(scene)
	queue.evaluator = func(_snapshot: Dictionary) -> Dictionary:
		# Finish while scene deletion joins this worker; delivery is still deferred.
		OS.delay_msec(30)
		return {"ok": true}
	queue.batch_prepared.connect(
		func(_token: int, _payload: Dictionary, _committed: bool) -> void:
			events.append("published")
	)
	var source: Dictionary = WorldDocument.new("perf02-shutdown").snapshot()
	meadow.request(source)
	assert_gt(queue.request(source, Rect2(-32, -32, 64, 64), true), 0)
	assert_true(meadow.is_busy())
	assert_true(queue.is_busy())
	var scene_ref: WeakRef = weakref(scene)
	var meadow_ref: WeakRef = weakref(meadow)
	var queue_ref: WeakRef = weakref(queue)
	var callbacks: Array[int] = [0]
	SceneShutdown.release_scene(
		scene,
		func() -> void:
			callbacks[0] += 1
			assert_null(scene_ref.get_ref())
			assert_null(meadow_ref.get_ref())
			assert_null(queue_ref.get_ref())
			assert_true("meadow_closed" in events)
			assert_true("queue_closed" in events)
			assert_false("published" in events)
	)
	for index: int in range(4):
		await get_tree().process_frame
	assert_eq(callbacks[0], 1)
	assert_false("published" in events, "Late worker deliveries cannot publish a destroyed world")
