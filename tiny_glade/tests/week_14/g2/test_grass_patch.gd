extends GutTest

const PATCH: PackedScene = preload("res://app/painterly_grass_patch.tscn")
var patch: PainterlyGrassPatch
var source: Dictionary
var history_version: int


func before_all() -> void:
	patch = PATCH.instantiate()
	assert_true(patch.qa_mode, "F6 must isolate preferences before inherited ready")
	add_child(patch)
	var deadline: int = Time.get_ticks_msec() + 40000
	while not patch.patch_ready and not patch.patch_failed and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	assert_true(patch.patch_ready, "G2 must load real derivatives into the existing garden")
	source = patch.document.snapshot()
	history_version = patch.session._history.get_version()


func after_all() -> void:
	patch.seasonal_music.shutdown()
	patch.soundscape.shutdown()
	await SceneShutdown.wait_wallclock(get_tree(), 0.4)
	await SceneShutdown.release_scene(patch)
	for i: int in 8:
		await get_tree().process_frame


func test_scattering_is_deterministic_and_default_density_is_recalibrated() -> void:
	var a: Dictionary = PainterlyGrassPatchData.generate(source)
	assert_eq(a["groups"], patch.patch_data["groups"])
	var sparse: Dictionary = PainterlyGrassPatchData.generate(source, 0.15)
	var dense: Dictionary = PainterlyGrassPatchData.generate(source, 0.8)
	var count: int = 0
	for kind: int in 3:
		assert_lte(sparse["groups"][kind].size(), a["groups"][kind].size())
		assert_lte(a["groups"][kind].size(), dense["groups"][kind].size())
		count += a["groups"][kind].size()
	assert_gt(count, 50)
	assert_lt(count, a["old_rank_selected"])
	assert_eq(patch.document.snapshot(), source)


func test_full_mesh_footprints_and_wind_envelopes_stay_in_legal_region() -> void:
	var obstacles: Dictionary = MeadowData._obstacles(source)
	for kind: int in 3:
		var points: PackedVector3Array = patch.patch_meshes[kind].surface_get_arrays(0)[
			Mesh.ARRAY_VERTEX
		]
		for item: Dictionary in patch.patch_data["groups"][kind]:
			var pose: Transform3D = item["pose"]
			var center: Vector2 = Vector2(pose.origin.x, pose.origin.z)
			assert_true(
				PainterlyGrassPatchData.envelope_clear(center, item["radius"], obstacles, source)
			)
			for point: Vector3 in points:
				var offset: Vector3 = pose.basis * point
				var wind_margin: float = 0.061 if kind < 2 else 0.005
				assert_lte(
					Vector2(offset.x, offset.z).length() + wind_margin, float(item["radius"])
				)


func test_envelope_rejects_segment_circle_rect_and_pool_overlap_not_just_centers() -> void:
	var point: Vector2 = Vector2(4, 6)
	var examples: Array[Dictionary] = [
		{"kind": "segment", "a": Vector2(3, 6.3), "b": Vector2(5, 6.3), "radius": 0.1},
		{"kind": "circle", "center": Vector2(4, 6.3), "radius": 0.1},
		{"kind": "rect", "bounds": Rect2(3.9, 6.3, 0.2, 0.2)}
	]
	var empty: Dictionary = source.duplicate(true)
	empty["instances"] = []
	empty["pool"] = {}
	for item: Dictionary in examples:
		var cells: Dictionary = {Vector2i(0, 0): [item]}
		assert_true(PainterlyGrassPatchData.envelope_clear(point, 0.05, cells, empty))
		assert_false(PainterlyGrassPatchData.envelope_clear(point, 0.4, cells, empty))
	empty["pool"] = {"center": [4.0, 7.3], "radius": 0.5, "water_y": 0.0}
	assert_true(PainterlyGrassPatchData.envelope_clear(point, 0.05, {}, empty))
	assert_false(PainterlyGrassPatchData.envelope_clear(point, 0.4, {}, empty))
	assert_false(PainterlyGrassPatchData.envelope_clear(Vector2(0.1, 6), 0.4, {}, source))


