class_name SaveStore
extends RefCounted
static func whole(value,minimum:int,maximum:int=2147483647) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value>=minimum and value<=maximum and float(value)==floorf(float(value))
static func validate(payload) -> Error:
	if not payload is Dictionary or payload.get("schema_version",0)!=1 or not payload.get("tiles") is Dictionary or not payload.get("objects") is Array or not payload.get("people") is Array:return ERR_FILE_CORRUPT
	if payload.tiles.size()>4096 or payload.objects.size()>4096 or payload.people.size()>12:return ERR_FILE_CORRUPT
	if not whole(payload.get("next_id"),1) or not whole(payload.get("resident_next_id"),1):return ERR_FILE_CORRUPT
	for key in payload.tiles:
		var xy=String(key).split(",");var cell=payload.tiles[key]
		if xy.size()!=2 or not xy[0].is_valid_int() or not xy[1].is_valid_int() or not BuildingRules.inside(Vector2i(int(xy[0]),int(xy[1]))):return ERR_FILE_CORRUPT
		if String(key)!="%d,%d"%[int(xy[0]),int(xy[1])]:return ERR_FILE_CORRUPT
		if not cell is Dictionary or not whole(cell.get("h"),0,4) or cell.get("surface") not in ["water","sand","grass","rock"] or not cell.get("road") is bool or not cell.get("flower") is bool:return ERR_FILE_CORRUPT
	var ids:Dictionary={};var highest=0
	for object in payload.objects:
		if not object is Dictionary or object.get("kind") not in BuildingRules.TOOLS or not object.get("locked") is bool:return ERR_FILE_CORRUPT
		for key in ["id","x","z","rotation","length"]:
			if not whole(object.get(key),1 if key=="id" else 0,2147483647 if key=="id" else 63 if key in ["x","z"] else 3 if key=="rotation" else 6):return ERR_FILE_CORRUPT
		if int(object.length)<2 or (object.kind=="dock" and int(object.length)>4):return ERR_FILE_CORRUPT
		if not whole(object.get("color",0),0,2) or object.get("variant","basic") not in ["basic","garden","coast"]:return ERR_FILE_CORRUPT
		var id=int(object.id)
		if ids.has(id):return ERR_FILE_CORRUPT
		ids[id]=true;highest=maxi(highest,id)
	if int(payload.next_id)<=highest:return ERR_FILE_CORRUPT
	ids.clear();highest=0
	for person in payload.people:
		if not person is Dictionary or not person.has_all(["id","home","x","z","state","route"]):return ERR_FILE_CORRUPT
		if not whole(person.id,1) or not whole(person.home,0) or not person.route is Array:return ERR_FILE_CORRUPT
		for key in ["x","z"]:
			if not (person[key] is float or person[key] is int) or not is_finite(float(person[key])) or person[key]<0 or person[key]>63:return ERR_FILE_CORRUPT
		if person.state not in ["arriving","resting","waiting","home","walking","bench","tea","garden","greenhouse","lighthouse"]:return ERR_FILE_CORRUPT
		if not whole(person.get("target",0),0) or not whole(person.get("arrival_dock",0),0):return ERR_FILE_CORRUPT
		if not whole(person.get("routine_choices",0),0,2):return ERR_FILE_CORRUPT
		var timer=person.get("timer",0.0)
		if not (timer is int or timer is float) or not is_finite(float(timer)) or absf(float(timer))>1000000:return ERR_FILE_CORRUPT
		if person.get("activity","") not in ["","bench","tea","garden","greenhouse","lighthouse"] or not person.get("crossed",false) is bool:return ERR_FILE_CORRUPT
		for key in ["target_x","target_z"]:
			if person.has(key) and not whole(person[key],0,63):return ERR_FILE_CORRUPT
		var id=int(person.id)
		if ids.has(id):return ERR_FILE_CORRUPT
		ids[id]=true;highest=maxi(highest,id)
	if int(payload.resident_next_id)<=highest:return ERR_FILE_CORRUPT
	if not payload.get("completed",[]) is Array or payload.get("completed",[]).size()>6:return ERR_FILE_CORRUPT
	ids.clear()
	for wish in payload.get("completed",[]):
		if wish not in ["bench","garden","tea","bridge","greenhouse","lighthouse"] or ids.has(wish):return ERR_FILE_CORRUPT
		ids[wish]=true
	var hidden=payload.get("hidden_wishes",[])
	if not hidden is Array or hidden.size()>6:return ERR_FILE_CORRUPT
	ids.clear()
	for wish in hidden:
		if wish not in ["bench","garden","tea","bridge","greenhouse","lighthouse"] or ids.has(wish):return ERR_FILE_CORRUPT
		ids[wish]=true
	if not payload.get("sunset",false) is bool:return ERR_FILE_CORRUPT
	var presentation=payload.get("presentation",{})
	if not presentation is Dictionary or not presentation.get("settings",{}) is Dictionary:return ERR_FILE_CORRUPT
	if presentation.has("camera"):
		var camera=presentation.camera
		if not camera is Dictionary or not camera.has_all(["center","angle","size"]) or not camera.center is Array or camera.center.size()!=3:return ERR_FILE_CORRUPT
		for value in camera.center+[camera.angle,camera.size]:
			if not (value is int or value is float) or not is_finite(float(value)):return ERR_FILE_CORRUPT
		if camera.size<13 or camera.size>58 or absf(camera.angle)>100000 or camera.center[0]<8 or camera.center[0]>56 or camera.center[2]<8 or camera.center[2]>56 or absf(camera.center[1])>16:return ERR_FILE_CORRUPT
	# Validate layout in a temporary world, before touching live state or history.
	var candidate=IslandData.new();candidate.restore(payload)
	for object in candidate.objects:
		if not BuildingRules.check(candidate,object,int(object.id)).is_empty():return ERR_FILE_CORRUPT
	return OK
