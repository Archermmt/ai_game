extends GutTest

var playground: Node3D
var viewport: SubViewport


func before_each() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.own_world_3d = true
	add_child_autofree(viewport)
	playground = load("res://app/hover_root.tscn").instantiate() as Node3D
	playground.qa_mode = true
	viewport.add_child(playground)
	playground.saves.directory = "user://qa_ux03_scene"
	_clean_slots()
	await _settle()


func after_each() -> void:
	playground.exit_photo()
	await _settle()
	_clean_slots()
	playground.preferences.reset()
	await get_tree().process_frame


func _clean_slots() -> void:
	for index: int in range(5):
		for suffix: String in ["", ".tmp", ".bak1", ".bak2", ".bak3"]:
			var path: String = SlotStore.path_for(playground.saves.directory, index) + suffix
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _settle() -> void:
	var started: int = Time.get_ticks_msec()
	while (
		(
			playground._busy()
			or playground.queue.is_busy()
			or playground.stage.is_busy()
			or playground.meadow.is_busy()
		)
		and Time.get_ticks_msec() - started < 10000
	):
		await get_tree().process_frame
	assert_false(playground._busy())
	assert_false(playground.queue.is_busy())
	assert_false(playground.stage.is_busy() or playground.meadow.is_busy())


func _same(a: Dictionary, b: Dictionary) -> bool:
	a = a.duplicate(true)
	b = b.duplicate(true)
	a.erase("revision")
	b.erase("revision")
	return a == b