func test_root_heightmap_tracks_flat_rolling_and_brushed_slope_within_two_cm() -> void:
	var flat: Dictionary = source.duplicate(true)
	flat["terrain"]["base_profile"] = "flat"
	flat["terrain"]["height_deltas"] = []
	var slope: Dictionary = TerrainField.brush(source, Vector2(5, 6), 0.7, 3)
	var errors: Array[float] = []
	for snapshot: Dictionary in [flat, source, slope]:
		var field: TerrainField = TerrainField.new(snapshot)
		var map: Image = PainterlyGrassPatchData.height_image(field)
		var maximum: float = 0.0
		for kind: int in 3:
			var arrays: Array = patch.patch_meshes[kind].surface_get_arrays(0)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var weights: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			for item: Dictionary in patch.patch_data["groups"][kind]:
				for i: int in points.size():
					if weights[i].r > 0.00001:
						continue
					var position: Vector3 = item["pose"] * points[i]
					var xz: Vector2 = Vector2(position.x, position.z)
					maximum = maxf(
						maximum,
						absf(PainterlyGrassPatchData.sampled_height(map, xz) - field.height_at(xz))
					)
		errors.append(maximum)
		assert_lt(
			maximum, 0.02, "Bilinear heightmap at every actual root, including wide floor cards"
		)

	DirAccess.make_dir_recursive_absolute("res://reports/week_14/g2")
	var output: FileAccess = FileAccess.open(
		"res://reports/week_14/g2/root_errors.json", FileAccess.WRITE
	)
	output.store_string(
		JSON.stringify(
			{
				"profiles": ["flat", "rolling", "brush"],
				"max_error_m": errors,
				"limit_m": 0.02,
				"method": "every actual mesh root; bilinear RF terrain map vs TerrainField"
			},
			"\t"
		)
	)
	output.close()


func test_ab_changes_only_derivatives_and_keeps_camera_light_history_and_source() -> void:
	patch.set_patch_view(2)
	patch.set_patch_paused(true)
	var pose: Transform3D = patch.camera_rig.camera.global_transform
	var calendar: Dictionary = patch.calendar.record()
	var light: Transform3D = patch.sun.global_transform
	var undo_count: int = patch.session._history.get_history_count()
	for enabled: bool in [false, true, false, true]:
		patch.set_variant(enabled)
		await get_tree().process_frame
		assert_eq(patch.meadow.material.get_shader_parameter("preview_patch_enabled"), enabled)
		for view: MultiMeshInstance3D in patch.patch_views:
			assert_eq(view.visible, enabled)
		assert_eq(patch.document.snapshot(), source)
		assert_eq(patch.session._history.get_version(), history_version)
		assert_eq(patch.session._history.get_history_count(), undo_count)
		assert_eq(patch.camera_rig.camera.global_transform, pose)
		assert_eq(patch.calendar.record(), calendar)
		assert_eq(patch.sun.global_transform, light)


func test_f6_read_only_controls_cannot_edit_or_write_formal_files() -> void:
	assert_eq(patch.saves.directory, "user://qa_painterly_grass/g2")
	assert_eq(patch.active_slot, -1)
	assert_true(patch.photo_active)
	assert_false(patch.hud.visible)
	patch._start_save(0, "must never write")
	patch._persist_preferences()
	patch._on_action(&"delete")
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_DELETE
	key.pressed = true
	patch._input(key)
	patch._unhandled_input(key)
	assert_eq(patch.blocked_save_attempts, 1)
	assert_eq(patch.document.snapshot(), source)
	assert_eq(patch.session._history.get_version(), history_version)


func test_walk_exit_retains_pause_and_all_five_views_keep_dof_disabled() -> void:
	patch.set_patch_view(0)
	patch.set_patch_paused(true)
	patch.toggle_patch_walk()
	assert_true(patch.walk_controller.active)
	patch.toggle_patch_walk()
	assert_false(patch.walk_controller.active)
	assert_true(patch._climate_frozen)
	for index: int in 5:
		patch.set_patch_view(index)
		assert_null(patch.camera_rig.camera.attributes)
	patch.set_patch_light(1)
	assert_eq(patch.calendar.minute_of_day, 1098.0)
	patch.set_patch_light(0)
	patch.set_patch_paused(false)
	var before: float = patch.patch_time
	await get_tree().process_frame
	await get_tree().process_frame
	assert_gt(patch.patch_time, before)
	assert_eq(patch.document.snapshot(), source)


func test_shared_material_defaults_and_reflection_exclusion_preserve_baseline() -> void:
	var old: ShaderMaterial = ShaderMaterial.new()
	old.shader = load("res://features/garden_presentation/meadow.gdshader")
	assert_ne(old.get_shader_parameter("preview_patch_enabled"), true)
	assert_true(old.shader.code.contains("uniform bool preview_patch_enabled = false;"))
	var sample: ShaderMaterial = PainterlyGrassSamples.material(
		patch.patch_material.get_shader_parameter("coverage")
	)
	assert_ne(sample.get_shader_parameter("conform_ground"), true)
	assert_true(sample.shader.code.contains("uniform bool conform_ground = false;"))
	assert_ne(sample.get_shader_parameter("garden_colors"), true)
	assert_true(sample.shader.code.contains("uniform bool garden_colors = false;"))
	for view: MultiMeshInstance3D in patch.patch_views:
		assert_same(view.get_parent(), patch.meadow)
		assert_eq(view.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		assert_eq(view.layers & PondReflections.REFLECTION_LAYER, 0)
