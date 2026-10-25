class_name LandscapeTerrainAdapter
extends Node3D
## The artist heightfield is source data; Terrain3D owns only its derived view.

signal configured

const SOURCE_ORIGIN: Vector2 = Vector2(-32.0, -32.0)
const VERTEX_SPACING: float = 0.25
const SOURCE_SPACING: float = 64.0 / 255.0
const SOIL_TEXTURE: Texture2D = preload("res://assets/materials/art_pass_01/warm_soil.png")
const MEADOW_TEXTURE: Texture2D = preload("res://assets/materials/art_pass_01/meadow.png")
const TEXTURE_SIZE: int = 512

var terrain: Terrain3D
var height_image: Image
var color_image: Image
var data_ready: bool = false
var last_error: String = ""
var relief_scale: float = 1.0
var _source_height: Image


func _ready() -> void:
	if is_instance_valid(terrain) and not data_ready:
		_publish_maps()


func configure(source: Image, colormap: Image = null) -> void:
	if source == null or source.is_empty() or source.get_size() != Vector2i(256, 256):
		last_error = "Valley terrain requires a 256 by 256 source height image."
		push_error(last_error)
		return
	_source_height = source.duplicate() as Image
	_source_height.convert(Image.FORMAT_RF)
	height_image = _resample_height()
	color_image = _prepare_color(colormap)
	if is_instance_valid(terrain):
		terrain.free()
	data_ready = false
	last_error = ""
	terrain = Terrain3D.new()
	terrain.name = "ValleyTerrain"
	terrain.transform = Transform3D.IDENTITY
	terrain.vertex_spacing = VERTEX_SPACING
	# Dynamic assets have no resource path for the plugin to reload at startup.
	terrain.free_editor_textures = false
	terrain.collision_mode = 0
	terrain.mesh_size = 64
	terrain.mesh_lods = 5
	terrain.material = _create_material()
	terrain.assets = _create_assets()
	add_child(terrain)
	if is_inside_tree():
		_publish_maps()


func set_relief(scale_value: float) -> void:
	if _source_height == null:
		return
	relief_scale = clampf(scale_value, 0.0, 2.0)
	height_image = _resample_height()
	if is_inside_tree() and is_instance_valid(terrain):
		_publish_maps()


func sample_surface(point: Vector2) -> Dictionary:
	if height_image == null or not _inside_source(point):
		return {"height": NAN, "normal": Vector3.UP, "allowed": false}
	var height: float = _sample_image(point)
	var normal: Vector3 = _sample_normal(point, height)
	if data_ready and is_instance_valid(terrain):
		var position: Vector3 = Vector3(point.x, 0, point.y)
		height = terrain.data.get_height(position)
		var native_normal: Vector3 = terrain.data.get_normal(position)
		if native_normal.is_finite():
			normal = native_normal
	return {"height": height, "normal": normal, "allowed": is_finite(height)}


func set_camera(camera: Camera3D) -> void:
	if is_instance_valid(terrain):
		terrain.set_camera(camera)


func _publish_maps() -> void:
	if height_image == null or not is_instance_valid(terrain):
		return
	# The public region-size setter operates on initialized native data. Calling
	# it before entering World3D leaves the plugin at its 256-pixel default.
	terrain.region_size = Terrain3D.SIZE_128
	terrain.material.set_shader_param("auto_base_texture", 0)
	terrain.material.set_shader_param("auto_overlay_texture", 1)
	terrain.material.set_shader_param("auto_slope", 1.35)
	terrain.material.set_shader_param("auto_height_reduction", 0.0)
	# Control pixels are uint32 bits stored in RF memory. Bit zero enables the
	# plugin's automatic slope blend. Color(1, 0, 0) would encode the wrong bits.
	var controls: PackedByteArray = PackedByteArray()
	controls.resize(height_image.get_width() * height_image.get_height() * 4)
	for offset: int in range(0, controls.size(), 4):
		controls.encode_u32(offset, 1)
	var control_image: Image = Image.create_from_data(256, 256, false, Image.FORMAT_RF, controls)
	var maps: Array[Image] = [height_image, control_image, color_image]
	terrain.data.import_images(maps, Vector3(SOURCE_ORIGIN.x, 0, SOURCE_ORIGIN.y), 0.0, 1.0)
	terrain.data.calc_height_range(true)
	data_ready = terrain.data.get_region_count() == 4
	if not data_ready:
		last_error = "Terrain3D did not import the four Valley heightfield regions."
		push_error(last_error)
		return
	configured.emit()


func _create_material() -> Terrain3DMaterial:
	var result: Terrain3DMaterial = Terrain3DMaterial.new()
	result.world_background = Terrain3DMaterial.NONE
	result.auto_shader = true
	result.texture_filtering = Terrain3DMaterial.LINEAR
	return result


