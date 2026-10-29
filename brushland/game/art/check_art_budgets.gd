extends SceneTree
func _initialize() -> void:call_deferred("run")
func triangles(node:Node) -> int:
	var count=0
	if node is MeshInstance3D and node.mesh!=null:count+=node.mesh.get_faces().size()/3
	if node is MultiMeshInstance3D and node.multimesh!=null:count+=node.multimesh.mesh.get_faces().size()/3*node.multimesh.instance_count
	for child in node.get_children():count+=triangles(child)
	return count
func run() -> void:
	var regex=RegEx.new();regex.compile("≤\\s*(\\d+)\\s*三角面")
	var f=FileAccess.open("res://docs/art_asset_manifest.csv",FileAccess.READ);var header=f.get_csv_line();header[0]=header[0].trim_prefix("\ufeff");var results:Array=[]
	while not f.eof_reached():
		var values=f.get_csv_line()
		if values.size()!=header.size():continue
		var row:Dictionary={}
		for i in range(header.size()):row[header[i]]=values[i]

		var matches=regex.search_all(row.spec)
		if matches.is_empty():continue
		for variant in range(int(row.total_deliverables)):
			var node=ArtCatalog.create(row.asset_id,variant)
			if not node is Node:continue
			var count=triangles(node);var limit=int(matches[mini(variant,matches.size()-1)].get_string(1));node.free()
			results.append({"asset_id":row.asset_id,"variant":variant,"triangles":count,"limit":limit,"passed":count<=limit})
			if count>limit:print("BUDGET_OVER ",row.asset_id," variant ",variant," ",count," / ",limit)
	var file=FileAccess.open("res://docs/art_i6/budgets.json",FileAccess.WRITE);file.store_string(JSON.stringify(results,"  "));file.close();print("BUDGET_REVIEW ",results.size()," records");quit(0 if results.all(func(record):return record.passed) else 1)
