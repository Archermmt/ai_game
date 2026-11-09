class_name WoodlandNature
extends RefCounted
## Deterministic meshes for editable nature, brush batches and the distant forest.

const SHADER: Shader = preload("res://features/art_direction/materials/woodland_foliage.gdshader")
const BARK: Color = Color("#62594e")
const LEAF: Vector2 = Vector2(0.85, 1.0)
const FLOWER: Vector2 = Vector2(0.72, 2.0)
const NEEDLE: Color = Color("#435f52")
static var _meshes: Dictionary = {}


static func supports(asset: String) -> bool:
	return (
		asset
		in [
			"NAT-01", "NAT-02", "NAT-03", "NAT-04", "NAT-05", "NAT-06", "NAT-07", "NAT-08", "NAT-09"
		]
	)


static func create(asset: String, key: String) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "WoodlandNature"
	root.set_meta("asset_id", asset)
	root.set_meta("object_id", key)
	var paint: ShaderMaterial = ShaderMaterial.new()
	paint.shader = SHADER
	paint.set_shader_parameter("phase", posmod(key.hash(), 10000) * 0.001)
	paint.set_shader_parameter("season_deciduous", asset in ["NAT-01", "NAT-03", "NAT-05"])
	var tree: bool = asset in ["NAT-01", "NAT-02", "NAT-03"]
	var envelope: AABB
	var first: bool = true
	for lod: int in 2 if tree else 1:
		var cache_key: String = "%s/%d" % [asset, lod]
		if not _meshes.has(cache_key):
			_meshes[cache_key] = _generate(asset, lod > 0)
		for mesh: ArrayMesh in _meshes[cache_key]:
			var part: MeshInstance3D = MeshInstance3D.new()
			part.name = mesh.resource_name
			part.mesh = mesh
			part.material_override = paint
			part.visibility_range_begin = 37.0 if lod == 1 else 0.0
			part.visibility_range_end = 37.0 if tree and lod == 0 else 0.0
			part.extra_cull_margin = 0.25
			root.add_child(part, true)
			envelope = mesh.get_aabb() if first else envelope.merge(mesh.get_aabb())
			first = false
	root.set_meta("pick_bounds", envelope)
	for part: MeshInstance3D in root.get_children():
		part.custom_aabb = envelope.grow(0.25)
	return root


static func _generate(asset: String, low: bool) -> Array[ArrayMesh]:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = ("woodland-1109:" + asset).hash()
	var body: WoodlandMesh = WoodlandMesh.new()
	var leaves: WoodlandMesh = WoodlandMesh.new()
	match asset:
		"NAT-01", "NAT-03":
			_broadleaf(body, leaves, rng, asset == "NAT-03", low)
			return [body.finish("bark_forked_limb"), leaves.finish("foliage_deciduous_boughs")]
		"NAT-02":
			_pine(body, leaves, rng, low)
			return [body.finish("bark_spruce"), leaves.finish("branch_pads_evergreen")]
		"NAT-04":
			_fern(leaves, rng)
		"NAT-05":
			_flowers(body, leaves, rng)
			return [body.finish("flower_stems"), leaves.finish("flowers_in_bloom")]
		"NAT-06", "NAT-07":
			for i: int in 8 if asset == "NAT-07" else 5:
				var center: Vector3 = Vector3(
					rng.randf_range(-0.30, 0.30),
					rng.randf_range(0.26, 0.64),
					rng.randf_range(-0.25, 0.25)
				)
				if asset == "NAT-07":
					center.x += 0.13 * (i - 4)
				var root: Vector3 = Vector3(center.x * 0.25, -0.02, center.z * 0.25)
				leaves.stem(root, center, 0.035, 0.012, 5, BARK)
				_crown(leaves, center, Vector3(0.34, 0.23, 0.32), Color("#778c51"), i, true)
			return [leaves.finish("compact_shrub_body")]
		"NAT-08", "NAT-09":
			_stone(body, rng, asset == "NAT-08")
			return [body.finish("stone_outcrop")]
	return [leaves.finish("ferny_fronds")]


