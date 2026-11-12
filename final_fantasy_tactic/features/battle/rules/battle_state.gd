extends RefCounted

const ROWS = ["............", ".3333333333.", ".33333#3333.", "..33333333..", "..2....222..", "..1....111..", "000000000000", "00000#000000", "000000000000", ".0000000000."]
const STATS = [[120,0,32,10,10,3],[85,0,28,6,12,4],[80,24,20,5,9,3]]
const DIRS = [Vector2i(0,-1),Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0)]
var tiles: Dictionary = {}
var units: Array = []
var active: int = -1
var revision: int = 0
var result: String = ""
var tick: int = 0

func _init() -> void:
	for z in range(10):
		for x in range(12):
			var c: String = ROWS[z][x]
			if c != ".": tiles[Vector2i(x,z)] = {"h": (3 if z==2 else 0) if c=="#" else int(c), "blocked":c=="#"}
	var positions = [Vector2i(3,7),Vector2i(2,3),Vector2i(4,8),Vector2i(4,2),Vector2i(2,8),Vector2i(8,1)]
	for i in range(6):
		var job: int = i / 2
		var s: Array = STATS[job]
		units.append({"id":i,"team":i%2,"job":job,"p":positions[i],"hp":s[0],"mp":s[1],"ct":0,"moved":false,"acted":false})
	advance()

func height(p: Vector2i) -> int:
	return int(tiles[p].h) if tiles.has(p) else -99

func occupant(p: Vector2i) -> int:
	for u in units:
		if u.hp>0 and u.p==p: return u.id
	return -1

func walkable(p: Vector2i) -> bool:
	return tiles.has(p) and not tiles[p].blocked

func paths(id: int, limit: int = -1, ignore_units: bool = false) -> Dictionary:
	var start: Vector2i = units[id].p
	var found: Dictionary = {start:[]}
	var queue: Array = [start]
	while not queue.is_empty():
		var p: Vector2i = queue.pop_front()
		if limit>=0 and found[p].size()>=limit: continue
		for d in DIRS:
			var q: Vector2i = p+d
			if found.has(q) or not walkable(q) or abs(height(q)-height(p))>1: continue
			if not ignore_units and occupant(q)>=0 and q!=start: continue
			found[q]=found[p]+[q]
			queue.append(q)
	return found

func advance() -> void:
	if not result.is_empty(): return
	while true:
		var ready: Array = []
		for u in units:
			if u.hp>0 and u.ct>=100: ready.append(u.id)
		if not ready.is_empty():
			ready.sort_custom(func(a,b): return units[a].ct>units[b].ct if units[a].ct!=units[b].ct else a<b)
			active=ready[0]
			units[active].moved=false
			units[active].acted=false
			return
		for u in units:
			if u.hp>0: u.ct+=STATS[u.job][4]
		tick+=1

# Closed slab intervals include corner-touching cells: a deterministic supercover.
func line_clear(a: Vector2i,b: Vector2i) -> bool:
	var origin := Vector2(a)+Vector2(0.5,0.5)
	var delta := Vector2(b-a)
	for p in tiles:
		if p==a or p==b: continue
		var enter: float=0.0
		var leave: float=1.0
		var hit: bool=true
		for axis in range(2):
			if abs(delta[axis])<0.00001:
				if origin[axis]<p[axis] or origin[axis]>p[axis]+1: hit=false
			else:
				var t1: float=(p[axis]-origin[axis])/delta[axis]
				var t2: float=(p[axis]+1-origin[axis])/delta[axis]
				enter=maxf(enter,minf(t1,t2))
				leave=minf(leave,maxf(t1,t2))
		if not hit or enter>leave+0.00001: continue
		var top: int=height(p)+(2 if tiles[p].blocked else 0)
		var low: float=minf(lerpf(height(a)+2,height(b)+2,enter),lerpf(height(a)+2,height(b)+2,leave))
		if low<=top+0.00001: return false
	return true

func preview(kind: String, target: Vector2i, expected: int = -1) -> Dictionary:
	var response: Dictionary=_preview(kind,target,expected)
	response["battle_id"]=get_instance_id()
	response["actor"]=active
	return response

