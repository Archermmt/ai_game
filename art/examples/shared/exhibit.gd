extends Node3D

const CASES := ["street/street", "examples/island/island", "examples/cabin/cabin", "examples/desert/desert", "examples/lava/lava"]
@export var focus_point := Vector3.ZERO
@export var camera_node: NodePath = ^"Camera3D"
@onready var camera: Camera3D = get_node(camera_node)
var initial: Transform3D
var orbiting := false
var automated := false

func _ready() -> void:
	initial = camera.transform
	var args := OS.get_cmdline_user_args()
	if "--no-ink" in args and camera.has_node("Linework"):
		camera.get_node("Linework").hide()
	if "--aa=off" in args:
		get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	elif "--aa=taa" in args:
		get_viewport().msaa_3d = Viewport.MSAA_DISABLED
		get_viewport().use_taa = true
	for arg in args:
		if arg.begins_with("--azimuth="):
			_orbit(deg_to_rad(arg.trim_prefix("--azimuth=").to_float()),0.0)
	for arg in args:
		if arg.begins_with("--capture="):
			automated = true
			_capture.call_deferred(arg.trim_prefix("--capture="))
		elif arg.begins_with("--benchmark="):
			automated = true
			_benchmark.call_deferred(arg.trim_prefix("--benchmark="))

func _unhandled_input(event: InputEvent) -> void:
	if automated:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			orbiting = event.pressed
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var arm := camera.position-focus_point
			var factor := .92 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.087
			camera.position = focus_point+arm.normalized()*clampf(arm.length()*factor,(initial.origin-focus_point).length()*.50,(initial.origin-focus_point).length()*1.65)
	elif event is InputEventMouseMotion and orbiting:
		_orbit(-event.relative.x*.004, -event.relative.y*.003)
	elif event is InputEventKey and event.pressed and event.keycode in [KEY_R, KEY_HOME]:
		camera.transform = initial

	elif event is InputEventKey and event.pressed and not event.echo and event.keycode >= KEY_1 and event.keycode <= KEY_5:
		var path := "res://%s.tscn" % CASES[event.keycode - KEY_1]
		if ResourceLoader.exists(path):
			get_tree().change_scene_to_file(path)

func _orbit(yaw: float, pitch: float) -> void:
	var arm := camera.position-focus_point
	var elevation := asin(arm.normalized().y)
	pitch = clampf(elevation+pitch, deg_to_rad(-12.),deg_to_rad(76.))-elevation
	var rot := Basis(Vector3.UP,yaw)*Basis(camera.basis.x.normalized(),-pitch)
	camera.position = focus_point+rot*arm
	camera.basis = rot*camera.basis

func _capture(path: String) -> void:
	for i in 12:
		await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var absolute := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var error := img.save_png(absolute)
	print("CAPTURE ",path," ", img.get_size()," status=",error)
	get_tree().quit(0 if error == OK else 1)

func _benchmark(path: String) -> void:
	var timings: Array[float] = []
	var sweep := "--bench-motion" in OS.get_cmdline_user_args()
	var last_angle := 0.0
	for i in 30:
		await get_tree().process_frame
	var drawn := Engine.get_frames_drawn()
	print("Benchmark measuring rendered frames for 30 seconds")
	var start := Time.get_ticks_usec()
	var prev := start
	while Time.get_ticks_usec()-start < 30100000:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		timings.append(float(now-prev)/1000.)
		if sweep:
			var angle := deg_to_rad(8.0)*sin(float(now-start)/1000000.*0.38)
			_orbit(angle-last_angle,0.0)
			last_angle = angle
		prev = now
	timings.sort()
	var report := {
		"gpu":RenderingServer.get_video_adapter_name(),"backend":RenderingServer.get_current_rendering_driver_name(),
		"camera_motion":sweep,"viewport":str(get_viewport().get_visible_rect().size),"msaa_3d":get_viewport().msaa_3d,
		"samples":timings.size(),"duration_s":float(prev-start)/1000000.,
		"frames_drawn":Engine.get_frames_drawn()-drawn,
		"fps":(Engine.get_frames_drawn()-drawn)*1000000./float(prev-start),"median_ms":timings[timings.size()/2],
		"p95_ms":timings[int(timings.size()*.95)],"max_ms":timings.back(),
		"draw_calls":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)}
	var f := FileAccess.open(path,FileAccess.WRITE)
	f.store_string(JSON.stringify(report,"  "))
	print("BENCHMARK ",report)
	get_tree().quit()
