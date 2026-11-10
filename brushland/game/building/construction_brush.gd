extends RefCounted
## Candidate foundations always contain the cell under the brush. On an exposed
## wall prefer the legal candidate with the longest shared edge.
static func foundation(data: IslandData, cell: Vector2i, kind: String, rotation: int) -> Dictionary:
	var raw := {"id": 0, "x": cell.x, "z": cell.y, "kind": kind, "rotation": rotation, "length": 3, "locked": false, "color": 0}
	if not BuildingRules.inside(cell):
		return raw
	var neighbors: Array = []
	var beside_wall := false
	for building in data.objects:
		if building.kind not in BuildingRules.BUILDINGS:
			continue
		var delta := cell - Vector2i(building.x, building.z)
		if delta.x < -2 or delta.x > 3 or delta.y < -2 or delta.y > 3:
			continue
		var gap := Vector2i(maxi(-delta.x, delta.x - 1), maxi(-delta.y, delta.y - 1))
		if gap.x <= 0 and gap.y <= 0:
			return raw
		if maxi(0, gap.x) + maxi(0, gap.y) == 1:
			beside_wall = true
		if data.cell(cell).h == data.cell(Vector2i(building.x, building.z)).h:
			neighbors.append(building)
	if not beside_wall:
		return raw
	var best := raw
	var best_score := 0
	for offset in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.UP, Vector2i(-1,-1)]:
		var candidate := raw.duplicate()
		candidate.x += offset.x
		candidate.z += offset.y
		var score := 0
		for other in neighbors:
			var dx := absi(int(candidate.x) - int(other.x))
			var dz := absi(int(candidate.z) - int(other.z))
			if dx == 2:
				score += maxi(0, 2 - dz)
			if dz == 2:
				score += maxi(0, 2 - dx)
		if score <= best_score:
			continue
		for turn in range(4):
			candidate.rotation = posmod(rotation + turn, 4)
			if BuildingRules.check(data, candidate).is_empty():
				best = candidate.duplicate()
				best_score = score
				break
	return best

# Plan against a shallow, append-only copy. The real world enters its undo
# history only once, after the button is released on the canvas.
var draft := IslandData.new()
var added: Array[Dictionary] = []
var visited: Dictionary = {}
var revision: int
var kind: String
var rotation: int

func _init(data: IslandData, brush: String, facing: int) -> void:
	draft.tiles = data.tiles
	draft.objects = data.objects.duplicate()
	draft.next_id = data.next_id
	revision = data.revision
	kind = brush
	rotation = facing

func sample(cell: Vector2i) -> void:
	if visited.has(cell):
		return
	visited[cell] = true
	var candidate := foundation(draft, cell, kind, rotation)
	if not BuildingRules.check(draft, candidate).is_empty():
		return
	candidate.id = draft.next_id
	draft.next_id += 1
	draft.objects.append(candidate)
	added.append(candidate)

func apply(data: IslandData) -> bool:
	if added.is_empty() or revision != data.revision:
		return false
	data.begin()
	data.objects.append_array(added)
	data.next_id = draft.next_id
	return true
