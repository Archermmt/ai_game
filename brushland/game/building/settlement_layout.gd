extends RefCounted
## Space descriptions are derived from occupied plots, never saved as gameplay
## objects. Flooding the bounded empty space distinguishes a court from a street.
static func describe(data: IslandData, buildings: Dictionary, seams: Dictionary) -> Dictionary:
	var layouts: Dictionary = {}
	var owner: Dictionary = {}
	for id in buildings:
		var object: Dictionary = buildings[id]
		for cell in BuildingRules.footprint(object):
			owner[cell] = id
		var directions: Dictionary = {}
		for seam in seams.get(id, []):
			directions[seam.direction] = true
		var role := "detached"
		if directions.size() == 1:
			role = "end"
		elif directions.size() == 2:
			var sides := directions.keys()
			role = "street" if Vector2i(sides[0]) + Vector2i(sides[1]) == Vector2i.ZERO else "corner"
		elif directions.size() >= 3:
			role = "junction"
		layouts[id] = {"role": role, "courts": [], "accent": posmod(int(object.x)*7 + int(object.z)*13, 3)}
	if buildings.size() < 4:
		return {"buildings": layouts, "courts": []}
	var low := Vector2i(63,63)
	var high := Vector2i.ZERO
	for p: Vector2i in owner:
		low = low.min(p)
		high = high.max(p)
	low -= Vector2i.ONE
	high += Vector2i.ONE
	var exterior: Dictionary = {}
	var todo: Array[Vector2i] = []
	for x in range(low.x, high.x+1):
		todo.append(Vector2i(x, low.y))
		todo.append(Vector2i(x, high.y))
	for z in range(low.y, high.y+1):
		todo.append(Vector2i(low.x, z))
		todo.append(Vector2i(high.x, z))
	var cursor := 0
	while cursor < todo.size():
		var p := todo[cursor]
		cursor += 1
		if exterior.has(p) or owner.has(p):
			continue
		exterior[p] = true
		for direction in BuildingRules.DIRS:
			var q: Vector2i = p + direction
			if q.x >= low.x and q.y >= low.y and q.x <= high.x and q.y <= high.y and not exterior.has(q):
				todo.append(q)
	var courts: Array = []
	var visited := exterior.duplicate()
	for z in range(low.y+1, high.y):
		for x in range(low.x+1, high.x):
			var start := Vector2i(x,z)
			if visited.has(start) or owner.has(start):
				continue
			var region: Array[Vector2i] = [start]
			visited[start] = true
			cursor = 0
			while cursor < region.size():
				var p := region[cursor]
				cursor += 1
				for direction in BuildingRules.DIRS:
					var q: Vector2i = p + direction
					if owner.has(q):
						var id: int = owner[q]
						var inward: Vector2i = -direction
						if not layouts[id].courts.has(inward):
							layouts[id].courts.append(inward)
					elif not visited.has(q):
						visited[q] = true
						region.append(q)
			courts.append(region)
	return {"buildings": layouts, "courts": courts}
