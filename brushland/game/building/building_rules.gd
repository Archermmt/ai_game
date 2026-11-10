class_name BuildingRules
extends RefCounted
const DIRS=[Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]
const BUILDINGS=["house","tea","greenhouse","lighthouse"]
const FORM_COUNT := 3
const BuildingSeams = preload("res://game/building/building_seams.gd")
const TOOLS=["house","tea","greenhouse","lighthouse","bench","pot","tree","bridge","dock"]
static func footprint(o:Dictionary) -> Array:
	var out:Array=[];var p=Vector2i(int(o.x),int(o.z));var kind=String(o.kind)
	if kind in ["bridge","dock"]:
		var dir:Vector2i=DIRS[int(o.get("rotation",0))%4]
		for i in range(int(o.get("length",3))+1):out.append(p+dir*i)
		if kind=="bridge":out.append(p+dir*(int(o.get("length",3))+1))
		if kind=="dock":
			var side=Vector2i(-dir.y,dir.x)
			for i in range(1,4):out.append(p+dir*i+side)
	elif kind in BUILDINGS:
		for x in range(2):
			for z in range(2):out.append(p+Vector2i(x,z))
	else:out.append(p)
	return out
static func inside(p:Vector2i) -> bool:
	return p.x>=0 and p.y>=0 and p.x<64 and p.y<64
static func occupied(d:IslandData,p:Vector2i,include_entry:bool=true,exclude_id:int=0) -> bool:
	for o in d.objects:
		if int(o.id)==exclude_id:continue
		if p in footprint(o) or (include_entry and (o.kind in BUILDINGS or o.kind=="bench") and p==activity_cell(o)):return true
	return false
static func road_paintable(d:IslandData,p:Vector2i) -> bool:
	if not inside(p) or int(d.cell(p).h)<=0:return false
	for object in d.objects:
		if not p in footprint(object):continue
		var anchor=Vector2i(object.x,object.z)
		if object.kind=="dock" and p==anchor:continue
		if object.kind=="bridge" and (p==anchor or p==anchor+DIRS[int(object.rotation)]*(int(object.length)+1)):continue
		return false
	return true
# Appearance is derived from the current player-owned tiles and footprints. The
# proposal shadows the object with the same ID for a move preview; ID 0 is new.
static func neighborhood(d: IslandData, proposal: Dictionary = {}) -> Dictionary:
	var buildings: Dictionary = {}
	var reserved: Dictionary = {}
	var owner: Dictionary = {}
	var objects: Array = d.objects.duplicate()
	if not proposal.is_empty():
		objects = objects.filter(func(o): return int(o.id) != int(proposal.get("id", 0)))
		objects.append(proposal)
	for object in objects:
		var is_building: bool = object.kind in BUILDINGS
		for cell in footprint(object):
			reserved[cell] = true
			if is_building:
				owner[cell] = int(object.id)
		if is_building or object.kind == "bench":
			reserved[activity_cell(object)] = true
		if is_building:
			buildings[int(object.id)] = object

	var variants: Dictionary = {}
	var reasons: Dictionary = {}
	var frontier: Dictionary = {}
	for id in buildings:
		var object: Dictionary = buildings[id]
		match object.kind:
			"greenhouse": frontier[id] = "garden"
			"lighthouse": frontier[id] = "coast"
			"house":
				var local := _home_constraint(d, object)
				if local.is_empty():
					continue
				variants[id] = local[0]
				reasons[id] = local[1]
				if local[0] != "basic":
					frontier[id] = local[0]

	# Each wave intersects the domains supplied by already settled neighbours.
	# "basic" is compatible with both styles so a conflict has a legal solution.
	# Resolve the entire wave at once: direction and placement order never break ties.
	for depth in range(2):
		var requests: Dictionary = {}
		for id in frontier:
			for neighbor_id in _linked_buildings(d, buildings[id], owner):
				if buildings[neighbor_id].kind != "house" or variants.has(neighbor_id):
					continue
				var mask := 3 if frontier[id] == "garden" else 5  # basic|garden or basic|coast
				requests[neighbor_id] = int(requests.get(neighbor_id, 7)) & mask
		frontier.clear()
		for id in requests:
			match requests[id]:
				3:
					variants[id] = "garden"
					reasons[id] = "邻家花园相连"
				5:
					variants[id] = "coast"
					reasons[id] = "邻家的海岸风貌延至这里"
				_:
					variants[id] = "basic"
					reasons[id] = "花园与海岸在庭院交会"
			if variants[id] != "basic":
				frontier[id] = variants[id]
		if frontier.is_empty():
			break
	for id in buildings:
		if buildings[id].kind == "house" and not variants.has(id):
			variants[id] = "basic"
			reasons[id] = ""
	var ground: Dictionary = {}
	for id in buildings:
		var object: Dictionary = buildings[id]
		var style: String = variants.get(id, "basic")
		var surface := "courtyard"
		if style == "garden" or object.kind == "greenhouse":
			surface = "meadow"
		elif style == "coast" or object.kind == "lighthouse":
			surface = "shore"
		var anchor := Vector2i(object.x, object.z)
		var height := int(d.cell(anchor).h)
		for x in range(-1, 3):
			for z in range(-1, 3):
				var cell := anchor + Vector2i(x, z)
				if reserved.has(cell):
					continue
				var tile := d.cell(cell)
				if height == 0 or int(tile.h) != height or tile.road or tile.flower:
					continue
				ground[cell] = surface if ground.get(cell, surface) == surface else "courtyard"
	var seams := BuildingSeams.for_world(d, buildings, owner)
	var halls := BuildingSeams.group_halls(buildings, seams)
	return {"variants": variants, "ground": ground, "reasons": reasons, "seams": seams, "halls": halls}

