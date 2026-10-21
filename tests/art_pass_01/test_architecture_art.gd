extends GutTest
## Structural regressions for the art presentation, independent of visual approval.


func test_authoritative_wall_reveals_gables_uv_and_normals_are_preserved() -> void:
	var fixture: Dictionary = _fixture()
	var original: Array = fixture["shell"].surface_get_arrays(0)
	var result: Array = CottageArt.wall_mesh(fixture["shell"]).surface_get_arrays(0)
	var source_colors: PackedColorArray = original[Mesh.ARRAY_COLOR]
	for channel: int in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV]:
		var expected: Array = []
		for start: int in range(0, source_colors.size(), 3):
			if source_colors[start].g >= 0.6:
				for offset: int in range(3):
					expected.append(original[channel][start + offset])
		if channel == Mesh.ARRAY_NORMAL:
			# Godot octahedrally encodes normals again when an ArrayMesh is created.
			# Bound that codec error to <0.006 degrees; positions and UV stay exact.
			var maximum_error: float = 0.0
			for index: int in range(expected.size()):
				maximum_error = maxf(
					maximum_error, result[channel][index].distance_to(expected[index])
				)
			assert_lte(maximum_error, 0.0001)
		else:
			assert_eq_deep(Array(result[channel]), expected)
	assert_gt(result[Mesh.ARRAY_VERTEX].size(), 100)
	assert_lt(result[Mesh.ARRAY_VERTEX].size(), original[Mesh.ARRAY_VERTEX].size())


func test_real_door_and_window_holes_remain_open_after_all_detail_meshes() -> void:
	var fixture: Dictionary = _fixture()
	var view: Node3D = CottageArt.decorate(fixture["home"], fixture["shell"], fixture["snapshot"])
	for point: Vector3 in [Vector3(-0.23, 0.6, 0), Vector3(0.23, 1.6, 0), Vector3(0, 1.9, 0)]:
		assert_false(_ray_hits(view, point, point + Vector3.BACK * 4), "Front arch stays open")
	for y: float in [1.3, 1.6, 1.9]:
		assert_false(_ray_hits(view, Vector3(0, y, 0), Vector3(4, y, 0)), "Side window stays open")
	assert_true(
		_ray_hits(view, Vector3(0.9, 1.3, 0), Vector3(0.9, 1.3, 4)),
		"Adjacent plaster remains solid"
	)
	view.free()


func test_round_cottage_keeps_radial_door_hole_and_closed_roof() -> void:
	var fixture: Dictionary = _fixture("round", 3.4, 3.0, 3.4)
	var view: Node3D = CottageArt.decorate(fixture["home"], fixture["shell"], fixture["snapshot"])
	for offset: float in [-0.43, 0.0, 0.43]:
		var angle: float = 0.15 * TAU + offset / 1.7
		var direction: Vector3 = Vector3(sin(angle), 0, cos(angle))
		for y: float in [0.6, 1.65]:
			assert_false(
				_ray_hits(view, Vector3(0, y, 0), direction * 4 + Vector3.UP * y),
				"Round aperture and curved jambs preserve clear passage"
			)
	var roof: MeshInstance3D = view.get_node("HandLaidTiles")
	assert_gt(roof.mesh.get_aabb().end.y, 4.7)
	assert_gt(roof.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size(), 1000)
	assert_true(_finite_mesh(roof.mesh), "Conical apex and every tile have finite geometry")
	assert_true(
		_ray_hits(roof, Vector3(0.9, 6, 0), Vector3(0.9, 2.9, 0)),
		"The roof bed closes tiny tile gaps"
	)
	view.free()


func test_details_are_deterministic_and_do_not_modify_player_source() -> void:
	var fixture: Dictionary = _fixture()
	var before: Dictionary = fixture["snapshot"].duplicate(true)
	var first: Node3D = CottageArt.decorate(fixture["home"], fixture["shell"], fixture["snapshot"])
	var second: Node3D = CottageArt.decorate(fixture["home"], fixture["shell"], fixture["snapshot"])
	assert_eq_deep(fixture["snapshot"], before)
	assert_eq(first.position, Vector3(0, 0.1, 0))
	assert_eq(first.get_meta("object_id"), fixture["home"]["id"])
	for part: String in ["HandLaidTiles", "HoneyTimber", "Limestone"]:
		var a: MeshInstance3D = first.get_node(part)
		var b: MeshInstance3D = second.get_node(part)
		assert_eq_deep(a.mesh.surface_get_arrays(0), b.mesh.surface_get_arrays(0))
	first.free()
	second.free()