func _preview(kind: String, target: Vector2i, expected: int = -1) -> Dictionary:
	var fail := {"ok":false,"reason":"操作不可用"}
	if expected>=0 and expected!=revision:
		fail.reason="预览已过期，请重新选择"; return fail
	if kind not in ["move","attack","heal","end"] or not result.is_empty(): return fail
	var u: Dictionary=units[active]
	if kind=="end": return {"ok":true,"kind":kind,"revision":revision}
	if kind=="move":
		if u.moved: fail.reason="本次移动已使用"; return fail
		var available: Dictionary=paths(active,STATS[u.job][5])
		if target==u.p: fail.reason="已在原位，不消耗移动"; return fail
		if not tiles.has(target): fail.reason="没有可站立面"; return fail
		if tiles[target].blocked: fail.reason="实心障碍不可通行"; return fail
		if occupant(target)>=0: fail.reason="目标格被单位占用"; return fail
		if not available.has(target):
			var unlimited: Dictionary=paths(active)
			if unlimited.has(target): fail.reason="超过移动步数：需要%d步，最多%d步"%[unlimited[target].size(),STATS[u.job][5]]
			elif paths(active,-1,true).has(target): fail.reason="路径被单位阻挡"
			else: fail.reason="没有高度连续的可走路径"
			return fail
		return {"ok":true,"kind":kind,"p":target,"path":available[target],"revision":revision}
	if u.acted: fail.reason="本次行动已使用"; return fail
	var other: int=occupant(target)
	if other<0: fail.reason="请选择存活单位"; return fail
	var v: Dictionary=units[other]
	var dist: int=abs(u.p.x-target.x)+abs(u.p.y-target.y)
	var dh: int=height(u.p)-height(target)
	var amount: int=0
	if kind=="heal":
		if u.job!=2 or v.team!=u.team: fail.reason="治疗需要医师与友方目标"; return fail
		if u.mp<6: fail.reason="MP不足：需要6"; return fail
		if v.hp==STATS[v.job][0]: fail.reason="目标满血"; return fail
		if dist>3 or abs(dh)>2: fail.reason="超出治疗距离或高差"; return fail
		amount=mini(36,STATS[v.job][0]-v.hp)
	else:
		if v.team==u.team: fail.reason="请选择敌方"; return fail
		if u.job==1:
			if dist<2 or dist>(5 if dh>0 else 4) or abs(dh)>3: fail.reason="超出弓箭射程或高度"; return fail
			if not line_clear(u.p,target): fail.reason="被地形遮挡"; return fail
		elif dist!=1 or abs(dh)>1: fail.reason="需要邻接且高差不超过1"; return fail
		var bonus: int=(4 if dh>0 else -4 if dh<0 else 0) if u.job==1 else 0
		amount=mini(v.hp,maxi(1,STATS[u.job][2]-STATS[v.job][3]+bonus))
	return {"ok":true,"kind":kind,"p":target,"target":other,"amount":amount,"revision":revision}

func snapshot():
	var copy = get_script().new()
	copy.tiles=tiles.duplicate(true)
	copy.units=units.duplicate(true)
	copy.active=active; copy.revision=revision; copy.result=result; copy.tick=tick
	return copy

func request(kind: String, target: Vector2i) -> Dictionary:
	var value: Dictionary=preview(kind,target)
	value["battle_id"]=get_instance_id()
	value["actor"]=active
	return value

func commit(request_data: Dictionary) -> Dictionary:
	if request_data.get("revision",-1)!=revision:
		return {"ok":false,"reason":"预览已过期，请重新选择"}
	if request_data.get("battle_id",-1)!=get_instance_id():
		return {"ok":false,"reason":"战局已替换"}
	if request_data.get("actor",-1)!=active:
		return {"ok":false,"reason":"行动者已改变"}
	var checked: Dictionary=preview(request_data.get("kind",""),request_data.get("p",Vector2i.ZERO),request_data.get("revision",-1))
	if not checked.ok: return checked
	var u: Dictionary=units[active]
	match checked.kind:
		"move": u.p=checked.p; u.moved=true
		"attack": units[checked.target].hp-=checked.amount; u.acted=true
		"heal": units[checked.target].hp+=checked.amount; u.mp-=6; u.acted=true
		"end": u.ct-=100
	revision+=1
	var alive: Array=[0,0]
	for v in units:
		if v.hp>0: alive[v.team]+=1
	if alive[0]==0: result="败北 · 重新规划路线"
	elif alive[1]==0: result="胜利 · 前哨已夺回"
	if checked.kind=="end" and result.is_empty(): advance()
	return checked

func timeline() -> String:
	var copy= snapshot()
	if not copy.result.is_empty(): return copy.result
	var labels: Array=[]
	for i in range(8):
		labels.append(copy.unit_name(copy.active))
		copy.units[copy.active].ct-=100
		copy.advance()
	return " → ".join(labels)

func unit_name(id: int) -> String:
	return ("我方" if units[id].team==0 else "对方")+["守卫","弓手","医师"][units[id].job]
