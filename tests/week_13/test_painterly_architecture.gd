extends GutTest
## Grain stays attached to its timber; quieter roof detail keeps its existing budget.


func test_timber_grain_is_invariant_under_translation_and_beam_orientation() -> void:
	var reference: CottageMesh = CottageMesh.new()
	reference.beam(Vector3.ZERO, Vector3.UP * 4.0, 0.16, 0.18, Color.WHITE, 7.1)
	for direction: Vector3 in [Vector3.RIGHT * 4.0, Vector3.BACK * 4.0, Vector3(2.4, 3.2, 0)]:
		var shifted: CottageMesh = CottageMesh.new()
		var origin: Vector3 = Vector3(8.25, 1.6, -3.0)
		shifted.beam(origin, origin + direction, 0.16, 0.18, Color.WHITE, 7.1)
		assert_eq(shifted.uvs.size(), reference.uvs.size())
		var maximum_error: float = 0.0
		for index: int in range(shifted.uvs.size()):
			maximum_error = maxf(
				maximum_error, shifted.uvs[index].distance_to(reference.uvs[index])
			)
		assert_lt(maximum_error, 0.00001, "Grain follows posts, rails and diagonal braces")
		assert_eq(shifted.vertices.size(), 192, "The grain unwrap adds no timber geometry")


func test_shared_timber_material_uses_the_authored_grain_axis() -> void:
	var materials: Dictionary = ArtMaterials.create()
	var timber: StandardMaterial3D = materials["wood"]
	assert_false(timber.uv1_triplanar)
	assert_false(timber.uv1_world_triplanar)
	assert_true(timber.albedo_texture is Texture2D)
	assert_eq(
		timber.albedo_texture.resource_path, "res://assets/materials/art_pass_01/honey_timber.png"
	)
	assert_gte(timber.roughness, 0.9, "Old timber has a soft, matte painted surface")
	var stone: StandardMaterial3D = materials["stone"]
	assert_true(stone.uv1_world_triplanar, "Masonry keeps its world-space painted scale")


func test_largest_default_cottages_keep_a_quieter_bounded_roof_and_four_draws() -> void:
	for shape: String in ["rect", "round"]:
		var snapshot: Dictionary = WorldDocument.new("painted-roof-budget").snapshot()
		var home: Dictionary = WorldDocument.allocate_building(
			snapshot, Vector3.ZERO, Vector3(12, 7.2, 12), shape
		)
		var before: Dictionary = snapshot.duplicate(true)
		var shell: ArrayMesh = BuildingGeometry.build(home, snapshot["buildings"])
		var view: Node3D = CottageArt.decorate(home, shell, snapshot)
		var roof: MeshInstance3D = view.get_node("HandLaidTiles")
		var vertices: PackedVector3Array = roof.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		assert_gt(vertices.size(), 1000, "Near eaves retain physical clay edges")
		assert_lte(
			vertices.size() / 3,
			29000,
			"Paint masses replace excess tile relief at the largest default cottage"
		)
		var draws: int = (view as MeshInstance3D).mesh.get_surface_count()
		for detail: MeshInstance3D in view.get_children():
			draws += detail.mesh.get_surface_count()
		assert_eq(draws, 4)
		assert_eq_deep(snapshot, before)
		view.free()


func test_soffit_board_is_a_closed_solid_with_a_visible_underside() -> void:
	var board: CottageMesh = CottageMesh.new()
	board.solid_panel(
		[Vector3(0, 3.5, 0), Vector3(0.4, 3.2, 0), Vector3(0.4, 3.2, 2), Vector3(0, 3.5, 2)],
		0.07,
		Color.WHITE
	)
	var edges: Dictionary = {}
	for start: int in range(0, board.vertices.size(), 3):
		for index: int in range(3):
			var a: String = str(board.vertices[start + index])
			var b: String = str(board.vertices[start + (index + 1) % 3])
			var key: String = a + "|" + b if a < b else b + "|" + a
			edges[key] = int(edges.get(key, 0)) + 1
	for count_value: int in edges.values():
		assert_eq(count_value, 2, "Top, bottom and edge faces share every board edge")
	assert_true(
		_front_hit(board.vertices, board.normals, Vector3(0.2, 2.0, 1), Vector3(0.2, 4.0, 1)),
		"A single-sided renderer sees the wooden underside from below"
	)


