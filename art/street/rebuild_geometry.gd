extends SceneTree
## Bake the procedural geometry into editor-visible, self-contained module scenes.
## The railway and trees are authored with the same meshes and materials used at run time.

const PARTS := {
	"landscape": ["res://street/layout/layout.gd", "res://street/layout/landscape.scn"],
	"planting": ["res://street/vegetation/vegetation.gd", "res://street/vegetation/planting.scn"],
	"station": ["res://street/railway/railway.gd", "res://street/railway/station.scn"]
}

func _initialize() -> void:
	_build.call_deferred()

func _build() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Run Godot with a graphics device to serialize MultiMesh instance transforms.")
		quit(2)
		return
	for part_name in PARTS:
		var paths: Array = PARTS[part_name]
		var script: Script = load(paths[0])
		if not script or not script.can_instantiate():
			push_error("Cannot build " + paths[0])
			quit(1)
			return
		var part := Node3D.new()
		part.name = part_name.capitalize()
		part.set_script(script)
		root.add_child(part)
		for child in part.find_children("*", "", true, false):
			child.owner = part
		part.set_script(null)
		var packed := PackedScene.new()
		var err := packed.pack(part)
		if err == OK:
			err = ResourceSaver.save(packed, paths[1], ResourceSaver.FLAG_COMPRESS)
		if err != OK:
			push_error("Failed to save %s (%s)" % [paths[1], error_string(err)])
			quit(1)
			return
		print("Baked ",paths[1]," with ",part.get_child_count()," direct children.")
		part.free()
	quit()
