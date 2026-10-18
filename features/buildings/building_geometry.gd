class_name BuildingGeometry
extends RefCounted
## Bounded facade strip tessellation: actual holes, shell thickness, no CSG.

const THICKNESS: float = 0.18
const PLASTER: Color = Color("e9dec5")
const ROOF: Color = Color("b66f52")
const STONE: Color = Color("92988b")

var _vertices: PackedVector3Array = PackedVector3Array()
var _normals: PackedVector3Array = PackedVector3Array()
var _colors: PackedColorArray = PackedColorArray()
var _uvs: PackedVector2Array = PackedVector2Array()


static func build(spec: Dictionary) -> ArrayMesh:
	var builder: BuildingGeometry = BuildingGeometry.new()
	var size: Array = spec["size"]
	var width: float = float(size[0])
	var height: float = float(size[1])
	var depth: float = float(size[2])
	var round_shape: bool = spec["shape"] == "round"
	var facades: int = 1 if round_shape else 4
	for facade: int in range(facades):
		var length: float = TAU * width * 0.5 if round_shape else width
		if not round_shape and facade % 2 == 1:
			length = depth
		var openings: Array[Dictionary] = []
		for opening: Dictionary in spec.get("openings", []):
			if int(opening.get("facade", 0)) == facade:
				openings.append(opening)
		builder._wall(length, height, facade, width, depth, round_shape, openings)
	builder._roof(width, height, depth, round_shape)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = builder._vertices
	arrays[Mesh.ARRAY_NORMAL] = builder._normals
	arrays[Mesh.ARRAY_COLOR] = builder._colors
	arrays[Mesh.ARRAY_TEX_UV] = builder._uvs
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func opening_interval(opening: Dictionary, u: float, length: float) -> Vector2:
	var center: float = float(opening.get("center", 0.5)) * length
	var width: float = float(opening.get("width", 1.0))
	var height: float = float(opening.get("height", 2.0))
	var sill: float = float(opening.get("sill", 0.0))
	var x: float = absf(u - center)
	if x > width * 0.5 + 0.00001:
		return Vector2(-1.0, -1.0)
	var kind: String = opening.get("kind", "rect")
	if kind == "round":
		var radial: float = sqrt(maxf(0.0, 1.0 - pow(x / (width * 0.5), 2.0)))
		return Vector2(sill + height * 0.5 * (1.0 - radial), sill + height * 0.5 * (1.0 + radial))
	if kind == "arch":
		var radius: float = width * 0.5
		return Vector2(sill, sill + height - radius + sqrt(maxf(0.0, radius * radius - x * x)))
	return Vector2(sill, sill + height)


func _wall(
	length: float,
	height: float,
	facade: int,
	width: float,
	depth: float,
	round_shape: bool,
	openings: Array[Dictionary]
) -> void:
	var cuts: Array[float] = [0.0, length]
	var steps: int = maxi(12, int(ceil(length / 0.12)))
	for index: int in range(steps + 1):
		cuts.append(length * float(index) / float(steps))
	for opening: Dictionary in openings:
		var center: float = float(opening.get("center", 0.5)) * length
		var half: float = float(opening.get("width", 1.0)) * 0.5
		for index: int in range(17):
			cuts.append(clampf(center - half + half * float(index) / 8.0, 0.0, length))
	cuts.sort()
	for index: int in range(cuts.size() - 1):
		var a: float = cuts[index]
		var b: float = cuts[index + 1]
		if b - a < 0.00001:
			continue
		var selected: Dictionary = {}
		for opening: Dictionary in openings:
			if opening_interval(opening, (a + b) * 0.5, length).x >= 0.0:
				selected = opening
		var bottom_a: float = height
		var bottom_b: float = height
		var top_a: float = height
		var top_b: float = height
		if not selected.is_empty():
			var bounds_a: Vector2 = opening_interval(selected, a, length)
			var bounds_b: Vector2 = opening_interval(selected, b, length)
			bottom_a = maxf(0.0, bounds_a.x)
			bottom_b = maxf(0.0, bounds_b.x)
			top_a = minf(height, bounds_a.y)
			top_b = minf(height, bounds_b.y)
		_strip(a, b, 0.0, 0.0, bottom_a, bottom_b, facade, width, depth, round_shape)
		if not selected.is_empty():
			_strip(a, b, top_a, top_b, height, height, facade, width, depth, round_shape)
			_cap(a, b, top_a, top_b, facade, width, depth, round_shape, Vector3.DOWN)
			if bottom_a > 0.0 or bottom_b > 0.0:
				_cap(a, b, bottom_a, bottom_b, facade, width, depth, round_shape, Vector3.UP)
	for opening: Dictionary in openings:
		var center: float = float(opening.get("center", 0.5)) * length
		var half: float = float(opening.get("width", 1.0)) * 0.5
		for edge: float in [center - half, center + half]:
			var bounds: Vector2 = opening_interval(opening, edge, length)
			var p: Vector3 = _point(edge, facade, width, depth, round_shape)
			var n: Vector3 = _normal(edge, facade, width, depth, round_shape)
			var tangent: Vector3 = n.cross(Vector3.UP)
			_quad(
				p + Vector3.UP * bounds.x,
				p - n * THICKNESS + Vector3.UP * bounds.x,
				p - n * THICKNESS + Vector3.UP * bounds.y,
				p + Vector3.UP * bounds.y,
				tangent if edge < center else -tangent,
				PLASTER.darkened(0.12)
			)


