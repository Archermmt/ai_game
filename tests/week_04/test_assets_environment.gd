extends GutTest


func test_nature_and_props_import_with_uv_color_ground_socket_and_budget() -> void:
	for name: String in [
		"fern", "wildflower", "shrub", "moss_rock", "flat_rock", "bench", "mailbox"
	]:
		var packed: PackedScene = load("res://assets/week_04/" + name + ".glb")
		var root: Node3D = packed.instantiate() as Node3D
		assert_not_null(root.find_child("socket_ground", true, false))
		var triangles: int = 0
		for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
			var arrays: Array = mesh.mesh.surface_get_arrays(0)
			assert_gt(arrays[Mesh.ARRAY_TEX_UV].size(), 0)
			assert_gt(arrays[Mesh.ARRAY_COLOR].size(), 0)
			triangles += (
				(
					arrays[Mesh.ARRAY_INDEX].size()
					if arrays[Mesh.ARRAY_INDEX] != null
					else arrays[Mesh.ARRAY_VERTEX].size()
				)
				/ 3
			)
		assert_lt(triangles, 2500)
		if name in ["fern", "wildflower", "shrub"]:
			assert_lte(triangles, 500)
		root.free()


func test_bench_has_tea_support_and_mailbox_distinct_geometry() -> void:
	var bench: Node3D = (
		(load("res://assets/week_04/bench.glb") as PackedScene).instantiate() as Node3D
	)
	var mail: Node3D = (
		(load("res://assets/week_04/mailbox.glb") as PackedScene).instantiate() as Node3D
	)
	assert_not_null(bench.find_child("socket_tea_surface", true, false))
	assert_not_null(mail.find_child("mail_slot", true, false))
	assert_not_null(mail.find_child("mailbox_flag", true, false))
	bench.free()
	mail.free()


func test_plants_have_zero_weight_roots_and_moving_tops() -> void:
	for name: String in ["fern", "wildflower", "shrub"]:
		var root: Node3D = (
			(load("res://assets/week_04/" + name + ".glb") as PackedScene).instantiate() as Node3D
		)
		var fixed: bool = false
		var moving: bool = false
		for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
			for color: Color in mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]:
				fixed = fixed or color.r < 0.01
				moving = moving or color.r > 0.2
		assert_true(fixed, name + " root")
		assert_true(moving, name + " top")
		root.free()


func test_rock_geometry_has_closed_bottom_faces_and_no_wind() -> void:
	for name: String in ["moss_rock", "flat_rock"]:
		var root: Node3D = (
			(load("res://assets/week_04/" + name + ".glb") as PackedScene).instantiate() as Node3D
		)
		var mesh: MeshInstance3D = root.find_child("stone_body", true, false)
		var hit: bool = false
		var faces: PackedVector3Array = mesh.mesh.get_faces()
		for i: int in range(0, faces.size(), 3):
			var point: Variant = Geometry3D.ray_intersects_triangle(
				Vector3(0, -2, 0), Vector3.UP, faces[i], faces[i + 1], faces[i + 2]
			)
			hit = hit or point is Vector3
		assert_true(hit, name + " closed bottom")
		var fixed: bool = true
		for color: Color in mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]:
			fixed = fixed and is_zero_approx(color.r)
		assert_true(fixed)
		root.free()


func test_light_rig_selects_nearest_four_and_emits_all_six() -> void:
	var rig: LightRig = LightRig.new()
	add_child_autofree(rig)
	var probes: Array = []
	for i: int in range(6):
		probes.append({"id": str(i), "position": [float(i) * 2, 1.0, 0.0]})
	rig.sync(probes, Vector3.ZERO, 1.0)
	assert_eq(rig.active_ids.size(), 4)
	assert_eq(rig.active_ids[0], "0")
	assert_eq(rig.views.size(), 6)
	rig.sync(probes, Vector3(20, 0, 0), 1.0)
	assert_eq(rig.active_ids[0], "5")
	for view: Node3D in rig.views.values():
		assert_gt(view.get_child(0).material_override.emission_energy_multiplier, 0.0)


func test_daytime_lamps_are_off_and_removed_probes_release_nodes() -> void:
	var rig: LightRig = LightRig.new()
	add_child_autofree(rig)
	rig.sync([{"id": "one", "position": [0, 1, 0]}], Vector3.ZERO, 0.0)
	assert_true(rig.active_ids.is_empty())
	rig.sync([], Vector3.ZERO, 1.0)
	assert_true(rig.views.is_empty())
	assert_eq(rig.get_child_count(), 0)


func test_environment_validation_rejects_invalid_wind_and_lamp_sources() -> void:
	var world: Dictionary = WorldDocument.new().snapshot()
	world["environment"]["wind_direction"] = "bad"
	assert_eq(WorldDocument.validate(world), "invalid_wind_direction")
	world["environment"]["wind_direction"] = 0.5
	world["environment"]["lamp_probes"] = [{"id": "a", "position": [NAN, 0, 0]}]
	assert_ne(WorldDocument.validate(world), "")


func test_fence_foundation_geometry_is_grounded_and_path_creates_gap() -> void:
	var world: Dictionary = WorldDocument.new().snapshot()
	FenceGeometry.allocate(world, [[-4, 0, 0], [4, 0, 0]])
	var before: Array = FenceGeometry.build(world)
	PathGeometry.allocate(world, [[0, 0, -4], [0, 0, 4]], 1.5)
	var after: Array = FenceGeometry.build(world)
	assert_lt(after[Mesh.ARRAY_VERTEX].size(), before[Mesh.ARRAY_VERTEX].size())
	assert_eq(WorldDocument.validate(world), "")


func test_fence_invalid_points_are_rejected_without_script_errors() -> void:
	var world: Dictionary = WorldDocument.new().snapshot()
	world["fences"] = [{"id": "fence", "closed": false, "points": [[0, 0, 0], [INF, 0, 0]]}]
	assert_ne(WorldDocument.validate(world), "")
	world["fences"][0]["points"] = [[0, 0, 0], [30, 0, 0]]
	assert_eq(WorldDocument.validate(world), "fence_outside_bounds")


func test_cloth_draft_retains_fixed_hanging_vertices_and_wind_weights() -> void:
	var root: Node3D = (
		(load("res://assets/week_04/clothesline.glb") as PackedScene).instantiate() as Node3D
	)
	var fixed: bool = false
	var moving: bool = false
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if not mesh.name.begins_with("cloth"):
			continue
		for color: Color in mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]:
			fixed = fixed or color.r < 0.001
			moving = moving or color.r > 0.5
	assert_true(fixed)
	assert_true(moving)
	root.free()