static func _broadleaf(
	body: WoodlandMesh, leaves: WoodlandMesh, rng: RandomNumberGenerator, fruit: bool, low: bool
) -> void:
	var height: float = 4.35 if fruit else 6.55
	var spread: float = 1.55 if fruit else 1.98
	var foot: Vector3 = Vector3(0, -0.04, 0)
	var fork: Vector3 = Vector3(0.12, height * 0.34, -0.11)
	var middle: Vector3 = Vector3(-0.18, height * 0.61, 0.04)
	var heel: Vector3 = Vector3(-0.13, height * 0.12, 0.11)
	_root_flare(body, height, heel)
	body.stem(foot, heel, height * 0.054, height * 0.035, 9, BARK)
	body.stem(heel, fork, height * 0.037, height * 0.030, 8, BARK)
	body.stem(fork, middle, height * 0.033, height * 0.022, 7, BARK)
	body.stem(middle, Vector3(0.21, height, -0.1), height * 0.022, 0.035, 6, BARK)
	for i: int in 12:
		var tier: float = float(i) / 11
		var angle: float = 2.39996 * i + rng.randf_range(-0.30, 0.30)
		var direction: Vector3 = Vector3(cos(angle), 0, sin(angle))
		var arm: float = (
			spread * (0.55 + 0.65 * sin(1.1 + tier * 2.3)) * rng.randf_range(0.74, 1.04)
		)
		var shoulder: Vector3 = fork.lerp(middle, tier)
		var elbow: Vector3 = (
			shoulder + direction * arm * 0.66 + Vector3.UP * height * rng.randf_range(0.09, 0.16)
		)
		var center: Vector3 = shoulder + direction * arm
		center.y = height * (0.60 + 0.37 * tier) + rng.randf_range(-0.30, 0.25)
		body.stem(shoulder, elbow, height * 0.020 * (1.0 - tier * 0.45), 0.067, 5, BARK)
		body.stem(elbow, center, 0.076, 0.018, 5, BARK)
		var twig: Vector3 = (
			elbow + direction.rotated(Vector3.UP, 0.7) * 0.48 + Vector3.UP * height * 0.20
		)
		body.stem(elbow, twig, 0.047, 0.013, 5, BARK)
		var branch_side: Vector3 = direction.rotated(Vector3.UP, (-1 if i % 2 else 1) * 1.24)
		var sprout: Vector3 = center + branch_side * 0.43 + Vector3.UP * 0.51
		body.stem(center, sprout, 0.026, 0.008, 4, BARK)
		body.stem(twig, twig + direction * 0.29 + Vector3.UP * 0.33, 0.019, 0.005, 4, BARK)
		if not low:
			body.stem(
				twig.lerp(elbow, 0.22),
				twig + branch_side * 0.30 + Vector3.UP * 0.17,
				0.014,
				0.004,
				4,
				BARK
			)
		var radius: Vector3 = (
			Vector3(
				rng.randf_range(0.90, 1.36),
				rng.randf_range(0.47, 0.83),
				rng.randf_range(0.86, 1.27)
			)
			* (0.83 if fruit else 1.0)
		)
		var pigment: Color = Color("#4b7057").lerp(
			Color("#91ac58"), 0.18 + 0.39 * tier + rng.randf_range(0.0, 0.35)
		)
		if fruit:
			pigment = pigment.lerp(Color("#829750"), 0.37)
		_crown(leaves, center, radius, pigment, i * 0.98, low)
		if fruit and not low:
			for j: int in 3:
				var pos: Vector3 = center + Vector3(cos(j * 2.4), -0.62, sin(j * 2.4)) * radius
				leaves.lobe(pos, Vector3.ONE * 0.095, 5, angle, Color("#bf7453"), FLOWER)


