extends GutTest

var playground: Node3D
var viewport: SubViewport


func before_each() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.own_world_3d = true
	add_child_autofree(viewport)
	playground = load("res://app/week_six_root.tscn").instantiate() as Node3D
	viewport.add_child(playground)
	await get_tree().process_frame


func after_each() -> void:
	await get_tree().process_frame


func _settle() -> void:
	var started: int = Time.get_ticks_msec()
	while playground.queue.is_busy() and Time.get_ticks_msec() - started < 10000:
		await get_tree().process_frame
	assert_false(playground.queue.is_busy(), "W06 worker/preparation did not settle")


func _motion(p: Vector2) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = p
	viewport.push_input(event, true)


func _button(p: Vector2, pressed: bool, alt: bool = false) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = p
	event.pressed = pressed
	event.alt_pressed = alt
	viewport.push_input(event, true)