func test_object_id_changes_tile_variation_without_moving_apertures() -> void:
	var fixture: Dictionary = _fixture()
	var first: MeshInstance3D = (
		CottageArt.decorate(fixture["home"], fixture["shell"], fixture["snapshot"])
		as MeshInstance3D
	)
	var other: Dictionary = fixture["home"].duplicate(true)
	other["id"] = "art-seed-distinct-home"
	var second: MeshInstance3D = (
		CottageArt.decorate(other, fixture["shell"], fixture["snapshot"]) as MeshInstance3D
	)
	var a: MeshInstance3D = first.get_node("HandLaidTiles")
	var b: MeshInstance3D = second.get_node("HandLaidTiles")
	assert_ne(
		a.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR],
		b.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	)
	assert_eq_deep(first.mesh.surface_get_arrays(0), second.mesh.surface_get_arrays(0))
	first.free()
	second.free()


func test_rectangular_size_extremes_have_bounded_overhang_and_triangle_cost() -> void:
	for size: Vector3 in [Vector3(3, 2.4, 3), Vector3(5, 3.2, 6), Vector3(12, 7.2, 12)]:
		var fixture: Dictionary = _fixture("rect", size.x, size.y, size.z, false)
		var view: Node3D = CottageArt.decorate(
			fixture["home"], fixture["shell"], fixture["snapshot"]
		)
		var roof: MeshInstance3D = view.get_node("HandLaidTiles")
		var bounds: AABB = roof.mesh.get_aabb()
		assert_lte(bounds.end.x, size.x * 0.5 + 0.46, "Eaves have a metre-based overhang")
		assert_gte(bounds.position.x, -size.x * 0.5 - 0.46)
		assert_lte(bounds.end.z, size.z * 0.5 + 0.44)
		assert_lte(_triangles(roof.mesh), 40000, "Merged roof remains inside its worst-case budget")
		assert_true(_finite_mesh(roof.mesh))
		assert_eq(_draw_count(view), 4, "No per-tile nodes or material surfaces")
		view.free()


func test_round_size_extremes_have_bounded_geometry_and_four_draws() -> void:
	for diameter: float in [3.0, 12.0]:
		var fixture: Dictionary = _fixture("round", diameter, 2.4, diameter, false)
		var view: Node3D = CottageArt.decorate(
			fixture["home"], fixture["shell"], fixture["snapshot"]
		)
		var roof: MeshInstance3D = view.get_node("HandLaidTiles")
		assert_lte(_triangles(roof.mesh), 40000)
		assert_lte(roof.mesh.get_aabb().end.x, diameter * 0.5 + 0.56)
		assert_true(_finite_mesh(roof.mesh))
		assert_eq(_draw_count(view), 4)
		view.free()


func test_attached_building_roof_is_clipped_at_the_contact_side() -> void:
	var fixture: Dictionary = _fixture("rect", 5, 3.2, 5, false)
	WorldDocument.allocate_building(fixture["snapshot"], Vector3(5, 0.1, 0), Vector3(5, 3.2, 5))
	var shell: ArrayMesh = BuildingGeometry.build(fixture["home"], fixture["snapshot"]["buildings"])
	var view: Node3D = CottageArt.decorate(fixture["home"], shell, fixture["snapshot"])
	var roof: MeshInstance3D = view.get_node("HandLaidTiles")
	assert_lte(
		roof.mesh.get_aabb().end.x, 2.50001, "No decorative tiles intrude into a touching wall"
	)
	assert_lt(roof.mesh.get_aabb().position.x, -2.8, "Contact does not trim the opposite eave")
	view.free()


