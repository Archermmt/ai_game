extends SceneTree
class FaultIO:
	extends "res://game/world/save_file_io.gd"
	var stage=""
	func write_temp(path:String,text:String) -> Error:
		if stage=="partial":
			var file=FileAccess.open(path,FileAccess.WRITE);file.store_string(text.substr(0,17));file.close();return ERR_FILE_CANT_WRITE
		return super.write_temp(path,text)
	func copy(source:String,destination:String) -> Error:
		return ERR_FILE_CANT_WRITE if stage=="backup" else super.copy(source,destination)
	func replace(source:String,destination:String) -> Error:
		return ERR_FILE_CANT_WRITE if stage=="replace" else super.replace(source,destination)
func _initialize() -> void:call_deferred("run")
func write(path:String,payload) -> void:
	var file=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(payload));file.close()
func run() -> void:
	create_timer(30).timeout.connect(func():push_error("Save fault test timeout");quit(1))
	var path="user://test_completion_atomic.json";var bad="user://test_completion_corrupt.json"
	var d=IslandData.new();DemoIsland.create(d);var sim=ResidentSim.new();sim.tick(d,8.1)
	sim.hidden_wishes=["bench"];var extra={"camera":{"center":[31.5,0,33],"angle":0.3,"size":30.5},"settings":{"ui_scale":1.25}}
	assert(SaveStore.save_game(d,sim,path,extra)==OK)
	var original=FileAccess.get_file_as_string(path);var payload=JSON.parse_string(original)
	for stage in ["partial","backup","replace"]:
		var fault=FaultIO.new();fault.stage=stage
		assert(SaveStore.save_game(d,sim,path,extra,fault)!=OK)
		assert(FileAccess.get_file_as_string(path)==original)
		var check=IslandData.new();var resumed=ResidentSim.new();assert(SaveStore.load_game(check,resumed,path)==OK)
	# A failed partial write must not poison the next save or its rolling copies.
	for i in range(4):
		d.paint([Vector2i(5+i,5)],"grass");assert(SaveStore.save_game(d,sim,path,extra)==OK)
	for suffix in [".bak",".bak2",".bak3"]:
		assert(SaveStore.load_game(IslandData.new(),ResidentSim.new(),path+suffix)==OK)
	var cases:Array=[]
	var p=payload.duplicate(true);p.schema_version=999;cases.append(p)
	p=payload.duplicate(true);p.next_id=1;cases.append(p)
	p=payload.duplicate(true);p.resident_next_id=1;cases.append(p)
	p=payload.duplicate(true);p.objects.append(p.objects[0].duplicate());cases.append(p)
	p=payload.duplicate(true);p.objects[0].rotation=1000;cases.append(p)
	p=payload.duplicate(true);p.objects[0].length=1000000000;cases.append(p)
	p=payload.duplicate(true);p.objects[0].x=63;cases.append(p)
	p=payload.duplicate(true);p.objects[0].locked="yes";cases.append(p)
	p=payload.duplicate(true);p.tiles[p.tiles.keys()[0]].road="yes";cases.append(p)
	p=payload.duplicate(true);p.tiles[p.tiles.keys()[0]].h=1.5;cases.append(p)
	p=payload.duplicate(true);p.completed=["unknown"];cases.append(p)
	p=payload.duplicate(true);p.people[0].state={};cases.append(p)
	p=payload.duplicate(true);p.people[0].route="bad";cases.append(p)
	p=payload.duplicate(true);p.people[0].activity=[];cases.append(p)
	p=payload.duplicate(true);p.presentation.camera.size=-1;cases.append(p)
	for item in cases:
		write(bad,item);var before=d.snapshot();var people=sim.people.duplicate(true);var revision=d.revision;var history=d.history.duplicate(true)
		assert(SaveStore.load_game(d,sim,bad)==ERR_FILE_CORRUPT)
		assert(d.snapshot()==before and sim.people==people and d.revision==revision and d.history==history)
	var file=FileAccess.open(bad,FileAccess.WRITE);file.store_string('{"schema_version":1');file.close();assert(SaveStore.load_game(d,sim,bad)==ERR_FILE_CORRUPT)
	var output:Dictionary={};assert(SaveStore.load_game(d,sim,path,output)==OK);assert(sim.hidden_wishes==["bench"])
	assert(output.camera.size==30.5 and output.camera.center[0]==31.5 and output.camera.center[2]==33 and output.settings.ui_scale==1.25)
	for suffix in ["",".tmp",".bak",".bak2",".bak3"]:DirAccess.remove_absolute(path+suffix)
	DirAccess.remove_absolute(bad)
	print("PASS atomic partial-write/backup/rename failures, 3 recoverable backups, ",cases.size()+1," corrupt saves, unchanged live world and camera/settings metadata");quit()
