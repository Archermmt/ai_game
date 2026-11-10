extends SubViewport
## The same edited island, seen from the eye reflected under the lake surface.
## Only this camera omits the water and the placement cursor.
const WATER_LAYER := 1 << 18
const CURSOR_LAYER := 1 << 19
var eye := Camera3D.new()
var previous_clip := Projection()
var last_draw := -1.0
var last_wall_usec := 0
var previous_pose := Transform3D.IDENTITY
var drawing_geometry := false
var refresh := true

func _ready() -> void:
	disable_3d = false
	gui_disable_input = true
	transparent_bg = true
	render_target_update_mode = UPDATE_DISABLED
	positional_shadow_atlas_size = 0
	add_child(eye)
	eye.current = true

func reflect_view(source: Camera3D, water: MeshInstance3D, clock: float) -> void:
	if source == null:
		return
	# At overview scale, a few shoreline pixels carry the reflection. Fade to
	# a height-field shore shadow instead of drawing the entire scene again.
	var detail := 1.0 - smoothstep(26.0, 40.0, source.size)
	water.material_override.set_shader_parameter("reflection_detail", detail)
	if detail <= 0.0:
		if drawing_geometry:
			drawing_geometry = false
			refresh = true
			render_target_update_mode = UPDATE_DISABLED
			water.material_override.set_shader_parameter("has_reflection", false)
		return
	drawing_geometry = true
	var frame: Vector2 = source.get_viewport().get_visible_rect().size
	if frame.x < 2 or frame.y < 2:
		return
	var target := Vector2i((frame * minf(0.5, 768.0 / frame.x)).round())
	target = target.max(Vector2i(2, 2))
	if size != target:
		size = target
		refresh = true
	var source_pose := source.get_camera_transform()
	var normal := Vector3.UP
	var plane_height := water.global_position.y
	var pose := Transform3D(
			Basis(-source_pose.basis.x.bounce(normal), source_pose.basis.y.bounce(normal), source_pose.basis.z.bounce(normal)),
			Vector3(source_pose.origin.x, 2.0 * plane_height - source_pose.origin.y, source_pose.origin.z))
	eye.global_transform = pose
	eye.projection = source.projection
	eye.keep_aspect = source.keep_aspect
	eye.size = source.size
	eye.fov = source.fov
	eye.far = source.far
	eye.near = source.near
	eye.cull_mask = source.cull_mask & ~(WATER_LAYER | CURSOR_LAYER)
	var clip := eye.get_camera_projection() * Projection(pose.affine_inverse())
	if not refresh:
		if clip == previous_clip and clock >= last_draw and clock - last_draw < 0.12:
			return
		# Keep the texture projected with the exact pose that produced it.
		# Tiny movements can share a frame while a large pan redraws at once.
		if clip != previous_clip and Time.get_ticks_usec() - last_wall_usec < 33333 and previous_pose.origin.distance_squared_to(pose.origin) < 0.09 and previous_pose.basis.z.dot(pose.basis.z) > 0.9999:
			return
	last_wall_usec = Time.get_ticks_usec()
	previous_pose = pose
	last_draw = clock
	previous_clip = clip
	refresh = false
	render_target_update_mode = UPDATE_ONCE
	water.material_override.set_shader_parameter("reflected_clip", clip)
	water.material_override.set_shader_parameter("has_reflection", true)
