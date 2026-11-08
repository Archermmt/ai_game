extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	create_timer(15).timeout.connect(func():quit(1))
	for path in ["res://game/bootstrap/launcher.tscn","res://game/island.tscn","res://game/validation/performance_scene.tscn","res://game/ui/fonts/noto_sans_cjk_sc_regular.otf","res://game/art/models/house_basic.glb"]:
		assert(ResourceLoader.exists(path));assert(load(path)!=null)
	for path in ["res://THIRD_PARTY_NOTICES.md","res://game/ui/fonts/OFL.txt","res://game/art/materials/LICENSE-CC0.txt"]:
		print("LICENSE ",path," ",FileAccess.file_exists(path)," size ",FileAccess.get_file_as_string(path).length());assert(FileAccess.file_exists(path) and FileAccess.get_file_as_string(path).length()>100)
	for path in ["res://docs/PRD.md","res://tests/test_world.gd","res://game/art_lab/art_lab.tscn","res://game/art/catalog_sources/SCN_001.tscn"]:assert(not FileAccess.file_exists(path))
	print("PASS standalone packed scenes, fonts, models and licenses; authoring/tests excluded");quit()
