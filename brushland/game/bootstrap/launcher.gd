extends Node
# Resolve GDScript class defaults on the main loader thread (Godot 4.7).
# PackedScene transitions still use the scene-local asynchronous loader.
const SCENE_TYPES=[preload("res://game/island.gd"),preload("res://game/validation/performance_scene.gd")]
var started=Time.get_ticks_msec()
func _ready() -> void:
	var layer=CanvasLayer.new();add_child(layer);var background=ColorRect.new();background.color=Color("8bbcb9");background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);layer.add_child(background)
	var label=Label.new();label.text="正在准备海湾…";label.add_theme_font_override("font",preload("res://game/ui/fonts/noto_sans_cjk_sc_regular.otf"));label.add_theme_font_size_override("font_size",26);label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);layer.add_child(label)
	var loader=preload("res://game/bootstrap/async_loader.gd").new();add_child(loader)
	loader.progress_changed.connect(func(value):label.text="正在准备海湾… %d%%"%value)
	loader.failed.connect(func(path):label.text="未能载入场景，请重新启动。";push_error("Scene load failed: "+path))
	loader.completed.connect(func(resource):
		var scene=resource.instantiate();get_tree().root.add_child(scene);get_tree().current_scene=scene
		print("BOOT_READY_MS ",Time.get_ticks_msec()-started);queue_free())
	loader.request("res://game/validation/performance_scene.tscn" if OS.get_cmdline_user_args().has("--benchmark") else "res://game/island.tscn")