static func save_game(d:IslandData,sim:ResidentSim,path:String="user://island.json",presentation:Dictionary={},backend:RefCounted=null) -> Error:
	var payload=d.snapshot();payload.schema_version=1;payload.people=sim.people.duplicate(true);payload.resident_next_id=sim.next_id
	payload.hidden_wishes=sim.hidden_wishes.duplicate();payload.completed=sim.completed.duplicate();payload.sunset=sim.sunset;payload.presentation=presentation.duplicate(true)
	for person in payload.people:person.route=[]
	var error=validate(payload)
	if error!=OK:return error
	var io=backend if backend!=null else preload("res://game/world/save_file_io.gd").new()
	error=io.write_temp(path+".tmp",JSON.stringify(payload))
	if error!=OK:return error
	for pair in [[".bak2",".bak3"],[".bak",".bak2"],["",".bak"]]:
		if FileAccess.file_exists(path+pair[0]):
			error=io.copy(path+pair[0],path+pair[1])
			if error!=OK:return error
	return io.replace(path+".tmp",path)
static func load_game(d:IslandData,sim:ResidentSim,path:String="user://island.json",presentation:Dictionary={}) -> Error:
	if not FileAccess.file_exists(path):return ERR_FILE_NOT_FOUND
	var file=FileAccess.open(path,FileAccess.READ)
	if file==null:return FileAccess.get_open_error()
	if file.get_length()>8*1024*1024:file.close();return ERR_FILE_CORRUPT
	var text=file.get_as_text();file.close();var parser=JSON.new()
	if parser.parse(text)!=OK:return ERR_FILE_CORRUPT
	var payload=parser.data
	var error=validate(payload)
	if error!=OK:return error
	d.restore(payload);d.history.clear();d.future.clear()
	sim.hidden_wishes=payload.get("hidden_wishes",[]);sim.people=payload.people;sim.next_id=int(payload.resident_next_id);sim.completed=payload.get("completed",[]);sim.sunset=bool(payload.get("sunset",false))
	for person in sim.people:
		person.route=[];person.target=0;person.arrival_dock=0
		if person.state not in ["arriving","resting","waiting"]:person.state="home"
		person.timer=0.0
	sim.reconcile(d);sim.revision=d.revision
	presentation.clear();presentation.merge(payload.get("presentation",{}).duplicate(true))
	return OK
