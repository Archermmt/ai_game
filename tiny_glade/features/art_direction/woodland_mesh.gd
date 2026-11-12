class_name WoodlandMesh
extends RefCounted
## Triangle brush for the clearing's solid foliage, forked stems and mossy stones.
## COLOR stores sRGB pigment, UV.x stores wind weight, UV.y marks living tissue.

var positions: PackedVector3Array = []
var normals: PackedVector3Array = []
var colors: PackedColorArray = []
var masks: PackedVector2Array = []


func triangle(
	a: Vector3, b: Vector3, c: Vector3, outward: Vector3, ink: Color, mask: Vector2
) -> void:
	var normal: Vector3 = (b - a).cross(c - a)
	if normal.length_squared() < 0.000000000001:
		return
	normal = normal.normalized()
	if normal.dot(outward) < 0.0:
		normal = -normal
		positions.append_array(PackedVector3Array([a, b, c]))
	else:
		positions.append_array(PackedVector3Array([a, c, b]))
	for i: int in 3:
		normals.append(normal)
		colors.append(ink)
		masks.append(mask)


func stem(a: Vector3, b: Vector3, bottom: float, top: float, sides: int, color: Color) -> void:
	var axis: Vector3 = (b - a).normalized()
	var u: Vector3 = axis.cross(Vector3.FORWARD).normalized()
	var v: Vector3 = axis.cross(u)
	for i: int in sides:
		var angle: float = TAU * float(i) / sides
		var next: float = TAU * float(i + 1) / sides
		var r: Vector3 = u * cos(angle) + v * sin(angle)
		var s: Vector3 = u * cos(next) + v * sin(next)
		var ink: Color = color.lightened(0.04 * maxf(r.x, 0.0))
		var begin: int = normals.size()
		var mask: Vector2 = Vector2(0.0, -1.0)
		triangle(a + r * bottom, a + s * bottom, b + r * top, r + s, ink, mask)
		triangle(b + r * top, a + s * bottom, b + s * top, r + s, ink, mask)
		for j: int in range(begin, normals.size()):
			var offset: Vector3 = positions[j] - a
			var radial: Vector3 = (offset - axis * offset.dot(axis)).normalized()
			normals[j] = normals[j].lerp(radial, 0.75).normalized()


func lobe(
	center: Vector3, radius: Vector3, sides: int, seed_angle: float, ink: Color, mask: Vector2
) -> void:
	# Staggered, irregular rings keep sections from reading as stacked spheres.
	var begin: int = normals.size()
	var slant: Vector3 = Vector3(cos(seed_angle), 0.0, sin(seed_angle)) * radius * 0.20
	var previous: PackedVector3Array = []
	for k: int in range(1, 5):
		var y: float = [-0.80, -0.25, 0.40, 0.83][k - 1]
		var ring: PackedVector3Array = []
		for i: int in sides:
			var angle: float = TAU * (float(i) + 0.32 * (k % 2)) / sides
			var bulge: float = (
				(1.0 + 0.18 * sin(3.0 * angle + seed_angle) + 0.09 * cos(5.0 * angle - k))
				* sqrt(1.0 - y * y)
			)
			ring.append(
				(
					center
					+ slant * y
					+ (
						radius
						* Vector3(
							bulge * cos(angle),
							y + 0.11 * sin(angle * 3.0 + k + seed_angle),
							bulge * sin(angle)
						)
					)
				)
			)
		for i: int in sides:
			var j: int = (i + 1) % sides
			var outward: Vector3 = (ring[i] + ring[j]) * 0.5 - center
			var value: float = clampf(
				0.54 + 0.27 * y + 0.20 * outward.normalized().dot(Vector3(-0.6, 0.4, 0.5)), 0.0, 1.0
			)
			var pigment: Color = ink.darkened((1.0 - value) * 0.27).lerp(
				ink.lightened(0.14), value * value
			)
			if k == 1:
				triangle(
					center - slant - Vector3.UP * radius.y, ring[i], ring[j], outward, pigment, mask
				)
			else:
				triangle(previous[i], previous[j], ring[i], outward, pigment, mask)
				triangle(ring[i], previous[j], ring[j], outward, pigment, mask)
			if k == 4:
				triangle(
					ring[i], center + slant + Vector3.UP * radius.y, ring[j], outward, pigment, mask
				)
		previous = ring
	for i: int in range(begin, normals.size()):
		var radial: Vector3 = ((positions[i] - center) / radius).normalized()
		normals[i] = normals[i].lerp(radial, 0.89).normalized()


func leaf(base: Vector3, tip: Vector3, side: Vector3, ink: Color, mask: Vector2) -> void:
	# Two ridged halves catch light separately. Normal orientation is upward for
	# the upper face even on drooping leaves; backfaces remain visible from below.
	var mid: Vector3 = base.lerp(tip, 0.46)
	var ridge: Vector3 = mid + Vector3.UP * side.length() * 0.35
	triangle(base, mid + side, ridge, Vector3.UP, ink, mask)
	triangle(ridge, mid + side, tip, Vector3.UP, ink, mask)
	triangle(base, ridge, mid - side, Vector3.UP, ink.darkened(0.055), mask)
	triangle(ridge, tip, mid - side, Vector3.UP, ink.darkened(0.055), mask)


func leaflet(
	base: Vector3, tip: Vector3, side: Vector3, volume_normal: Vector3, ink: Color
) -> void:
	# Wide at the shoulder, blunt at the end. Small strokes curl around their
	# parent bough and share its normals to avoid glitter as the camera orbits.
	var begin: int = normals.size()
	var shoulder: Vector3 = base.lerp(tip, 0.41)
	var nose: Vector3 = base.lerp(tip, 0.82)
	var mask: Vector2 = Vector2(0.92, 1.0)
	triangle(base, shoulder - side, shoulder + side, Vector3.UP, ink, mask)
	triangle(shoulder - side, nose - side * 0.63, shoulder + side, Vector3.UP, ink, mask)
	triangle(shoulder + side, nose - side * 0.63, nose + side * 0.56, Vector3.UP, ink, mask)
	triangle(nose - side * 0.63, tip, nose + side * 0.56, Vector3.UP, ink, mask)
	for i: int in range(begin, normals.size()):
		normals[i] = normals[i].lerp(volume_normal, 0.88).normalized()


func finish(label: String) -> ArrayMesh:
	var result: ArrayMesh = ArrayMesh.new()
	result.resource_name = label
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = masks
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result
