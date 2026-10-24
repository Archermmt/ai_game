extends GutTest


func _data(versions: Dictionary, height: float = 0.0) -> Dictionary:
	var data: Dictionary = {
		"chunks": {}, "buffers": {}, "versions": versions, "count": 0, "worker_ms": 1.0
	}
	for key: Vector2i in versions:
		var items: Array = [
			{
				"p": Vector3(key.x * 8 + 1, height, key.y * 8 + 2),
				"yaw": 0.4,
				"scale": 1.2,
				"phase": 0.25,
				"rank": 0.75
			}
		]
		data["chunks"][key] = items
		data["buffers"][key] = MeadowData.chunk_buffer(items, key)
		data["count"] += items.size()
	return data


func _renderer() -> MeadowRenderer:
	var renderer: MeadowRenderer = MeadowRenderer.new()
	add_child_autofree(renderer)
	renderer.set_process(false)
	return renderer


func _publish(renderer: MeadowRenderer, data: Dictionary) -> void:
	renderer._deliver(renderer._token, data)
	for i: int in range(100):
		if renderer._data.is_empty():
			break
		renderer._process(0)
	assert_false(renderer.is_busy())


func test_packed_buffers_match_legacy_transform_and_custom_data() -> void:
	for key: Vector2i in [Vector2i(-3, -2), Vector2i.ZERO, Vector2i(2, 1)]:
		var items: Array = []
		for yaw: float in [-PI, -0.8, 0.0, PI * 0.5, TAU]:
			items.append(
				{"p": Vector3(-1, 3.5, 12), "yaw": yaw, "scale": 0.73, "phase": 0.37, "rank": 0.89}
			)
		var buffer: PackedFloat32Array = MeadowData.chunk_buffer(items, key)
		assert_eq(buffer.size(), items.size() * 16)
		for i: int in range(items.size()):
			var t: Transform3D = Transform3D(
				Basis(Vector3.UP, items[i]["yaw"]).scaled(Vector3.ONE * 0.73),
				items[i]["p"] - Vector3(key.x * 8 + 4, 0, key.y * 8 + 4)
			)
			var decoded: Transform3D = Transform3D(
				Basis(
					Vector3(buffer[i * 16], buffer[i * 16 + 4], buffer[i * 16 + 8]),
					Vector3(buffer[i * 16 + 1], buffer[i * 16 + 5], buffer[i * 16 + 9]),
					Vector3(buffer[i * 16 + 2], buffer[i * 16 + 6], buffer[i * 16 + 10])
				),
				Vector3(buffer[i * 16 + 3], buffer[i * 16 + 7], buffer[i * 16 + 11])
			)
			assert_true(decoded.is_equal_approx(t))
			assert_almost_eq(buffer[i * 16 + 12], 0.37, 0.000001)
			assert_almost_eq(buffer[i * 16 + 13], 0.89, 0.000001)
			assert_eq(buffer[i * 16 + 14], 0.0)
			assert_eq(buffer[i * 16 + 15], 1.0)


func test_local_publication_reuses_unchanged_nodes_and_keeps_density() -> void:
	var renderer: MeadowRenderer = _renderer()
	renderer.set_density(1.0)
	var versions: Dictionary = {Vector2i.ZERO: [1, "flat"], Vector2i.ONE: [1, "flat"]}
	_publish(renderer, _data(versions))
	var original: Dictionary = renderer._published_chunks.duplicate()
	versions = {Vector2i.ZERO: [1, "raised"], Vector2i.ONE: [1, "flat"]}
	_publish(renderer, _data(versions, 0.2))
	assert_ne(renderer._published_chunks[Vector2i.ZERO], original[Vector2i.ZERO])
	assert_eq(renderer._published_chunks[Vector2i.ONE], original[Vector2i.ONE])
	assert_eq(renderer.rebuilt_chunks, 1)
	assert_eq(renderer.reused_chunks, 1)
	assert_eq(renderer.visible_count(), 2)
	assert_eq(renderer.total, 2)


func test_cancelling_staging_never_frees_retained_live_chunks() -> void:
	var renderer: MeadowRenderer = _renderer()
	_publish(renderer, _data({Vector2i.ZERO: [1, "flat"]}))
	var retained: MultiMeshInstance3D = renderer.batches[0]
	renderer._staging.append(retained)
	var detached: MultiMeshInstance3D = MultiMeshInstance3D.new()
	renderer._staging.append(detached)
	renderer._clear_staging()
	assert_true(is_instance_valid(retained))
	assert_eq(retained.get_parent(), renderer)
	assert_false(is_instance_valid(detached))
	assert_eq(renderer.batches.size(), 1)


func test_latest_generation_removes_old_chunks_and_rebuilds_same_terrain() -> void:
	var renderer: MeadowRenderer = _renderer()
	_publish(renderer, _data({Vector2i.ZERO: [1, "flat"], Vector2i.ONE: [1, "flat"]}))
	var previous: MultiMeshInstance3D = renderer._published_chunks[Vector2i.ONE]
	_publish(renderer, _data({Vector2i.ONE: [2, "flat"]}))
	assert_false(renderer._published_chunks.has(Vector2i.ZERO))
	assert_ne(renderer._published_chunks[Vector2i.ONE], previous)
	assert_eq(renderer.rebuilt_chunks, 1)
	assert_eq(renderer.reused_chunks, 0)
	assert_eq(renderer.total, 1)


