extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	create_timer(20).timeout.connect(func(): push_error("Building forms test timed out"); quit(1))
	check_group_halls()
	check_locked_halls()
	var data := IslandData.new()
	var cells := []
	for x in range(8, 26):
		for z in range(8, 22):
			cells.append(Vector2i(x, z))
	data.paint(cells, "grass")
	var anchor := Vector2i(12, 12)
	assert(BuildingRules.place(data, anchor, "house").begins_with("Placed"))
	var left_id := int(data.objects[0].id)
	var east := anchor + Vector2i.RIGHT * 2
	var next := {"id": 0, "kind": "tea", "x": east.x, "z": east.y, "rotation": 0, "length": 3}
	var before := data.snapshot()
	var preview: Dictionary = BuildingRules.neighborhood(data, next).seams
	assert(preview[left_id][0].other == 0 and preview[0][0].other == left_id)
	assert(preview[left_id][0].width == 2.0 and preview[left_id][0].center == Vector2(13.5, 12.5))
	assert(data.snapshot() == before)
	assert(BuildingRules.place(data, east, "tea").begins_with("Placed"))
	var tea_id := int(data.objects[-1].id)
	var full: Dictionary = BuildingRules.neighborhood(data).seams
	assert(full[left_id][0].other == tea_id and full[tea_id][0].direction == Vector2i.LEFT)
	assert(full[left_id][0].center == full[tea_id][0].center)
	assert(BuildingRules.place(data, east + Vector2i(2, 1), "greenhouse").begins_with("Placed"))
	var glass_id := int(data.objects[-1].id)
	var half: Array = BuildingRules.neighborhood(data).seams[glass_id]
	assert(half.size() == 1 and half[0].width == 1.0 and half[0].center == Vector2(15.5, 13.0))
	var corner := {"id": 0, "kind": "lighthouse", "x": 10, "z": 10, "rotation": 2}
	assert(not BuildingRules.neighborhood(data, corner).seams.has(0))
	assert(not BuildingRules.place(data, anchor + Vector2i.DOWN * 2, "tea").begins_with("Placed"))
	var raised := [Vector2i(12,10), Vector2i(13,10), Vector2i(12,11), Vector2i(13,11), Vector2i(12,9)]
	data.paint(raised, "raise")
	assert(BuildingRules.place(data, Vector2i(12,10), "lighthouse", 2).begins_with("Placed"))
	assert(not BuildingRules.neighborhood(data).seams.has(data.objects[-1].id))
	var initial_assembly := data.snapshot()
	var all_seams: Dictionary = BuildingRules.neighborhood(data).seams
	data.objects.reverse()
	assert(BuildingRules.neighborhood(data).seams == all_seams)
	data.objects.reverse()
	var sim := ResidentSim.new()
	sim.people.append({"id": 1, "home": left_id, "state": "home", "route": [], "x": 12.0, "z": 14.0})
	sim.next_id = 2
	for object in data.objects:
		var cell := Vector2i(object.x, object.z) + Vector2i.ONE
		var original_id := int(object.id)
		var entrance := BuildingRules.activity_cell(object)
		for expected in [1, 2, 0]:
			assert(BuildingRules.reshape_target(data, cell, object.kind).id == original_id)
			assert(BuildingRules.next_form(object) == expected)
			assert(BuildingRules.reshape(data, cell, object.kind).is_empty())
			assert(object.get("form", 0) == expected and object.id == original_id)
			assert(BuildingRules.activity_cell(object) == entrance)
			sim.reconcile(data)
			assert(sim.people.size() == 1 and sim.people[0].home == left_id)
	assert(data.snapshot() == initial_assembly)
	assert(not BuildingRules.reshape(data, east, "house").is_empty())
	assert(BuildingRules.reshape_target(data, Vector2i(12,14), "house").is_empty())
	assert(BuildingRules.reshape_target(data, anchor, "erase").is_empty())
	var revision := data.revision
	data.objects[0].locked = true
	assert(not BuildingRules.reshape(data, anchor, "house").is_empty() and data.revision == revision)
	assert(BuildingRules.neighborhood(data).seams == all_seams)
	data.objects[0].locked = false

	# The neighbor's render signature changes even though the other building
	# has the same ID and unchanged object record.
	assert(BuildingRules.reshape(data, east, "tea").is_empty())
	var changed_seams: Dictionary = BuildingRules.neighborhood(data).seams
	assert(changed_seams[left_id][0].other_form == 1)
	data.undo()
	assert(data.snapshot() == initial_assembly and BuildingRules.neighborhood(data).seams == all_seams)
	data.redo()
	assert(BuildingRules.neighborhood(data).seams == changed_seams)
	var moved: Dictionary = data.objects[1].duplicate()
	moved.x = 22
	var move_preview: Dictionary = BuildingRules.neighborhood(data, moved).seams
	assert(not move_preview.has(left_id) and not move_preview.has(tea_id))
	data.begin()
	data.objects[1].x = 22
	assert(BuildingRules.neighborhood(data).seams == move_preview)
	data.undo()
	data.begin()
	data.objects.remove_at(1)
	assert(not BuildingRules.neighborhood(data).seams.has(left_id))
	data.undo()
	assert(BuildingRules.neighborhood(data).seams == changed_seams)

	# A v1 save may mix original records with reshaped records. Reconstruct
	# contacts from the saved board and keep the player's resident references.
	var path := "user://test_building_forms_%d.json" % Time.get_ticks_usec()
	assert(SaveStore.save_game(data, sim, path) == OK)
	var restored := IslandData.new()
	var resumed := ResidentSim.new()
	assert(SaveStore.load_game(restored, resumed, path) == OK)
	assert(restored.snapshot() == data.snapshot() and resumed.people[0].home == left_id)
	assert(BuildingRules.neighborhood(restored).seams == changed_seams)
	var payload = JSON.parse_string(FileAccess.get_file_as_string(path))
	DirAccess.remove_absolute(path)
	assert(not payload.objects[0].has("form"))
	for invalid in [3, -1, "1", false, 1.5]:
		payload.objects[1].form = invalid
		assert(SaveStore.validate(payload) == ERR_FILE_CORRUPT)
	print("PASS building forms: full/half walls, connected central halls, prediction, grades, entrances, all four families, lock, residents, undo, redo, move, delete and v1 saves")
	quit()

