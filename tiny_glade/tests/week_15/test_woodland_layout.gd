extends GutTest


func test_starter_and_empty_plot_are_reproducible_valid_editable_documents() -> void:
	var garden: Dictionary = WoodlandLayout.create()
	var blank: Dictionary = WoodlandLayout.empty()
	assert_eq_deep(garden, WoodlandLayout.create())
	assert_eq(WorldDocument.validate(garden), "")
	assert_eq(WorldDocument.validate(blank), "")
	assert_true(blank["buildings"].is_empty())
	assert_true(blank["pool"].is_empty())
	for tree: Dictionary in blank["instances"]:
		assert_gte(maxf(absf(tree["position"][0]), absf(tree["position"][2])), 15.0)
		assert_has(garden["instances"], tree)
	assert_eq(garden["world_seed"], blank["world_seed"])
	for key: String in ["buildings", "paths", "pool", "stairs", "bridges", "instances"]:
		assert_false(garden[key].is_empty(), key)
	for structure: Dictionary in garden["stairs"] + garden["bridges"]:
		assert_eq(GardenStructures.status(garden, structure), "")
	assert_true(
		garden["instances"].any(func(item: Dictionary) -> bool: return item["source"] == "brush")
	)


func test_previous_and_new_gardens_roundtrip_without_visual_data_in_the_save() -> void:
	var old: Dictionary = TerrainRelief.apply(ArtLayout.create())
	for garden: Dictionary in [old, WoodlandLayout.create()]:
		var encoded: PackedByteArray = SaveCodec.encode(garden)
		assert_false(encoded.is_empty())
		var decoded: Dictionary = SaveCodec.decode(encoded)
		assert_true(decoded["ok"])
		assert_eq_deep(decoded["snapshot"], garden)
		var bank: Node3D = Node3D.new()
		WoodlandPond.add_leaves(bank, decoded["snapshot"])
		assert_true(bank.has_node("FloatingLeaves"))
		var leaves: MeshInstance3D = bank.get_node("FloatingLeaves")
		var vertices: PackedVector3Array = leaves.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var outside: int = 0
		for point: Vector3 in vertices:
			if PondShape.distance(garden["pool"], Vector2(point.x, point.z)) >= 0:
				outside += 1
		assert_eq(outside, 0)
		bank.free()
		assert_eq_deep(decoded["snapshot"], garden)
	assert_ne(old["world_seed"], WoodlandLayout.create()["world_seed"])
