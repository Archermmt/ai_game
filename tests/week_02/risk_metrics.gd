extends SceneTree
## Measurement only; hardware-dependent timings are evidence, never unit-test thresholds.


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1:
		quit(1)
		return
	var measurements: Array[Dictionary] = []
	for spacing: float in [0.25, 0.5]:
		var draft: Dictionary = WorldDocument.new().snapshot()
		WorldDocument.allocate_building(draft, Vector3.ZERO, Vector3(4, 3, 4))
		draft = TerrainField.pond(draft, Vector2(10, 6), 2.0)
		draft["terrain"]["spacing"] = spacing
		var start: int = Time.get_ticks_usec()
		var data: Dictionary = WorldRebuild.evaluate(draft)
		var evaluate_ms: float = float(Time.get_ticks_usec() - start) / 1000.0
		if not data["ok"]:
			quit(1)
			return
		var vertices: int = 0
		var triangles: int = 0
		for arrays: Array in data["terrain_arrays"]:
			vertices += arrays[Mesh.ARRAY_VERTEX].size()
			triangles += arrays[Mesh.ARRAY_INDEX].size() / 3
		start = Time.get_ticks_usec()
		var prepared: Dictionary = WorldRebuild.materialize(data)
		measurements.append(
			{
				"spacing_m": spacing,
				"chunks": prepared["terrain_meshes"].size(),
				"vertices": vertices,
				"triangles": triangles,
				"evaluate_ms": evaluate_ms,
				"headless_materialize_ms": float(Time.get_ticks_usec() - start) / 1000.0
			}
		)
	var file: FileAccess = FileAccess.open(args[0], FileAccess.WRITE)
	file.store_string(
		JSON.stringify(
			{
				"engine": Engine.get_version_info()["string"],
				"samples": measurements,
				"selected_spacing_m": 0.5,
				"note": "CPU/headless full-field sample; not GPU frame time"
			},
			"\t"
		)
	)
	file.close()
	print("RISK_METRICS_PASS")
	quit(0)
