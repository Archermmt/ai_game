extends GutTest


func _world() -> Dictionary:
	var world: Dictionary = WorldDocument.new("w06-cache").snapshot()
	WorldDocument.allocate_building(world, Vector3(-6, 0, -6), Vector3(5, 3, 5))
	PathGeometry.allocate(world, [[-6, 0, -2], [-6, 0, 6]])
	world = TerrainField.pond(world, Vector2(9, -9), 2)
	GardenStructures.allocate(world, "bridge", Vector2(9, -11.5), Vector2(9, -6.5))
	FenceGeometry.allocate(world, [[-12, 0, 10], [-8, 0, 10]])
	var item: Dictionary = InstanceEdits.allocate(world, Vector3(14, 0, 14))
	item["asset_id"] = "PROP-05"
	return world


func test_cold_local_generation_matches_full_reference_geometry() -> void:
	var world: Dictionary = _world()
	var local: Dictionary = LocalRebuild.evaluate(world, {})
	var full: Dictionary = WorldRebuild.evaluate(world)
	for key: String in [
		"building_arrays",
		"terrain_arrays",
		"path_arrays",
		"fence_arrays",
		"water_arrays",
		"structures"
	]:
		assert_eq(local[key], full[key], key)
	assert_eq(local["supports"][0]["foundation"], full["supports"][0]["foundation"])


func test_identical_snapshot_reuses_all_units() -> void:
	var cache: Dictionary = {}
	LocalRebuild.evaluate(_world(), cache)
	var result: Dictionary = LocalRebuild.evaluate(_world(), cache)
	assert_true(result["generated"].is_empty())
	assert_eq(result["terrain_rebuilt"], 0)
	assert_gt(result["reused"].size(), 64)


func test_far_terrain_edit_rebuilds_halo_not_buildings_path_or_water() -> void:
	var cache: Dictionary = {}
	var world: Dictionary = _world()
	LocalRebuild.evaluate(world, cache)
	world = TerrainEdits.stroke(world, Vector2(18, -18), "raise")
	var result: Dictionary = LocalRebuild.evaluate(world, cache)
	assert_gt(result["terrain_rebuilt"], 0)
	assert_lt(result["terrain_rebuilt"], 8)
	for key: String in result["generated"]:
		assert_true(key.begins_with("terrain:"), key)
	assert_eq(result["terrain_arrays"], WorldRebuild.evaluate(world)["terrain_arrays"])


func test_environment_change_does_not_regenerate_geometry_or_poses() -> void:
	var cache: Dictionary = {}
	var world: Dictionary = _world()
	LocalRebuild.evaluate(world, cache)
	world["environment"]["dusk"] = true
	world["environment"]["wind_strength"] = 0
	assert_true(LocalRebuild.evaluate(world, cache)["generated"].is_empty())


func test_instance_edit_changes_own_pose_without_geometry_rebuild() -> void:
	var cache: Dictionary = {}
	var world: Dictionary = _world()
	LocalRebuild.evaluate(world, cache)
	world["instances"][0]["position"][0] += 1
	var result: Dictionary = LocalRebuild.evaluate(world, cache)
	assert_eq(result["generated"], ["instance:" + world["instances"][0]["id"]])


func test_parent_support_change_invalidates_child_pose() -> void:
	var cache: Dictionary = {}
	var world: Dictionary = _world()
	var parent: Dictionary = world["instances"][0]
	var child: Dictionary = InstanceEdits.allocate(world, Vector3(14, 0, 14))
	child["asset_id"] = "PROP-07"
	child["support_id"] = parent["id"]
	var before: Dictionary = LocalRebuild.evaluate(world, cache)
	parent["scale"] = 1.5
	var after: Dictionary = LocalRebuild.evaluate(world, cache)
	assert_has(after["generated"], "instance:" + child["id"])
	assert_gt(after["poses"][child["id"]].origin.y, before["poses"][child["id"]].origin.y)


func test_deleted_objects_pruned_from_pure_cache() -> void:
	var cache: Dictionary = {}
	var world: Dictionary = _world()
	LocalRebuild.evaluate(world, cache)
	var id_value: String = world["instances"][0]["id"]
	world["instances"] = []
	LocalRebuild.evaluate(world, cache)
	assert_false(cache.has("instance:" + id_value))