static func _crown(
	leaves: WoodlandMesh, center: Vector3, radius: Vector3, pigment: Color, phase: float, low: bool
) -> void:
	leaves.lobe(center, radius * 0.92, 7 if low else 9, phase, pigment, LEAF)
	if radius.y > 0.32:
		var lateral: Vector3 = Vector3(cos(phase), -0.25, sin(phase))
		var ledge: Vector3 = center + lateral * radius * 0.62
		leaves.lobe(
			ledge, radius * Vector3(0.68, 0.54, 0.64), 7, phase + 1.72, pigment.darkened(0.05), LEAF
		)
	# Broad overlapping sprigs flare outside the crown body. Blades are
	# attached to a short twig and point in related but distinct directions.
	var count: int = 13 if low else 32
	for i: int in count:
		var t: float = (i + 0.5) / count
		var y: float = lerpf(-0.73, 0.99, t)
		var angle: float = 2.39996 * i + phase
		var d: Vector3 = Vector3(cos(angle), 0, sin(angle))
		var outward: Vector3 = d * sqrt(1.0 - y * y) + Vector3.UP * y
		var pos: Vector3 = center + radius * outward * 0.925
		var ink: Color = pigment.lightened(0.008 + 0.055 * maxf(0, y) + 0.01 * cos(angle))
		var direction: Vector3 = d.rotated(Vector3.UP, 0.59 * sin(phase + i))
		for j: int in 1 if low else 2:
			var tangent: Vector3 = direction.cross(Vector3.UP)
			var start: Vector3 = pos + tangent * radius * j * 0.105
			var tip: Vector3 = (
				start
				+ radius * (direction * (0.21 + j * 0.055) + Vector3.UP * 0.06 * sin(angle + j))
			)
			var axis: Vector3 = outward.lerp(Vector3.UP, 0.22).normalized()
			leaves.leaflet(
				start - direction * radius * 0.19, tip, tangent * radius * 0.105, axis, ink
			)


static func _root_flare(body: WoodlandMesh, height: float, heel: Vector3) -> void:
	for i: int in 6:
		var angle: float = 2.39996 * i
		var d: Vector3 = Vector3(cos(angle), 0.0, sin(angle))
		var ridge: Vector3 = d * height * (0.049 + 0.011 * sin(angle)) + Vector3.UP * 0.095
		var end: Vector3 = (
			d.rotated(Vector3.UP, 0.19) * height * (0.108 + 0.025 * sin(i * 0.9))
			- Vector3.UP * 0.12
		)
		body.stem(heel * 0.56, ridge, height * 0.030, height * 0.024, 6, BARK)
		body.stem(ridge, end, height * 0.026, 0.043, 6, BARK.darkened(0.07))


static func _pine(
	body: WoodlandMesh, leaves: WoodlandMesh, rng: RandomNumberGenerator, low: bool
) -> void:
	var height: float = 7.72
	_root_flare(body, height, Vector3(0.02, 0.75, 0.07))
	body.stem(Vector3(0, -0.03, 0), Vector3(0.06, height, 0.13), 0.31, 0.02, 8, BARK.darkened(0.1))
	for tier: int in 9:
		var y: float = 1.55 + tier * 0.67
		var reach: float = 0.18 + (1.0 - tier / 9.0) * 2.13
		var arms: int = 5 if low else 8
		for i: int in arms:
			var angle: float = TAU * i / arms + tier * 1.07
			var d: Vector3 = Vector3(cos(angle), 0, sin(angle))
			var side: Vector3 = d.cross(Vector3.UP)
			var root: Vector3 = Vector3(0.02, y, 0.06)
			var tip: Vector3 = (
				root + d * reach * rng.randf_range(0.91, 1.04) - Vector3.UP * reach * 0.24
			)
			body.stem(root, tip, reach * 0.039, 0.015, 4, BARK)
			var ink: Color = NEEDLE.lerp(
				Color("#74916e"), 0.20 + tier * 0.048 + rng.randf_range(-0.07, 0.12)
			)
			for j: int in 2 if low else 4:
				var t: float = (j + 1.0) / (2.4 if low else 4.4)
				var a: Vector3 = root.lerp(tip, t * 0.78)
				for dir: float in [-1.0, 1.0]:
					var end: Vector3 = a + (d * 0.52 + side * dir * 0.48) * reach * (1.0 - t * 0.53)
					end.y -= reach * (0.07 + 0.12 * t)
					leaves.leaf(a + Vector3.UP * 0.09, end, side * reach * 0.12, ink, LEAF)
			leaves.leaf(
				root.lerp(tip, 0.45) + Vector3.UP * 0.08,
				tip + d * 0.1,
				side * reach * 0.16,
				ink,
				LEAF
			)


