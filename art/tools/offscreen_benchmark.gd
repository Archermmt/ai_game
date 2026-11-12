extends SceneTree
## An uncapped serialized Metal render/readback test, independent of window presentation.
## godot --path . --disable-render-loop --script tools/offscreen_benchmark.gd -- --case=street
## Output: captures/<case>/offscreen_benchmark.json. --seconds= defaults to 30.

const SIZE := Vector2i(1704, 960)
const CASES := {
	"street": "res://street/street.tscn",
	"cabin": "res://examples/cabin/cabin.tscn",
	"island": "res://examples/island/island.tscn",
	"desert": "res://examples/desert/desert.tscn",
	"lava": "res://examples/lava/lava.tscn"
}
var case_name := "street"
var seconds := 30.0
var port := SubViewport.new()
var camera: Camera3D
var initial: Transform3D
var focus: Vector3


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--case="):
			case_name = arg.trim_prefix("--case=")
		elif arg.begins_with("--seconds="):
			seconds = clampf(arg.trim_prefix("--seconds=").to_float(), 1.0, 300.0)
	run.call_deferred()


func run() -> void:
	if not CASES.has(case_name) or RenderingServer.get_rendering_device() == null:
		push_error("Select a known case and a hardware RenderingDevice backend.")
		quit(1)
		return
	if RenderingServer.render_loop_enabled:
		push_error("Run with --disable-render-loop to isolate manual draws.")
		quit(1)
		return
	Engine.max_fps = 0
	root.disable_3d = true
	port.size = SIZE
	port.msaa_3d = Viewport.MSAA_4X
	port.world_3d = World3D.new()
	port.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(port)
	var packed: PackedScene = load(CASES[case_name])
	if packed == null:
		push_error("Could not load the requested scene")
		quit(1)
		return
	var stage: Node3D = packed.instantiate()
	port.add_child(stage)
	await process_frame
	await process_frame
	camera = port.get_camera_3d()
	if camera == null:
		push_error("The scene did not activate a 3D camera in its own viewport.")
		quit(1)
		return
	initial = camera.global_transform
	focus = stage.get("focus_point")
	for idx in 16:
		draw_completed_frame(idx * 0.006)
	RenderingServer.force_sync()
	var total_ms: Array[float] = []
	var draw_ms: Array[float] = []
	var copy_ms: Array[float] = []
	var samples: Array[int] = []
	var varied_samples := {}
	var luma_span := 0.0
	var started := Time.get_ticks_usec()
	var begin_engine_frames := Engine.get_frames_drawn()
	while Time.get_ticks_usec() - started < 1000000.0 * seconds:
		var before := Time.get_ticks_usec()
		var delta_angle := deg_to_rad(8.0) * sin((before-started) / 1000000.0 * 0.52)
		move_camera(delta_angle)
		RenderingServer.force_draw(false, 1.0 / 60.0)
		var submitted := Time.get_ticks_usec()
		var completed := port.get_texture().get_image()
		var finished := Time.get_ticks_usec()
		if completed == null or completed.get_size() != SIZE:
			push_error("GPU readback failed or returned an unexpected size")
			quit(1)
			return
		total_ms.append((finished-before) / 1000.0)
		draw_ms.append((submitted-before) / 1000.0)
		copy_ms.append((finished-submitted) / 1000.0)
		if samples.is_empty() or total_ms.size() % 24 == 0:
			var row := sample_pixels(completed)
			var signature := int(row[0])
			samples.append(signature)
			varied_samples[signature] = true
			luma_span = maxf(luma_span, float(row[1]))
		# Let the host handle events. Overall wall time includes this yield.
		if total_ms.size() % 32 == 0:
			await process_frame
	var duration_s := (Time.get_ticks_usec() - started) / 1000000.0
	total_ms.sort()
	draw_ms.sort()
	copy_ms.sort()
	if varied_samples.size() < 2 or luma_span < 0.05:
		push_error("Sampled pixels do not demonstrate a visible moving 3D frame")
		quit(1)
		return
	var report := {
		"case": case_name, "scene": CASES[case_name], "engine": Engine.get_version_info().string,
		"backend": RenderingServer.get_current_rendering_driver_name(),
		"renderer": RenderingServer.get_current_rendering_method(), "gpu": RenderingServer.get_video_adapter_name(),
		"resolution": [SIZE.x,SIZE.y], "msaa_samples": 4, "warmup_draws": 16,
		"duration_s": duration_s, "completed_gpu_readbacks": total_ms.size(),
		"manual_draw_calls_to_force_draw": total_ms.size(),
		"engine_frames_drawn_delta": Engine.get_frames_drawn()-begin_engine_frames,
		"completed_readback_fps": total_ms.size() / duration_s,
		"frame_ms_median": percentile(total_ms,0.50), "frame_ms_p95": percentile(total_ms,0.95),
		"frame_ms_max": total_ms.back(), "submit_ms_median": percentile(draw_ms,0.5),
		"readback_ms_median": percentile(copy_ms,0.5), "sample_hashes": samples,
		"distinct_sample_hashes": varied_samples.size(), "max_sample_luminance_span": luma_span,
		"last_visible_draw_calls": port.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
		"last_shadow_draw_calls": port.get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
		"last_visible_primitives": port.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME),
		"method": "SubViewport UPDATE_ALWAYS. Camera oscillates +/-8 degrees. force_draw(false) and a full synchronous color readback for each counted frame. 24x-spaced signatures use 48 RGB samples; wall time includes occasional event yields. Pipeline overlap is deliberately suppressed by readback.",
		"scope": "Offscreen render plus transfer throughput for this view, including real shadow and post-processing costs. It does not measure desktop window presentation, latency or game-loop interaction."
	}
	var output := ProjectSettings.globalize_path("res://captures/%s/offscreen_benchmark.json" % case_name)
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		push_error("Cannot save report at " + output)
		quit(1)
		return
	file.store_string(JSON.stringify(report,"  ") + "\n")
	file.close()
	print("OFFSCREEN ",case_name," ",total_ms.size()," completed images in ",duration_s,"s; median/P95 ",report.frame_ms_median," / ",report.frame_ms_p95,"ms. ",output)
	quit(0)


func move_camera(angle: float) -> void:
	var spin := Basis(Vector3.UP, angle)
	camera.global_transform = Transform3D(spin * initial.basis, focus + spin * (initial.origin - focus))
	camera.force_update_transform()


func draw_completed_frame(angle: float) -> void:
	move_camera(angle)
	RenderingServer.force_draw(false,1.0/60.0)
	port.get_texture().get_image()


func sample_pixels(img: Image) -> Array:
	var pixels := PackedInt32Array()
	var lo := 1.0
	var hi := 0.0
	for row in 6:
		for col in 8:
			var color := img.get_pixel((col*2+1) * SIZE.x / 16,(row*2+1) * SIZE.y / 12)
			pixels.append(color.to_rgba32())
			lo = minf(lo,color.get_luminance())
			hi = maxf(hi,color.get_luminance())
	return [hash(pixels),hi-lo]


func percentile(sorted: Array[float], fraction: float) -> float:
	return sorted[clampi(ceili(sorted.size()*fraction)-1,0,sorted.size()-1)]