func _create_assets() -> Terrain3DAssets:
	var result: Terrain3DAssets = Terrain3DAssets.new()
	result.set_texture(0, _texture_asset(SOIL_TEXTURE, "Exposed soil", Color(0.40, 0.38, 0.31)))
	result.set_texture(1, _texture_asset(MEADOW_TEXTURE, "Painted meadow", Color(0.62, 0.69, 0.43)))
	return result


func _texture_asset(texture: Texture2D, label: String, tint: Color) -> Terrain3DTextureAsset:
	var asset: Terrain3DTextureAsset = Terrain3DTextureAsset.new()
	asset.name = label
	var albedo: Image = texture.get_image()
	if albedo.is_compressed():
		albedo.decompress()
	albedo.convert(Image.FORMAT_RGBA8)
	albedo.resize(TEXTURE_SIZE, TEXTURE_SIZE, Image.INTERPOLATE_LANCZOS)
	# This project's painted RGB maps do not contain Terrain3D's height channel.
	# Supply a neutral value rather than treating opaque alpha as maximum relief.
	for z: int in range(TEXTURE_SIZE):
		for x: int in range(TEXTURE_SIZE):
			var pixel: Color = albedo.get_pixel(x, z)
			pixel.a = 0.5
			albedo.set_pixel(x, z, pixel)
	albedo.generate_mipmaps()
	asset.albedo_texture = ImageTexture.create_from_image(albedo)
	asset.albedo_color = tint
	asset.uv_scale = 0.38
	asset.detiling_rotation = 0.35
	asset.detiling_shift = 0.12
	asset.normal_depth = 0.0
	asset.ao_strength = 0.0
	var normal: Image = Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	normal.fill(Color(0.5, 0.5, 1.0, 0.94))
	normal.generate_mipmaps()
	asset.normal_texture = ImageTexture.create_from_image(normal)
	return asset


func _prepare_color(source: Image) -> Image:
	if source != null and not source.is_empty():
		var result: Image = source.duplicate() as Image
		if result.is_compressed():
			result.decompress()
		result.convert(Image.FORMAT_RGBA8)
		result.resize(256, 256, Image.INTERPOLATE_BILINEAR)
		return result
	var result: Image = Image.create(256, 256, false, Image.FORMAT_RGBA8)
	result.fill(Color(1.0, 1.0, 1.0, 0.5))
	return result


func _inside_source(point: Vector2) -> bool:
	var uv: Vector2 = (point - SOURCE_ORIGIN) / VERTEX_SPACING
	return uv.x >= 0.0 and uv.y >= 0.0 and uv.x <= 255.0 and uv.y <= 255.0


func _resample_height() -> Image:
	# The Blender raster includes both -32 and +32 endpoints (64 / 255 m).
	# Terrain3D regions start on its global integer grid. Sampling that source
	# at the aligned .25 m grid avoids a silent half-pixel import translation.
	var result: Image = Image.create(256, 256, false, Image.FORMAT_RF)
	for z: int in range(256):
		for x: int in range(256):
			var grid: Vector2 = Vector2(x, z) * VERTEX_SPACING / SOURCE_SPACING
			var height: float = _bilinear(_source_height, grid) * relief_scale
			result.set_pixel(x, z, Color(height, 0, 0, 1))
	return result


func _sample_image(point: Vector2) -> float:
	var grid: Vector2 = (point - SOURCE_ORIGIN) / VERTEX_SPACING
	grid = grid.clamp(Vector2.ZERO, Vector2.ONE * 255.0)
	# Match Terrain3D's near-vertex shortcut as well as its bilinear interior.
	if point.distance_squared_to(point.snapped(Vector2.ONE * VERTEX_SPACING)) < 0.0001:
		return height_image.get_pixelv(Vector2i(grid.floor())).r
	return _bilinear(height_image, grid)


func _bilinear(image: Image, grid: Vector2) -> float:
	var cell: Vector2i = Vector2i(grid.floor())
	var next: Vector2i = (cell + Vector2i.ONE).clamp(Vector2i.ZERO, Vector2i(255, 255))
	var fraction: Vector2 = grid - Vector2(cell)
	var low: float = lerpf(
		image.get_pixel(cell.x, cell.y).r, image.get_pixel(next.x, cell.y).r, fraction.x
	)
	var high: float = lerpf(
		image.get_pixel(cell.x, next.y).r, image.get_pixel(next.x, next.y).r, fraction.x
	)
	return lerpf(low, high, fraction.y)


func _sample_normal(point: Vector2, height: float) -> Vector3:
	# Terrain3D uses forward differences at the vertex spacing for CPU normals.
	var east: float = _sample_image(point + Vector2(VERTEX_SPACING, 0))
	var south: float = _sample_image(point + Vector2(0, VERTEX_SPACING))
	return Vector3(height - east, VERTEX_SPACING, height - south).normalized()