func test_tall_cottage_keeps_its_eaves_above_a_lower_offset_wing() -> void:
	var snapshot: Dictionary = WorldDocument.new("art-roof-compound").snapshot()
	var home: Dictionary = WorldDocument.allocate_building(
		snapshot, Vector3(2, 0.55, -1.5), Vector3(5.8, 3.5, 5.4)
	)
	var wing: Dictionary = WorldDocument.allocate_building(
		snapshot, Vector3(6.4, 0.38, -0.4), Vector3(3, 2.4, 3.2)
	)
	var main_view: Node3D = CottageArt.decorate(
		home, BuildingGeometry.build(home, snapshot["buildings"]), snapshot
	)
	var wing_view: Node3D = CottageArt.decorate(
		wing, BuildingGeometry.build(wing, snapshot["buildings"]), snapshot
	)
	var main_roof: MeshInstance3D = main_view.get_node("HandLaidTiles")
	var wing_roof: MeshInstance3D = wing_view.get_node("HandLaidTiles")
	assert_gt(main_roof.mesh.get_aabb().end.x, 3.25, "High eave passes above the low wing")
	assert_lt(main_roof.mesh.get_aabb().position.x, -3.25, "Opposite high eave remains intact")
	assert_gte(wing_roof.mesh.get_aabb().position.x, -1.50001, "Low roof ends at the high wall")
	assert_gt(wing_roof.mesh.get_aabb().end.x, 1.8, "The low wing retains its exposed outer eave")
	main_view.free()
	wing_view.free()


func test_lower_front_neighbor_keeps_clear_high_gable_overhang() -> void:
	var snapshot: Dictionary = WorldDocument.new("art-front-roof-compound").snapshot()
	var home: Dictionary = WorldDocument.allocate_building(
		snapshot, Vector3(0, 0.2, 0), Vector3(5, 4.0, 5)
	)
	var wing: Dictionary = WorldDocument.allocate_building(
		snapshot, Vector3(0.8, 0.2, 4), Vector3(3, 2.4, 3)
	)
	var main_view: Node3D = CottageArt.decorate(
		home, BuildingGeometry.build(home, snapshot["buildings"]), snapshot
	)
	var wing_view: Node3D = CottageArt.decorate(
		wing, BuildingGeometry.build(wing, snapshot["buildings"]), snapshot
	)
	var main_roof: MeshInstance3D = main_view.get_node("HandLaidTiles")
	var wing_roof: MeshInstance3D = wing_view.get_node("HandLaidTiles")
	assert_gt(main_roof.mesh.get_aabb().end.z, 2.8)
	assert_lt(main_roof.mesh.get_aabb().position.z, -2.8)
	assert_gte(wing_roof.mesh.get_aabb().position.z, -1.50001)
	assert_gt(wing_roof.mesh.get_aabb().end.z, 1.8)
	main_view.free()
	wing_view.free()


func test_partially_offset_equal_roofs_clip_only_the_touching_gable_end() -> void:
	var fixture: Dictionary = _fixture("rect", 5, 3.2, 5, false)
	WorldDocument.allocate_building(fixture["snapshot"], Vector3(0.8, 0.1, 5), Vector3(5, 3.2, 5))
	var view: Node3D = CottageArt.decorate(
		fixture["home"],
		BuildingGeometry.build(fixture["home"], fixture["snapshot"]["buildings"]),
		fixture["snapshot"]
	)
	var roof: MeshInstance3D = view.get_node("HandLaidTiles")
	assert_lte(roof.mesh.get_aabb().end.z, 2.50001)
	assert_lt(roof.mesh.get_aabb().position.z, -2.8)
	assert_true(_finite_mesh(roof.mesh))
	view.free()


func test_roof_has_no_large_downward_prism_intersecting_the_gable() -> void:
	var fixture: Dictionary = _fixture()
	var view: Node3D = CottageArt.decorate(fixture["home"], fixture["shell"], fixture["snapshot"])
	var roof: MeshInstance3D = view.get_node("HandLaidTiles")
	var arrays: Array = roof.mesh.surface_get_arrays(0)
	var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var large_underside: bool = false
	for start: int in range(0, positions.size(), 3):
		var area: float = (
			(
				(positions[start + 1] - positions[start])
				. cross(positions[start + 2] - positions[start])
				. length()
			)
			* 0.5
		)
		large_underside = large_underside or (area > 0.25 and normals[start].y < -0.5)
	assert_false(
		large_underside,
		"Tile edges may have undersides; no old full roof prism cuts through the plaster gable"
	)
	view.free()


