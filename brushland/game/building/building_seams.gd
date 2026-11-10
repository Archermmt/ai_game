extends RefCounted
## Contacts between 2×2 buildings. One record per uninterrupted piece of
## common wall, expressed in board coordinates regardless of building rotation.

static func for_world(data: IslandData, buildings: Dictionary, owner: Dictionary) -> Dictionary:
	var seams: Dictionary = {}
	for id in buildings:
		var object: Dictionary = buildings[id]
		var anchor := Vector2i(object.x, object.z)
		var level := int(data.cell(anchor).h)
		var contacts: Array = []
		for direction: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var first := anchor + Vector2i(maxi(0, direction.x), maxi(0, direction.y))
			var along := Vector2i(absi(direction.y), absi(direction.x))
			var left := neighbor_at(data, owner, first, direction, level)
			var right := neighbor_at(data, owner, first + along, direction, level)
			var center := Vector2(first) + Vector2(direction) * 0.5
			if left >= 0 and left == right:
				contacts.append(contact(buildings[left], direction, center + Vector2(along) * 0.5, 2.0))
			else:
				if left >= 0:
					contacts.append(contact(buildings[left], direction, center, 1.0))
				if right >= 0:
					contacts.append(contact(buildings[right], direction, center + Vector2(along), 1.0))
		if not contacts.is_empty():
			seams[id] = contacts
	return seams

static func neighbor_at(data: IslandData, owner: Dictionary, edge_cell: Vector2i, direction: Vector2i, level: int) -> int:
	var adjacent := edge_cell + direction
	if not owner.has(adjacent) or level == 0:
		return -1
	if int(data.cell(edge_cell).h) != level or int(data.cell(adjacent).h) != level:
		return -1
	return owner[adjacent]

static func contact(neighbor: Dictionary, direction: Vector2i, center: Vector2, width: float) -> Dictionary:
	return {
		"other": int(neighbor.id), "other_kind": neighbor.kind, "other_form": int(neighbor.get("form", 0)),
		"direction": direction, "center": center, "width": width,
	}

# Grow a central roof only when at least three buildings actually share walls.
# A hand-shaped central building serves as the focal point in its own right.
static func group_halls(buildings: Dictionary, seams: Dictionary) -> Dictionary:
	var halls: Dictionary = {}
	for id in buildings:
		var object: Dictionary = buildings[id]
		if object.get("locked", false) and object.get("hall_locked", false):
			halls[id] = true
	var seen: Dictionary = {}
	for first in seams:
		if seen.has(first):
			continue
		var component: Array = [first]
		var cursor := 0
		var sum := Vector2i.ZERO
		var already_has_hall := false
		seen[first] = true
		while cursor < component.size():
			var id: int = component[cursor]
			cursor += 1
			var object: Dictionary = buildings[id]
			sum += Vector2i(object.x, object.z)
			if halls.has(id):
				already_has_hall = true
			for seam in seams[id]:
				if not seen.has(seam.other):
					seen[seam.other] = true
					component.append(seam.other)
		if component.size() < 3 or already_has_hall:
			continue
		var host := central_host(buildings, component, sum)
		if not host.is_empty() and int(host.get("form", 0)) == 0:
			halls[int(host.id)] = true
	return halls

static func central_host(buildings: Dictionary, component: Array, sum: Vector2i) -> Dictionary:
	var best: Dictionary = {}
	var best_distance := 0
	for id in component:
		var object: Dictionary = buildings[id]
		if object.kind not in ["house", "tea"] or object.get("locked", false):
			continue
		# All footprints have equal area; the half-cell center offsets cancel.
		# Compare squared distance times N² using integer arithmetic for exact ties.
		var dx := int(object.x) * component.size() - sum.x
		var dz := int(object.z) * component.size() - sum.y
		var distance := dx * dx + dz * dz
		if best.is_empty() or distance < best_distance or (distance == best_distance and Vector2i(object.x, object.z) < Vector2i(best.x, best.z)):
			best = object
			best_distance = distance
	return best
