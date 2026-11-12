extends RefCounted
## Sample a union of swept paths and clip its edge. Shared grid vertices leave
## no stacked surfaces where two strokes meet. Positive values lie in worn soil.

const STEP: float = 0.25
const CORNERS: Array[Vector2i] = [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.ONE, Vector2i.DOWN]


static func include(samples: Dictionary, segments: Array, width: float) -> void:
	var radius: float = width * 0.43
	var padding: Vector2 = Vector2.ONE * (radius + STEP * 1.6)
	for segment: Array in segments:
		var a: Vector2 = segment[0]
		var b: Vector2 = segment[1]
		if a.distance_squared_to(b) < 0.000001:
			continue
		var lo: Vector2i = Vector2i(((a.min(b) - padding) / STEP).floor())
		var hi: Vector2i = Vector2i(((a.max(b) + padding) / STEP).ceil())
		for z: int in range(lo.y, hi.y + 1):
			for x: int in range(lo.x, hi.x + 1):
				var key: Vector2i = Vector2i(x, z)
				var p: Vector2 = Vector2(key) * STEP
				var nearest: Vector2 = Geometry2D.get_closest_point_to_segment(p, a, b)
				var value: float = radius - p.distance_to(nearest)
				samples[key] = maxf(samples.get(key, -INF), value)


static func draw(
	builder: BuildingGeometry, samples: Dictionary, field: TerrainField, blocked: Callable
) -> void:
	var cells: Dictionary = {}
	for key: Vector2i in samples:
		var p: Vector2 = Vector2(key) * STEP
		# Small coves in the soil edge let turf interrupt an otherwise perfect ribbon.
		samples[key] += (
			0.071 * sin(p.x * 4.5 + 0.9 * sin(p.y * 3.1)) + 0.038 * sin(p.y * 6.2 - p.x * 2.7)
		)
		if samples[key] >= 0:
			for corner: Vector2i in CORNERS:
				cells[key - corner] = true
	var keys: Array = cells.keys()
	keys.sort()
	for cell: Vector2i in keys:
		var vertices: Array[Vector3] = []
		for corner: Vector2i in CORNERS:
			var key: Vector2i = cell + corner
			# Store signed distance in Y until each clipped triangle reaches the ground.
			vertices.append(Vector3(key.x * STEP, samples.get(key, -STEP), key.y * STEP))
		_clip(builder, [vertices[0], vertices[1], vertices[2]], field, blocked)
		_clip(builder, [vertices[0], vertices[2], vertices[3]], field, blocked)


static func _clip(
	builder: BuildingGeometry, triangle: Array[Vector3], field: TerrainField, blocked: Callable
) -> void:
	var rim: Array[Vector3] = []
	var samples: Array[float] = []
	for i: int in 3:
		var a: Vector3 = triangle[i]
		var b: Vector3 = triangle[(i + 1) % 3]
		if a.y >= 0:
			rim.append(a)
		if (a.y > 0 and b.y < 0) or (a.y < 0 and b.y > 0):
			rim.append(a.lerp(b, a.y / (a.y - b.y)))
	if rim.size() < 3:
		return
	for i: int in rim.size():
		var p: Vector2 = Vector2(rim[i].x, rim[i].z)
		if blocked.call(p):
			return
		samples.append(smoothstep(0.0, 0.26, rim[i].y))
		rim[i].y = field.height_at(p) + 0.014
	for i: int in range(1, rim.size() - 1):
		var offset: int = builder._vertices.size()
		builder._triangle(rim[0], rim[i], rim[i + 1], Vector3.UP, Color.WHITE)
		for index: int in range(offset, builder._vertices.size()):
			var v: Vector3 = builder._vertices[index]
			var sample_index: int = 0 if v == rim[0] else (i if v == rim[i] else i + 1)
			var shade: float = 0.035 * sin(v.x * 3.2 + v.z * 2.4)
			var tint: Color = (
				Color("a6b17a").lerp(Color("b79b76"), samples[sample_index]).lightened(shade)
			)
			tint.a = samples[sample_index]
			builder._colors[index] = tint
