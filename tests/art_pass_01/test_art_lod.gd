extends GutTest
## All roles of a tree must cross the distance threshold together.


func test_leaf_trunk_and_crown_share_one_lod_reference_center() -> void:
	var materials: Dictionary = ArtMaterials.create()
	ArtFoliageCatalog.configure(materials["foliage"].shader)
	for asset: String in ["NAT-01", "NAT-02", "NAT-03"]:
		var tree: Node3D = ArtFoliageCatalog.create(
			asset, "lod-boundary", materials["wood"], materials["stone"]
		)
		var center: Vector3
		var first: bool = true
		for view: MeshInstance3D in tree.find_children("*", "MeshInstance3D", true, false):
			var relative: Transform3D = Transform3D.IDENTITY
			var cursor: Node3D = view
			while cursor != tree:
				relative = cursor.transform * relative
				cursor = cursor.get_parent() as Node3D
			var actual: Vector3 = relative * view.custom_aabb.get_center()
			if first:
				center = actual
				first = false
			assert_true(
				actual.is_equal_approx(center), "All six roles switch at the same camera distance"
			)
			assert_true(view.custom_aabb.encloses(view.mesh.get_aabb()))
		assert_false(first)
		tree.free()


func test_spatial_batch_uses_one_envelope_for_both_lods_and_preserves_source() -> void:
	var materials: Dictionary = ArtMaterials.create()
	ArtFoliageCatalog.configure(materials["foliage"].shader)
	var items: Array = [
		{"id": "a", "asset_id": "NAT-01", "position": [9.0, 0.0, 9.0], "seed": "tree-a"},
		{"id": "b", "asset_id": "NAT-01", "position": [12.0, 0.0, 11.0], "seed": "tree-b"}
	]
	var poses: Dictionary = {
		"a": Transform3D(Basis(Vector3.UP, 0.7), Vector3(9, 0.2, 9)),
		"b": Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 1.2), Vector3(12, 0.8, 11))
	}
	var before: Array = items.duplicate(true)
	var parts: Array[Dictionary] = ArtViewPlan.describe(
		"NAT-01", materials["wood"], materials["stone"]
	)
	var batch: Node3D = ArtViewPlan.build_batch(
		items, poses, materials["wood"], materials["stone"], parts
	)
	var reference: AABB = (batch.get_child(0) as MultiMeshInstance3D).custom_aabb
	for view: MultiMeshInstance3D in batch.get_children():
		assert_eq(view.custom_aabb, reference)
		for item: Dictionary in items:
			var pose: Transform3D = poses[item["id"]]
			pose.origin -= batch.position
			assert_true(reference.encloses(pose * view.multimesh.mesh.get_aabb()))
	assert_eq_deep(items, before)
	batch.free()
