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
