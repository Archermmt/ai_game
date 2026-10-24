extends "res://tests/ux_02/playground_test_base.gd"


func _mouse(
	point: Vector2, pressed: bool, button: MouseButton = MOUSE_BUTTON_LEFT
) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = point
	return event


func _empty_house() -> Dictionary:
	var source: Dictionary = WorldDocument.new("ux-scene").snapshot()
	var home: Dictionary = WorldDocument.allocate_building(source, Vector3.ZERO, Vector3(4, 3, 4))
	assert_true(playground.session.replace_document(source, playground._prepare_views)["ok"])
	await _settle()
	playground.selected_buildings.assign([home["id"]])
	playground.tools.mode = "inspect"
	return home


func test_eraser_and_prop_choice_keep_visible_category_consistent_with_active_tool() -> void:
	await _empty_house()
	playground.hud.open_group("erase")
	var screen: Vector2 = playground.camera_rig.camera.unproject_position(Vector3(0, 1, 0))
	playground._unhandled_input(_mouse(screen, true))
	await _settle()
	assert_eq(playground.tools.mode, "smart_erase")
	assert_true(playground.hud.ribbon_buttons["erase"].button_pressed)
	assert_eq(playground.document.state["buildings"].size(), 0)
	playground.hud.open_group("props")
	playground.hud.quick_assets.get_child(2).pressed.emit()
	assert_eq(playground.tools.mode, "place_asset")
	assert_true(playground.hud.ribbon_buttons["openings"].button_pressed)
