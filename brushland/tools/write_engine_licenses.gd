extends SceneTree
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://.tools/licenses")
	var file=FileAccess.open("res://.tools/licenses/GODOT_LICENSE.txt",FileAccess.WRITE);file.store_string(Engine.get_license_text());file.close()
	file=FileAccess.open("res://.tools/licenses/ENGINE_THIRD_PARTY.json",FileAccess.WRITE);file.store_string(JSON.stringify({"licenses":Engine.get_license_info(),"copyright":Engine.get_copyright_info()},"  "));file.close();print("PASS engine license export");quit()
