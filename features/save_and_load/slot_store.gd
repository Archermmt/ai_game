class_name SlotStore
extends RefCounted
## Worker-safe single-container storage. Main file changes only at the final rename.

const COUNT: int = 5
const BACKUPS: int = 3


static func path_for(directory: String, index: int) -> String:
	return (
		directory.path_join("slot_%02d.wgs" % (index + 1)) if index >= 0 and index < COUNT else ""
	)


static func write_slot(
	directory: String,
	index: int,
	snapshot: Dictionary,
	title: String,
	presentation: Dictionary = {},
	fail_before_replace: bool = false
) -> Dictionary:
	var path: String = path_for(directory, index)
	if path.is_empty():
		return {"ok": false, "error": "invalid_slot"}
	var bytes: PackedByteArray = SceneSave.encode(snapshot, title, presentation)
	if bytes.is_empty():
		return {"ok": false, "error": "invalid_snapshot"}
	var absolute: String = ProjectSettings.globalize_path(path)
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK:
		return {"ok": false, "error": "create_directory_failed"}
	if FileAccess.file_exists(path):
		var current: Dictionary = SceneSave.decode(FileAccess.get_file_as_bytes(path))
		if not current["ok"]:
			return {"ok": false, "error": "protected_invalid_save"}
	var file: FileAccess = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "write_failed"}
	file.store_buffer(bytes)
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error != OK or not SceneSave.decode(FileAccess.get_file_as_bytes(path + ".tmp"))["ok"]:
		return {"ok": false, "error": "verify_failed"}
	if fail_before_replace:
		return {"ok": false, "error": "injected_replace_failure"}
	if FileAccess.file_exists(path):
		for i: int in range(BACKUPS, 0, -1):
			var source: String = path if i == 1 else path + ".bak%d" % (i - 1)
			if FileAccess.file_exists(source):
				if (
					DirAccess.copy_absolute(
						ProjectSettings.globalize_path(source), absolute + ".bak%d" % i
					)
					!= OK
				):
					return {"ok": false, "error": "backup_failed"}
	error = DirAccess.rename_absolute(absolute + ".tmp", absolute)
	return {"ok": error == OK, "error": "" if error == OK else "replace_failed"}


static func read_slot(directory: String, index: int) -> Dictionary:
	var path: String = path_for(directory, index)
	if path.is_empty():
		return {"ok": false, "error": "invalid_slot"}
	var primary: Dictionary = {"ok": false, "error": "no_valid_save"}
	for i: int in range(BACKUPS + 1):
		var location: String = path if i == 0 else path + ".bak%d" % i
		if not FileAccess.file_exists(location):
			continue
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(location)
		var result: Dictionary = SceneSave.decode(bytes)
		if i == 0:
			primary = result
			# Unknown/future magic must not silently load an older revision.
			if (
				String(result.get("error", "")).begins_with("unsupported_")
				and bytes.slice(0, 6) == "WGLADE".to_utf8_buffer()
			):
				return result
		if result["ok"]:
			result["recovered_backup"] = i
			return result
	return primary


static func catalog(directory: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i: int in range(COUNT):
		var entry: Dictionary = read_slot(directory, i)
		result.append(
			{
				"index": i,
				"ok": entry["ok"],
				"metadata": entry.get("metadata", {}),
				"backup": entry.get("recovered_backup", 0),
				"error": entry.get("error", "")
			}
		)
	return result