func test_low_cameras_see_wood_under_all_exposed_roof_forms() -> void:
	for shape: String in ["rect", "round"]:
		for flat: bool in [false, true]:
			var snapshot: Dictionary = WorldDocument.new("low-camera-eaves").snapshot()
			var home: Dictionary = WorldDocument.allocate_building(
				snapshot, Vector3.ZERO, Vector3(5, 3.2, 6), shape
			)
			if flat:
				home["roof_rise"] = 0.0
			var view: Node3D = CottageArt.decorate(
				home, BuildingGeometry.build(home, snapshot["buildings"]), snapshot
			)
			var timber: MeshInstance3D = view.get_node("HoneyTimber")
			var arrays: Array = timber.mesh.surface_get_arrays(0)
			var samples: Array[Vector3] = []
			if shape == "round":
				for index: int in range(12):
					var angle: float = (float(index) + 0.37) * TAU / 12.0
					samples.append(Vector3(sin(angle) * 2.66, 0, cos(angle) * 2.66))
			else:
				for x: float in [-2.0, -1.0, 0.0, 1.0, 2.0]:
					for end: float in [-1.0, 1.0]:
						samples.append(Vector3(x, 0, end * 3.16))
				for z: float in [-2.31, -1.19, 0.17, 1.33, 2.47]:
					for side: float in [-1.0, 1.0]:
						samples.append(Vector3(side * 2.66, 0, z))
			for point: Vector3 in samples:
				assert_true(
					_front_hit(
						arrays[Mesh.ARRAY_VERTEX],
						arrays[Mesh.ARRAY_NORMAL],
						point + Vector3.UP * 2.3,
						point + Vector3.UP * (4.0 + RoofProfile.rise(home))
					),
					"Every exposed overhang has front-facing wood, including between rafters"
				)
			view.free()


func test_soffits_stay_outside_the_wall_footprint_and_clip_at_roof_contacts() -> void:
	var snapshot: Dictionary = WorldDocument.new("soffit-contact-clearance").snapshot()
	var home: Dictionary = WorldDocument.allocate_building(
		snapshot, Vector3.ZERO, Vector3(5, 3.2, 6)
	)
	WorldDocument.allocate_building(snapshot, Vector3(5, 0, 0), Vector3(5, 3.2, 6))
	var board: CottageMesh = CottageMesh.new()
	CottageArt._eave_soffits(home, snapshot["buildings"], board)
	assert_gt(board.vertices.size(), 0)
	for point: Vector3 in board.vertices:
		assert_lte(point.x, 2.50001, "The shared wall has no intrusive wooden overhang")
		assert_false(
			absf(point.x) < 2.4999 and absf(point.z) < 2.9999,
			"No downward roof slab enters the plaster gable or room"
		)
	assert_false(
		_front_hit(board.vertices, board.normals, Vector3(0, 1.5, 0), Vector3(0, 1.5, 5)),
		"Door clearance remains empty"
	)
	assert_false(
		_front_hit(board.vertices, board.normals, Vector3(0, 1.6, 0), Vector3(-4, 1.6, 0)),
		"Side-window clearance remains empty"
	)


func _front_hit(
	vertices: PackedVector3Array, normals: PackedVector3Array, from: Vector3, to: Vector3
) -> bool:
	var direction: Vector3 = (to - from).normalized()
	for start: int in range(0, vertices.size(), 3):
		# Geometry3D intersections alone accept back faces. Require the same
		# outward-facing side a single-sided material would actually render.
		if normals[start].dot(direction) >= -0.0001:
			continue
		if (
			Geometry3D.segment_intersects_triangle(
				from, to, vertices[start], vertices[start + 1], vertices[start + 2]
			)
			!= null
		):
			return true
	return false
