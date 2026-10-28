class_name BuildingRules
extends RefCounted
const DIRS=[Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]
const BUILDINGS=["house","tea","greenhouse","lighthouse"]
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
static func variant(d:IslandData,o:Dictionary) -> String:
	if o.kind!="house":return "basic"
	if o.get("locked",false):return o.get("variant","basic")
	var flowers=0;var coast=false
	for x in range(-1,3):
		for z in range(-1,3):
			if x>=0 and x<2 and z>=0 and z<2:continue
			if d.cell(Vector2i(int(o.x)+x,int(o.z)+z)).flower:flowers+=1
	for f in footprint(o):
		for delta in DIRS:
			var mid:Vector2i=f+delta
			if d.cell(mid).h==0:coast=true
			if d.cell(mid).h>d.cell(f).h:continue
			for second in DIRS:
				if d.cell(mid+second).h==0:coast=true
	return "garden" if flowers>=3 else "coast" if coast else "basic"
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
