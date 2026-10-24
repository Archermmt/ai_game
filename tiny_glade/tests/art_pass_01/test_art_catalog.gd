extends GutTest
## The art layer changes generated views while preserving editable source and IDs.

var _materials: Dictionary = {}


func before_each() -> void:
	_materials = ArtMaterials.create()
	ArtFoliageCatalog.configure(_materials["foliage"].shader)


func after_each() -> void:
	ArtFoliageCatalog.configure(preload("res://features/vegetation/vegetation.gdshader"))
	_materials.clear()


func test_p0_nature_ids_are_supported_and_unknown_assets_are_not() -> void:
	for number: int in range(1, 10):
		assert_true(ArtFoliageCatalog.supports("NAT-%02d" % number))
	for unknown: String in ["", "NAT-00", "NAT-10", "NAT-99", "PROP-01"]:
		assert_false(ArtFoliageCatalog.supports(unknown))
		var missing: Node3D = _create(unknown, "unknown")
		assert_eq(missing.get_child_count(), 0)
		missing.free()


func test_hedge_reuses_three_shrubs_with_independent_source_identity() -> void:
	var hedge: Node3D = _create("NAT-07", "hedge-a")
	assert_eq(hedge.get_meta("object_id"), "hedge-a")
	assert_eq(hedge.get_meta("asset_id"), "NAT-07")
	assert_eq(hedge.get_child_count(), 3)
	var ids: Dictionary = {}
	for shrub: Node3D in hedge.get_children():
		assert_eq(shrub.get_meta("asset_id"), "NAT-06")
		ids[shrub.get_meta("object_id")] = true
		assert_gt(_meshes(shrub).size(), 0)
	assert_eq(ids.size(), 3)
	assert_false(ArtFoliageCatalog.PACKS.has("NAT-07"))
	assert_lt(hedge.get_child(0).position.x, hedge.get_child(2).position.x)
	hedge.free()


func test_all_imported_models_have_complete_finite_mesh_uv_and_wind_arrays() -> void:
	for asset: String in ArtFoliageCatalog.PACKS:
		var view: Node3D = _create(asset, "mesh-" + asset)
		var meshes: Array[MeshInstance3D] = _meshes(view)
		assert_gt(meshes.size(), 0, asset)
		for part: MeshInstance3D in meshes:
			_assert_complete_mesh(part.mesh, asset + "/" + part.name)
		view.free()


func test_tree_roots_are_fixed_and_both_lods_have_moving_canopies() -> void:
	for asset: String in ["NAT-01", "NAT-02", "NAT-03"]:
		var tree: Node3D = _create(asset, "wind-" + asset)
		assert_eq(tree.get_child_count(), 2, asset)
		for level: Node3D in tree.get_children():
			var bark_seen: bool = false
			var leaf_max: float = 0.0
			var bark_max: float = 0.0
			var opaque_wind_alpha: bool = true
			for part: MeshInstance3D in _meshes(level):
				var bark: bool = String(part.name).begins_with("bark")
				bark_seen = bark_seen or bark
				for surface: int in range(part.mesh.get_surface_count()):
					var colors: PackedColorArray = part.mesh.surface_get_arrays(surface)[
						Mesh.ARRAY_COLOR
					]
					for color: Color in colors:
						opaque_wind_alpha = opaque_wind_alpha and is_equal_approx(color.a, 1.0)
						if bark:
							bark_max = maxf(bark_max, color.r)
						else:
							leaf_max = maxf(leaf_max, color.r)
			assert_true(bark_seen, asset)
			assert_almost_eq(bark_max, 0.0, 0.0001, asset + " roots remain fixed")
			assert_gt(leaf_max, 0.25, asset + " canopy responds to wind")
			assert_true(opaque_wind_alpha, asset + " COLOR alpha is not texture opacity")
		tree.free()


func test_tree_lods_cover_the_37_meter_boundary_without_a_gap() -> void:
	for asset: String in ["NAT-01", "NAT-02", "NAT-03"]:
		var tree: Node3D = _create(asset, "lod-" + asset)
		for index: int in range(2):
			var parts: Array[MeshInstance3D] = _meshes(tree.get_child(index))
			assert_gt(parts.size(), 0)
			for part: MeshInstance3D in parts:
				assert_eq(part.visibility_range_begin, 0.0 if index == 0 else 37.0)
				assert_eq(part.visibility_range_end, 37.0 if index == 0 else 0.0)
				assert_gt(part.extra_cull_margin, 0.0)
		tree.free()


