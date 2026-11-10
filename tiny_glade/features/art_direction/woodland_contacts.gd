class_name WoodlandContacts
extends RefCounted
## Disposable ground transitions. Worker builds arrays; publication creates one draw.

const SHADER: Shader = preload("res://features/art_direction/materials/woodland_contacts.gdshader")
const FOOTPRINT: float = 0.21
const LIMIT: int = 1600


static func signature(source: Dictionary) -> String:
	return DirtyGraph.key(
		[
			source["world_seed"],
			source["buildings"],
			source["instances"],
			source["paths"],
			source["pool"],
			source["terrain"],
			source.get("bridges", []),
			source.get("stairs", [])
		]
	)


static func generate(source: Dictionary) -> Dictionary:
	var field: TerrainField = TerrainField.new(source)
	var obstacles: Dictionary = MeadowData._obstacles(source)
	var patches: Array[Dictionary] = []
	# Independent keys preserve each object's planting when unrelated objects change.
	for home: Dictionary in source["buildings"]:
		var w: float = home["size"][0]
		var d: float = home["size"][2]
		var rounded: bool = home["shape"] == "round"
		var origin: Vector2 = Vector2(home["position"][0], home["position"][2])
		for facade: int in range(1 if rounded else 4):
			var span: float = PI * w if rounded else (w if facade % 2 == 0 else d)
			var rng: RandomNumberGenerator = _rng(str(home["seed"]) + ":foot:" + str(facade))
			var count: int = ceili(span / 0.27)
			for i: int in count:
				if sin(i * 0.56 + facade * 1.7) < -0.32:
					continue
				var u: float = span * (i + rng.randf_range(0.2, 0.8)) / count
				var local: Vector3 = BuildingGeometry._point(u, facade, w, d, rounded)
				var normal: Vector3 = BuildingGeometry._normal(u, facade, w, d, rounded)
				var p: Vector2 = origin + Vector2(local.x, local.z)
				p += Vector2(normal.x, normal.z) * rng.randf_range(0.35, 0.63)
				_offer(patches, source, field, obstacles, p, "wall", rng)
	for item: Dictionary in source["instances"]:
		if item["asset_id"] not in ["NAT-01", "NAT-02", "NAT-03", "NAT-08", "NAT-09"]:
			continue
		var rng: RandomNumberGenerator = _rng(str(item["seed"]) + ":roots")
		var origin: Vector2 = Vector2(item["position"][0], item["position"][2])
		for i: int in 13:
			var p: Vector2 = (
				origin
				+ (
					Vector2.from_angle(i * 2.39996 + rng.randf())
					* rng.randf_range(0.38, 1.02)
					* float(item["scale"])
				)
			)
			_offer(patches, source, field, obstacles, p, "root", rng)
	for path: Dictionary in source["paths"]:
		var points: Array[Vector2] = PathCurve.sample(path)
		var rng: RandomNumberGenerator = _rng(str(path["id"]) + ":verge")
		for i: int in range(points.size() - 1):
			var a: Vector2 = points[i]
			var b: Vector2 = points[i + 1]
			var normal: Vector2 = (b - a).orthogonal().normalized()
			for j: int in maxi(1, ceili(a.distance_to(b) / 0.6)):
				if rng.randf() < 0.48:
					continue
				var p: Vector2 = (
					a.lerp(b, rng.randf())
					+ normal * (1.0 if j % 2 else -1.0) * (float(path["width"]) * 0.5 + 0.39)
				)
				_offer(patches, source, field, obstacles, p, "verge", rng)
	if not source["pool"].is_empty():
		var contour: PackedVector2Array = PondShape.contour(source["pool"])
		for edge: int in contour.size():
			var a: Vector2 = contour[edge]
			var b: Vector2 = contour[(edge + 1) % contour.size()]
			var normal: Vector2 = (b - a).orthogonal().normalized()
			if PondShape.distance(source["pool"], a.lerp(b, 0.5) + normal * 0.3) < 0:
				normal = -normal
			var rng: RandomNumberGenerator = _rng(str(source["world_seed"]) + ":cove:" + str(edge))
			for i: int in maxi(1, ceili(a.distance_to(b) / 0.19)):
				if sin(edge * 1.81 + i * 0.3) < -0.25:
					continue
				var p: Vector2 = a.lerp(b, rng.randf()) + normal * rng.randf_range(0.23, 0.64)
				_offer(patches, source, field, obstacles, p, "bank", rng)
	var builder: WoodlandMesh = WoodlandMesh.new()
	for patch: Dictionary in patches:
		_tuft(builder, patch)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = builder.positions
	arrays[Mesh.ARRAY_NORMAL] = builder.normals
	arrays[Mesh.ARRAY_COLOR] = builder.colors
	arrays[Mesh.ARRAY_TEX_UV] = builder.masks
	return {"arrays": arrays, "patches": patches}


