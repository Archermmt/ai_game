class_name CottageMesh
extends RefCounted
## Small deterministic, merged mesh builder for the editable cottage presentation.

var vertices: PackedVector3Array = PackedVector3Array()
var normals: PackedVector3Array = PackedVector3Array()
var colors: PackedColorArray = PackedColorArray()
var uvs: PackedVector2Array = PackedVector2Array()


func triangle(a: Vector3, b: Vector3, c: Vector3, outside: Vector3, color: Color) -> void:
	var normal: Vector3 = (b - a).cross(c - a)
	if normal.length_squared() < 0.000000001:
		return
	normal = normal.normalized()
	if normal.dot(outside) < 0.0:
		normal = -normal
	# Godot uses clockwise front faces. Keep winding and the explicit normal aligned.
	var points: Array[Vector3] = [a, b, c]
	if (b - a).cross(c - a).dot(normal) > 0:
		points[1] = c
		points[2] = b
	var tangent: Vector3 = Vector3.UP.cross(normal).normalized()
	if tangent.length_squared() < 0.01:
		tangent = Vector3.RIGHT
	var bitangent: Vector3 = normal.cross(tangent).normalized()
	for point: Vector3 in points:
		vertices.append(point)
		normals.append(normal)
		colors.append(color)
		uvs.append(Vector2(point.dot(tangent), point.dot(bitangent)))


func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, outside: Vector3, color: Color) -> void:
	triangle(a, b, c, outside, color)
	triangle(a, c, d, outside, color)


func triangle_uv(
	a: Vector3,
	b: Vector3,
	c: Vector3,
	outside: Vector3,
	color: Color,
	uv_a: Vector2,
	uv_b: Vector2,
	uv_c: Vector2
) -> void:
	var start: int = vertices.size()
	triangle(a, b, c, outside, color)
	for index: int in range(start, vertices.size()):
		uvs[index] = uv_a if vertices[index] == a else (uv_b if vertices[index] == b else uv_c)


func quad_uv(
	a: Vector3,
	b: Vector3,
	c: Vector3,
	d: Vector3,
	outside: Vector3,
	color: Color,
	uv_a: Vector2,
	uv_b: Vector2,
	uv_c: Vector2,
	uv_d: Vector2
) -> void:
	triangle_uv(a, b, c, outside, color, uv_a, uv_b, uv_c)
	triangle_uv(a, c, d, outside, color, uv_a, uv_c, uv_d)


func beam(
	a: Vector3,
	b: Vector3,
	width: float,
	depth: float,
	color: Color,
	seed_value: float = 0.0,
	section_axis: Vector3 = Vector3.ZERO
) -> void:
	if a.distance_squared_to(b) < 0.00001:
		return
	var axis: Vector3 = (b - a).normalized()
	var across: Vector3 = axis.cross(Vector3.UP).normalized()
	if section_axis.length_squared() > 0.1:
		across = (section_axis - axis * section_axis.dot(axis)).normalized()
	if across.length_squared() < 0.1:
		across = Vector3.RIGHT
	var up: Vector3 = across.cross(axis).normalized()
	var bevel: float = minf(width, depth) * 0.18
	var section: Array[Vector2] = [
		Vector2(-width * 0.5 + bevel, -depth * 0.5),
		Vector2(width * 0.5 - bevel, -depth * 0.5),
		Vector2(width * 0.5, -depth * 0.5 + bevel),
		Vector2(width * 0.5, depth * 0.5 - bevel),
		Vector2(width * 0.5 - bevel, depth * 0.5),
		Vector2(-width * 0.5 + bevel, depth * 0.5),
		Vector2(-width * 0.5, depth * 0.5 - bevel),
		Vector2(-width * 0.5, -depth * 0.5 + bevel)
	]
	var previous: Array[Vector3] = []
	for span: int in range(4):
		var t: float = float(span) / 3.0
		var center: Vector3 = a.lerp(b, t)
		center += across * sin(t * PI) * sin(seed_value * 0.73) * 0.012
		center += up * sin(t * PI) * cos(seed_value * 0.41) * 0.009
		var current: Array[Vector3] = []
		for p: Vector2 in section:
			current.append(center + across * p.x + up * p.y)
		if span == 0 or span == 3:
			for index: int in range(8):
				triangle(
					center,
					current[index],
					current[(index + 1) % 8],
					-axis if span == 0 else axis,
					color.lightened(0.035)
				)
		if not previous.is_empty():
			for index: int in range(8):
				var next: int = (index + 1) % 8
				var radial: Vector2 = (section[index] + section[next]).normalized()
				var outward: Vector3 = across * radial.x + up * radial.y
				quad(
					previous[index],
					previous[next],
					current[next],
					current[index],
					outward,
					color.lightened(0.018 * sin(float(index) + seed_value))
				)
		previous = current


func stone(
	center: Vector3, size: Vector3, outward: Vector3, color: Color, seed_value: float
) -> void:
	var along: Vector3 = Vector3.UP.cross(outward).normalized()
	var up: Vector3 = outward.cross(along).normalized()
	var bevel: float = minf(size.x, size.y) * 0.13
	var corners: Array[Vector2] = [
		Vector2(-size.x * 0.5 + bevel, -size.y * 0.5),
		Vector2(size.x * 0.5 - bevel, -size.y * 0.5),
		Vector2(size.x * 0.5, -size.y * 0.5 + bevel),
		Vector2(size.x * 0.5, size.y * 0.5 - bevel),
		Vector2(size.x * 0.5 - bevel, size.y * 0.5),
		Vector2(-size.x * 0.5 + bevel, size.y * 0.5),
		Vector2(-size.x * 0.5, size.y * 0.5 - bevel),
		Vector2(-size.x * 0.5, -size.y * 0.5 + bevel)
	]
	var face: Array[Vector3] = []
	var back: Array[Vector3] = []
	for index: int in range(8):
		var p: Vector2 = corners[index]
		p.y += sin(seed_value + float(index) * 2.43) * 0.008
		face.append(center + along * p.x * 0.94 + up * p.y * 0.94 + outward * size.z * 0.5)
		back.append(center + along * p.x + up * p.y - outward * size.z * 0.5)
	for index: int in range(8):
		var next: int = (index + 1) % 8
		triangle(center + outward * size.z * 0.55, face[index], face[next], outward, color)
		var radial: Vector3 = (along * corners[index].x + up * corners[index].y).normalized()
		quad(
			face[index],
			back[index],
			back[next],
			face[next],
			outward + radial,
			color.darkened(0.035)
		)


func mesh() -> ArrayMesh:
	var result: ArrayMesh = ArrayMesh.new()
	if vertices.is_empty():
		return result
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result
