class_name RouteGraph
extends RefCounted
static func entrance(o:Dictionary) -> Vector2i:
	var p=Vector2i(o.x,o.z)
	return p+[Vector2i(0,2),Vector2i(-1,0),Vector2i(0,-1),Vector2i(2,0)][int(o.get("rotation",0))%4]
static func neighbors(d:IslandData,p:Vector2i) -> Array:
	var out:Array=[]
	for dir in BuildingRules.DIRS:
		var q=p+dir
		if d.cell(q).h>0 and d.cell(q).road and absi(int(d.cell(p).h)-int(d.cell(q).h))<=1:out.append(q)
	for o in d.objects:
		if o.kind!="bridge":continue
		var a=Vector2i(o.x,o.z);var b=a+BuildingRules.DIRS[int(o.rotation)%4]*(int(o.length)+1)
		if p==a and d.cell(b).road:out.append(b)
		if p==b and d.cell(a).road:out.append(a)
	return out
static func path(d:IslandData,start:Vector2i,goal:Vector2i) -> Array:
	if not d.cell(start).road or not d.cell(goal).road:return []
	var queue:Array=[start];var prev:Dictionary={start:start};var at=0
	while at<queue.size():
		var p:Vector2i=queue[at];at+=1
		if p==goal:
			var result:Array=[p]
			while p!=start:p=prev[p];result.push_front(p)
			return result
		for q in neighbors(d,p):
			if not prev.has(q):prev[q]=p;queue.append(q)
	return []
static func open_sea(d:IslandData,o:Dictionary) -> bool:
	var dir=BuildingRules.DIRS[int(o.rotation)%4];var start=Vector2i(o.x,o.z)+dir*(int(o.length)+1)
	if d.cell(start).h!=0:return false
	var queue:Array=[start];var seen:Dictionary={start:true};var at=0
	while at<queue.size():
		var p:Vector2i=queue[at];at+=1
		if p.x==0 or p.y==0 or p.x==63 or p.y==63:return true
		for delta in BuildingRules.DIRS:
			var q=p+delta
			if q.x<0 or q.x>=64 or q.y<0 or q.y>=64 or seen.has(q) or d.cell(q).h!=0 or BuildingRules.occupied(d,q):continue
			seen[q]=true;queue.append(q)
	return false
