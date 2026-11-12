extends "res://tests/week_15/woodland_capture.gd"
## Exercise the homeward route on the actual walk surface and after a published edit.


func _additional_views() -> void:
	root.size = Vector2i(1600, 900)
	root.content_scale_size = root.size
	garden.hud.close_context()
	garden.hud.hide()
	for time_of_day: float in [10.5, 17.85]:
		_climate(5, time_of_day, "clear")
		await _walk_home("day" if time_of_day < 12 else "dusk")
	await _move_entry()
	await _two_attached_homes()


func _walk_home(label: String) -> void:
	var bridge: Dictionary = garden.document.state["bridges"][0]
	var head: Vector2 = Vector2(bridge["b"][0], bridge["b"][1])
	garden._recommended_view(0)
	if not garden.enter_photo():
		_check(label + " enter photography", false)
		return
	var index: int = garden.hud.bookmarks.item_count - 1
	_check(
		label + " bridgehead bookmark available",
		garden.hud.bookmarks.get_item_text(index).contains("桥头望小屋")
	)
	garden.hud.bookmarks.select(index)
	garden._photo_action("restore")
	if not garden.start_walk():
		_check(label + " enter walk", false)
		return
	garden.hud.hide()
	var walker: FirstPersonWalk = garden.walk_controller
	var start: Vector2 = Vector2(walker.feet.x, walker.feet.z)
	_check(label + " starts at bridgehead", start.distance_to(head) < 0.4)
	_face(walker, Vector2(0.17, 1.65), -0.07)
	_check(
		label + " window illumination follows daylight",
		(garden.lanterns.active_window_count > 0) == (label == "dusk")
	)
	_check(label + " gravel cove is published", garden._pond_bank.has_node("GravelShallows"))
	await _capture("bridge_" + label)
	# Drive W along the two connected path records in reverse, using the same
	# acceleration, collision, stair top and camera that an actual walker uses.
	var route: Array[Vector2] = []
	var paths: Array = garden.document.state["paths"]
	for i: int in range(1, -1, -1):
		var samples: Array[Vector2] = PathCurve.sample(paths[i])
		samples.reverse()
		route.append_array(samples)
	route.append(Vector2(0.17, 2.35))
	var reached: bool = true
	for point: Vector2 in route:
		if not _walk_to(walker, point):
			print("WALK ROUTE stopped at ", walker.feet, " before ", point)
			reached = false
			break
	walker.reset_input()
	_check(label + " follows path and climbs doorstep", reached)
	garden.exit_photo()
	garden._recommended_view(1)
	garden.hud.hide()


func _walk_to(walker: FirstPersonWalk, point: Vector2) -> bool:
	for step: int in 240:
		if Vector2(walker.feet.x, walker.feet.z).distance_to(point) < 0.10:
			return true
		_face(walker, point, -0.1)
		walker.keys[KEY_W] = true
		walker.step(1.0 / 60.0)
	return false


func _face(walker: FirstPersonWalk, target: Vector2, elevation: float) -> void:
	var backward: Vector2 = Vector2(walker.feet.x, walker.feet.z) - target
	walker.yaw = atan2(backward.x, backward.y)
	walker.pitch = elevation
	walker._apply_view()


func _move_entry() -> void:
	var original: Dictionary = garden.document.snapshot()
	var draft: Dictionary = original.duplicate(true)
	var home: Dictionary = draft["buildings"][0]
	var east: Vector2 = Vector2(1.85, 0.65)
	var place: Dictionary = DoorRules.wall_point(home, east)
	home["openings"][0]["facade"] = place["facade"]
	home["openings"][0]["center"] = place["center"]
	_check("door snaps to east wall", DoorRules.snap_manual(home, 0, draft["buildings"]))
	draft["paths"][0]["points"] = [
		[2.05, 0, 0.65],
		[2.75, 0, 1.05],
		[2.68, 0, 2.55],
		[2.20, 0, 4.2],
		[2.5, 0, 6.1],
		[3.4, 0, 7.8],
		[4.9, 0, 9.05]
	]
	var old_mesh: Mesh = garden._live_units["path"]
	garden._submit_async(draft, "挪门并重画石径")
	await _settle()
	_check(
		"moved door and new path published",
		(
			garden.document.state["revision"] == original["revision"] + 1
			and garden.document.state["buildings"][0]["openings"][0]["facade"] == 1
			and garden._live_units["path"] != old_mesh
		)
	)
	_check(
		"stairs and bridge retain player positions",
		(
			garden.document.state["stairs"] == original["stairs"]
			and garden.document.state["bridges"] == original["bridges"]
		)
	)
	_climate(5, 10.5, "clear")
	_orbit(Vector3(1.1, 1.1, 0.8), 13.8, 0.85, 0.41)
	await _capture("relocated_entry")
	_orbit(Vector3(-1.15, 1.5, east.y), 12, PI / 2, 0.4)
	var supported: bool = false
	if garden.enter_photo() and garden.start_walk():
		var walker: FirstPersonWalk = garden.walk_controller
		if _walk_to(walker, east + Vector2(0.46, 0)):
			var position_xz: Vector2 = Vector2(walker.feet.x, walker.feet.z)
			var lift: float = walker.feet.y - walker.surface.field.height_at(position_xz)
			supported = lift > 0.15 and lift < WalkSurface.MAX_STEP
		walker.reset_input()
	if garden.photo_active:
		garden.exit_photo()
	_check("walker steps onto the rebuilt threshold stone", supported)
	garden._on_action(&"undo")
	await _settle()
	var restored: Dictionary = garden.document.snapshot()
	restored.erase("revision")
	original.erase("revision")
	_check("undo restores the original garden", restored == original)


func _two_attached_homes() -> void:
	var bare: Dictionary = WorldDocument.new("eaves-study").snapshot()
	WorldDocument.allocate_building(bare, Vector3.ZERO, Vector3(4, 2.7, 6))
	var result: Dictionary = garden.session.replace_document(bare, garden._prepare_views)
	_check("loaded single-house study", result["ok"])
	await _settle()
	var draft: Dictionary = garden.document.snapshot()
	WorldDocument.allocate_building(draft, Vector3(4, 0, -1.5), Vector3(4, 4.5, 3))
	garden._submit_async(draft, "局部贴靠高屋")
	await _settle()
	_check(
		"partial contact built through editor transaction",
		garden.document.state["buildings"].size() == 2
	)
	_orbit(Vector3(1.8, 2.7, 0.4), 15.0, 0.85, 0.51)
	await _capture("partial_eaves")


func _orbit(target: Vector3, distance: float, yaw: float, pitch: float) -> void:
	garden.camera_rig.target = target
	garden.camera_rig.distance = distance
	garden.camera_rig.yaw = yaw
	garden.camera_rig.pitch = pitch
	garden.camera_rig.refresh()
	garden.hud.hide()


func _settle() -> void:
	var end: int = Time.get_ticks_msec() + 60000
	while (
		garden.queue.is_busy()
		or garden.stage.is_busy()
		or garden.meadow.is_busy()
		or garden.landscape_terrain.is_busy()
	):
		if Time.get_ticks_msec() >= end:
			_check("source and views settled", false)
			return
		await process_frame