func test_configured_models_share_one_atlas_and_one_material_per_instance() -> void:
	for asset: String in ArtFoliageCatalog.PACKS:
		var view: Node3D = _create(asset, "paint-" + asset)
		var material_ids: Dictionary = {}
		for part: MeshInstance3D in _meshes(view):
			assert_true(part.material_override is ShaderMaterial, asset)
			var material: ShaderMaterial = part.material_override
			assert_eq(material.shader, _materials["foliage"].shader)
			assert_eq(material.get_shader_parameter("atlas"), ArtFoliageCatalog.ATLAS)
			material_ids[material.get_instance_id()] = true
		assert_eq(material_ids.size(), 1, asset + " shares paint between mesh parts/LODs")
		view.free()
	assert_eq(ArtFoliageCatalog.ATLAS.get_size(), Vector2(2048, 2048))


func test_descriptors_keep_complete_meshes_and_convert_wind_to_batched_materials() -> void:
	for asset: String in ["NAT-01", "NAT-02", "NAT-04", "NAT-08"]:
		var parts: Array[Dictionary] = ArtViewPlan.describe(
			asset, _materials["wood"], _materials["stone"]
		)
		assert_gt(parts.size(), 0, asset)
		for part: Dictionary in parts:
			assert_true(part["mesh"] is Mesh)
			assert_gt(part["mesh"].get_aabb().size.length(), 0.0)
			var part_transform: Transform3D = part["transform"]
			assert_true(part_transform.origin.is_finite())
			var material: ShaderMaterial = part["material"]
			assert_eq(material.shader, _materials["foliage"].shader)
			assert_eq(material.get_shader_parameter("atlas"), ArtFoliageCatalog.ATLAS)
			assert_true(material.get_shader_parameter("batched"))
		var manual: Node3D = _create(asset, "manual-after-describe")
		var manual_material: ShaderMaterial = _meshes(manual)[0].material_override
		var manual_batched: Variant = manual_material.get_shader_parameter("batched")
		assert_true(manual_batched == null or manual_batched == false)
		manual.free()


