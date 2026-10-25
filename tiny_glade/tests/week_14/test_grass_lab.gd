extends GutTest

const LAB: PackedScene = preload("res://app/painterly_grass_preview.tscn")

var lab: PainterlyGrassLab


func before_each() -> void:
	lab = LAB.instantiate()
	add_child(lab)
	var deadline: int = Time.get_ticks_msec() + 15000
	while not lab.loaded and not lab.failed and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	assert_true(lab.loaded, "Local derivative samples must actually load; no old-grass fallback")


func after_each() -> void:
	if is_instance_valid(lab):
		remove_child(lab)
		lab.free()
	for i: int in 4:
		await get_tree().process_frame


func test_imported_meshes_preserve_single_surface_budget_and_root_weights() -> void:
	assert_eq(lab.meshes.size(), 3)
	for mesh: Mesh in lab.meshes:
		assert_eq(mesh.get_surface_count(), 1)
		var arrays: Array = mesh.surface_get_arrays(0)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		assert_eq(indices.size(), 24)
		assert_eq(colors.size(), points.size())
		var roots: int = 0
		var tips: int = 0
		for i: int in points.size():
			assert_true(points[i].is_finite())
			if points[i].y < 0.00001:
				roots += 1
				assert_eq(colors[i].r, 0.0, "Ground roots must stay pinned")
			tips += int(colors[i].r > 0.95)
		assert_gt(roots, 0)
		assert_gt(tips, 0)


func test_imported_y_up_scale_and_origin_match_manifest() -> void:
	var text: String = FileAccess.get_file_as_string(
		"res://art_source/painterly_grass/manifest.json"
	)
	var manifest: Array = JSON.parse_string(text)
	for i: int in 3:
		var bounds: AABB = lab.meshes[i].get_aabb()
		var expected: Array = manifest[i]["dimensions_y_up"]
		assert_almost_eq(bounds.position.y, 0.0, 0.00001)
		for axis: int in 3:
			assert_almost_eq(bounds.size[axis], float(expected[axis]), 0.00001)
		if i < 2:
			assert_between(bounds.size.y, 0.4, 0.45)
		else:
			assert_lt(bounds.size.y, 0.05)


func test_coverage_has_real_transparent_and_brush_edge_pixels() -> void:
	var texture: Texture2D = lab.paint.get_shader_parameter("coverage")
	var image: Image = texture.get_image()
	if image.is_compressed():
		assert_eq(image.decompress(), OK)
	assert_eq(image.get_size(), Vector2i(2048, 2048))
	assert_true(image.has_mipmaps(), "Brush coverage needs mipmaps when the view rotates away")
	var empty: int = 0
	var solid: int = 0
	var brush: int = 0
	for y: int in range(0, 2048, 16):
		for x: int in range(0, 2048, 16):
			var alpha: float = image.get_pixel(x, y).a
			empty += int(alpha < 0.02)
			solid += int(alpha > 0.95)
			brush += int(alpha > 0.05 and alpha < 0.9)
	assert_gt(empty, 1000)
	assert_gt(solid, 100)
	assert_gt(brush, 100)


func test_batches_are_deterministic_and_share_only_per_lab_material() -> void:
	var a: MultiMeshInstance3D = PainterlyGrassSamples.batch(lab.meshes[0], lab.paint, 1)
	var b: MultiMeshInstance3D = PainterlyGrassSamples.batch(lab.meshes[0], lab.paint, 1)
	assert_eq(a.multimesh.buffer, b.multimesh.buffer)
	assert_same(a.material_override, b.material_override)
	assert_almost_eq(a.multimesh.get_instance_transform(0).origin.y, 0.0, 0.00001)
	var independent: ShaderMaterial = PainterlyGrassSamples.material(
		lab.paint.get_shader_parameter("coverage")
	)
	independent.set_shader_parameter("wind_strength", 0.0)
	assert_ne(lab.paint.get_shader_parameter("wind_strength"), 0.0)
	a.free()
	b.free()


func test_pause_resume_and_reduce_motion_are_independent_local_controls() -> void:
	lab.toggle_pause()
	var before: float = lab.elapsed
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(lab.elapsed, before)
	lab.toggle_pause()
	await get_tree().process_frame
	assert_gt(lab.elapsed, before)
	lab.toggle_orbit()
	lab.set_reduced_motion(true)
	assert_false(lab.rotating)
	assert_true(lab.rotate_button.disabled)
	assert_true(lab.paint.get_shader_parameter("reduce_motion"))
	assert_true(lab.old_paint.get_shader_parameter("reduce_motion"))


func test_light_modes_and_close_views_do_not_rebuild_geometry() -> void:
	var id_before: int = lab.meshes[0].get_instance_id()
	lab.set_light(1)
	assert_false(lab.sun.visible)
	lab.set_light(2)
	assert_true(lab.sun.visible)
	lab.set_view(1)
	assert_lt(lab.rig.distance, 10.0)
	assert_false(lab.headers[1].visible)
	assert_eq(lab.meshes[0].get_instance_id(), id_before)


func test_reset_restores_local_presentation_and_preview_has_no_save_service() -> void:
	lab.wind_slider.value = 0.95
	lab.toggle_pause()
	lab.motion_toggle.button_pressed = true
	lab.set_view(5)
	lab.reset()
	assert_false(lab.paused)
	assert_false(lab.reduced_motion)
	assert_false(lab.rotating)
	assert_almost_eq(lab.wind, 0.45, 0.0001)
	assert_eq(lab.light_picker.selected, 0)
	assert_eq(lab.view_picker.selected, 0)
	assert_true(lab.find_children("*", "SaveRepository", true, false).is_empty())
	assert_eq(lab.samples.find_children("*", "MultiMeshInstance3D", true, false).size(), 7)


func test_missing_derivatives_report_failure_without_substituting_old_grass() -> void:
	var missing: PainterlyGrassLab = LAB.instantiate()
	missing.sample_paths = ["res://not_a_real_grass_asset.glb"]
	add_child(missing)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(missing.failed)
	assert_false(missing.loaded)
	assert_true(missing.samples.find_children("*", "MultiMeshInstance3D", true, false).is_empty())
	remove_child(missing)
	missing.free()
