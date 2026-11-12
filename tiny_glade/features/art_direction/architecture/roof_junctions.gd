extends RefCounted
## Local roof cuts for touching rectangular cottages, shared by slate, snow bed and timber.

var margins: Array[float] = [0.36, 0.39, 0.36, 0.39]
var notches: Array[Array] = []
var returns: Array[Dictionary] = []


func _init(home: Dictionary, neighbors: Array) -> void:
	if home["shape"] != "rect" or RoofProfile.rise(home) <= 0.02:
		return
	for facade: int in 4:
		var along: int = 0 if facade % 2 == 0 else 2
		var half: float = float(home["size"][along]) * 0.5
		var runs: Array[Vector2] = []
		for other: Dictionary in neighbors:
			if BuildingContact.intervals(home, [other], facade).is_empty():
				continue
			var offset: float = float(other["position"][along]) - float(home["position"][along])
			var neighbor_half: float = float(other["size"][along]) * 0.5
			var lo: float = maxf(-half, offset - neighbor_half)
			var hi: float = minf(half, offset + neighbor_half)
			if along == 2:
				var neighbor_width: float = float(other["size"][0]) * 0.5
				# Sample the adjacent slope at the outer tip of this possible eave.
				if (
					_roof_height(other, maxf(0.0, neighbor_width - 0.45))
					>= float(home["position"][1]) + float(home["size"][1]) - 0.05
				):
					runs.append(Vector2(lo, hi))
			else:
				_gable_intersections(home, other, lo, hi, offset, runs)
		var merged: Array[Vector2] = _unite(runs)
		if merged.size() == 1 and merged[0].x <= -half + 0.001 and merged[0].y >= half - 0.001:
			margins[facade] = 0.0
			continue
		var outward: Vector3 = [Vector3.BACK, Vector3.RIGHT, Vector3.FORWARD, Vector3.LEFT][facade]
		var tangent: Vector3 = Vector3.RIGHT if along == 0 else Vector3.BACK
		var wall: float = float(home["size"][2 if along == 0 else 0]) * 0.5
		for run: Vector2 in merged:
			var planes: Array[Plane] = [Plane(outward, wall)]
			# Runs that reach a wall corner also cut the projecting corner of the soffit.
			for end: int in 2:
				var u: float = run[end]
				if absf(u) >= half - 0.001:
					continue
				var sign_u: float = 1.0 if end == 0 else -1.0
				planes.append(Plane(tangent * sign_u, u * sign_u))
				returns.append(
					{
						"inner": outward * wall + tangent * u,
						"direction": outward,
						"facade": facade,
						"normal": tangent * sign_u
					}
				)
			notches.append(planes)


static func _roof_height(home: Dictionary, x_from_center: float) -> float:
	var half: float = float(home["size"][0]) * 0.5 + 0.39
	return (
		float(home["position"][1])
		+ float(home["size"][1])
		+ RoofProfile.rise(home) * (1.0 - absf(x_from_center) / half)
	)


static func _gable_intersections(
	home: Dictionary, other: Dictionary, lo: float, hi: float, offset: float, runs: Array[Vector2]
) -> void:
	# Each gable is piecewise linear. Split at both ridges then solve where one
	# roof overtakes the other, rather than hiding an entire gable after one sample.
	var cuts: Array[float] = [lo, hi]
	for ridge: float in [0.0, offset]:
		if ridge > lo and ridge < hi:
			cuts.append(ridge)
	cuts.sort()
	for i: int in range(cuts.size() - 1):
		var a: float = cuts[i]
		var b: float = cuts[i + 1]
		var da: float = _roof_height(other, a - offset) - _roof_height(home, a) + 0.05
		var db: float = _roof_height(other, b - offset) - _roof_height(home, b) + 0.05
		if da < 0.0 and db < 0.0:
			continue
		if da < 0.0:
			a = lerpf(a, b, da / (da - db))
		elif db < 0.0:
			b = lerpf(a, b, da / (da - db))
		if b - a > 0.001:
			runs.append(Vector2(a, b))


static func _unite(runs: Array[Vector2]) -> Array[Vector2]:
	runs.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var merged: Array[Vector2] = []
	for interval: Vector2 in runs:
		if merged.is_empty() or merged[-1].y < interval.x - 0.001:
			merged.append(interval)
		else:
			merged[-1].y = maxf(merged[-1].y, interval.y)
	return merged


func clip(mesh: CottageMesh) -> void:
	for planes: Array in notches:
		var result: CottageMesh = CottageMesh.new()
		var first_untouched: int = 0
		for i: int in range(0, mesh.vertices.size(), 3):
			var a: Vector3 = mesh.vertices[i]
			var b: Vector3 = mesh.vertices[i + 1]
			var c: Vector3 = mesh.vertices[i + 2]
			var untouched: bool = false
			for plane: Plane in planes:
				if (
					maxf(plane.distance_to(a), maxf(plane.distance_to(b), plane.distance_to(c)))
					<= 0.00001
				):
					untouched = true
					break
			if untouched:
				continue
			_copy_run(mesh, result, first_untouched, i)
			first_untouched = i + 3
			# Split into disjoint outside pieces. Continue clipping just the
			# inside remainder; the final interior belongs to the neighbouring wall.
			var polygon: PackedVector3Array = PackedVector3Array([a, b, c])
			for plane: Plane in planes:
				_emit_polygon(mesh, i, Geometry3D.clip_polygon(polygon, plane), result)
				polygon = Geometry3D.clip_polygon(polygon, -plane)
				if polygon.size() < 3:
					break
		if first_untouched > 0:
			_copy_run(mesh, result, first_untouched, mesh.vertices.size())
			mesh.vertices = result.vertices
			mesh.normals = result.normals
			mesh.colors = result.colors
			mesh.uvs = result.uvs


static func _copy_run(src: CottageMesh, dst: CottageMesh, start: int, end: int) -> void:
	if end <= start:
		return
	dst.vertices.append_array(src.vertices.slice(start, end))
	dst.normals.append_array(src.normals.slice(start, end))
	dst.colors.append_array(src.colors.slice(start, end))
	dst.uvs.append_array(src.uvs.slice(start, end))


static func _emit_polygon(
	src: CottageMesh, start: int, polygon: PackedVector3Array, dst: CottageMesh
) -> void:
	for i: int in range(1, polygon.size() - 1):
		if (
			(polygon[i] - polygon[0]).cross(polygon[i + 1] - polygon[0]).length_squared()
			< 0.000000000001
		):
			continue
		for point: Vector3 in [polygon[0], polygon[i], polygon[i + 1]]:
			var w: Vector3 = Geometry3D.get_triangle_barycentric_coords(
				point, src.vertices[start], src.vertices[start + 1], src.vertices[start + 2]
			)
			dst.vertices.append(point)
			# CottageMesh stores one pigment and face normal per triangle.
			dst.colors.append(src.colors[start])
			dst.normals.append(src.normals[start])
			dst.uvs.append(
				src.uvs[start] * w.x + src.uvs[start + 1] * w.y + src.uvs[start + 2] * w.z
			)