static func _fern(leaves: WoodlandMesh, rng: RandomNumberGenerator) -> void:
	for i: int in 9:
		var angle: float = 2.4 * i
		var d: Vector3 = Vector3(cos(angle), 0, sin(angle))
		var side: Vector3 = d.cross(Vector3.UP)
		var length: float = rng.randf_range(0.37, 0.67)
		leaves.stem(
			Vector3.DOWN * 0.01,
			(d * 0.13 + Vector3.UP * 0.28) * length,
			0.012,
			0.009,
			4,
			Color("#84915c")
		)
		for j: int in range(1, 8):
			var t: float = j / 8.0
			var pos: Vector3 = d * length * t + Vector3.UP * length * sin(t * 2.25)
			var span: float = length * (0.10 + 0.19 * sin(t * PI))
			for dir: float in [-1.0, 1.0]:
				leaves.leaf(
					pos,
					pos + side * dir * span + d * span * 0.78,
					d * span * 0.25,
					Color("#778f51"),
					LEAF
				)
			leaves.leaf(
				pos - d * 0.07 - Vector3.UP * 0.04,
				pos + d * 0.08,
				side * 0.012,
				Color("#9aab62"),
				LEAF
			)


static func _flowers(body: WoodlandMesh, bloom: WoodlandMesh, rng: RandomNumberGenerator) -> void:
	for i: int in 8:
		var pos: Vector3 = Vector3(rng.randf_range(-0.25, 0.25), 0.0, rng.randf_range(-0.22, 0.22))
		var end: Vector3 = (
			pos + Vector3(rng.randf_range(-0.10, 0.10), rng.randf_range(0.26, 0.55), 0.04)
		)
		body.stem(pos, end, 0.013, 0.009, 4, Color("#6c8450"))
		var color: Color = [Color("#f1dfae"), Color("#c6a5bf"), Color("#ebc16c")][i % 3]
		for j: int in 6:
			var angle: float = j * TAU / 6.0
			var d: Vector3 = Vector3(cos(angle), 0, sin(angle))
			bloom.leaf(
				end,
				end + d * 0.078 + Vector3.UP * 0.036,
				d.cross(Vector3.UP) * 0.033,
				color,
				FLOWER
			)
			bloom.leaf(
				pos,
				pos + d * 0.14 + Vector3.UP * 0.14,
				d.cross(Vector3.UP) * 0.030,
				Color("#829a52"),
				LEAF
			)
		bloom.lobe(
			end + Vector3.UP * 0.019, Vector3(0.034, 0.028, 0.036), 5, 0.0, Color("#e2ae5c"), FLOWER
		)


static func _stone(body: WoodlandMesh, rng: RandomNumberGenerator, moss: bool) -> void:
	var tall: float = 0.68 if moss else 0.31
	var ring: PackedVector3Array = []
	var shoulder: PackedVector3Array = []
	var crown: PackedVector3Array = []
	for i: int in 8:
		var angle: float = TAU * i / 8.0
		var r: Vector3 = (
			Vector3(cos(angle) * 0.73, 0, sin(angle) * 0.57) * rng.randf_range(0.83, 1.12)
		)
		ring.append(r - Vector3.UP * 0.10)
		shoulder.append(
			r * rng.randf_range(0.83, 1.07) + Vector3.UP * tall * rng.randf_range(0.48, 0.69)
		)
		crown.append(
			(
				r * rng.randf_range(0.44, 0.76)
				+ Vector3(0.055, tall * rng.randf_range(0.81, 1.02), -0.07)
			)
		)
	for i: int in 8:
		var j: int = (i + 1) % 8
		var stone: Color = Color("#737367").lerp(Color("#919181"), rng.randf_range(0.0, 0.65))
		var top: Color = Color("#859156") if moss and i not in [1, 2] else stone.lightened(0.07)
		body.triangle(ring[i], ring[j], shoulder[j], ring[i], stone, Vector2.ZERO)
		body.triangle(ring[i], shoulder[j], shoulder[i], ring[i], stone, Vector2.ZERO)
		body.triangle(
			shoulder[i],
			shoulder[j],
			crown[j],
			ring[i] + Vector3.UP,
			stone.lightened(0.04),
			Vector2.ZERO
		)
		body.triangle(shoulder[i], crown[j], crown[i], ring[i] + Vector3.UP, top, Vector2.ZERO)
		body.triangle(crown[i], crown[j], Vector3(0.04, tall, 0), Vector3.UP, top, Vector2.ZERO)
		body.triangle(ring[i], Vector3.DOWN * 0.11, ring[j], Vector3.DOWN, stone, Vector2.ZERO)