func test_empty_result_clears_previous_grass_instead_of_claiming_idle_early() -> void:
	var renderer: MeadowRenderer = _renderer()
	_publish(renderer, _data({Vector2i.ZERO: [1, "flat"]}))
	renderer._deliver(renderer._token, _data({}))
	assert_true(renderer.is_busy())
	renderer._process(0)
	assert_false(renderer.is_busy())
	assert_eq(renderer.total, 0)
	assert_eq(renderer.visible_count(), 0)
	assert_true(renderer.batches.is_empty())
	assert_true(renderer._published_chunks.is_empty())
	assert_true(renderer._published_versions.is_empty())


func test_density_zero_and_reenable_use_latest_pending_source() -> void:
	var renderer: MeadowRenderer = _renderer()
	renderer.set_density(0.0)
	var source: Dictionary = ArtLayout.empty()
	renderer.request(source)
	assert_false(renderer.is_busy())
	assert_false(renderer._pending.is_empty())
	renderer.set_density(1.0)
	assert_true(renderer.is_busy())
	var timeout: int = Time.get_ticks_msec() + 15000
	while renderer.is_busy() and Time.get_ticks_msec() < timeout:
		renderer._process(0)
		await get_tree().process_frame
	assert_false(renderer.is_busy())
	assert_gt(renderer.visible_count(), 30000)
	assert_eq(renderer.visible_count(), renderer.total)
	renderer.set_density(0.0)
	assert_eq(renderer.visible_count(), 0)


func test_worker_versions_survive_cancelled_publication_and_undo() -> void:
	var source: Dictionary = ArtLayout.create()
	var cache: Dictionary = {}
	var initial: Dictionary = MeadowData.generate_cached(source, cache)
	var original_buffer: PackedFloat32Array = initial["buffers"][Vector2i(1, 1)].duplicate()
	var changed: Dictionary = TerrainField.brush(source, Vector2(12, 8), 0.1)
	var skipped: Dictionary = MeadowData.generate_cached(changed, cache)
	var latest: Dictionary = MeadowData.generate_cached(changed, cache)
	assert_eq_deep(skipped["versions"], latest["versions"])
	assert_eq(latest["updated_chunks"], 0)
	assert_ne(initial["versions"], latest["versions"])
	assert_eq(initial["buffers"][Vector2i(1, 1)], original_buffer)
	var undone: Dictionary = MeadowData.generate_cached(source, cache)
	assert_eq_deep(undone["chunks"], initial["chunks"])
	assert_eq_deep(undone["versions"], initial["versions"])
	for key: Vector2i in initial["buffers"]:
		assert_eq(undone["buffers"][key], initial["buffers"][key])


func test_roof_wall_height_and_non_clearance_edits_reuse_grass_distribution() -> void:
	var source: Dictionary = ArtLayout.create()
	var cache: Dictionary = {}
	var initial: Dictionary = MeadowData.generate_cached(source, cache)
	var changed: Dictionary = source.duplicate(true)
	changed["buildings"][0]["roof_rise"] = 1.4
	changed["buildings"][0]["size"][1] += 0.2
	for opening: Dictionary in changed["buildings"][0]["openings"]:
		if opening["height"] < 1.8:
			opening["width"] *= 0.9
			opening["sill"] += 0.1
	for item: Dictionary in changed["instances"]:
		if String(item["asset_id"]).begins_with("PROP-"):
			item["position"][1] += 0.2
			item["yaw"] += 0.1
		else:
			item["position"][0] += 0.1
	var actual: Dictionary = MeadowData.generate_cached(changed, cache)
	assert_eq(actual["updated_chunks"], 0)
	assert_eq_deep(actual["versions"], initial["versions"])
	assert_eq_deep(actual["chunks"], MeadowData.generate(changed)["chunks"])
	assert_eq_deep(actual["buffers"], initial["buffers"])


func test_footprint_entrance_and_prop_clearance_changes_invalidate_distribution() -> void:
	var source: Dictionary = ArtLayout.create()
	var cache: Dictionary = {}
	MeadowData.generate_cached(source, cache)
	for kind: String in ["footprint", "entrance", "prop"]:
		var changed: Dictionary = source.duplicate(true)
		if kind == "footprint":
			changed["buildings"][0]["size"][0] += 0.25
		elif kind == "entrance":
			for opening: Dictionary in changed["buildings"][0]["openings"]:
				if opening["height"] >= 1.8 and opening.get("sill", 0) <= 0.1:
					opening["center"] += 0.03
		else:
			for item: Dictionary in changed["instances"]:
				if String(item["asset_id"]).begins_with("PROP-"):
					item["position"][0] += 0.1
					item["scale"] *= 1.01
		var actual: Dictionary = MeadowData.generate_cached(changed, cache)
		assert_gt(actual["updated_chunks"], 0)
		assert_eq_deep(actual["chunks"], MeadowData.generate(changed)["chunks"])


func test_entrance_height_and_sill_thresholds_keep_exact_clearance() -> void:
	var source: Dictionary = ArtLayout.create()
	var cache: Dictionary = {}
	for sill: float in [0.1, 0.100001]:
		for height: float in [1.799999, 1.8]:
			var changed: Dictionary = source.duplicate(true)
			var opening: Dictionary = changed["buildings"][0]["openings"][0]
			opening["height"] = height
			opening["sill"] = sill
			var actual: Dictionary = MeadowData.generate_cached(changed, cache)
			assert_eq_deep(actual["chunks"], MeadowData.generate(changed)["chunks"])
