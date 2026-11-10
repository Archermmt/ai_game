extends RefCounted
## Retain pick geometry independently of render batches, which can merge several
## houses into a single draw. Create triangle acceleration data only on demand.
var chunks: Dictionary = {}

func clear_chunk(chunk: Vector2i) -> void:
	chunks.erase(chunk)

func register(chunk: Vector2i, anchor: Vector2i, node: Node3D) -> void:
	var parts: Array = []
	var bounds := AABB()
	for leaf: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		if leaf.mesh == null or not leaf.is_visible_in_tree() or leaf.is_in_group("island_smoke"):
			continue
		var pose := leaf.global_transform
		var box: AABB = pose * leaf.mesh.get_aabb()
		bounds = box if parts.is_empty() else bounds.merge(box)
		parts.append({"box": box, "inverse": pose.affine_inverse(), "mesh": leaf.mesh})
	if parts.is_empty():
		return
	if not chunks.has(chunk):
		chunks[chunk] = []
	chunks[chunk].append({"box": bounds, "anchor": anchor, "parts": parts})

func closest(origin: Vector3, direction: Vector3, max_distance: float) -> Vector2i:
	var nearest := max_distance
	var selected := Vector2i(-1, -1)
	for buildings: Array in chunks.values():
		for building in buildings:
			if building.box.intersects_ray(origin, direction) == null:
				continue
			for part in building.parts:
				if part.box.intersects_ray(origin, direction) == null:
					continue
				var inverse: Transform3D = part.inverse
				var local_start := inverse * origin
				var local_dir := inverse.basis * direction
				var triangles: TriangleMesh = part.mesh.generate_triangle_mesh()
				if triangles == null:
					continue
				var hit := triangles.intersect_segment(local_start, local_start + local_dir * nearest)
				if not hit.is_empty():
					nearest = local_start.distance_to(hit.position) / local_dir.length()
					selected = building.anchor
	return selected
