extends SceneTree
func _initialize() -> void:
	var d=IslandData.new()
	d.paint([Vector2i(1,1)],"grass")
	assert(d.cell(Vector2i(1,1)).h==1)
	d.undo();assert(d.cell(Vector2i(1,1)).h==0)
	d.redo();assert(d.cell(Vector2i(1,1)).h==1)
	for i in range(60):d.paint([Vector2i(1,1)],"raise")
	assert(d.history.size()==50)
	assert(d.cell(Vector2i(1,1)).h==4)
	print("PASS week 1: paint, undo, redo, height limit, history limit")
	quit()
