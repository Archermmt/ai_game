extends GutTest


func test_every_editable_nature_family_has_generated_pigment_and_pick_envelope() -> void:
	for index: int in range(1, 10):
		var asset: String = "NAT-%02d" % index
		var view: Node3D = WoodlandNature.create(asset, "edited")
		assert_eq(view.get_meta("object_id"), "edited")
		var envelope: AABB = view.get_meta("pick_bounds")
		assert_true(envelope.has_volume(), asset)
		for part: MeshInstance3D in view.get_children():
			assert_true(part.mesh.resource_path.is_empty(), asset + " mesh generated in memory")
			assert_eq(part.material_override.shader, WoodlandNature.SHADER)
			assert_true(envelope.grow(0.001).encloses(part.mesh.get_aabb()))
			var arrays: Array = part.mesh.surface_get_arrays(0)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var pigments: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			assert_gt(vertices.size(), 0)
			assert_eq(vertices.size(), pigments.size())
			assert_eq(vertices.size(), (arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array).size())
		view.free()


func test_tree_lods_share_one_envelope_and_brush_reuses_manual_geometry() -> void:
	for asset: String in ["NAT-01", "NAT-02", "NAT-03"]:
		var view: Node3D = WoodlandNature.create(asset, "planted_tree")
		var parts: Array[Dictionary] = ArtViewPlan.describe(asset, null, null, true)
		assert_eq(parts.size(), view.get_child_count())
		assert_eq(parts.size(), 4)
		for i: int in parts.size():
			var manual: MeshInstance3D = view.get_child(i)
			assert_eq(parts[i]["mesh"], manual.mesh)
			assert_eq(manual.custom_aabb, view.get_meta("pick_bounds").grow(0.25))
			assert_eq(parts[i]["begin"], 0.0 if i < 2 else 37.0)
			assert_eq(parts[i]["end"], 37.0 if i < 2 else 0.0)
			assert_eq(parts[i]["material"].get_shader_parameter("batched"), true)
			assert_eq(
				manual.material_override.get_shader_parameter("season_deciduous"), asset != "NAT-02"
			)
		assert_eq(
			BlanketSnowRenderer._kind(
				view.get_child(0).mesh.resource_name, "", view.get_child(0).material_override
			),
			"nature"
		)
		assert_eq(
			BlanketSnowRenderer._kind(
				view.get_child(1).mesh.resource_name, "", view.get_child(1).material_override
			),
			"nature" if asset == "NAT-02" else ""
		)
		view.free()


func test_pick_body_binds_generated_view_without_changing_source_item() -> void:
	var source: Dictionary = ArtLayout.empty()
	var item: Dictionary = source["instances"][0]
	var before: Dictionary = item.duplicate(true)
	var view: Node3D = WoodlandNature.create(item["asset_id"], item["id"])
	var wrapper: Node3D = AssetRegistry.create(item, source, null, null, view)
	var shape: CollisionShape3D = wrapper.get_node("PickProxy/SelectionShape")
	assert_eq(wrapper.get_node("Visual"), view)
	assert_eq(wrapper.get_meta("object_id"), item["id"])
	assert_eq(shape.shape.size, view.get_meta("pick_bounds").size)
	assert_eq(shape.position, view.get_meta("pick_bounds").get_center())
	assert_eq_deep(item, before)
	wrapper.free()


func test_distant_tree_envelopes_clear_the_entire_editable_square() -> void:
	var bounds: Dictionary = {}
	for asset: String in ["NAT-01", "NAT-02"]:
		var tree: Node3D = WoodlandNature.create(asset, "backdrop")
		bounds[asset] = tree.get_meta("pick_bounds")
		tree.free()
	var nearest: float = INF
	for item: Dictionary in ArtScenery.curtain_placements(ArtLayout.empty(), true):
		var p: Array = item["position"]
		var pose: Transform3D = Transform3D(
			Basis(Vector3.UP, item["yaw"]).scaled(Vector3.ONE * float(item["scale"])),
			Vector3(p[0], p[1], p[2])
		)
		var envelope: AABB = pose * bounds[item["asset_id"]]
		var x: float = maxf(envelope.position.x, -envelope.end.x)
		var z: float = maxf(envelope.position.z, -envelope.end.z)
		nearest = minf(nearest, maxf(x, z))
	assert_gt(nearest, 24.0)
