class_name MeshParts
extends RefCounted


static func arrays(builder: BuildingGeometry) -> Array:
	var result: Array = []
	result.resize(Mesh.ARRAY_MAX)
	result[Mesh.ARRAY_VERTEX] = builder._vertices
	result[Mesh.ARRAY_NORMAL] = builder._normals
	result[Mesh.ARRAY_COLOR] = builder._colors
	result[Mesh.ARRAY_TEX_UV] = builder._uvs
	return result


static func box(builder: BuildingGeometry, center: Vector3, size: Vector3, tint: Color) -> void:
	if size.x <= 0.0001 or size.y <= 0.0001 or size.z <= 0.0001:
		return
	var p: Vector3 = center - size * 0.5
	var q: Vector3 = center + size * 0.5
	for face: Array in [
		[
			Vector3(p.x, p.y, q.z),
			Vector3(q.x, p.y, q.z),
			Vector3(q.x, q.y, q.z),
			Vector3(p.x, q.y, q.z),
			Vector3.BACK
		],
		[
			Vector3(q.x, p.y, p.z),
			Vector3(p.x, p.y, p.z),
			Vector3(p.x, q.y, p.z),
			Vector3(q.x, q.y, p.z),
			Vector3.FORWARD
		],
		[
			Vector3(q.x, p.y, q.z),
			Vector3(q.x, p.y, p.z),
			Vector3(q.x, q.y, p.z),
			Vector3(q.x, q.y, q.z),
			Vector3.RIGHT
		],
		[
			Vector3(p.x, p.y, p.z),
			Vector3(p.x, p.y, q.z),
			Vector3(p.x, q.y, q.z),
			Vector3(p.x, q.y, p.z),
			Vector3.LEFT
		],
		[
			Vector3(p.x, q.y, q.z),
			Vector3(q.x, q.y, q.z),
			Vector3(q.x, q.y, p.z),
			Vector3(p.x, q.y, p.z),
			Vector3.UP
		],
		[
			Vector3(p.x, p.y, p.z),
			Vector3(q.x, p.y, p.z),
			Vector3(q.x, p.y, q.z),
			Vector3(p.x, p.y, q.z),
			Vector3.DOWN
		]
	]:
		builder._quad(face[0], face[1], face[2], face[3], face[4], tint)
