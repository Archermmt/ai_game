class_name SaveStore
extends RefCounted
static func save_game(d:IslandData,sim:ResidentSim,path:String="user://island.json") -> Error:
	var payload=d.snapshot()
	payload.schema_version=1;payload.people=sim.people.duplicate(true);payload.resident_next_id=sim.next_id
	payload.completed=sim.completed.duplicate();payload.sunset=sim.sunset
	for person in payload.people:person.route=[]
	var file=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null:return FileAccess.get_open_error()
	file.store_string(JSON.stringify(payload));file.flush();file.close()
	for pair in [[".bak2",".bak3"],[".bak",".bak2"],["",".bak"]]:
		if FileAccess.file_exists(path+pair[0]):
			var err=DirAccess.copy_absolute(path+pair[0],path+pair[1])
			if err!=OK:return err
	return DirAccess.rename_absolute(path+".tmp",path)
static func load_game(d:IslandData,sim:ResidentSim,path:String="user://island.json") -> Error:
	if not FileAccess.file_exists(path):return ERR_FILE_NOT_FOUND
	var payload=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not payload is Dictionary or payload.get("schema_version",0)!=1 or not payload.get("tiles") is Dictionary or not payload.get("objects") is Array or not payload.get("people") is Array:return ERR_FILE_CORRUPT
	for key in payload.tiles:
		var xy=String(key).split(",");var c=payload.tiles[key]
		if xy.size()!=2 or not xy[0].is_valid_int() or not xy[1].is_valid_int() or not BuildingRules.inside(Vector2i(int(xy[0]),int(xy[1]))):return ERR_FILE_CORRUPT
		if not c is Dictionary or not c.has_all(["h","surface","road","flower"]) or int(c.h)<0 or int(c.h)>4:return ERR_FILE_CORRUPT
	if not payload.has_all(["next_id","resident_next_id"]):return ERR_FILE_CORRUPT
	var ids:Dictionary={}
	for o in payload.objects:
		if not o is Dictionary or not o.has_all(["id","kind","x","z","rotation","length","locked"]):return ERR_FILE_CORRUPT
		if not o.kind in BuildingRules.TOOLS or int(o.rotation)<0 or int(o.rotation)>3 or ids.has(o.id):return ERR_FILE_CORRUPT
		for p in BuildingRules.footprint(o):
			if not BuildingRules.inside(p):return ERR_FILE_CORRUPT
		ids[o.id]=true
	if payload.people.size()>12:return ERR_FILE_CORRUPT
	ids.clear()
	for person in payload.people:
		if not person is Dictionary or not person.has_all(["id","home","x","z","state","route"]):return ERR_FILE_CORRUPT
		if ids.has(person.id) or not is_finite(float(person.x)) or not is_finite(float(person.z)):return ERR_FILE_CORRUPT
		ids[person.id]=true
	if not payload.get("completed",[]) is Array:return ERR_FILE_CORRUPT
	d.restore(payload);d.history.clear();d.future.clear()
	sim.people=payload.people;sim.next_id=int(payload.resident_next_id);sim.completed=payload.get("completed",[]);sim.sunset=bool(payload.get("sunset",false))
	for person in sim.people:
		person.route=[];person.target=0
		if person.state not in ["arriving","resting","waiting"]:person.state="home"
		person.timer=0.0
	sim.reconcile(d);sim.revision=d.revision
	return OK
