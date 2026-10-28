class_name SaveStore
extends RefCounted
static func save_game(d:IslandData,sim:ResidentSim,path:String="user://island.json") -> Error:
	var payload=d.snapshot()
	payload.schema_version=1;payload.people=sim.people.duplicate(true);payload.resident_next_id=sim.next_id
	for person in payload.people:person.route=[]
	var file=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null:return FileAccess.get_open_error()
	file.store_string(JSON.stringify(payload));file.flush();file.close()
	if FileAccess.file_exists(path):
		var err=DirAccess.copy_absolute(path,path+".bak")
		if err!=OK:return err
	return DirAccess.rename_absolute(path+".tmp",path)
static func load_game(d:IslandData,sim:ResidentSim,path:String="user://island.json") -> Error:
	if not FileAccess.file_exists(path):return ERR_FILE_NOT_FOUND
	var payload=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not payload is Dictionary or payload.get("schema_version",0)!=1 or not payload.get("tiles") is Dictionary or not payload.get("objects") is Array or not payload.get("people") is Array:return ERR_FILE_CORRUPT
	for c in payload.tiles.values():
		if not c is Dictionary or not c.has_all(["h","surface","road","flower"]) or int(c.h)<0 or int(c.h)>4:return ERR_FILE_CORRUPT
	if not payload.has_all(["next_id","resident_next_id"]):return ERR_FILE_CORRUPT
	for o in payload.objects:
		if not o is Dictionary or not o.has_all(["id","kind","x","z","rotation","length","locked"]):return ERR_FILE_CORRUPT
	for person in payload.people:
		if not person is Dictionary or not person.has_all(["id","home","x","z","state","route"]):return ERR_FILE_CORRUPT
	d.restore(payload);d.history.clear();d.future.clear()
	sim.people=payload.people;sim.next_id=int(payload.resident_next_id)
	for person in sim.people:person.route=[]
	sim.reconcile(d)
	return OK
