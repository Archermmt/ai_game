extends GutTest
## Presentation contracts: dense crown values and fine grass within the old budget.


func test_grass_retains_nine_triangles_and_pinned_roots() -> void:
	var mesh: ArrayMesh = MeadowData.blade_mesh()
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	assert_eq(vertices.size(), 27)
	assert_eq(colors.size(), vertices.size())
	var roots: int = 0
	var max_height: float = 0.0
	var all_finite: bool = true
	var all_pinned: bool = true
	var all_normals_valid: bool = true
	for i: int in vertices.size():
		var point: Vector3 = vertices[i]
		all_finite = all_finite and point.is_finite()
		max_height = maxf(max_height, point.y)
		if absf(point.y) < 0.00001:
			roots += 1
			all_pinned = all_pinned and is_zero_approx(colors[i].r)
		all_normals_valid = all_normals_valid and normals[i].is_normalized()
	assert_true(all_finite)
	assert_true(all_pinned, "Grass roots remain still when the wind bends the tips")
	assert_true(all_normals_valid)
	assert_gte(roots, 6)
	assert_between(max_height, 0.30, 0.43)
	for triangle: int in range(0, vertices.size(), 3):
		var area: float = (
			(vertices[triangle + 1] - vertices[triangle])
			. cross(vertices[triangle + 2] - vertices[triangle])
			. length()
		)
		assert_gt(area, 0.00001, "Every budgeted triangle contributes visible blade area")


func test_crown_atlas_has_opaque_body_and_joined_edge_clusters() -> void:
	var image: Image = ArtFoliageCatalog.ATLAS.get_image()
	if image != null and image.is_compressed():
		assert_eq(image.decompress(), OK)
	assert_not_null(image)
	if image == null:
		return
	assert_eq(image.get_size(), Vector2i(2048, 2048))
	for tile: int in [0, 1, 2, 3, 15]:
		var samples: int = 0
		var covered: int = 0
		var origin: Vector2i = Vector2i(tile % 4, 3 - floori(float(tile) / 4.0)) * 512
		for y: int in range(0, 512, 8):
			for x: int in range(0, 512, 8):
				covered += int(image.get_pixel(origin.x + x, origin.y + y).a > 0.43)
				samples += 1
		assert_between(
			float(covered) / float(samples),
			0.45,
			0.80,
			"Edge clusters read as joined leaves while their outer contour stays open"
		)
	var opaque: bool = true
	for y: int in range(0, 512, 8):
		for x: int in range(1024, 1536, 8):
			opaque = opaque and image.get_pixel(x, y).a > 0.99
	assert_true(opaque, "Opaque crown bodies prevent holes through the whole canopy")


func test_tree_and_shrub_refresh_does_not_increase_existing_triangle_cost() -> void:
	var old_costs: Dictionary = {
		"NAT-01": 3630,
		"NAT-01-LOD1": 1676,
		"NAT-02": 3412,
		"NAT-02-LOD1": 1576,
		"NAT-03": 3154,
		"NAT-03-LOD1": 1500,
		"NAT-06": 342,
	}
	var manifest: Array = JSON.parse_string(
		FileAccess.get_file_as_string("res://art_source/art_pass_01/nature/manifest.json")
	)
	var checked: int = 0
	for entry: Dictionary in manifest:
		if old_costs.has(entry["asset_id"]):
			assert_lte(int(entry["triangles"]), int(old_costs[entry["asset_id"]]))
			assert_lte(int(entry["triangles"]), int(entry["budget"]))
			checked += 1
	assert_eq(checked, old_costs.size())