static func _rng(key: String) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = key.hash()
	return rng


static func allowed(source: Dictionary, obstacles: Dictionary, p: Vector2) -> bool:
	if not Rect2(-23.8, -23.8, 47.6, 47.6).has_point(p):
		return false
	for offset: Vector2 in [Vector2.ZERO, Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		var sample_point: Vector2 = p + offset * FOOTPRINT
		if not MeadowData.clear(sample_point, obstacles, {}):
			return false
		if (
			not source["pool"].is_empty()
			and PondShape.distance(source["pool"], sample_point) < 0.02
		):
			return false
	return true


static func _offer(
	patches: Array[Dictionary],
	source: Dictionary,
	field: TerrainField,
	obstacles: Dictionary,
	p: Vector2,
	kind: String,
	rng: RandomNumberGenerator
) -> void:
	if patches.size() >= LIMIT or not allowed(source, obstacles, p) or field.normal_at(p).y < 0.72:
		return
	# Adapt every leaf root to the current slope, not to the building's base Y.
	patches.append(
		{
			"p": Vector3(p.x, field.height_at(p) + 0.008, p.y),
			"normal": field.normal_at(p),
			"kind": kind,
			"phase": rng.randf(),
			"size": rng.randf_range(0.72, 1.18)
		}
	)


static func _tuft(builder: WoodlandMesh, patch: Dictionary) -> void:
	var root: Vector3 = patch["p"]
	var reed: bool = patch["kind"] == "bank"
	var phase: float = patch["phase"]
	var size: float = patch["size"]
	var tint: Color = Color("73874c").lerp(Color("a3ad68"), phase * 0.7)
	for i: int in 7 if reed else 5:
		var angle: float = i * 2.39996 + phase * TAU
		var d: Vector3 = Vector3(cos(angle), 0, sin(angle))
		var base: Vector3 = root + d * 0.018
		var tip: Vector3 = base + d * (0.09 if reed else 0.13) * size
		tip.y += (
			(0.40 + 0.20 * sin(i * 1.7 + phase)) * size if reed else (0.10 + 0.10 * phase) * size
		)
		var side: Vector3 = d.cross(Vector3.UP) * (0.016 if reed else 0.041) * size
		var start: int = builder.positions.size()
		builder.leaf(base, tip, side, tint, Vector2(phase, 0))
		for vertex: int in range(start, builder.positions.size()):
			builder.masks[vertex] = Vector2(
				phase, clampf((builder.positions[vertex].y - root.y) / 0.45, 0, 1)
			)
			var offset: Vector3 = builder.positions[vertex] - root
			var normal: Vector3 = patch["normal"]
			builder.positions[vertex].y -= (normal.x * offset.x + normal.z * offset.z) / normal.y


static func view(data: Dictionary) -> MeshInstance3D:
	var root: MeshInstance3D = MeshInstance3D.new()
	root.name = "WoodlandContacts"
	if data["patches"].is_empty():
		return root
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, data["arrays"])
	root.mesh = mesh
	var paint: ShaderMaterial = ShaderMaterial.new()
	paint.shader = SHADER
	root.material_override = paint
	root.extra_cull_margin = 0.15
	root.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root