func _strip(
	a: float,
	b: float,
	low_a: float,
	low_b: float,
	high_a: float,
	high_b: float,
	facade: int,
	width: float,
	depth: float,
	round_shape: bool
) -> void:
	if high_a - low_a < 0.00001 and high_b - low_b < 0.00001:
		return
	var p: Vector3 = _point(a, facade, width, depth, round_shape)
	var q: Vector3 = _point(b, facade, width, depth, round_shape)
	var np: Vector3 = _normal(a, facade, width, depth, round_shape)
	var nq: Vector3 = _normal(b, facade, width, depth, round_shape)
	var n: Vector3 = (np + nq).normalized()
	_quad(
		p + Vector3.UP * low_a,
		q + Vector3.UP * low_b,
		q + Vector3.UP * high_b,
		p + Vector3.UP * high_a,
		n,
		PLASTER
	)
	_quad(
		p - np * THICKNESS + Vector3.UP * low_a,
		p - np * THICKNESS + Vector3.UP * high_a,
		q - nq * THICKNESS + Vector3.UP * high_b,
		q - nq * THICKNESS + Vector3.UP * low_b,
		-n,
		PLASTER.darkened(0.18)
	)


func _cap(
	a: float,
	b: float,
	ya: float,
	yb: float,
	facade: int,
	width: float,
	depth: float,
	round_shape: bool,
	normal: Vector3
) -> void:
	var p: Vector3 = _point(a, facade, width, depth, round_shape) + Vector3.UP * ya
	var q: Vector3 = _point(b, facade, width, depth, round_shape) + Vector3.UP * yb
	_quad(
		p,
		q,
		q - _normal(b, facade, width, depth, round_shape) * THICKNESS,
		p - _normal(a, facade, width, depth, round_shape) * THICKNESS,
		normal,
		PLASTER.darkened(0.14)
	)


func _roof(width: float, height: float, depth: float, round_shape: bool) -> void:
	if round_shape:
		var radius: float = width * 0.5 + 0.35
		var tip: Vector3 = Vector3(0.0, height + width * 0.48, 0.0)
		for index: int in range(64):
			var a: float = float(index) * TAU / 64.0
			var b: float = float(index + 1) * TAU / 64.0
			var p: Vector3 = Vector3(sin(a) * radius, height, cos(a) * radius)
			var q: Vector3 = Vector3(sin(b) * radius, height, cos(b) * radius)
			_triangle(p, q, tip, Vector3(sin(a), 0.8, cos(a)).normalized(), ROOF)
	else:
		var w: float = width * 0.5 + 0.35
		var d: float = depth * 0.5 + 0.35
		var ridge: float = height + width * 0.38
		_quad(
			Vector3(-w, height, -d),
			Vector3(-w, height, d),
			Vector3(0, ridge, d),
			Vector3(0, ridge, -d),
			Vector3(-0.7, 1, 0).normalized(),
			ROOF
		)
		_quad(
			Vector3(0, ridge, -d),
			Vector3(0, ridge, d),
			Vector3(w, height, d),
			Vector3(w, height, -d),
			Vector3(0.7, 1, 0).normalized(),
			ROOF
		)
		_triangle(
			Vector3(-width * 0.5, height, depth * 0.5),
			Vector3(width * 0.5, height, depth * 0.5),
			Vector3(0, ridge, depth * 0.5),
			Vector3.BACK,
			PLASTER
		)
		_triangle(
			Vector3(width * 0.5, height, -depth * 0.5),
			Vector3(-width * 0.5, height, -depth * 0.5),
			Vector3(0, ridge, -depth * 0.5),
			Vector3.FORWARD,
			PLASTER
		)


func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, tint: Color) -> void:
	_triangle(a, b, c, n, tint)
	_triangle(a, c, d, n, tint)


func _triangle(a: Vector3, b: Vector3, c: Vector3, n: Vector3, tint: Color) -> void:
	if (b - a).cross(c - a).length_squared() < 0.00000001:
		return
	var points: Array[Vector3] = [a, b, c]
	if (b - a).cross(c - a).dot(n) > 0.0:
		points[1] = c
		points[2] = b
	for point: Vector3 in points:
		_vertices.append(point)
		_normals.append(n)
		_colors.append(tint)
		_uvs.append(Vector2(point.x + point.z, point.y))


static func _point(u: float, facade: int, width: float, depth: float, rounded: bool) -> Vector3:
	if rounded:
		var angle: float = u / (width * 0.5)
		return Vector3(sin(angle) * width * 0.5, 0, cos(angle) * width * 0.5)
	match facade:
		0:
			return Vector3(u - width * 0.5, 0, depth * 0.5)
		1:
			return Vector3(width * 0.5, 0, depth * 0.5 - u)
		2:
			return Vector3(width * 0.5 - u, 0, -depth * 0.5)
		_:
			return Vector3(-width * 0.5, 0, u - depth * 0.5)


static func _normal(u: float, facade: int, width: float, _depth: float, rounded: bool) -> Vector3:
	if rounded:
		return Vector3(sin(u / (width * 0.5)), 0, cos(u / (width * 0.5)))
	return [Vector3.BACK, Vector3.RIGHT, Vector3.FORWARD, Vector3.LEFT][facade]
