extends GutTest


func test_demo_and_empty_are_deterministic_legal_source_documents() -> void:
	var source: Dictionary = ArtLayout.create()
	assert_eq(WorldDocument.validate(source), "")
	assert_eq(WorldDocument.validate(ArtLayout.empty()), "")
	assert_eq_deep(ArtLayout.create(), source)
	assert_eq_deep(ArtLayout.empty()["terrain"], source["terrain"])
	assert_eq(source["buildings"].size(), 3)
	for collection: String in ["bridges", "stairs"]:
		for structure: Dictionary in source[collection]:
			assert_eq(GardenStructures.status(source, structure), "")
	for tree: Dictionary in ArtLayout.empty()["instances"]:
		assert_true(tree in source["instances"])


func test_new_presentation_roundtrips_with_the_existing_save_format() -> void:
	var source: Dictionary = ArtLayout.create()
	var encoded: PackedByteArray = SceneSave.encode(source, "手绘庭院")
	assert_gt(encoded.size(), 0)
	var result: Dictionary = SceneSave.decode(encoded)
	assert_true(result["ok"])
	assert_eq_deep(result["snapshot"], source)
	assert_eq(result["metadata"]["title"], "手绘庭院")
	assert_eq(source["generator_version"], ForestTemplate.create()["generator_version"])


func test_flagstones_follow_the_authoritative_path_and_do_not_fill_pond_or_house() -> void:
	var source: Dictionary = ArtLayout.create()
	var before: Dictionary = source.duplicate(true)
	var arrays: Array = ArtPathGeometry.arrays(source)
	assert_eq_deep(source, before)
	assert_eq_deep(ArtPathGeometry.arrays(source), arrays)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	assert_gt(vertices.size(), 100)
	var all_finite: bool = true
	var centers_clear: bool = true
	# Each flagstone contributes 8 top triangles and 8 bevel quads (72 vertices).
	for offset: int in range(0, vertices.size(), 72):
		var center: Vector3 = vertices[offset]
		centers_clear = (
			centers_clear and not PathGeometry._blocked(Vector2(center.x, center.z), source)
		)
	for point: Vector3 in vertices:
		all_finite = all_finite and point.is_finite()
	assert_true(all_finite)
	assert_true(centers_clear, "Flagstones use the same source masks as path generation")
