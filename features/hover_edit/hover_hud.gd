extends "res://features/direct_edit/simple_hud.gd"


func _ready() -> void:
	super._ready()
	remove_child(direct_handles)
	direct_handles.queue_free()
	direct_handles = SurfaceHandles.new()
	direct_handles.name = "SurfaceHandles"
	add_child(direct_handles)


func special_actions(enabled: bool) -> void:
	show_object_actions(false, enabled)
	# Copy/exact parameter forms still belong to the historical house/prop inspector.
	for index: int in [0, 2]:
		object_bar.get_child(0).get_child(index).disabled = true