func test_dirty_regions_include_old_and_new_locations_plus_terrain() -> void:
	var before: Dictionary = _world()
	var after: Dictionary = before.duplicate(true)
	after["instances"][0]["position"][0] -= 5
	after = TerrainEdits.stroke(after, Vector2(18, 18), "raise")
	var changes: Dictionary = DirtyGraph.changed(before, after)
	assert_has(changes["ids"], before["instances"][0]["id"])
	assert_true(changes["regions"].any(func(r: Rect2) -> bool: return r.has_point(Vector2(14, 14))))
	assert_true(changes["regions"].any(func(r: Rect2) -> bool: return r.has_point(Vector2(9, 14))))
	assert_true(changes["regions"].any(func(r: Rect2) -> bool: return r.has_point(Vector2(18, 18))))


func test_worker_and_sync_caches_are_independent() -> void:
	var worker: Dictionary = {}
	var sync: Dictionary = {}
	var world: Dictionary = _world()
	LocalRebuild.evaluate(world, worker)
	assert_true(sync.is_empty())
	var old_keys: Array = worker.keys()
	LocalRebuild.evaluate(TerrainEdits.stroke(world, Vector2(18, 18), "raise"), sync)
	assert_eq(worker.keys(), old_keys)
	assert_true(LocalRebuild.evaluate(world, worker)["generated"].is_empty())


func test_staged_publication_requires_matching_reserved_source() -> void:
	var doc: WorldDocument = WorldDocument.new()
	var edit: EditSession = EditSession.new(doc)
	var candidate: Dictionary = doc.snapshot()
	candidate["environment"]["dusk"] = true
	assert_true(edit.reserve_commit(candidate, "light")["ok"])
	assert_false(edit.finish_prepared({"ok": true, "source": doc.snapshot()})["ok"])
	assert_false(doc.state["environment"]["dusk"])
	assert_eq(edit.history_count(), 0)
	edit.dispose()


func test_staged_commit_records_one_history_and_undo_redo() -> void:
	var doc: WorldDocument = WorldDocument.new()
	var edit: EditSession = EditSession.new(doc)
	var candidate: Dictionary = doc.snapshot()
	candidate["environment"]["dusk"] = true
	edit.reserve_commit(candidate, "light")
	assert_true(edit.finish_prepared({"ok": true, "source": candidate})["ok"])
	assert_eq(edit.history_count(), 1)
	assert_true(edit.request_undo()["ok"])
	assert_false(doc.state["environment"]["dusk"])
	assert_true(edit.request_redo()["ok"])
	assert_true(doc.state["environment"]["dusk"])
	edit.dispose()


func test_cancel_reserved_staged_result_cannot_publish() -> void:
	var doc: WorldDocument = WorldDocument.new()
	var edit: EditSession = EditSession.new(doc)
	var candidate: Dictionary = doc.snapshot()
	candidate["environment"]["dusk"] = true
	edit.reserve_commit(candidate, "light")
	edit.cancel_gesture()
	assert_false(edit.finish_prepared({"ok": true, "source": candidate})["ok"])
	assert_eq(edit.history_count(), 0)
	assert_false(doc.state["environment"]["dusk"])
	edit.dispose()


func test_resource_stage_spreads_jobs_and_keeps_detached_nodes_invisible() -> void:
	var stage: ResourceStage = ResourceStage.new()
	add_child_autofree(stage)
	stage.budget_usec = 1
	var counter: Array[int] = [0]
	var jobs: Array[Callable] = []
	for i: int in range(5):
		jobs.append(func() -> void: counter[0] += 1)
	stage.begin(8, jobs, {"ok": true})
	stage.set_process(false)
	stage._process(0)
	assert_lt(counter[0], 5)
	while stage.is_busy():
		stage._process(0)
	assert_eq(counter[0], 5)
	assert_gt(stage.slices_ms.size(), 1)


func test_cancel_stage_destroys_only_unpublished_nodes() -> void:
	var stage: ResourceStage = ResourceStage.new()
	add_child_autofree(stage)
	var detached: Node3D = Node3D.new()
	stage.own(detached)
	stage.cancel()
	assert_false(is_instance_valid(detached))


func test_rebuild_queue_commit_preparation_is_an_input_barrier() -> void:
	var queue: RebuildQueue = RebuildQueue.new()
	add_child_autofree(queue)
	queue.consumer_busy = true
	queue.consumer_locked = true
	assert_true(queue.is_busy())
	assert_eq(queue.request(_world(), Rect2(), false), -1)
	queue.invalidate()
	assert_false(queue.consumer_locked)
	assert_false(queue.is_busy())
