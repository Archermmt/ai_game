class_name WoodlandGrasses
extends RefCounted
## Four original bentgrass, sedge, flower and turf meshes. We fold each leaf along
## its midrib, so grass keeps a silhouette from above as well as at eye level.

const NAMES: Array[String] = ["Bentgrass", "WoodSedge", "MeadowStars", "ShortSward"]
const LEAVES: Array[int] = [12, 8, 6, 11]
const HEIGHTS: Array[float] = [0.36, 0.25, 0.22, 0.11]
const WIDTHS: Array[float] = [0.023, 0.042, 0.026, 0.028]
const SPREAD: Array[float] = [0.20, 0.16, 0.12, 0.25]


static func make(kind: int) -> ArrayMesh:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 62832 + kind
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index: int in LEAVES[kind]:
		var angle: float = index * 2.39996 + rng.randf_range(-0.21, 0.21)
		var out: Vector3 = Vector3(cos(angle), 0, sin(angle))
		var side: Vector3 = Vector3(-out.z, 0, out.x) * WIDTHS[kind] * rng.randf_range(0.75, 1.2)
		var height: float = HEIGHTS[kind] * rng.randf_range(0.55, 1.18)
		var spread: float = SPREAD[kind] * rng.randf_range(0.65, 1.12)
		var base: Vector3 = out * spread * rng.randf_range(0.05, 0.65)
		var mid: Vector3 = base + Vector3.UP * height * 0.64 + out * spread * 0.24
		var ridge: Vector3 = mid - out * side.length() * 0.45
		var tip: Vector3 = base + Vector3.UP * height + out * spread
		var pale: float = rng.randf_range(0.2, 0.9)
		for point: Vector3 in [
			base,
			mid - side,
			ridge,
			base,
			ridge,
			mid + side,
			mid - side,
			tip,
			ridge,
			ridge,
			tip,
			mid + side
		]:
			surface.set_color(Color(clampf(point.y / height, 0.0, 1.0), 0, pale))
			surface.add_vertex(point)
	if kind == 2:
		for index: int in 3:
			var angle: float = rng.randf_range(0.0, TAU)
			var out: Vector3 = Vector3(cos(angle), 0, sin(angle))
			var center: Vector3 = (
				Vector3.UP * rng.randf_range(0.22, 0.34) + out * (0.07 + 0.05 * index)
			)
			var across: Vector3 = Vector3(-out.z, 0.0, out.x)
			for point: Vector3 in [
				center * Vector3(1, 0, 1) - across * 0.009,
				center,
				center * Vector3(1, 0, 1) + across * 0.009
			]:
				surface.set_color(Color(point.y / center.y, 0, 0.32))
				surface.add_vertex(point)
			for petal: int in 5:
				var direction: Vector3 = out.rotated(Vector3.UP, float(petal) * TAU / 5.0)
				var rim: Vector3 = direction * 0.044
				var side: Vector3 = direction.cross(Vector3.UP) * 0.021
				var middle: Vector3 = center + rim * 0.60 + Vector3.UP * 0.012
				for point: Vector3 in [
					center, middle - side, middle + side, middle - side, center + rim, middle + side
				]:
					surface.set_color(Color(1, 1, 1 if point == center else 0))
					surface.add_vertex(point)
	surface.generate_normals()
	surface.index()
	var result: ArrayMesh = surface.commit()
	result.resource_name = NAMES[kind]
	return result
