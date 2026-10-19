class_name SceneSave
extends RefCounted
## Versioned source/metadata codec. SlotStore owns W08 slots and backup rotation.

const MAGIC: String = "WGLADE02"
const LIMIT: int = 8 * 1024 * 1024


static func encode(
	snapshot: Dictionary, title: String = "林间作品", presentation: Dictionary = {}
) -> PackedByteArray:
	if not WorldDocument.validate(snapshot).is_empty():
		return PackedByteArray()
	var raw: PackedByteArray = (
		ExactFloatJson.encode(SnapshotDto.pack(snapshot, title, presentation)).to_utf8_buffer()
	)
	if (
		raw.size() > LIMIT
		or not SnapshotDto.unpack(SnapshotDto.pack(snapshot, title, presentation))["ok"]
	):
		return PackedByteArray()
	var zipped: PackedByteArray = raw.compress(FileAccess.COMPRESSION_DEFLATE)
	var result: PackedByteArray = MAGIC.to_utf8_buffer()
	result.resize(12)
	result.encode_u32(8, raw.size())
	result.append_array(SaveCodec._digest(zipped))
	result.append_array(zipped)
	return result


static func decode(bytes: PackedByteArray) -> Dictionary:
	if bytes.slice(0, 8) == SaveCodec.MAGIC.to_utf8_buffer():
		var legacy: Dictionary = SaveCodec.decode(bytes)
		if legacy["ok"]:
			legacy["metadata"] = {
				"title": "旧版作品",
				"scene_id": "SCN-01",
				"generator": WorldDocument.GENERATOR_VERSION,
				"presentation": {}
			}
		return legacy
	if bytes.size() <= 44 or bytes.slice(0, 8) != MAGIC.to_utf8_buffer():
		return {"ok": false, "error": "unsupported_save_format"}
	var length: int = bytes.decode_u32(8)
	if length < 2 or length > LIMIT or SaveCodec._digest(bytes.slice(44)) != bytes.slice(12, 44):
		return {"ok": false, "error": "invalid_save_checksum"}
	var raw: PackedByteArray = bytes.slice(44).decompress(length, FileAccess.COMPRESSION_DEFLATE)
	if raw.size() != length:
		return {"ok": false, "error": "invalid_save_compression"}
	var parser: JSON = JSON.new()
	if parser.parse(raw.get_string_from_utf8()) != OK or not parser.data is Dictionary:
		return {"ok": false, "error": "invalid_json"}
	var restored: Dictionary = ExactFloatJson.restore(parser.data)
	if not restored["ok"]:
		return {"ok": false, "error": "invalid_json"}
	return SnapshotDto.unpack(restored["snapshot"])


static func write_file(path: String, snapshot: Dictionary, title: String = "林间作品") -> Error:
	var bytes: PackedByteArray = encode(snapshot, title)
	if bytes.is_empty():
		return ERR_INVALID_DATA
	var absolute: String = ProjectSettings.globalize_path(path)
	var error: Error = DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if error != OK:
		return error
	# Never overwrite a future/unknown container in an older application.
	if FileAccess.file_exists(path) and not decode(FileAccess.get_file_as_bytes(path))["ok"]:
		return ERR_FILE_UNRECOGNIZED
	var file: FileAccess = FileAccess.open(absolute + ".tmp", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_buffer(bytes)
	file.flush()
	error = file.get_error()
	file.close()
	if error != OK or not decode(FileAccess.get_file_as_bytes(absolute + ".tmp"))["ok"]:
		return ERR_FILE_CORRUPT
	if FileAccess.file_exists(absolute):
		error = DirAccess.copy_absolute(absolute, absolute + ".bak")
		if error != OK:
			return error
	return DirAccess.rename_absolute(absolute + ".tmp", absolute)


static func read_file(path: String) -> Dictionary:
	var primary: Dictionary = {"ok": false, "error": "no_valid_save"}
	for location: String in [path, path + ".bak"]:
		if FileAccess.file_exists(location):
			var result: Dictionary = decode(FileAccess.get_file_as_bytes(location))
			if location == path:
				primary = result
				if String(result.get("error", "")).begins_with("unsupported_"):
					return result
			if result["ok"]:
				result["recovered_backup"] = location != path
				return result
	return primary
