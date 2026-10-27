extends SceneTree
## Actual production scene and keyboard walking; native rendering is run serially by QA.

const FOLDER: String = "res://reports/immersion/native"
const SIZE: Vector2i = Vector2i(1920, 1080)
const ROUTE_LENGTH: float = 6.4
var garden: Variant
var checks: Dictionary = {}
var measurements: Dictionary = {}
var images: Dictionary = {}
var source: Dictionary = {}
var history: int = 0
var versions: Dictionary = {}
var terrain_signature: String = ""
var grass_signature: int = -1
var grass_roots: Array[Vector2] = []
var blocked_paths: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(label: String, passed: bool) -> bool:
	checks[label] = bool(checks.get(label, true)) and passed
	if not passed:
		push_error(label)
	return passed


func _draw_frames(count: int) -> void:
	for i: int in count:
		await process_frame
		RenderingServer.force_draw(false)


func _capture(label: String) -> Image:
	await _draw_frames(16)
	var picture: Image = root.get_texture().get_image()
	var path: String = FOLDER.path_join(label + ".png")
	_check(label + " saved", picture.get_size() == SIZE and picture.save_png(path) == OK)
	images[label] = path
	return picture


func _key(code: Key, down: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	await process_frame


func _busy() -> bool:
	return (
		garden.queue.is_busy()
		or garden.stage.is_busy()
		or garden.meadow.is_busy()
		or garden.landscape_terrain.is_busy()
		or garden.saves.is_busy()
		or garden._loading
	)


func _climate(month: int) -> void:
	garden.calendar.month = month
	garden.calendar.weather = "clear"
	garden.calendar.minute_of_day = 720
	garden.calendar.speed = 0
	garden.calendar.automatic_weather = false
	garden.atmosphere.blend.advance(0, garden.calendar.sample())
	garden.atmosphere.blend.advance(WeatherBlend.DURATION, garden.calendar.sample())
	garden.atmosphere.update(0, garden.calendar.sample())


func _source_unchanged(label: String) -> void:
	_check(label + " source unchanged", garden.document.snapshot() == source)
	_check(label + " history unchanged", garden.session.history_count() == history)
	_check(label + " grass versions unchanged", garden.meadow._published_versions == versions)
	_check(
		label + " grass signature unchanged", garden.meadow.published_signature == grass_signature
	)
	_check(
		label + " Terrain3D signature unchanged",
		garden.landscape_terrain.published_signature == terrain_signature
	)


func _prepare_route_data() -> void:
	for path: Dictionary in source.get("paths", []):
		var points: Array[Vector2] = PathCurve.sample(path)
		for i: int in range(points.size() - 1):
			blocked_paths.append(
				{"a": points[i], "b": points[i + 1], "radius": float(path["width"]) * 0.5 + 0.6}
			)
	for collection: String in ["bridges", "stairs"]:
		for item: Dictionary in source.get(collection, []):
			blocked_paths.append(
				{
					"a": Vector2(item["a"][0], item["a"][1]),
					"b": Vector2(item["b"][0], item["b"][1]),
					"radius": float(item["width"]) * 0.5 + 0.6
				}
			)
	# Match the renderer's first density fraction, rather than invisible candidates.
	for key: Vector2i in garden.meadow.published_chunks:
		for kind: int in 3:
			var items: Array = garden.meadow.published_chunks[key][kind]
			for i: int in floori(items.size() * garden.meadow.density):
				var pose: Transform3D = items[i]["pose"]
				grass_roots.append(Vector2(pose.origin.x, pose.origin.z))


func _clear_grass(point: Vector2, surface: WalkSurface) -> bool:
	var ground: Variant = surface.ground_at(point)
	if ground == null or absf(float(ground) - surface.field.height_at(point)) > 0.03:
		return false
	for segment: Dictionary in blocked_paths:
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(
			point, segment["a"], segment["b"]
		)
		if point.distance_to(closest) < float(segment["radius"]):
			return false
	for home: Dictionary in source["buildings"]:
		var center: Vector2 = Vector2(home["position"][0], home["position"][2])
		var half: Vector2 = Vector2(home["size"][0], home["size"][2]) * 0.5
		if Rect2(center - half, half * 2).grow(0.75).has_point(point):
			return false
	return true


func _nearby_tufts(point: Vector2) -> int:
	var result: int = 0
	for root_point: Vector2 in grass_roots:
		if root_point.distance_squared_to(point) < 1.0:
			result += 1
	return result


func _find_route(surface: WalkSurface) -> Dictionary:
	var starts: Array[Vector2] = [
		Vector2(12, 12),
		Vector2(10, 12),
		Vector2(12, 10),
		Vector2(8, 12),
		Vector2(-10, 12),
		Vector2(-12, 10),
		Vector2(-10, -8),
		Vector2(10, -10)
	]
	for z: int in range(-16, 17, 4):
		for x: int in range(-16, 17, 4):
			starts.append(Vector2(x, z))
	for start: Vector2 in starts:
		for index: int in 12:
			var direction: Vector2 = Vector2.from_angle(float(index) * TAU / 12)
			var valid: bool = true
			for sample: int in 33:
				var point: Vector2 = start + direction * (ROUTE_LENGTH * sample / 32)
				if not _clear_grass(point, surface):
					valid = false
					break
			if valid and _nearby_tufts(start + direction * 2.4) >= 4:
				return {
					"start": Vector3(start.x, float(surface.ground_at(start)), start.y),
					"direction": direction,
					"yaw": atan2(-direction.x, -direction.y),
					"length": ROUTE_LENGTH
				}
	return {}


func _walk_distance(distance: float, label: String) -> float:
	var walk: FirstPersonWalk = garden.walk_controller
	var start: Vector3 = walk.feet
	var deadline: int = Time.get_ticks_msec() + 12000
	await _key(KEY_W, true)
	while start.distance_to(walk.feet) < distance and Time.get_ticks_msec() < deadline:
		await _draw_frames(1)
	await _key(KEY_W, false)
	# Release the last velocity without synthesizing positions or call-by-call steps.
	await _draw_frames(12)
	var moved: float = start.distance_to(walk.feet)
	measurements[label + "_distance_m"] = moved
	_check(label + " real W input moves requested distance", moved >= distance)
	_check(
		label + " ends on safe ground", walk.surface.can_stand(Vector2(walk.feet.x, walk.feet.z))
	)
	return moved


func _contact_count() -> int:
	var count: int = 0
	for contact: Vector4 in garden.meadow.get_walker_contacts():
		count += int(contact.w > 0)
	return count


func _region(points: Array[Vector3], padding: Vector3) -> Rect2i:
	var low: Vector2 = Vector2(SIZE)
	var high: Vector2 = Vector2.ZERO
	for point: Vector3 in points:
		for corner: int in 8:
			var offset: Vector3 = Vector3(
				padding.x * (-1 if (corner & 1) == 0 else 1),
				padding.y * (-1 if (corner & 2) == 0 else 1),
				padding.z * (-1 if (corner & 4) == 0 else 1)
			)
			var screen: Vector2 = garden.camera_rig.camera.unproject_position(point + offset)
			low = low.min(screen)
			high = high.max(screen)
	return Rect2i(Rect2(low, high - low).grow(6)).intersection(Rect2i(Vector2i.ZERO, SIZE))


func _difference(a: Image, b: Image, region: Rect2i) -> Dictionary:
	var sum: float = 0.0
	var changed: int = 0
	var count: int = 0
	for y: int in range(region.position.y, region.end.y, 2):
		for x: int in range(region.position.x, region.end.x, 2):
			var delta: Color = a.get_pixel(x, y) - b.get_pixel(x, y)
			var value: float = (absf(delta.r) + absf(delta.g) + absf(delta.b)) / 3
			sum += value
			changed += int(value > 0.01)
			count += 1
	return {"mean": sum / maxi(count, 1), "changed_samples": changed, "samples": count}


func _layer_checks() -> void:
	var layer: int = SnowFootprints.RECEIVER_LAYER
	_check("footprint receiver bit is layer 18", layer == 1 << 17)
	_check(
		"actual Terrain3D receives decals",
		(garden.landscape_terrain.terrain.render_layers & layer) != 0
	)
	var grass_excluded: bool = not garden.meadow.batches.is_empty()
	for view: MultiMeshInstance3D in garden.meadow.batches:
		grass_excluded = grass_excluded and (view.layers & layer) == 0
	_check("all actual grass batches exclude footprint receiver", grass_excluded)
	# W06+ publishes decorated cottages through _live_units. The inherited W02
	# _building_views dictionary is empty in the production scene. Include every
	# cottage descendant so actual tiles, openings and timber are all inspected.
	var building_count: int = 0
	var roof_count: int = 0
	var building_geometry: Array[Dictionary] = []
	var roofs_excluded: bool = true
	for key: String in garden._live_units:
		if not key.begins_with("building:"):
			continue
		var cottage: Node3D = garden._live_units[key]
		building_count += 1
		var geometry: Array[Node] = cottage.find_children("*", "GeometryInstance3D", true, false)
		if cottage is GeometryInstance3D:
			geometry.push_front(cottage)
		for node: Node in geometry:
			var view: GeometryInstance3D = node as GeometryInstance3D
			roofs_excluded = roofs_excluded and (view.layers & layer) == 0
			roof_count += int(view.name == &"HandLaidTiles")
			building_geometry.append(
				{"unit": key, "path": String(view.get_path()), "layers": view.layers}
			)
	measurements["building_receiver_inspection"] = {
		"buildings": building_count, "roof_meshes": roof_count, "geometry": building_geometry
	}
	_check(
		"all source cottages inspected as published nodes",
		building_count == source["buildings"].size() and building_count > 0
	)
	_check("all cottage tile roof meshes inspected", roof_count == source["buildings"].size())
	roofs_excluded = roofs_excluded and not building_geometry.is_empty()
	_check("all actual building and roof meshes exclude footprint receiver", roofs_excluded)
	_check("Terrain3D is visible receiver", garden.landscape_terrain.visible)
	for view: MeshInstance3D in garden._terrain_views:
		_check("legacy terrain fallback hidden", not view.visible)


func _grass_pixels(direction: Vector2) -> void:
	var walk: FirstPersonWalk = garden.walk_controller
	_check("actual walk populates grass contacts", _contact_count() > 0)
	measurements["grass_contacts_after_walk"] = _contact_count()
	walk.pitch = -0.6
	walk.look(Vector2.ZERO)
	await _capture("grass_first_person")
	garden._freeze_photo(true)
	await _draw_frames(2)
	garden.set_process(false)
	var contacts: PackedVector4Array = garden.meadow.get_walker_contacts()
	var center: Vector3 = walk.feet + Vector3.UP * 0.25
	var camera: Camera3D = garden.camera_rig.camera
	camera.global_position = center - Vector3(direction.x, 0, direction.y) * 2.5 + Vector3.UP * 1.5
	camera.look_at(center)
	var area: Rect2i = _region([walk.feet], Vector3(1.3, 0.7, 1.3))
	garden.meadow.material.set_shader_parameter("walker_interaction_active", false)
	var quiet_a: Image = await _capture("grass_contact_off")
	var quiet_b: Image = await _capture("grass_contact_off_repeat")
	garden.meadow.material.set_shader_parameter("walker_interaction_active", true)
	var bent: Image = await _capture("grass_contact_on")
	var noise: Dictionary = _difference(quiet_a, quiet_b, area)
	var delta: Dictionary = _difference(quiet_b, bent, area)
	measurements["grass_pixels"] = {"off_repeat": noise, "off_on": delta, "region": area}
	_check("frozen contact samples remain exact", garden.meadow.get_walker_contacts() == contacts)
	_check("frozen grass baseline stable", float(noise["mean"]) < 0.0001)
	_check(
		"real grass bending changes pixels",
		(
			float(delta["mean"]) > maxf(0.00001, float(noise["mean"]) * 5)
			and int(delta["changed_samples"]) > 30
		)
	)
	garden.set_process(true)
	garden._freeze_photo(false)
	walk.pitch = -0.1
	walk.look(Vector2.ZERO)
	_source_unchanged("grass walking")


func _snow_pixels(direction: Vector2) -> void:
	var walk: FirstPersonWalk = garden.walk_controller
	var prints: SnowFootprints = garden.snow_footprints
	_check("real winter walk emits at least three footprints", prints.active_count() >= 3)
	measurements["footprints_after_walk"] = prints.contact_records()
	measurements["footprints_total_emitted"] = prints.total_emitted
	walk.yaw = wrapf(walk.yaw + PI, -PI, PI)
	walk.pitch = -0.62
	walk.look(Vector2.ZERO)
	garden._freeze_photo(true)
	await _draw_frames(2)
	await _capture("winter_first_person_look_back")
	garden.set_process(false)
	var records: Array[Dictionary] = prints.contact_records()
	if not _check("footprint records available for camera diagnosis", records.size() >= 3):
		garden.set_process(true)
		return
	var points: Array[Vector3] = []
	var focus: Vector3 = Vector3.ZERO
	for record: Dictionary in records:
		points.append(record["point"])
		focus += record["point"]
	focus /= points.size()
	var camera: Camera3D = garden.camera_rig.camera
	var forward: Vector3 = Vector3(direction.x, 0, direction.y)
	camera.global_position = focus + forward * 2.7 + Vector3.UP * 1.8
	camera.look_at(focus)
	var area: Rect2i = _region(points, Vector3(0.3, 0.1, 0.3))
	var fresh: Image = await _capture("winter_footprints_fresh")
	var fresh_repeat: Image = await _capture("winter_footprints_fresh_repeat")
	for decal: Decal in prints.get_decals():
		decal.hide()
	var hidden: Image = await _capture("winter_footprints_hidden")
	for decal: Decal in prints.get_decals():
		decal.show()
	var noise: Dictionary = _difference(fresh, fresh_repeat, area)
	var imprint: Dictionary = _difference(fresh_repeat, hidden, area)
	_check("frozen footprints do not age during captures", prints.contact_records() == records)
	_check("frozen snow baseline stable", float(noise["mean"]) < 0.0001)
	_check(
		"decals change actual Terrain3D pixels",
		(
			float(imprint["mean"]) > maxf(0.000002, float(noise["mean"]) * 5)
			and int(imprint["changed_samples"]) > 15
		)
	)
	prints.update_contact(walk.feet, walk.yaw, true, 0.98, 18.0, false)
	var faded_records: Array[Dictionary] = prints.contact_records()
	var alpha_faded: bool = faded_records.size() == records.size()
	for record: Dictionary in faded_records:
		alpha_faded = (
			alpha_faded and float(record["opacity"]) > 0 and float(record["opacity"]) < 0.5
		)
	_check("eighteen seconds fades every existing print alpha", alpha_faded)
	var faded: Image = await _capture("winter_footprints_faded_18s")
	var fade_delta: Dictionary = _difference(faded, hidden, area)
	_check(
		"fade visibly weakens footprint pixels",
		(
			float(fade_delta["mean"]) < float(imprint["mean"]) * 0.85
			and float(fade_delta["mean"]) > float(noise["mean"])
		)
	)
	prints.update_contact(walk.feet, walk.yaw, true, 0.98, 7.0, false)
	_check("twenty five seconds expires all prints", prints.active_count() == 0)
	var hidden_after_age: bool = true
	for decal: Decal in prints.get_decals():
		hidden_after_age = hidden_after_age and not decal.visible
	_check("expired pooled decals all hidden", hidden_after_age)
	var gone: Image = await _capture("winter_footprints_gone_25s")
	var gone_delta: Dictionary = _difference(gone, hidden, area)
	_check(
		"expired print pixels return to unmarked snow",
		float(gone_delta["mean"]) < maxf(0.00002, float(imprint["mean"]) * 0.1)
	)
	measurements["snow_pixels"] = {
		"region": area,
		"frozen_repeat": noise,
		"fresh_vs_hidden": imprint,
		"faded_vs_hidden": fade_delta,
		"gone_vs_hidden": gone_delta
	}
	measurements["footprints_faded_records"] = faded_records
	measurements["footprints_expired_count"] = prints.active_count()
	garden.set_process(true)
	garden._freeze_photo(false)
	walk.yaw = atan2(-direction.x, -direction.y)
	walk.pitch = -0.1
	walk.look(Vector2.ZERO)
	_source_unchanged("snow walking and fading")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(FOLDER)
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	if not _check("native renderer required", DisplayServer.get_name() != "headless"):
		await _finish()
		return
	garden = (load("res://app/living_root.tscn") as PackedScene).instantiate()
	garden.qa_mode = true
	root.add_child(garden)
	current_scene = garden
	var isolated: String = "user://qa_immersion/native/%d" % Time.get_ticks_usec()
	garden.saves.directory = isolated.path_join("saves")
	garden.active_slot = -1
	garden.hud.photo_directory.text = ProjectSettings.globalize_path(isolated.path_join("photos"))
	var deadline: int = Time.get_ticks_msec() + 120000
	while (
		not garden.landscape_ready
		and not garden.landscape_failed
		and Time.get_ticks_msec() < deadline
	):
		await _draw_frames(1)
	if not _check(
		"actual production landscape ready", garden.landscape_ready and not garden.landscape_failed
	):
		await _finish()
		return
	deadline = Time.get_ticks_msec() + 60000
	while _busy() and Time.get_ticks_msec() < deadline:
		await _draw_frames(1)
	_check("source publications settled", not _busy())
	_check(
		"QA saves isolated",
		garden.qa_mode and garden.saves.directory.begins_with("user://qa_immersion/native/")
	)
	_check("actual production grass renderer", garden.meadow is ProductionGrassRenderer)
	_check("formal scene uses accepted volume clouds", garden.cloud_adapter.ready_for_clouds)
	root.use_taa = false
	garden.preferences.values["reduce_motion"] = false
	garden._apply_preferences()
	garden.camera_rig.camera.attributes = null
	garden.pond_reflections.enabled = false
	garden.pond_reflections.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_climate(7)
	await _draw_frames(3)
	source = garden.document.snapshot()
	history = garden.session.history_count()
	versions = garden.meadow._published_versions.duplicate(true)
	grass_signature = garden.meadow.published_signature
	terrain_signature = garden.landscape_terrain.published_signature
	_layer_checks()
	_check("actual photo mode entered", garden.enter_photo())
	# Preserve a real pre-walk freeze choice so stop_walk must restore it.
	garden.hud.freeze.set_pressed_no_signal(true)
	garden._freeze_photo(true)
	if not _check("actual FirstPersonWalk entered", garden.start_walk()):
		await _finish()
		return
	garden.hud.hide()
	_prepare_route_data()
	var walk: FirstPersonWalk = garden.walk_controller
	var route: Dictionary = _find_route(walk.surface)
	if not _check("continuous safe off road grass route found", not route.is_empty()):
		await _finish()
		return
	measurements["route"] = route
	# One initial spawn; every subsequent movement uses real routed W events.
	walk.feet = route["start"]
	walk.yaw = route["yaw"]
	walk.pitch = -0.1
	walk.look(Vector2.ZERO)
	await _draw_frames(3)
	_check(
		"actual walk temporarily thaws prior frozen photo",
		not garden._climate_frozen and not garden.atmosphere.frozen
	)
	var direction: Vector2 = route["direction"]
	await _walk_distance(2.3, "summer_walk")
	_check("summer footsteps not emitted", garden.snow_footprints.active_count() == 0)
	await _grass_pixels(direction)
	_climate(1)
	await _draw_frames(3)
	_check(
		"winter clear cover stable",
		(
			float(garden.atmosphere.blend.current["cover"]) > 0.9
			and float(garden.atmosphere.blend.current["snow"]) < 0.01
		)
	)
	var snow_deadline: int = Time.get_ticks_msec() + 120000
	while garden.snow_cover.is_busy() and Time.get_ticks_msec() < snow_deadline:
		await _draw_frames(1)
	_check("winter snow geometry ready before contact captures", not garden.snow_cover.is_busy())
	await _walk_distance(2.6, "winter_walk")
	await _snow_pixels(direction)
	await _walk_distance(0.8, "exit_setup_walk")
	_check("exit starts with live footprints", garden.snow_footprints.active_count() > 0)
	_check("exit starts with live grass contact", _contact_count() > 0)
	garden.stop_walk()
	await _draw_frames(2)
	_check(
		"exit restores prior frozen photo",
		(
			garden.photo_active
			and garden.hud.freeze.button_pressed
			and garden._climate_frozen
			and garden.atmosphere.frozen
		)
	)
	_check("exit stops actual FirstPersonWalk", not walk.active)
	_check(
		"exit clears snow footprints",
		garden.snow_footprints.active_count() == 0 and garden.snow_footprints.allocated_count() == 0
	)
	await SceneShutdown.wait_wallclock(self, 1.1)
	await _draw_frames(2)
	_check("grass contact returns within about one second", _contact_count() == 0)
	_check(
		"grass recovery preserves photo and wind freeze",
		(
			garden._climate_frozen
			and garden.atmosphere.frozen
			and bool(garden.meadow.material.get_shader_parameter("freeze_time"))
		)
	)
	_check(
		"inactive grass GPU contact fast path restored",
		not bool(garden.meadow.material.get_shader_parameter("walker_interaction_active"))
	)
	_source_unchanged("exit")
	await _finish()


func _finish() -> void:
	var passed: bool = not checks.is_empty() and not checks.values().has(false)
	if is_instance_valid(garden):
		garden.set_process(true)
		garden.seasonal_music.shutdown()
		garden.soundscape.shutdown()
		await SceneShutdown.wait_wallclock(self, 0.4)
		await SceneShutdown.release_scene(garden)
	await _draw_frames(8)
	var file: FileAccess = FileAccess.open(FOLDER.path_join("result.json"), FileAccess.WRITE)
	file.store_string(
		(
			JSON.stringify(
				{
					"passed": passed,
					"checks": checks,
					"measurements": measurements,
					"images": images,
					"viewport_size": [SIZE.x, SIZE.y],
					"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
					"taa_during_pixel_checks": false,
					"real_keyboard_walking": true,
					"single_initial_spawn": true,
					"baseline_sky_only": false,
					"production_clouds": true,
					"performance_gate_run": false,
					"windows_real_device_verified": false
				},
				"\t"
			)
			+ "\n"
		)
	)
	file.close()
	print("IMMERSION_NATIVE_", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)
