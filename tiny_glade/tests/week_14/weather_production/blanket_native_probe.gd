extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var source: ArrayMesh = ArrayMesh.new()
	source.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, BoxMesh.new().surface_get_arrays(0))
	var result: ArrayMesh = BlanketBaker.bake(source, 0.25)
	var ok: bool = result != null and result.get_surface_count() == 1
	if ok:
		print("BLANKET_BOUNDS ", result.get_aabb())
		var arrays: Array = result.surface_get_arrays(0)
		var low: float = INF
		var high: float = -INF
		for at: int in arrays[Mesh.ARRAY_INDEX]:
			low = minf(low, arrays[Mesh.ARRAY_VERTEX][at].y)
			high = maxf(high, arrays[Mesh.ARRAY_VERTEX][at].y)
		print("INDEXED_CAP_RANGE ", low, " ", high)
		ok = high > 0.65 and low >= 0.45 and arrays[Mesh.ARRAY_INDEX].size() > 6
	print("BLANKET_COMPATIBILITY ", ok)
	result = null
	BlanketShaders.shutdown()
	for index: int in 5:
		await process_frame
	quit(0 if ok else 1)