func test_batches_keep_source_poses_ids_phase_and_enclose_transformed_meshes() -> void:
	var items: Array = [
		{"id": "a", "asset_id": "NAT-01", "position": [9.0, 0.0, 9.0], "seed": "oak-a"},
		{"id": "b", "asset_id": "NAT-01", "position": [12.0, 0.0, 11.0], "seed": "oak-b"}
	]
	var poses: Dictionary = {
		"a": Transform3D(Basis(Vector3.UP, 0.4), Vector3(9, 0.2, 9)),
		"b": Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 1.2), Vector3(12, 0.8, 11))
	}
	var items_before: Array = items.duplicate(true)
	var poses_before: Dictionary = poses.duplicate(true)
	var parts: Array[Dictionary] = ArtViewPlan.describe(
		"NAT-01", _materials["wood"], _materials["stone"]
	)
	var batch: Node3D = ArtViewPlan.build_batch(
		items, poses, _materials["wood"], _materials["stone"], parts
	)
	add_child_autofree(batch)
	await get_tree().process_frame
	var native_renderer: bool = DisplayServer.get_name() != "headless"
	print("ART_BATCHES_RENDERER ", DisplayServer.get_name(), " GPU_READBACK ", native_renderer)
	if OS.get_environment("WINDHAVEN_ART_NATIVE_BATCHES_REQUIRED") == "1":
		assert_true(native_renderer, "Native batch verification cannot use the Dummy renderer")
	if native_renderer:
		await RenderingServer.frame_post_draw
	assert_eq_deep(items, items_before)
	assert_eq_deep(poses, poses_before)
	assert_eq_deep(batch.get_meta("ids"), ["a", "b"])
	assert_eq(batch.get_child_count(), parts.size())
	for part_index: int in range(parts.size()):
		var view: MultiMeshInstance3D = batch.get_child(part_index)
		var mm: MultiMesh = view.multimesh
		assert_eq(mm.instance_count, 2)
		assert_true(mm.use_custom_data)
		assert_eq(mm.mesh, parts[part_index]["mesh"])
		assert_eq(view.material_override, parts[part_index]["material"])
		var batch_material: ShaderMaterial = view.material_override
		assert_true(batch_material.get_shader_parameter("batched"))
		var bounds: AABB = mm.get_aabb() if native_renderer else AABB()
		if native_renderer:
			assert_true(bounds.position.is_finite() and bounds.size.is_finite())
			assert_gt(bounds.size.length(), 0.0)
		var cpu_union: AABB
		for index: int in range(items.size()):
			var expected: Transform3D = poses[items[index]["id"]]
			expected.origin -= batch.position
			expected *= parts[part_index]["transform"]
			# Dummy rendering discards instance buffers entirely. Validate actual imported
			# vertices and descriptors on CPU, then require renderer readback in native QA.
			var cpu_bounds: AABB = expected * mm.mesh.get_aabb()
			assert_true(cpu_bounds.position.is_finite() and cpu_bounds.size.is_finite())
			assert_gt(cpu_bounds.size.length(), 0.0)
			cpu_union = cpu_bounds if index == 0 else cpu_union.merge(cpu_bounds)
			var enclosed: bool = true
			for surface: int in range(mm.mesh.get_surface_count()):
				var vertices: PackedVector3Array = mm.mesh.surface_get_arrays(surface)[
					Mesh.ARRAY_VERTEX
				]
				for point: Vector3 in vertices:
					enclosed = enclosed and cpu_bounds.grow(0.001).has_point(expected * point)
			assert_true(enclosed, "Source affine pose encloses every imported vertex")
			if native_renderer:
				var actual: Transform3D = mm.get_instance_transform(index)
				assert_true(
					actual.is_equal_approx(expected), "preserves source pose and part transform"
				)
				assert_true(bounds.grow(0.01).encloses(actual * mm.mesh.get_aabb()))
				var custom: Color = mm.get_instance_custom_data(index)
				assert_true(is_finite(custom.r) and absf(custom.r) <= 1.0)
				assert_eq(custom.a, 1.0)
				assert_almost_eq(
					custom.r, float(String(items[index]["seed"]).hash() % 10000) / 10000, 0.0001
				)
		assert_gt(cpu_union.size.x, 3.0, "Both source placements contribute to the derived bounds")


func test_catalog_and_material_factory_are_deterministic_and_keep_source_files() -> void:
	var before: String = FileAccess.get_sha256("res://assets/nature/art_pass_01/tree_broadleaf.glb")
	var atlas_before: String = FileAccess.get_sha256(
		"res://assets/nature/art_pass_01/painted_forest_atlas.png"
	)
	var first: Node3D = _create("NAT-01", "same-source-id")
	var second: Node3D = _create("NAT-01", "same-source-id")
	assert_eq_deep(_geometry_signature(first), _geometry_signature(second))
	assert_eq(first.get_meta("object_id"), second.get_meta("object_id"))
	var first_material: ShaderMaterial = _meshes(first)[0].material_override
	var second_material: ShaderMaterial = _meshes(second)[0].material_override
	assert_eq(
		first_material.get_shader_parameter("phase"), second_material.get_shader_parameter("phase")
	)
	var more_materials: Dictionary = ArtMaterials.create()
	assert_eq(
		more_materials["terrain"].get_shader_parameter("grass_map"),
		_materials["terrain"].get_shader_parameter("grass_map")
	)
	assert_ne(more_materials["terrain"], _materials["terrain"])
	assert_eq(FileAccess.get_sha256("res://assets/nature/art_pass_01/tree_broadleaf.glb"), before)
	assert_eq(
		FileAccess.get_sha256("res://assets/nature/art_pass_01/painted_forest_atlas.png"),
		atlas_before
	)
	first.free()
	second.free()


func test_forest_curtain_is_derived_deterministic_geometry_without_source_edits() -> void:
	var source: Dictionary = ForestTemplate.create()
	var before: Dictionary = source.duplicate(true)
	var first: Node3D = ArtScenery.curtain(
		source, _materials["wood"], _materials["stone"], _materials["terrain"]
	)
	var second: Node3D = ArtScenery.curtain(
		source, _materials["wood"], _materials["stone"], _materials["terrain"]
	)
	assert_eq_deep(source, before)
	assert_eq_deep(_geometry_signature(first), _geometry_signature(second))
	var batches: Array[MultiMeshInstance3D] = _batches(first)
	assert_gt(batches.size(), 0)
	for view: MultiMeshInstance3D in batches:
		assert_gt(view.multimesh.instance_count, 0)
		assert_true(
			(
				(view.visibility_range_begin == 0.0 and view.visibility_range_end == 37.0)
				or (view.visibility_range_begin == 37.0 and view.visibility_range_end == 0.0)
			),
			"Spatial forest cells preserve the shared 37m high/low coverage"
		)
	first.free()
	second.free()


