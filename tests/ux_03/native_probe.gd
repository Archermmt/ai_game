extends "res://tests/ux_02/native_probe.gd"


func _check(name: String, value: bool) -> void:
	evidence[name] = value
	if not value:
		push_error("UX03 native check failed: " + name)


func _hover_at(point: Vector3) -> void:
	var screen: Vector2 = playground.camera_rig.camera.unproject_position(point)
	await _motion(screen, Vector2.ZERO)
	for i: int in range(5):
		await process_frame


func _drag_handle(kind: String, delta: Vector2) -> void:
	var chip: Control = playground.hud.direct_handles.handles[kind]
	_check(kind + "_handle_visible", chip.is_visible_in_tree())
	var screen: Vector2 = chip.get_global_rect().get_center()
	var start: Vector2 = playground._pointer
	for step: int in range(1, 9):
		var next: Vector2 = start.lerp(screen, float(step) / 8)
		await _motion(next, (screen - start) / 8)
	await _mouse(screen, true)
	_check(
		kind + "_gui_capture",
		not playground.surface_drag.is_empty() or not playground.direct.is_empty()
	)
	await _motion(screen + delta, delta, MOUSE_BUTTON_LEFT)

	await _mouse(screen + delta, false)
	await _settle()


func _run() -> void:
	folder = OS.get_cmdline_user_args()[-1]
	DirAccess.make_dir_recursive_absolute(folder)
	playground = load("res://app/hover_root.tscn").instantiate()
	playground.qa_mode = true
	root.add_child(playground)
	await _settle()
	var before: Dictionary = playground.document.snapshot()
	var home: Dictionary = before["buildings"][0]
	var p: Array = home["position"]
	var size: Array = home["size"]
	var roof_point: Vector3 = Vector3(
		p[0] + size[0] * 0.22, p[1] + size[1] + RoofProfile.rise(home) * 0.6, p[2]
	)
	playground.hud.open_group("build")
	await _hover_at(roof_point)
	_check("hover_unselected_roof", playground.hovered.get("zone", "") == "roof")
	_check(
		"hover_keeps_creation_tool",
		(
			playground.tools.mode == "rect"
			and playground.selected_buildings.is_empty()
			and playground.document.state == before
		)
	)
	await _frame("hover_roof")
	await _drag_handle("roof", Vector2(0, -35))
	_check(
		"roof_source_changed_once",
		(
			RoofProfile.rise(playground.document.state["buildings"][0]) > RoofProfile.rise(home)
			and playground.session.history_count() == 1
		)
	)
	await _frame("roof_raised")
	playground._on_action(&"undo")
	await _settle()
	_check("roof_undo_exact", playground.document.state["buildings"] == before["buildings"])
	await _hover_at(roof_point)
	await _drag_handle("roof", Vector2(0, 230))
	_check("roof_flat", RoofProfile.rise(playground.document.state["buildings"][0]) == 0)
	await _frame("roof_flat")
	playground._on_action(&"undo")
	await _settle()
	# Source-authoritative opening priority over its parent wall.
	var opening: Dictionary = {}
	for candidate: Dictionary in home["openings"]:
		if candidate.get("facade", 0) == 0 and candidate.get("sill", 0) > 0.5:
			opening = candidate
			break
	_check("window_fixture", not opening.is_empty())
	if not opening.is_empty():
		await _hover_at(SurfaceEditData.opening_origin(home, opening))
		_check("hover_window", playground.hovered.get("family", "") == "opening")
		await _frame("hover_window")
		await _drag_handle("width", Vector2(14, 0))
		_check(
			"window_changed",
			playground.document.state["buildings"][0]["openings"] != home["openings"]
		)
		playground._on_action(&"undo")
		await _settle()
	var door: Dictionary = home["openings"][0]
	await _hover_at(SurfaceEditData.opening_origin(home, door))
	_check("hover_door", playground.hovered.get("family", "") == "opening")
	await _frame("hover_door")
	await _drag_handle("height", Vector2(0, -5))
	_check(
		"door_changed",
		playground.document.state["buildings"][0]["openings"][0]["height"] != door["height"]
	)
	playground._on_action(&"undo")
	await _settle()
	# The demo's bridge is a saved editable structure, not a merged decoration.
	var bridge: Dictionary = before["bridges"][0]
	var target: Dictionary = {"family": "bridge", "id": bridge["id"]}
	await _hover_at(SurfaceEditData.origin(before, target))
	_check("hover_bridge", playground.hovered.get("family", "") == "bridge")
	await _frame("hover_bridge")
	await _drag_handle("end_a", Vector2(-5, 0))
	_check(
		"bridge_head_changed",
		(
			playground.document.state["bridges"][0]["a"] != bridge["a"]
			and playground.document.state["bridges"][0]["b"] == bridge["b"]
		)
	)
	await _frame("bridge_changed")
	playground._on_action(&"undo")
	await _settle()
	await _hover_at(roof_point)
	playground._preference_changed("ui_scale", 1.5)
	await _frame("hover_150")
	_check("handles_150_inside", _handles_inside())
	playground.enter_photo()
	await _frame("photo")
	_check(
		"photo_hides_handles",
		(
			not playground.hud.direct_handles.visible
			or not playground.hud.direct_handles.handles["roof"].visible
		)
	)
	playground.exit_photo()
	for i: int in range(5):
		await process_frame
	await _frame("photo_return")
	_check("photo_restores_hover", playground.hud.direct_handles.handles["roof"].visible)
	var file: FileAccess = FileAccess.open(folder.path_join("native_report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence, "\t"))
	file.close()
	var passed: bool = true
	for value: bool in evidence.values():
		passed = passed and value
	quit(0 if passed else 1)


func _handles_inside() -> bool:
	for chip: Control in playground.hud.direct_handles.handles.values():
		if (
			chip.visible
			and not Rect2(Vector2.ZERO, Vector2(root.size)).encloses(chip.get_global_rect())
		):
			return false
	return true
