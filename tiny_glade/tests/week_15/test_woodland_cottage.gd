extends GutTest

const Openings = preload("res://features/art_direction/architecture/cabin_openings.gd")


func test_chimney_resizes_with_the_ridge_and_leaves_offset_roofs_clear() -> void:
	var snapshot: Dictionary = WorldDocument.new("woodland-cabin-test").snapshot()
	var home: Dictionary = WorldDocument.allocate_building(snapshot, Vector3.ZERO, Vector3(5, 3, 4))
	for rise: float in [1.4, 2.2, 3.3]:
		home["roof_rise"] = rise
		var before: Dictionary = snapshot.duplicate(true)
		var view: Node3D = CottageArt.decorate(
			home, BuildingGeometry.build(home, snapshot["buildings"]), snapshot
		)
		var stones: MeshInstance3D = view.get_node("Limestone")
		var mouth: Vector3 = CottageArt.Joinery.chimney_mouth(home)
		assert_gt(mouth.y, 3.0 + rise)
		assert_almost_eq(stones.mesh.get_aabb().end.y, mouth.y, 0.02)
		assert_eq_deep(snapshot, before)
		view.free()
	home["roof_rise"] = 0.0
	assert_false(CottageArt.has_chimney(home))
	home["shape"] = "round"
	home["roof_rise"] = 2.2
	assert_false(CottageArt.has_chimney(home))


func test_five_generated_panel_shapes_and_curved_glazing_follow_actual_wall_dimensions() -> void:
	var wood: StandardMaterial3D = StandardMaterial3D.new()
	var glass: ShaderMaterial = ShaderMaterial.new()
	var wall_radius: float = 1.75
	for kind: String in ["arch", "plank", "glass", "round_window", "rect_window"]:
		var glazed: bool = kind not in ["arch", "plank"]
		var height: float = 1.0 if kind.ends_with("window") else 2.1
		var opening: Dictionary = {"width": 0.94, "height": height}
		var panel: Node3D = Openings.make(kind, opening, wood, glass, wall_radius)
		var frame: MeshInstance3D = panel.get_node("Joinery")
		assert_eq(frame.material_override, wood)
		assert_lt(frame.mesh.get_aabb().size.x, 1.04)
		assert_gte(frame.mesh.get_aabb().size.y, height - 0.025)
		assert_eq(panel.has_node("Panes"), glazed)
		if glazed:
			var pane: MeshInstance3D = panel.get_node("Panes")
			assert_eq(pane.material_override, glass)
			var vertices: PackedVector3Array = pane.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var error: float = 0.0
			for point: Vector3 in vertices:
				var radial: Vector2 = Vector2(
					point.x, point.z + wall_radius - OpeningAssembly.RECESS
				)
				error = maxf(
					error, absf(radial.length() - (wall_radius - OpeningAssembly.RECESS + 0.016))
				)
			assert_lt(error, 0.0001)
		panel.free()


func test_saved_palette_ids_change_the_physical_pigments_and_age() -> void:
	var materials: Dictionary = ArtMaterials.create()
	var before: Dictionary = {"palette": {"plaster": "plaster_rose", "roof": "roof_smoke"}}
	ArtMaterials.sync_cottage_palette(materials, before)
	assert_eq(materials["architecture"].get_shader_parameter("plaster_tint"), Color("bd8474"))
	assert_eq(materials["roof"].get_shader_parameter("roof_tint"), Color("536675"))
	ArtMaterials.sync_cottage_palette(materials, {"aged": true})
	assert_eq(materials["architecture"].get_shader_parameter("plaster_tint"), Color("d5bea0"))
	assert_eq(materials["roof"].get_shader_parameter("roof_tint"), Color("ab7159"))
	for part: String in ["masonry", "joinery", "roof"]:
		assert_true(materials[part].get_shader_parameter("aged"))
