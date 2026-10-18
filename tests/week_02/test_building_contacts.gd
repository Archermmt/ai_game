extends GutTest


func _pair() -> Dictionary:
	var draft: Dictionary = WorldDocument.new().snapshot()
	WorldDocument.allocate_building(draft, Vector3.ZERO, Vector3(4, 4, 6))
	WorldDocument.allocate_building(draft, Vector3(4, 0, 1), Vector3(4, 3, 3))
	return draft


func test_partial_contact_ranges_and_no_surface_inside_hidden_rectangle() -> void:
	var draft: Dictionary = _pair()
	assert_eq(WorldDocument.validate(draft), "")
	var spec: Dictionary = draft["buildings"][0]
	var regions: Array[Rect2] = BuildingContact.intervals(spec, draft["buildings"], 1)
	assert_eq(regions.size(), 1)
	assert_eq(regions[0], Rect2(0.5, 0, 3, 3))
	var arrays: Array = BuildingGeometry.build_arrays(spec, draft["buildings"])
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var covered_triangles: int = 0
	var upper_triangles: int = 0
	for index: int in range(0, points.size(), 3):
		var center: Vector3 = (points[index] + points[index + 1] + points[index + 2]) / 3
		if normals[index].dot(Vector3.RIGHT) > 0.99 and absf(center.x - 2) < 0.001:
			if center.z > -0.5 and center.z < 2.5 and center.y < 3.0:
				covered_triangles += 1
			if center.y > 3.0:
				upper_triangles += 1
	assert_eq(covered_triangles, 0)
	assert_gt(upper_triangles, 0)


func test_contact_endpoint_jambs_close_wall_thickness() -> void:
	var draft: Dictionary = _pair()
	var arrays: Array = BuildingGeometry.build_arrays(draft["buildings"][0], draft["buildings"])
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var found_low: bool = false
	var found_high: bool = false
	for point: Vector3 in points:
		if is_equal_approx(point.x, 2.0 - BuildingGeometry.THICKNESS):
			found_low = found_low or is_equal_approx(point.z, -0.5)
			found_high = found_high or is_equal_approx(point.z, 2.5)
	assert_true(found_low)
	assert_true(found_high)


func test_contact_on_any_facade_is_symmetric() -> void:
	for p: Vector3 in [Vector3(4, 0, 0), Vector3(-4, 0, 0), Vector3(0, 0, 4), Vector3(0, 0, -4)]:
		var draft: Dictionary = WorldDocument.new().snapshot()
		var a: Dictionary = WorldDocument.allocate_building(draft, Vector3.ZERO, Vector3(4, 3, 4))
		var b: Dictionary = WorldDocument.allocate_building(draft, p, Vector3(4, 3, 4))
		var count_a: int = 0
		var count_b: int = 0
		for facade: int in range(4):
			count_a += BuildingContact.intervals(a, draft["buildings"], facade).size()
			count_b += BuildingContact.intervals(b, draft["buildings"], facade).size()
		assert_eq(count_a, 1)
		assert_eq(count_b, 1)


func test_contact_cannot_hide_manual_opening_and_margin_conflicts_reject() -> void:
	var draft: Dictionary = _pair()
	var spec: Dictionary = draft["buildings"][0]
	spec["openings"] = [{"kind": "arch", "center": 0.3, "width": 1, "height": 2, "facade": 1}]
	assert_eq(WorldDocument.validate(draft), "opening_on_contact")
	spec["openings"] = [{"kind": "rect", "center": 0.14, "width": 1, "height": 2}]
	assert_eq(WorldDocument.validate(draft), "opening_margin_0_15m")
	spec["openings"] = [
		{"kind": "rect", "center": 0.5, "width": 1, "height": 2},
		{"kind": "round", "center": 0.6, "width": 0.7, "height": 0.7, "sill": 1}
	]
	assert_eq(WorldDocument.validate(draft), "opening_clearance_0_15m")


func test_minimum_circle_radius_accepts_all_three_profiles_without_frame_scaling() -> void:
	for kind: String in ["rect", "arch", "round"]:
		var draft: Dictionary = WorldDocument.new().snapshot()
		var spec: Dictionary = WorldDocument.allocate_building(
			draft, Vector3.ZERO, Vector3(3, 2.4, 3), "round"
		)
		spec["openings"] = [
			{"kind": kind, "center": 0.25, "width": 1.1, "height": 1.0 if kind == "round" else 2.0}
		]
		assert_eq(WorldDocument.validate(draft), "")
		assert_gt(BuildingGeometry.build(spec).surface_get_array_len(0), 0)
