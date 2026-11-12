class_name WoodlandPond
extends RefCounted
## A few notched leaves gathered in coves. Derived from each player's actual shoreline.


static func add_leaves(bank: Node3D, source: Dictionary) -> void:
	var pond: Dictionary = source["pool"]
	if pond.is_empty():
		return
	var contour: PackedVector2Array = PondShape.contour(pond)
	var bounds: Rect2 = Rect2(contour[0], Vector2.ZERO)
	for p: Vector2 in contour:
		bounds = bounds.expand(p)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = (str(source["world_seed"]) + ":floating-leaves").hash()
	var mesh: SurfaceTool = SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var centers: Array[Vector2] = []
	var leaf_count: int = 0
	for attempt: int in 70:
		if centers.size() >= 3:
			break
		var p: Vector2 = bounds.position + Vector2(rng.randf(), rng.randf()) * bounds.size
		var distance: float = PondShape.distance(pond, p)
		if distance > -0.30 or distance < -0.95 or not ArtScenery._bridge_clear(source, p):
			continue
		if centers.any(func(previous: Vector2) -> bool: return p.distance_to(previous) < 1.1):
			continue
		centers.append(p)
		for i: int in 4:
			var spot: Vector2 = p + Vector2.from_angle(i * 2.5) * (0.16 * sqrt(float(i)))
			if PondShape.distance(pond, spot) > -0.19 or not ArtScenery._bridge_clear(source, spot):
				continue
			_leaf(mesh, spot, pond["water_y"] + 0.024 + 0.005 * i, rng)
			leaf_count += 1
	if leaf_count == 0:
		return
	var leaves: MeshInstance3D = MeshInstance3D.new()
	leaves.name = "FloatingLeaves"
	leaves.mesh = mesh.commit()
	var paint: StandardMaterial3D = StandardMaterial3D.new()
	paint.vertex_color_use_as_albedo = true
	paint.vertex_color_is_srgb = true
	paint.roughness = 0.83
	paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	leaves.material_override = paint
	leaves.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bank.add_child(leaves)


static func add_shallows(bank: Node3D, source: Dictionary) -> void:
	var pond: Dictionary = source["pool"]
	if pond.is_empty():
		return
	var contour: PackedVector2Array = PondShape.contour(pond)
	var field := TerrainField.new(source)
	# Shape just one pocket inside the existing shoreline. The margin sinks
	# below the native bed so the wet gravel has no exposed straight mesh edge.
	for i: int in contour.size():
		var a: Vector2 = contour[i]
		var b: Vector2 = contour[(i + 1) % contour.size()]
		var along: Vector2 = (b - a).normalized()
		var inward: Vector2 = along.orthogonal()
		var center: Vector2 = a.lerp(b, 0.52)
		if PondShape.distance(pond, center + inward * 0.2) > 0:
			inward = -inward
		if not _shoal_clear(source, center + inward * 0.42):
			continue
		var half_span: float = minf(1.45, float(pond["radius"]) * 0.50)
		var builder := WoodlandMesh.new()
		var previous: PackedVector3Array = []
		for row: int in 7:
			var line: PackedVector3Array = []
			var v: float = row / 6.0
			for column: int in 13:
				var u: float = column / 6.0 - 1.0
				line.append(_shoal_point(field, center, along, inward, half_span, u, v))
			if row > 0:
				for j: int in 12:
					var tint: Color = Color("94896c").lerp(
						Color("72785b"), 0.22 * sin(j * 1.5) + 0.36 * v
					)
					builder.triangle(
						line[j], previous[j], line[j + 1], Vector3.UP, tint, Vector2.ZERO
					)
					builder.triangle(
						line[j + 1], previous[j], previous[j + 1], Vector3.UP, tint, Vector2.ZERO
					)
			previous = line
		var rng := RandomNumberGenerator.new()
		rng.seed = (str(source["world_seed"]) + ":shoal:" + str(i)).hash()
		for n: int in 24:
			var u: float = rng.randf_range(-0.86, 0.86)
			var v: float = rng.randf_range(0.10, 0.78)
			var p: Vector3 = _shoal_point(field, center, along, inward, half_span, u, v)
			if PondShape.distance(pond, Vector2(p.x, p.z)) > -0.10:
				continue
			var size: float = rng.randf_range(0.055, 0.165)
			var pigment: Color = Color("797666").lerp(Color("a49a7f"), rng.randf())
			builder.lobe(
				p,
				Vector3(size, size * 0.38, size * 0.72),
				7,
				rng.randf() * TAU,
				pigment,
				Vector2.ZERO
			)
		var shoal := MeshInstance3D.new()
		shoal.name = "GravelShallows"
		shoal.mesh = builder.finish("pond_gravel")
		var paint := ShaderMaterial.new()
		paint.shader = WoodlandNature.SHADER
		shoal.material_override = paint
		bank.add_child(shoal)
		return


static func _shoal_clear(source: Dictionary, center: Vector2) -> bool:
	for bridge: Dictionary in source.get("bridges", []):
		var nearest: Vector2 = Geometry2D.get_closest_point_to_segment(
			center, Vector2(bridge["a"][0], bridge["a"][1]), Vector2(bridge["b"][0], bridge["b"][1])
		)
		if center.distance_to(nearest) < float(bridge["width"]) * 0.5 + 1.9:
			return false
	return true


static func _shoal_point(
	field: TerrainField,
	center: Vector2,
	along: Vector2,
	inward: Vector2,
	half_span: float,
	u: float,
	v: float
) -> Vector3:
	var p: Vector2 = center + along * u * half_span + inward * lerpf(0.035, 0.90 - u * u * 0.35, v)
	var floor_y: float = field.height_at(p) - 0.12
	var wet_sand: float = float(field.pool["water_y"]) - 0.025 - v * v * 0.27
	var feather: float = (1.0 - smoothstep(0.55, 1.0, absf(u))) * (1.0 - smoothstep(0.7, 1, v))
	feather *= smoothstep(0.025, 0.16, -PondShape.distance(field.pool, p))
	return Vector3(p.x, lerpf(floor_y, wet_sand, feather), p.y)


static func _leaf(mesh: SurfaceTool, spot: Vector2, y: float, rng: RandomNumberGenerator) -> void:
	var center: Vector3 = Vector3(spot.x, y, spot.y)
	var angle: float = rng.randf_range(0, TAU)
	var radius: float = rng.randf_range(0.095, 0.155)
	var tint: Color = Color("829656").lerp(Color("b5bc74"), rng.randf())
	for i: int in 10:
		var face: Array[Vector3] = [center]
		for t: int in [i, i + 1]:
			var dir: Vector2 = Vector2.from_angle(angle + 5.87 * t / 10.0)
			face.append(center + Vector3(dir.x * radius, 0.012, dir.y * radius * 0.86))
		for vertex: Vector3 in face:
			mesh.set_normal(Vector3.UP)
			mesh.set_color(tint.darkened(0.13) if vertex == center else tint)
			mesh.add_vertex(vertex)