func check_group_halls() -> void:
	var data := IslandData.new()
	var cells: Array = []
	for x in range(7, 23):
		for z in range(7, 22):
			cells.append(Vector2i(x, z))
	data.paint(cells, "grass")
	for x in [10, 12]:
		assert(BuildingRules.place(data, Vector2i(x, 10), "house").begins_with("Placed"))
	assert(BuildingRules.neighborhood(data).halls.is_empty())
	var middle: int = data.objects[1].id
	var third := {"id": 0, "kind": "tea", "x": 14, "z": 10, "rotation": 0}
	var one_hall: Dictionary = {middle: true}
	assert(BuildingRules.neighborhood(data, third).halls == one_hall)
	assert(BuildingRules.place(data, Vector2i(14, 10), "tea").begins_with("Placed"))
	assert(BuildingRules.neighborhood(data).halls == one_hall)
	assert(BuildingRules.reshape(data, Vector2i(12, 10), "house").is_empty())
	assert(BuildingRules.neighborhood(data).halls.is_empty() and data.objects[1].form == 1)
	data.undo()
	assert(BuildingRules.neighborhood(data).halls == one_hall)
	data.objects[1].locked = true
	assert(BuildingRules.neighborhood(data).halls.has(data.objects[0].id))
	data.objects[1].locked = false

	# Four centers produce a tie; the left center wins even after reordering.
	assert(BuildingRules.place(data, Vector2i(16, 10), "greenhouse").begins_with("Placed"))
	data.objects.reverse()
	assert(BuildingRules.neighborhood(data).halls == one_hall)
	assert(BuildingRules.place(data, Vector2i(18, 10), "lighthouse").begins_with("Placed"))
	assert(BuildingRules.neighborhood(data).halls.has(BuildingRules.reshape_target(data, Vector2i(14,10), "tea").id))
	data.undo()
	assert(BuildingRules.neighborhood(data).halls == one_hall)

	# Separate courtyards have their own main roof. Facilities can contribute
	# to a complex's size but only a home or tea room can carry that roof.
	for x in [10, 12, 14]:
		assert(BuildingRules.place(data, Vector2i(x, 18), "greenhouse").begins_with("Placed"))
	assert(BuildingRules.neighborhood(data).halls == one_hall)
	assert(BuildingRules.place(data, Vector2i(16, 18), "tea").begins_with("Placed"))
	var both: Dictionary = BuildingRules.neighborhood(data).halls
	assert(both.size() == 2 and both.has(middle) and both.has(data.objects[-1].id))
	data.begin()
	data.objects = data.objects.filter(func(o): return int(o.id) != middle)
	assert(not BuildingRules.neighborhood(data).halls.has(middle))
	data.undo()
	assert(BuildingRules.neighborhood(data).halls == both)

func check_locked_halls() -> void:
	var data := IslandData.new()
	var cells: Array = []
	for x in range(7, 23):
		for z in range(7, 16):
			cells.append(Vector2i(x, z))
	data.paint(cells, "grass")
	for x in [8, 10, 12, 16, 18, 20]:
		assert(BuildingRules.place(data, Vector2i(x, 10), "house").begins_with("Placed"))
	var west: Dictionary = data.objects[1]
	var east: Dictionary = data.objects[4]
	var twin: Dictionary = {int(west.id): true, int(east.id): true}
	assert(BuildingRules.neighborhood(data).halls == twin)
	for home in [west, east]:
		home.locked = true
		home.hall_locked = true
		home.variant = BuildingRules.variant(data, home)
	assert(BuildingRules.place(data, Vector2i(14, 10), "tea").begins_with("Placed"))
	var center := int(data.objects[-1].id)
	assert(BuildingRules.neighborhood(data).halls == twin)
	west.locked = false
	west.erase("hall_locked")
	assert(BuildingRules.neighborhood(data).halls == {int(east.id): true})
	east.locked = false
	east.erase("hall_locked")
	assert(BuildingRules.neighborhood(data).halls == {center: true})

	var hall: Dictionary = data.objects[-1]
	hall.locked = true
	hall.hall_locked = true
	data.objects = [hall]
	var isolated := BuildingRules.neighborhood(data)
	assert(isolated.seams.is_empty() and isolated.halls == {center: true})
	var sim := ResidentSim.new()
	var path := "user://test_locked_hall_%d.json" % Time.get_ticks_usec()
	assert(SaveStore.save_game(data, sim, path) == OK)
	var restored := IslandData.new()
	assert(SaveStore.load_game(restored, sim, path) == OK)
	assert(BuildingRules.neighborhood(restored).halls == isolated.halls)
	var payload = JSON.parse_string(FileAccess.get_file_as_string(path))
	DirAccess.remove_absolute(path)
	payload.objects[0].locked = false
	assert(SaveStore.validate(payload) == ERR_FILE_CORRUPT)
	payload.objects[0].locked = true
	payload.objects[0].hall_locked = 1
	assert(SaveStore.validate(payload) == ERR_FILE_CORRUPT)
	payload.objects[0].hall_locked = true
	payload.objects[0].form = 1
	assert(SaveStore.validate(payload) == ERR_FILE_CORRUPT)
