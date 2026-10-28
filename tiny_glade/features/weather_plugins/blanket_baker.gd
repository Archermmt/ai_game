class_name BlanketBaker
extends RefCounted
## Runs upstream Blanket's bevel/extrusion passes through owned 4.7 storage buffers.


static func bake(
	source: ArrayMesh, depth: float = 0.18, pose: Transform3D = Transform3D.IDENTITY
) -> ArrayMesh:
	if DisplayServer.get_name() == "headless" or RenderingServer.get_rendering_device() == null:
		return null
	BlanketShaders.initialize()
	var working: ArrayMesh = ArrayMesh.new()
	working.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, source.surface_get_arrays(0))
	var pipeline: BlanketPipeline = BlanketPipeline.new(working, 0, pose)
	pipeline.params.depth = depth
	pipeline.params.max_slope_degrees = 70.0
	pipeline.bake()

	var result: ArrayMesh
	if not pipeline.params.is_out_mesh_empty:
		result = _read_mesh(pipeline)
	# Pass destructors release their own sets/scratch storage. Bridge storage is ours.
	if pipeline.sets.out_mesh.is_valid():
		pipeline.rd.free_rid(pipeline.sets.out_mesh)
		pipeline.sets.out_mesh = RID()
	pipeline.select_passes.clear()
	pipeline.build_passes.clear()
	pipeline.update_passes.clear()
	pipeline.sets = null
	pipeline.surface.release_bridge()
	pipeline = null
	return result


static func _read_mesh(pipeline: BlanketPipeline) -> ArrayMesh:
	var params: BlanketParams = pipeline.params
	var device: RenderingDevice = pipeline.rd
	var surface: BlanketSurface = pipeline.surface
	var vertex_data: PackedByteArray = device.buffer_get_data(
		surface.bridge_buffer(surface.idx, "vertex_data")
	)
	var index_data: PackedByteArray = device.buffer_get_data(
		surface.bridge_buffer(surface.idx, "index_data")
	)
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var indices: PackedInt32Array = PackedInt32Array()
	for index: int in params.out_vertex_count:
		var at: int = index * params.out_vertex_stride
		vertices.append(
			Vector3(
				vertex_data.decode_float(at),
				vertex_data.decode_float(at + 4),
				vertex_data.decode_float(at + 8)
			)
		)
		var normal_at: int = params.out_normal_offset + index * params.out_normal_stride
		var encoded: Vector2 = (
			Vector2(vertex_data.decode_u16(normal_at), vertex_data.decode_u16(normal_at + 2))
			/ 65535.0
		)
		normals.append(Vector3.octahedron_decode(encoded))
	for index: int in params.out_index_count:
		indices.append(
			(
				index_data.decode_u32(index * 4)
				if params.out_index_stride == 4
				else index_data.decode_u16(index * 2)
			)
		)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	var used: Dictionary = {}
	var compact_vertices: PackedVector3Array = PackedVector3Array()
	var compact_normals: PackedVector3Array = PackedVector3Array()
	for index: int in indices.size():
		var original: int = indices[index]
		if original < 0 or original >= vertices.size():
			push_error("Blanket output index outside allocated vertex storage")
			return null
		if not used.has(original):
			used[original] = compact_vertices.size()
			compact_vertices.append(vertices[original])
			compact_normals.append(normals[original])
		indices[index] = used[original]
	arrays[Mesh.ARRAY_VERTEX] = compact_vertices
	arrays[Mesh.ARRAY_NORMAL] = compact_normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var result: ArrayMesh = ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result