# A second stroke belongs to the same building family. Crossing another family
# with the brush is still a blocked placement, and a reserved door is never a hit.
static func reshape_target(d: IslandData, cell: Vector2i, brush_kind: String) -> Dictionary:
	if brush_kind not in BUILDINGS:
		return {}
	for object in d.objects:
		if object.kind == brush_kind and cell in footprint(object):
			return object
	return {}

static func next_form(object: Dictionary) -> int:
	return (int(object.get("form", 0)) + 1) % FORM_COUNT

static func reshape(d: IslandData, cell: Vector2i, brush_kind: String) -> String:
	var target := reshape_target(d, cell, brush_kind)
	if target.is_empty():
		return "请在同类建筑上落笔"
	if target.get("locked", false):
		return "外观已定形，先解锁再改建"
	d.begin()
	var new_form := next_form(target)
	if new_form == 0:
		target.erase("form")
	else:
		target.form = new_form
	return ""

static func _linked_buildings(d: IslandData, object: Dictionary, owner: Dictionary) -> Dictionary:
	var linked: Dictionary = {}
	var anchor := Vector2i(object.x, object.z)
	var height := int(d.cell(anchor).h)
	for start in footprint(object):
		for direction in DIRS:
			var cell: Vector2i = start + direction
			if int(d.cell(cell).h) != height:
				continue
			if owner.has(cell):
				if int(owner[cell]) != int(object.id):
					linked[owner[cell]] = true
				continue
			# A one-cell garden or lane can join the two footprints, but a sea
			# channel and a height step cannot carry a neighbourhood style.
			for step in DIRS:
				var end := cell + Vector2i(step)
				if owner.has(end) and int(owner[end]) != int(object.id) and int(d.cell(end).h) == height:
					linked[owner[end]] = true
	return linked

static func flower_count(d: IslandData, object: Dictionary) -> int:
	if object.is_empty():
		return 0
	var anchor := Vector2i(object.x, object.z)
	var flowers := 0
	for x in range(-1, 3):
		for z in range(-1, 3):
			if x in [0, 1] and z in [0, 1]:
				continue
			if d.cell(anchor + Vector2i(x, z)).flower:
				flowers += 1
	return flowers

static func _home_constraint(d: IslandData, object: Dictionary) -> Array:
	if object.get("locked", false):
		return [object.get("variant", "basic"), "外观已锁定"]
	if flower_count(d, object) >= 3:
		return ["garden", "屋旁有三格花圃"]
	for cell in footprint(object):
		for direction in DIRS:
			var near: Vector2i = cell + direction
			if int(d.cell(near).h) == 0:
				return ["coast", "屋旁靠近海水"]
			if int(d.cell(near).h) > int(d.cell(cell).h):
				continue
			for step in DIRS:
				if int(d.cell(near + step).h) == 0:
					return ["coast", "屋旁靠近海水"]
	return []

static func variant(d: IslandData, object: Dictionary) -> String:
	if object.kind != "house":
		return "basic"
	var local := _home_constraint(d, object)
	if not local.is_empty():
		return local[0]
	return neighborhood(d, object).variants.get(int(object.id), "basic")

static func check(d:IslandData,o:Dictionary,exclude_id:int=0) -> String:
	if not String(o.kind) in TOOLS:return "未知物件"
	var p=Vector2i(o.x,o.z);var h=int(d.cell(p).h)
	for q in footprint(o):
		if not inside(q):return "超出岛屿编辑范围"
		if occupied(d,q,true,exclude_id):return "这里已有物件或需要预留入口"
	if o.kind in ["bridge","dock"]:
		var length=int(o.length);var dir:Vector2i=DIRS[int(o.rotation)%4]
		if h<1 or h>2:return "桥头 / 码头须在一至二级岸边"
		if length<2 or length>(6 if o.kind=="bridge" else 4):return "木桥跨度 2–6 格，码头长度 2–4 格"
		for i in range(1,length+1):
			if d.cell(p+dir*i).h!=0:return "跨段需要连续水面"
		if o.kind=="bridge" and d.cell(p+dir*(length+1)).h!=h:return "桥的两端需要同高陆地"
		if o.kind=="dock":
			var side=Vector2i(-dir.y,dir.x)
			for i in range(1,4):
				if d.cell(p+dir*i+side).h!=0:return "码头侧边须留出 1×3 格泊位"
	else:
		if h==0:return "请先画出一片陆地"
		for q in footprint(o):
			if d.cell(q).h!=h:return "建筑需要平整的 2×2 地基"
		if o.kind in BUILDINGS:
			var entry=RouteGraph.entrance(o)
			if not inside(entry) or d.cell(entry).h!=h or occupied(d,entry,true,exclude_id):return "门前需要同高、无遮挡的一格小路"
		elif o.kind=="bench":
			var entry=activity_cell(o)
			if not inside(entry) or d.cell(entry).h!=h or occupied(d,entry,true,exclude_id):return "长椅前需要同高的空地"
	return ""
static func activity_cell(o:Dictionary) -> Vector2i:
	return RouteGraph.entrance(o) if o.kind in BUILDINGS else Vector2i(o.x,o.z)+[Vector2i(0,1),Vector2i(-1,0),Vector2i(0,-1),Vector2i(1,0)][int(o.rotation)%4]
static func place(d:IslandData,p:Vector2i,kind:String,rotation:int=0,length:int=3) -> String:
	var o={"id":d.next_id,"x":p.x,"z":p.y,"kind":kind,"rotation":posmod(rotation,4),"length":length,"locked":false,"color":0}
	var error=check(d,o)
	if not error.is_empty():return error
	d.begin();d.objects.append(o);d.next_id+=1
	return "Placed " + kind
