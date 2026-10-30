extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	create_timer(15).timeout.connect(func():push_error("Preferences timeout");quit(1))
	var settings=IslandSettings.new();settings.path="user://test_completion_preferences.cfg"
	settings.values.music=0.35;settings.values.ui_scale=1.5;settings.values.reduced_motion=true
	assert(settings.bind("rotate",KEY_G).is_empty());assert(not settings.bind("rotate",KEY_P).is_empty())
	assert(settings.write()==OK)
	var restored=IslandSettings.new();restored.path=settings.path;assert(restored.read()==OK)
	assert(restored.values.music==0.35 and restored.values.ui_scale==1.5 and restored.values.reduced_motion)
	var key=InputEventKey.new();key.keycode=KEY_G;key.pressed=true;assert(restored.matches(key,"rotate"))
	var bad=ConfigFile.new();bad.set_value("settings","ui_scale",-5);bad.set_value("settings","music","bad");bad.set_value("input","keys",{"rotate":KEY_P});bad.save(settings.path)
	var safe=IslandSettings.new();safe.path=settings.path;assert(safe.read()==OK);assert(safe.values.ui_scale==0.75 and safe.values.music==0.65 and safe.keys.rotate==KEY_R)
	safe.merge_values({"music":NAN,"ui_scale":INF});assert(safe.values.music==0.65 and safe.values.ui_scale==0.75)
	DirAccess.remove_absolute(settings.path)
	print("PASS persistent volume, scale, motion, rebind, conflicts and malformed preferences");quit()