func test_pond_bank_is_deterministic_and_empty_pool_has_no_derived_objects() -> void:
	var source: Dictionary = ForestTemplate.create()
	var before: Dictionary = source.duplicate(true)
	var first: Node3D = ArtScenery.bank(source, _materials["wood"], _materials["stone"])
	var second: Node3D = ArtScenery.bank(source, _materials["wood"], _materials["stone"])
	assert_gt(_batches(first).size(), 0)
	assert_eq_deep(_geometry_signature(first), _geometry_signature(second))
	assert_eq_deep(source, before)
	first.free()
	second.free()
	source["pool"] = {}
	var empty_before: Dictionary = source.duplicate(true)
	var empty: Node3D = ArtScenery.bank(source, _materials["wood"], _materials["stone"])
	assert_eq(empty.get_child_count(), 0)
	assert_eq_deep(source, empty_before)
	empty.free()


func _create(asset: String, key: String) -> Node3D:
	return ArtFoliageCatalog.create(asset, key, _materials["wood"], _materials["stone"])


func _meshes(root: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		result.append(node as MeshInstance3D)
	return result


func _batches(root: Node) -> Array[MultiMeshInstance3D]:
	var result: Array[MultiMeshInstance3D] = []
	for node: Node in root.find_children("*", "MultiMeshInstance3D", true, false):
		result.append(node as MultiMeshInstance3D)
	return result


func _assert_complete_mesh(mesh: Mesh, context: String) -> void:
	assert_not_null(mesh, context)
	if mesh == null:
		return
	assert_gt(mesh.get_surface_count(), 0, context)
	var bounds: AABB = mesh.get_aabb()
	assert_true(bounds.position.is_finite() and bounds.size.is_finite(), context)
	assert_gt(bounds.size.length(), 0.0, context)
	for surface: int in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		assert_gt(vertices.size(), 2, context)
		assert_eq(normals.size(), vertices.size(), context)
		assert_eq(colors.size(), vertices.size(), context)
		assert_eq(uvs.size(), vertices.size(), context)
		assert_eq((indices.size() if not indices.is_empty() else vertices.size()) % 3, 0, context)
		var valid: bool = true
		for index: int in range(vertices.size()):
			valid = valid and vertices[index].is_finite() and normals[index].is_finite()
			valid = valid and normals[index].length_squared() > 0.1 and uvs[index].is_finite()
			valid = valid and uvs[index].x >= 0.0 and uvs[index].x <= 1.0
			valid = valid and uvs[index].y >= 0.0 and uvs[index].y <= 1.0
		for index: int in indices:
			valid = valid and index >= 0 and index < vertices.size()
		assert_true(valid, context + " indexed triangles, normals and atlas UVs remain valid")


func _geometry_signature(root: Node3D) -> Array:
	# Godot auto-generated node names have process counters; geometry and poses do not.
	var result: Array = [root.transform]
	if root is MeshInstance3D:
		var view: MeshInstance3D = root as MeshInstance3D
		for surface: int in range(view.mesh.get_surface_count()):
			result.append(view.mesh.surface_get_arrays(surface))
	if root is MultiMeshInstance3D:
		var view: MultiMeshInstance3D = root as MultiMeshInstance3D
		result.append([view.visibility_range_begin, view.visibility_range_end])
		for surface: int in range(view.multimesh.mesh.get_surface_count()):
			result.append(view.multimesh.mesh.surface_get_arrays(surface))
		result.append(view.multimesh.instance_count)
		if DisplayServer.get_name() != "headless":
			for index: int in range(view.multimesh.instance_count):
				result.append(view.multimesh.get_instance_transform(index))
				result.append(view.multimesh.get_instance_custom_data(index))
	for child: Node in root.get_children():
		if child is Node3D:
			result.append(_geometry_signature(child))
	return result
