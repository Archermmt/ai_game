extends GutTest


func test_bank_signature_tracks_pool_bridge_profile_and_bilinear_halo() -> void:
	var source: Dictionary = ArtLayout.empty()
	source["pool"] = {"center": [0.0, 0.0], "radius": 3.0, "water_y": -0.15}
	var signature: int = ArtScenery.bank_signature(source)
	var far: Dictionary = TerrainField.brush(source, Vector2(18, 18), 0.2)
	assert_eq(ArtScenery.bank_signature(far), signature)
	for step: float in [0.25, 0.5]:
		source["terrain"]["spacing"] = step
		signature = ArtScenery.bank_signature(source)
		# Just outside the farthest plant; interpolation can still consume this sample.
		var nearby: Dictionary = source.duplicate(true)
		nearby["terrain"]["height_deltas"] = [[int(36.25 / step), int(32 / step), 0.1]]
		assert_ne(ArtScenery.bank_signature(nearby), signature)
	for pair: Array in [
		["world_seed", "new"],
		["pool", {"center": [1.0, 0.0], "radius": 3.0, "water_y": -0.15}],
		["bridges", [{"a": [-4, 0], "b": [4, 0], "width": 1.0}]]
	]:
		var changed: Dictionary = source.duplicate(true)
		changed[pair[0]] = pair[1]
		assert_ne(ArtScenery.bank_signature(changed), signature)
	var profile: Dictionary = source.duplicate(true)
	profile["terrain"]["base_profile"] = "flat"
	assert_ne(ArtScenery.bank_signature(profile), signature)


func test_distant_brush_keeps_fresh_bank_geometry_exactly_equal_for_polygon_and_circle() -> void:
	var materials: Dictionary = ArtMaterials.create()
	ArtFoliageCatalog.configure(materials["foliage"].shader)
	for source: Dictionary in [
		ArtLayout.create(), TerrainField.pond(ArtLayout.empty(), Vector2.ZERO, 3)
	]:
		var changed: Dictionary = TerrainField.brush(source, Vector2(18, 18), 0.1)
		assert_eq(ArtScenery.bank_signature(source), ArtScenery.bank_signature(changed))
		var a: Node3D = ArtScenery.bank(source, materials["wood"], materials["stone"])
		var b: Node3D = ArtScenery.bank(changed, materials["wood"], materials["stone"])
		assert_eq(a.get_child_count(), b.get_child_count())
		var left: Array[Node] = a.find_children("*", "MultiMeshInstance3D", true, false)
		var right: Array[Node] = b.find_children("*", "MultiMeshInstance3D", true, false)
		assert_gt(left.size(), 0)
		assert_eq(left.size(), right.size())
		for i: int in range(left.size()):
			assert_eq(left[i].multimesh.buffer, right[i].multimesh.buffer)
		a.free()
		b.free()
