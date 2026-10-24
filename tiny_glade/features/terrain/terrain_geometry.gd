class_name TerrainGeometry
extends RefCounted
## Pure arrays in the worker; shared border positions/normals from global samples.


static func chunk(field: TerrainField, origin: Vector2, size: float = 8.0) -> Array:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	var cells: int = roundi(size / field.spacing)
	for z: int in range(cells + 1):
		for x: int in range(cells + 1):
			var point: Vector2 = origin + Vector2(x, z) * field.spacing
			var normal: Vector3 = field.normal_at(point)
			vertices.append(Vector3(point.x, field.height_at(point), point.y))
			normals.append(normal)
			uvs.append(point / 4.0)
			var wet: float = 0.0
			if not field.pool.is_empty():
				wet = 1.0 - smoothstep(-0.2, 0.75, PondShape.distance(field.pool, point))
			colors.append(Color(clampf((1.0 - normal.y) * 3.0, 0, 1), wet, 0, 1))
	for z: int in range(cells):
		for x: int in range(cells):
			var a: int = z * (cells + 1) + x
			indices.append_array(
				PackedInt32Array([a, a + 1, a + cells + 1, a + 1, a + cells + 2, a + cells + 1])
			)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	return arrays
