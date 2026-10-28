class_name PhotoExport
extends Node
## A separate render target shares only the editor's World3D, never its UI.

signal camera_created(camera: Camera3D)
signal camera_releasing(camera: Camera3D)

const SIZES: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(2560, 1440)]
var busy: bool = false


static func safe_title(title: String) -> String:
	var clean: String = title.strip_edges().validate_filename().left(64)
	return "林间作品" if clean.is_empty() or clean in [".", ".."] else clean


static func output_path(directory: String, title: String) -> String:
	var stamp: String = Time.get_datetime_string_from_system().replace(":", "-")
	return directory.path_join("%s_%s_%d.png" % [safe_title(title), stamp, Time.get_ticks_usec()])


func capture(source: Camera3D, dimensions: Vector2i, destination: String) -> Dictionary:
	if busy:
		return {"ok": false, "error": "busy"}
	if dimensions not in SIZES and dimensions != Vector2i(512, 288):
		return {"ok": false, "error": "invalid_size"}
	if DisplayServer.get_name() == "headless":
		return {"ok": false, "error": "renderer_required"}
	if not DirAccess.dir_exists_absolute(destination.get_base_dir()):
		return {"ok": false, "error": "directory_missing"}
	busy = true
	var viewport: SubViewport = SubViewport.new()
	viewport.size = dimensions
	viewport.world_3d = source.get_world_3d()
	viewport.transparent_bg = false
	viewport.msaa_3d = source.get_viewport().msaa_3d
	viewport.use_taa = source.get_viewport().use_taa
	viewport.screen_space_aa = source.get_viewport().screen_space_aa
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var camera: Camera3D = Camera3D.new()
	camera.transform = source.global_transform
	camera.fov = source.fov
	camera.near = source.near
	camera.far = source.far
	camera.cull_mask = source.cull_mask
	camera.environment = source.environment
	camera.attributes = source.attributes
	viewport.add_child(camera)
	camera.current = true
	camera_created.emit(camera)
	var settle_frames: int = 32 if camera.compositor != null else (8 if viewport.use_taa else 2)
	for frame: int in range(settle_frames):
		await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	var error: Error = image.save_png(destination)
	camera_releasing.emit(camera)
	await RenderingServer.frame_post_draw
	viewport.free()
	busy = false
	return {
		"ok": error == OK, "error": error_string(error), "path": destination, "size": dimensions
	}
