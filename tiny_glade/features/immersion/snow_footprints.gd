class_name SnowFootprints
extends Node3D
## Built-in Decal surface impressions; no snow mesh or source document is changed.

const RECEIVER_LAYER: int = 1 << 17
const MAX_PRINTS: int = 96
const STEP_LENGTH: float = 0.65
const FOOT_OFFSET: float = 0.10
const LIFETIME: float = 24.0
const FADE_BEGIN: float = 10.0
const MIN_SNOW_COVER: float = 0.35
const MAX_CONTACT_GAP: float = 2.0
const PRINT_SIZE: Vector3 = Vector3(0.22, 0.30, 0.34)
const SOLE: Texture2D = preload("res://features/immersion/assets/snow_sole.svg")

var total_emitted: int = 0
var rejected_contacts: int = 0
var surface_offset: float = 0.0
var _surface: WalkSurface
var _blocked_segments: Array[Dictionary] = []
var _pool: Array[Decal] = []
var _available: Array[Decal] = []
var _records: Array[Dictionary] = []
var _albedos: Array[Texture2D] = []
var _normals: Array[Texture2D] = []
var _orm: Texture2D
var _previous: Vector3 = Vector3.ZERO
var _has_anchor: bool = false
var _distance_since_step: float = 0.0
var _left_next: bool = true


func configure(snapshot: Dictionary) -> void:
	clear()
	total_emitted = 0
	rejected_contacts = 0
	_surface = WalkSurface.new()
	_surface.configure(snapshot)
	_blocked_segments.clear()
	for path: Dictionary in snapshot.get("paths", []):
		var points: Array[Vector2] = PathCurve.sample(path)
		for index: int in range(points.size() - 1):
			_add_blocked_segment(points[index], points[index + 1], float(path["width"]), true)
	for collection: String in ["bridges", "stairs"]:
		for item: Dictionary in snapshot.get(collection, []):
			_add_blocked_segment(
				Vector2(item["a"][0], item["a"][1]),
				Vector2(item["b"][0], item["b"][1]),
				float(item["width"])
			)


func update_contact(
	feet: Vector3, yaw: float, active: bool, snow_cover: float, delta: float, frozen: bool = false
) -> void:
	if not active:
		clear()
		return
	if not is_finite(delta) or delta < 0 or _surface == null:
		return
	if frozen:
		# A moved photo camera must not draw a catch-up trail when time resumes.
		if feet.is_finite():
			_previous = feet
		return
	_age_prints(delta)
	if not is_finite(snow_cover) or snow_cover < MIN_SNOW_COVER:
		clear()
		return
	if not feet.is_finite() or not is_finite(yaw) or not is_inside_tree():
		_has_anchor = false
		return
	_advance_stride(feet, yaw)


func _advance_stride(feet: Vector3, yaw: float) -> void:
	if not _has_anchor:
		_previous = feet
		_has_anchor = true
		return
	var displacement: Vector3 = feet - _previous
	var travel: float = displacement.length()
	var cursor: Vector3 = _previous
	_previous = feet
	if travel > MAX_CONTACT_GAP:
		_distance_since_step = 0.0
		return
	if Vector2(displacement.x, displacement.z).length() < 0.00001:
		return
	var direction: Vector3 = displacement.normalized()
	while _distance_since_step + travel + 0.000001 >= STEP_LENGTH:
		var needed: float = maxf(0, STEP_LENGTH - _distance_since_step)
		cursor += direction * minf(needed, travel)
		travel = maxf(0, travel - needed)
		_distance_since_step = 0.0
		_stamp(cursor, yaw, _left_next)
		_left_next = not _left_next
	_distance_since_step += travel


func active_count() -> int:
	return _records.size()


func allocated_count() -> int:
	return _pool.size()


func get_decals() -> Array[Decal]:
	return _pool.duplicate()


func contact_records() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for record: Dictionary in _records:
		result.append(
			{
				"point": record["point"],
				"normal": record["normal"],
				"left": record["left"],
				"age": record["age"],
				"opacity": record["opacity"],
				"sequence": record["sequence"]
			}
		)
	return result


func clear() -> void:
	_records.clear()
	_available.clear()
	for decal: Decal in _pool:
		if is_instance_valid(decal):
			decal.free()
	_pool.clear()
	_has_anchor = false
	_distance_since_step = 0.0
	_left_next = true


func shutdown() -> void:
	clear()
	_surface = null
	_blocked_segments.clear()
	_albedos.clear()
	_normals.clear()
	_orm = null


func _add_blocked_segment(a: Vector2, b: Vector2, width: float, terrain_path: bool = false) -> void:
	_blocked_segments.append(
		{"a": a, "b": b, "radius": width * 0.5 + 0.18, "terrain_path": terrain_path}
	)


