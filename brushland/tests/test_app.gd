extends SceneTree
var app:Node
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	app=load("res://game/island.tscn").instantiate();root.add_child(app)
	await process_frame
	app.close_modal();app.sim.paused=false
	app.hud.tool_selected.emit("tea");assert(app.tool=="tea")
	app.data.paint([Vector2i(18,20)],"grass");app.rebuild();assert(app.data.cell(Vector2i(18,20)).h==1)
	app.hud.action_requested.emit("undo");assert(app.data.cell(Vector2i(18,20)).h==0)
	app.hud.action_requested.emit("redo");assert(app.data.cell(Vector2i(18,20)).h==1)
	app.sim.paused=true;app.action("photo")
	await RenderingServer.frame_post_draw
	await process_frame
	assert(app.photo_mode and not app.hud.root.visible)
	app.action("photo");assert(app.sim.paused and app.hud.root.visible)
	app.sim.paused=false
	# Painting water beneath an actor chooses a surviving road in its prior region.
	var person=app.sim.people[0];var p=Vector2i(roundi(person.x),roundi(person.z));var regions=app.resident_regions()
	# A home's entry is protected, so use a public road tile for this fixture.
	person.x=28.0;person.z=33.0;regions=app.resident_regions()
	app.data.paint([Vector2i(28,33)],"water");app.protect_residents(regions)
	assert(app.data.cell(Vector2i(roundi(person.x),roundi(person.z))).h>0 or person.state=="resting")
	app.save_menu();await process_frame
	assert(app.modal!=null);app.close_modal()
	print("PASS UI signals, undo/redo, photo pause restore, safe actor relocation, save menu")
	app.free();quit()
