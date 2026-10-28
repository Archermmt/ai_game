extends GutTest


func _record(
	mesh: Mesh, origin: Vector3, kind: String = "nature", begin: float = 0.0, end: float = 0.0
) -> Dictionary:
	return {
		"baked_mesh": mesh,
		"pose": Transform3D(Basis.IDENTITY, origin),
		"kind": kind,
		"begin": begin,
		"end": end
	}


func _renderer(records: Array[Dictionary]) -> BlanketSnowRenderer:
	var renderer: BlanketSnowRenderer = BlanketSnowRenderer.new()
	renderer._material = StandardMaterial3D.new()
	renderer._records = records
	renderer.cap_count = records.size()
	renderer._cover = 0.98
	renderer._rebuild_views()
	return renderer


func _dispose(renderer: BlanketSnowRenderer) -> void:
	renderer.shutdown()
	renderer.free()


func test_batch_preserves_instance_meshes_poses_layers_and_source() -> void:
	var mesh: Mesh = BoxMesh.new()
	var records: Array[Dictionary] = [_record(mesh, Vector3.ONE), _record(mesh, Vector3(2, 1, 2))]
	var renderer: BlanketSnowRenderer = _renderer(records)
	assert_eq(renderer._views.size(), 1)
	assert_eq(renderer.cap_count, 2)
	var batch: MultiMeshInstance3D = renderer._views[0] as MultiMeshInstance3D
	assert_not_null(batch)
	assert_eq(batch.multimesh.mesh, mesh)
	assert_eq(batch.multimesh.instance_count, 2)
	assert_eq(batch.layers, 1 | PondReflections.REFLECTION_LAYER)
	assert_eq(mesh.get_aabb().size, Vector3.ONE)
	_dispose(renderer)


func test_roofs_and_distance_limited_caps_keep_individual_visibility_origins() -> void:
	var mesh: Mesh = BoxMesh.new()
	var records: Array[Dictionary] = [
		_record(mesh, Vector3.ONE, "roof"),
		_record(mesh, Vector3(2, 1, 2), "nature", 8, 30),
		_record(mesh, Vector3(3, 1, 3), "nature", 8, 30)
	]
	var renderer: BlanketSnowRenderer = _renderer(records)
	assert_eq(renderer._views.size(), 3)
	for index: int in records.size():
		var view: GeometryInstance3D = renderer._views[index]
		assert_true(view is MeshInstance3D)
		assert_eq(view.transform, records[index]["pose"])
		assert_eq(view.visibility_range_begin, records[index]["begin"])
		assert_eq(view.visibility_range_end, records[index]["end"])
	_dispose(renderer)


func test_spatial_groups_do_not_join_distant_caps_or_different_meshes() -> void:
	var mesh: Mesh = BoxMesh.new()
	var other: Mesh = SphereMesh.new()
	var renderer: BlanketSnowRenderer = _renderer(
		[
			_record(mesh, Vector3.ONE),
			_record(mesh, Vector3(10, 1, 1)),
			_record(other, Vector3(2, 1, 2))
		]
	)
	assert_eq(renderer._views.size(), 3)
	_dispose(renderer)


func test_melt_restores_original_objects_and_hash_fade_without_rebaking() -> void:
	var mesh: Mesh = BoxMesh.new()
	var renderer: BlanketSnowRenderer = _renderer(
		[_record(mesh, Vector3.ONE), _record(mesh, Vector3(2, 1, 2))]
	)
	renderer.sync(0.899)
	assert_eq(renderer._views.size(), 2)
	assert_eq(renderer._material.transparency, BaseMaterial3D.TRANSPARENCY_ALPHA_HASH)
	assert_lt(renderer._material.albedo_color.a, 1.0)
	renderer.sync(0.98)
	assert_eq(renderer._views.size(), 1)
	assert_eq(renderer._material.transparency, BaseMaterial3D.TRANSPARENCY_DISABLED)
	assert_eq(renderer._material.albedo_color.a, 1.0)
	assert_eq(renderer.baked_count, 0)
	_dispose(renderer)


func test_refresh_drops_old_cap_records_and_generated_views() -> void:
	var renderer: BlanketSnowRenderer = _renderer([_record(BoxMesh.new(), Vector3.ONE)])
	renderer.request(WorldDocument.new().snapshot())
	assert_eq(renderer.cap_count, 0)
	assert_true(renderer._views.is_empty())
	assert_true(renderer._records.is_empty())
	assert_true(renderer._dirty)
	_dispose(renderer)


func test_buried_floor_culling_retains_density_and_thaw_restores_exact_buffer() -> void:
	var grass: ProductionGrassRenderer = ProductionGrassRenderer.new()
	for kind: int in [0, 3]:
		var view: MultiMeshInstance3D = MultiMeshInstance3D.new()
		view.multimesh = MultiMesh.new()
		view.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		view.multimesh.mesh = BoxMesh.new()
		view.multimesh.instance_count = 10
		view.set_meta("grass_layer", kind)
		grass.add_child(view)
		grass.batches.append(view)
	grass.set_density(0.45)
	var buffer: PackedFloat32Array = grass.batches[1].multimesh.buffer.duplicate()
	grass.set_snow_cover(0.6499)
	assert_true(grass.batches[1].visible)
	grass.set_snow_cover(0.65)
	assert_false(grass.batches[1].visible)
	assert_true(grass.batches[0].visible)
	grass.set_density(1.0)
	assert_false(grass.batches[1].visible)
	assert_eq(grass.batches[1].multimesh.visible_instance_count, 10)
	grass.set_snow_cover(0.64)
	assert_true(grass.batches[1].visible)
	assert_eq(grass.batches[1].multimesh.buffer, buffer)
	grass.set_density(0.0)
	grass.set_snow_cover(0.98)
	grass.set_snow_cover(0.0)
	assert_false(grass.batches[1].visible)
	grass.free()