func test_close_legal_openings_reduce_frame_width_to_preserve_clearance() -> void:
	var fixture: Dictionary = _fixture("rect", 3, 2.4, 3, false)
	fixture["home"]["openings"] = [
		{
			"kind": "rect",
			"center": 0.30,
			"width": 1.0,
			"height": 1.0,
			"sill": 1.1,
			"source": "manual"
		},
		{
			"kind": "rect",
			"center": 0.70,
			"width": 1.0,
			"height": 1.0,
			"sill": 1.1,
			"source": "manual"
		}
	]
	assert_eq(BuildingContact.validate(fixture["home"], fixture["snapshot"]["buildings"]), "")
	var shell: ArrayMesh = BuildingGeometry.build(fixture["home"], fixture["snapshot"]["buildings"])
	var view: Node3D = CottageArt.decorate(fixture["home"], shell, fixture["snapshot"])
	for x: float in [-1.0, -0.2, 0.2, 1.0]:
		assert_false(_ray_hits(view, Vector3(x, 1.4, 0), Vector3(x, 1.4, 3)))
	view.free()


func test_gable_meets_the_roof_bed_without_a_visible_open_wedge() -> void:
	var fixture: Dictionary = _fixture("rect", 5, 3.2, 6, false)
	var view: MeshInstance3D = (
		CottageArt.decorate(fixture["home"], fixture["shell"], fixture["snapshot"])
		as MeshInstance3D
	)
	var walls_only: MeshInstance3D = MeshInstance3D.new()
	walls_only.mesh = view.mesh
	for x: float in [-2.2, 2.2]:
		assert_true(
			_ray_hits(walls_only, Vector3(x, 3.55, 0), Vector3(x, 3.55, 4)),
			"The plaster reaches the real roof plane"
		)
		assert_false(
			_ray_hits(walls_only, Vector3(x, 3.9, 0), Vector3(x, 3.9, 4)),
			"No floating plaster above the roof"
		)
	walls_only.free()
	view.free()


func _fixture(
	shape: String = "rect",
	width: float = 5,
	height: float = 3.2,
	depth: float = 6,
	openings: bool = true
) -> Dictionary:
	var snapshot: Dictionary = WorldDocument.new("art-architecture-check").snapshot()
	var home: Dictionary = WorldDocument.allocate_building(
		snapshot, Vector3(0, 0.1, 0), Vector3(width, height, depth), shape
	)
	if openings:
		home["openings"] = [
			{
				"kind": "arch",
				"center": 0.15 if shape == "round" else 0.5,
				"width": 1.1,
				"height": 2.05,
				"source": "manual"
			}
		]
		if shape == "rect":
			home["openings"].append(
				{
					"kind": "rect",
					"center": 0.5,
					"width": 1.0,
					"height": 1.0,
					"sill": 1.1,
					"facade": 1,
					"source": "manual"
				}
			)
	return {
		"home": home,
		"snapshot": snapshot,
		"shell": BuildingGeometry.build(home, snapshot["buildings"])
	}


func _ray_hits(node: Node3D, from: Vector3, to: Vector3) -> bool:
	if node is MeshInstance3D:
		var mesh_node: MeshInstance3D = node
		for surface: int in range(mesh_node.mesh.get_surface_count()):
			var positions: PackedVector3Array = mesh_node.mesh.surface_get_arrays(surface)[
				Mesh.ARRAY_VERTEX
			]
			for start: int in range(0, positions.size(), 3):
				if (
					Geometry3D.segment_intersects_triangle(
						from, to, positions[start], positions[start + 1], positions[start + 2]
					)
					!= null
				):
					return true
	for child: Node in node.get_children():
		if child is Node3D and _ray_hits(child, from, to):
			return true
	return false


func _triangles(mesh: ArrayMesh) -> int:
	return int(mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() / 3)


func _draw_count(node: Node) -> int:
	var result: int = 0
	if node is MeshInstance3D:
		result += node.mesh.get_surface_count()
	for child: Node in node.get_children():
		result += _draw_count(child)
	return result


func _finite_mesh(mesh: ArrayMesh) -> bool:
	var arrays: Array = mesh.surface_get_arrays(0)
	var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var coordinates: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	for index: int in range(positions.size()):
		if (
			not positions[index].is_finite()
			or not normals[index].is_finite()
			or not coordinates[index].is_finite()
		):
			return false
		if normals[index].length() < 0.9:
			return false
	return true