func _contact_height(point: Vector2, feet_height: float) -> Variant:
	for segment: Dictionary in _blocked_segments:
		if segment["terrain_path"] and surface_offset > 0.10:
			continue
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(
			point, segment["a"], segment["b"]
		)
		if point.distance_to(closest) <= float(segment["radius"]):
			return null
	var support: Variant = _surface.ground_at(point)
	if support == null or absf(float(support) - feet_height) > WalkSurface.MAX_STEP + 0.1:
		return null
	var ground: float = _surface.field.height_at(point)
	return ground if absf(float(support) - ground) < 0.04 else null


func _stamp(feet: Vector3, yaw: float, left: bool) -> void:
	var right: Vector2 = Vector2(cos(yaw), -sin(yaw))
	var point: Vector2 = Vector2(feet.x, feet.z) + right * FOOT_OFFSET * (-1.0 if left else 1.0)
	var height: Variant = _contact_height(point, feet.y)
	if height == null:
		rejected_contacts += 1
		return
	var up: Vector3 = _surface.field.normal_at(point)
	var forward: Vector3 = Vector3(-sin(yaw), 0, -cos(yaw))
	forward = (forward - up * forward.dot(up)).normalized()
	var side: Vector3 = forward.cross(up).normalized()
	var basis: Basis = Basis(side, up, side.cross(up).normalized())
	var decal: Decal = _obtain_decal()
	decal.texture_albedo = _albedos[0 if left else 1]
	decal.texture_normal = _normals[0 if left else 1]
	decal.global_transform = Transform3D(
		basis, Vector3(point.x, float(height) + surface_offset, point.y) + up * 0.035
	)
	decal.modulate = Color(0.52, 0.65, 0.77, 1.0)
	decal.visible = true
	total_emitted += 1
	_records.append(
		{
			"decal": decal,
			"point": Vector3(point.x, float(height) + surface_offset, point.y),
			"normal": up,
			"left": left,
			"age": 0.0,
			"opacity": 1.0,
			"sequence": total_emitted
		}
	)


func _obtain_decal() -> Decal:
	if _albedos.is_empty():
		_prepare_textures()
	if not _available.is_empty():
		return _available.pop_back()
	if _pool.size() == MAX_PRINTS:
		return _records.pop_front()["decal"]
	var decal: Decal = Decal.new()
	decal.name = "SnowFootprint%d" % _pool.size()
	decal.cull_mask = RECEIVER_LAYER
	decal.size = PRINT_SIZE
	decal.albedo_mix = 0.32
	decal.normal_fade = 0.65
	decal.upper_fade = 0.0
	decal.lower_fade = 0.0
	decal.distance_fade_enabled = true
	decal.distance_fade_begin = 26
	decal.distance_fade_length = 10
	decal.texture_orm = _orm
	add_child(decal)
	_pool.append(decal)
	return decal


func _age_prints(delta: float) -> void:
	for index: int in range(_records.size() - 1, -1, -1):
		var record: Dictionary = _records[index]
		record["age"] = float(record["age"]) + delta
		var decal: Decal = record["decal"]
		if float(record["age"]) >= LIFETIME:
			decal.visible = false
			_available.append(decal)
			_records.remove_at(index)
		else:
			var opacity: float = 1.0 - smoothstep(FADE_BEGIN, LIFETIME, float(record["age"]))
			record["opacity"] = opacity
			decal.modulate.a = opacity


func _prepare_textures() -> void:
	var source: Image = SOLE.get_image()
	if source.is_compressed():
		source.decompress()
	source.convert(Image.FORMAT_RGBA8)
	for left: bool in [true, false]:
		var mask: Image = source.duplicate() as Image
		if not left:
			mask.flip_x()
		var relief: Image = Image.create(
			mask.get_width(), mask.get_height(), false, Image.FORMAT_RGB8
		)
		for y: int in mask.get_height():
			for x: int in mask.get_width():
				var height: float = 1.0 - mask.get_pixel(x, y).a * 0.35
				relief.set_pixel(x, y, Color(height, height, height))
		relief.bump_map_to_normal_map(4.0)
		mask.generate_mipmaps()
		relief.generate_mipmaps()
		_albedos.append(ImageTexture.create_from_image(mask))
		_normals.append(ImageTexture.create_from_image(relief))
	var orm_image: Image = Image.create(4, 4, false, Image.FORMAT_RGB8)
	orm_image.fill(Color(0.80, 0.66, 0.0))
	_orm = ImageTexture.create_from_image(orm_image)


func _exit_tree() -> void:
	shutdown()
