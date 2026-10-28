class_name ResidentSim
extends RefCounted
var people:Array=[]
var elapsed:float=0
var next_id:int=1
var paused:bool=false
var completed:Array=[]
var pending_tea:Array=[]
var events:Array=[]
var sunset:bool=false
var revision:int=-1
func defaults(p:Dictionary) -> void:
	for k in {"timer":0.0,"target":0,"activity":"","route":[],"crossed":false}:
		if not p.has(k):p[k]={"timer":0.0,"target":0,"activity":"","route":[],"crossed":false}[k]
func object_by_id(d:IslandData,id:int) -> Dictionary:
	for o in d.objects:
		if int(o.id)==id:return o
	return {}
func reconcile(d:IslandData) -> void:
	var used:Dictionary={}
	for person in people:
		defaults(person)
		var house=object_by_id(d,int(person.home))
		if house.is_empty() or house.kind!="house" or used.has(person.home):
			person.home=0;person.state="resting";person.route=[];person.target=0
		else:
			used[person.home]=true
			if person.target!=0:
				var activity=object_by_id(d,int(person.target))
				var moved=not activity.is_empty() and (int(person.get("target_x",activity.x))!=int(activity.x) or int(person.get("target_z",activity.z))!=int(activity.z))
				if activity.is_empty() or moved:person.target=0;person.route=[];person.state="home";person.timer=0
			if person.state=="resting" and d.cell(RouteGraph.entrance(house)).road:
				var entry=RouteGraph.entrance(house);person.x=float(entry.x);person.z=float(entry.y);person.state="home";person.timer=0
			if person.state in ["arriving","waiting"] and person.route.is_empty():
				person.route=RouteGraph.path(d,Vector2i(roundi(person.x),roundi(person.z)),RouteGraph.entrance(house))
				if not person.route.is_empty():person.state="arriving"
	for person in people:
		if person.home!=0:continue
		for o in d.objects:
			if o.kind=="house" and not used.has(o.id):
				var r=arrival_path(d,o)
				if r.is_empty():continue
				person.home=o.id;used[o.id]=true;person.route=r;person.x=float(r[0].x);person.z=float(r[0].y);person.state="arriving";break
func arrival_path(d:IslandData,house:Dictionary) -> Array:
	for dock in d.objects:
		if dock.kind!="dock" or not d.cell(Vector2i(dock.x,dock.z)).road:continue
		var route=RouteGraph.path(d,Vector2i(dock.x,dock.z),RouteGraph.entrance(house))
		if route.is_empty():continue
		if RouteGraph.open_sea(d,dock):return route
	return []
func record(key:String) -> void:
	if not key in completed:completed.append(key);events.append(key)
func tick(d:IslandData,dt:float) -> bool:
	if paused:return false
	if revision!=d.revision:reconcile(d);revision=d.revision
	elapsed+=dt
	var changed=false
	if elapsed>=(8.0 if people.is_empty() else 25.0) and people.size()<12:
		elapsed=0
		var used:Array=[]
		for person in people:used.append(person.home)
		for o in d.objects:
			if o.kind!="house" or o.id in used:continue
			var r=arrival_path(d,o)
			if r.is_empty():continue
			people.append({"id":next_id,"home":o.id,"x":float(r[0].x),"z":float(r[0].y),"state":"arriving","route":r,"timer":0.0,"target":0,"activity":"","crossed":false})
			next_id+=1;changed=true;break
	for person in people:
		defaults(person)
		if person.state=="resting":continue
		person.timer=float(person.timer)-dt
		if not person.route.is_empty():
			var target:Vector2i=person.route[0]
			var here=Vector2i(roundi(person.x),roundi(person.z))
			var invalid_jump=here.distance_to(target)>1.5 and d.cell(here).h>0 and not target in RouteGraph.neighbors(d,here)
			if not d.cell(target).road or invalid_jump:
				person.route=[];person.target=0;person.state="waiting";continue
			var pos=Vector2(person.x,person.z);var goal=Vector2(target)
			# Bridge graph edges span water; the actor moves across the deck continuously.
			var old_cell=Vector2i(roundi(pos.x),roundi(pos.y))
			pos=pos.move_toward(goal,dt*1.1);person.x=pos.x;person.z=pos.y
			if old_cell.distance_to(target)>1.5:person.crossed=true
			if pos.distance_to(goal)<0.01:person.route.pop_front()
			if person.route.is_empty():
				person.state=person.activity if person.target!=0 else "home";person.timer=7.0
				if person.crossed:record("bridge");person.crossed=false
				changed=true
			continue
		if person.state in ["tea","greenhouse","bench","lighthouse"]:
			if person.timer<3.0:
				if person.state=="tea":
					var guests=0
					for other in people:
						if other.state=="tea" and other.target==person.target:guests+=1
					if guests>=2:record("tea")
				elif person.state=="lighthouse":
					if sunset:record("lighthouse")
				else:
					var place=object_by_id(d,int(person.target))
					if person.state=="greenhouse" and flower_count(d,place)>=3:record("greenhouse")
					if person.state=="bench" and has_sea_view(d,place):record("bench")
			if person.timer>0:continue
			person.state="home";person.target=0;person.timer=2.0
		if person.timer<=0:choose_activity(d,person)
	return changed
func choose_activity(d:IslandData,person:Dictionary) -> void:
	var home=object_by_id(d,int(person.home))
	if not home.is_empty() and BuildingRules.variant(d,home)=="garden":record("garden")
	var start=Vector2i(roundi(person.x),roundi(person.z))
	var candidates=d.objects.duplicate()
	# Stable rotation varies residents' routines without nondeterministic layout changes.
	if not candidates.is_empty():
		var offset=posmod(int(person.id)+int(elapsed),candidates.size())
		candidates=candidates.slice(offset)+candidates.slice(0,offset)
	for o in candidates:
		if not o.kind in ["tea","greenhouse","bench","lighthouse"]:continue
		var taken=0
		for other in people:
			if other.target==o.id:taken+=1
		if taken>=(2 if o.kind=="tea" else 1):continue
		var r=RouteGraph.path(d,start,BuildingRules.activity_cell(o))
		if r.is_empty():continue
		person.route=r;person.target=o.id;person.target_x=o.x;person.target_z=o.z;person.activity=o.kind;person.state="walking";return
	# With no activity reachable, stroll to a reachable road, then rest.
	var choices=RouteGraph.neighbors(d,start)
	if not choices.is_empty():person.route=[choices[posmod(int(person.id)+int(elapsed),choices.size())]]
	person.target=0;person.activity="";person.timer=5.0

func flower_count(d:IslandData,o:Dictionary) -> int:
	if o.is_empty():return 0
	var count=0
	for x in range(-1,3):
		for z in range(-1,3):
			if x>=0 and x<2 and z>=0 and z<2:continue
			if d.cell(Vector2i(o.x+x,o.z+z)).flower:count+=1
	return count
func has_sea_view(d:IslandData,o:Dictionary) -> bool:
	if o.is_empty():return false
	var dir=[Vector2i(0,1),Vector2i(-1,0),Vector2i(0,-1),Vector2i(1,0)][int(o.rotation)%4]
	for distance in range(1,4):
		if d.cell(Vector2i(o.x,o.z)+dir*distance).h==0:return true
	return false
