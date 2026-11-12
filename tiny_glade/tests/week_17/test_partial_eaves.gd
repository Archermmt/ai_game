extends GutTest


func _face_point(facade: int, along: float, beyond: float) -> Vector2:
	match facade:
		0:
			return Vector2(along, 3.0 + beyond)
		1:
			return Vector2(3.0 + beyond, along)
		2:
			return Vector2(along, -3.0 - beyond)
	return Vector2(-3.0 - beyond, along)


func _roof_hit(mesh: Mesh, point: Vector2, from_below: bool) -> bool:
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var bottom: Vector3 = Vector3(point.x, 1.8, point.y)
	var top: Vector3 = bottom + Vector3.UP * 5.5
	for i: int in range(0, vertices.size(), 3):
		if normals[i].y * (-1.0 if from_below else 1.0) < 0.15:
			continue
		if (
			Geometry3D.segment_intersects_triangle(
				bottom, top, vertices[i], vertices[i + 1], vertices[i + 2]
			)
			!= null
		):
			return true
	return false


func test_partial_contacts_only_remove_covered_tiles_and_soffits_on_each_facade() -> void:
	for facade: int in 4:
		var source: Dictionary = WorldDocument.new("eave-boundaries").snapshot()
		var low: Dictionary = WorldDocument.allocate_building(
			source, Vector3.ZERO, Vector3(6, 2.7, 6)
		)
		var p: Vector2 = _face_point(facade, -1.5, 1.5)
		WorldDocument.allocate_building(source, Vector3(p.x, 0, p.y), Vector3(3, 6, 3))
		var before: Dictionary = source.duplicate(true)
		var view: Node3D = CottageArt.decorate(
			low, BuildingGeometry.build(low, source["buildings"]), source
		)
		var roof: Mesh = view.get_node("HandLaidTiles").mesh
		var timber: Mesh = view.get_node("HoneyTimber").mesh
		var snow_bed: ArrayMesh = BlanketSnowRenderer.source_mesh(roof, Transform3D.IDENTITY, true)
		for along: float in [-2.71, -0.12, 0.14, 1.8]:
			var point: Vector2 = _face_point(facade, along, 0.23)
			assert_eq(
				_roof_hit(snow_bed, point, false),
				along > 0.0,
				"Blanket uses the same clipped roof bed"
			)
			assert_eq(
				_roof_hit(roof, point, false),
				along > 0.0,
				"Slates on facade %d at %.2f" % [facade, along]
			)
			assert_eq(
				_roof_hit(timber, point, true),
				along > 0.0,
				"Timber underside on facade %d at %.2f" % [facade, along]
			)
		assert_true(
			_roof_hit(roof, _face_point(facade, -1.0, -0.2), false), "Roof still meets the wall"
		)
		assert_eq_deep(source, before)
		view.free()


func test_eye_level_rays_cannot_see_sky_between_ridge_and_slates() -> void:
	var source: Dictionary = WoodlandLayout.create()
	var home: Dictionary = source["buildings"][0]
	var view: Node3D = CottageArt.decorate(
		home, BuildingGeometry.build(home, source["buildings"]), source
	)
	var roof: Mesh = view.get_node("HandLaidTiles").mesh
	var vertices: PackedVector3Array = roof.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var ridge: float = float(home["size"][1]) + RoofProfile.rise(home)
	for z: float in [-1.88, -0.44, 0.37, 1.86]:
		var missed: int = 0
		for offset_cm: int in range(2, 11):
			var origin: Vector3 = Vector3(0.55, ridge + offset_cm * 0.01, z)
			var to: Vector3 = origin + Vector3.LEFT * 1.1
			var found: bool = false
			for i: int in range(0, vertices.size(), 3):
				if (
					Geometry3D.segment_intersects_triangle(
						origin, to, vertices[i], vertices[i + 1], vertices[i + 2]
					)
					!= null
				):
					found = true
					break
			if not found:
				missed += 1
		assert_eq(missed, 0, "Closed roof silhouette beneath cap at z %.2f" % z)
	view.free()
