class_name ResidentSim
extends RefCounted
var people:Array=[]
var elapsed:float=0
var next_id:int=1
var paused:bool=false
func reconcile(d:IslandData) -> void:
	var used:Dictionary={}
	for person in people:
		var found=false
		for o in d.objects:
			if o.kind=="house" and o.id==person.home and not used.has(o.id):found=true;used[o.id]=true
		if not found:person.home=0;person.state="resting";person.route=[]
		elif person.state in ["arriving","waiting"] and person.route.is_empty():
			for o in d.objects:
				if o.id==person.home:
					person.route=RouteGraph.path(d,Vector2i(roundi(person.x),roundi(person.z)),RouteGraph.entrance(o))
					if not person.route.is_empty():person.state="arriving"
	for person in people:
		if person.home!=0:continue
		for o in d.objects:
			if o.kind=="house" and not used.has(o.id) and not arrival_path(d,o).is_empty():
				person.home=o.id;used[o.id]=true;person.route=arrival_path(d,o);person.state="arriving";break
func arrival_path(d:IslandData,house:Dictionary) -> Array:
	for dock in d.objects:
		if dock.kind!="dock" or not RouteGraph.open_sea(d,dock):continue
		var anchor=Vector2i(dock.x,dock.z)
		if not d.cell(anchor).road:continue
		var r=RouteGraph.path(d,anchor,RouteGraph.entrance(house))
		if not r.is_empty():return r
	return []
func tick(d:IslandData,dt:float) -> bool:
	if paused:return false
	reconcile(d);elapsed+=dt
	var changed=false
	if elapsed>=8.0 and people.size()<12:
		elapsed=0
		var used:Array=[]
		for person in people:used.append(person.home)
		for o in d.objects:
			if o.kind!="house" or o.id in used:continue
			var r=arrival_path(d,o)
			if r.is_empty():continue
			people.append({"id":next_id,"home":o.id,"x":float(r[0].x),"z":float(r[0].y),"state":"arriving","route":r})
			next_id+=1;changed=true;break
	for person in people:
		if person.route.is_empty():continue
		var target:Vector2i=person.route[0]
		if not d.cell(target).road:
			person.route=[];person.state="waiting";continue
		var pos=Vector2(person.x,person.z);var goal=Vector2(target)
		pos=pos.move_toward(goal,dt*1.1);person.x=pos.x;person.z=pos.y
		if pos.distance_to(goal)<0.01:person.route.pop_front()
		if person.route.is_empty():person.state="home";changed=true
	return changed
