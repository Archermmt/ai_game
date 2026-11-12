extends SceneTree

func _initialize() -> void:
	var d := IslandData.new()
	var cells: Array = []
	for x in range(7, 32):
		for z in range(7, 24):
			cells.append(Vector2i(x, z))
	d.paint(cells, "grass")
	for x in [15, 18, 21]:
		assert(BuildingRules.place(d, Vector2i(x, 15), "house").begins_with("Placed"))
	var home: Dictionary = d.objects[0]
	var second: Dictionary = d.objects[1]
	var third: Dictionary = d.objects[2]
	var before := d.snapshot()
	var plain := BuildingRules.neighborhood(d)
	assert(plain.variants == {home.id: "basic", second.id: "basic", third.id: "basic"})
	# Layouts now include every building identity, including greenhouses.
	var proposed := {"id": d.next_id, "x": 12, "z": 15, "kind": "greenhouse", "rotation": 0}
	var preview := BuildingRules.neighborhood(d, proposed)
	assert(d.snapshot() == before)
	assert(preview.variants == {home.id: "garden", second.id: "garden", third.id: "basic"})
	assert(BuildingRules.place(d, Vector2i(12, 15), "greenhouse").begins_with("Placed"))
	var planted := BuildingRules.neighborhood(d)
	assert(preview == planted)
	var sim := ResidentSim.new()
	var resident := {"home": home.id, "id": 1, "x": 15.0, "z": 17.0}
	sim.choose_activity(d, resident)
	assert("garden" not in sim.completed) # inherited flowers are scenery
	assert(planted.ground[Vector2i(14, 15)] == "meadow")
	assert(not planted.ground.has(Vector2i(15, 17))) # door
	assert(not planted.ground.has(Vector2i(15, 15))) # foundation
	d.undo()
	assert(BuildingRules.neighborhood(d) == plain and before == d.snapshot())
	d.redo()
	assert(BuildingRules.neighborhood(d) == planted)

	# A move preview removes the source at its old location and resolves both ends.
	var moved: Dictionary = d.objects[-1].duplicate()
	moved.x = 24
	var moved_preview := BuildingRules.neighborhood(d, moved)
	assert(moved_preview.variants == {home.id: "basic", second.id: "garden", third.id: "garden"})
	d.begin()
	d.objects[-1].x = 24
	assert(BuildingRules.neighborhood(d) == moved_preview)
	d.undo()
	d.objects.reverse()
	assert(BuildingRules.neighborhood(d) == planted)
	var loaded := IslandData.new()
	loaded.restore(JSON.parse_string(JSON.stringify(d.snapshot())))
	assert(BuildingRules.neighborhood(loaded) == planted)

	# Removing/replacing the source works for old schema-v1 records, without caches.
	d.begin()
	d.objects = d.objects.filter(func(o): return o.kind != "greenhouse")
	assert(BuildingRules.neighborhood(d) == plain)
	d.undo()
	d.paint([Vector2i(14, 15), Vector2i(14, 16)], "raise")
	assert(BuildingRules.neighborhood(d).variants[home.id] == "basic")
	d.undo()
	d.paint([Vector2i(14, 15)], "road")
	assert(not BuildingRules.neighborhood(d).ground.has(Vector2i(14, 15)))
	d.paint([Vector2i(14, 16)], "flower")
	assert(not BuildingRules.neighborhood(d).ground.has(Vector2i(14, 16)))

	# Competing sources leave a neutral courtyard. A lock wins even when painted.
	assert(BuildingRules.place(d, Vector2i(15, 12), "lighthouse").begins_with("Placed"))
	assert(BuildingRules.neighborhood(d).variants[home.id] == "basic")
	d.paint([Vector2i(15, 14), Vector2i(16, 14), Vector2i(17, 14)], "flower")
	assert(BuildingRules.neighborhood(d).variants[home.id] == "garden")
	sim.choose_activity(d, resident)
	assert("garden" in sim.completed)
	for o in d.objects:
		if o.id == home.id:
			d.begin()
			o.locked = true
			o.variant = "basic"
	assert(BuildingRules.neighborhood(d).variants[home.id] == "basic")
	assert(BuildingRules.neighborhood(d).variants[second.id] == "basic")
	print("PASS neighbourhood: two waves, conflicts, locks, protected ground, move preview, undo/redo, order and save reconstruction")
	quit()
