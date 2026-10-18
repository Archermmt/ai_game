class_name SaveCodec
extends RefCounted
## Single-file, checksummed source-state container. No scene-node serialization.

const MAGIC: String = "WGLADE01"
const HEADER_SIZE: int = 44
const MAX_PAYLOAD: int = 8 * 1024 * 1024


static func encode(snapshot: Dictionary) -> PackedByteArray:
	var validation: String = WorldDocument.validate(snapshot)
	if not validation.is_empty():
		return PackedByteArray()
	var raw: PackedByteArray = JSON.stringify(snapshot, "", true, true).to_utf8_buffer()
	var compressed: PackedByteArray = raw.compress(FileAccess.COMPRESSION_DEFLATE)
	var output: PackedByteArray = MAGIC.to_utf8_buffer()
	output.resize(12)
	output.encode_u32(8, raw.size())
	output.append_array(_digest(compressed))
	output.append_array(compressed)
	return output


static func decode(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() <= HEADER_SIZE or bytes.slice(0, 8).get_string_from_utf8() != MAGIC:
		return {"ok": false, "error": "invalid_header"}
	var length: int = bytes.decode_u32(8)
	if length < 2 or length > MAX_PAYLOAD:
		return {"ok": false, "error": "invalid_size"}
	var compressed: PackedByteArray = bytes.slice(HEADER_SIZE)
	if _digest(compressed) != bytes.slice(12, HEADER_SIZE):
		return {"ok": false, "error": "checksum_mismatch"}
	var raw: PackedByteArray = compressed.decompress(length, FileAccess.COMPRESSION_DEFLATE)
	if raw.size() != length:
		return {"ok": false, "error": "decompression_failed"}
	var parser: JSON = JSON.new()
	if parser.parse(raw.get_string_from_utf8()) != OK or not parser.data is Dictionary:
		return {"ok": false, "error": "invalid_json"}
	var snapshot: Dictionary = parser.data
	# JSON numbers are doubles; restore fields whose schema requires integer indices.
	for key: String in ["schema_version", "revision", "next_id"]:
		if snapshot.get(key) is float and is_finite(snapshot[key]):
			if snapshot[key] == floorf(snapshot[key]):
				snapshot[key] = int(snapshot[key])
	if snapshot.get("terrain") is Dictionary and snapshot["terrain"].get("height_deltas") is Array:
		for entry: Variant in snapshot["terrain"].get("height_deltas", []):
			if entry is Array and entry.size() == 3:
				for index: int in range(2):
					if entry[index] is float and entry[index] == floorf(entry[index]):
						entry[index] = int(entry[index])
	var validation: String = WorldDocument.validate(snapshot)
	if not validation.is_empty():
		return {"ok": false, "error": validation}
	return {"ok": true, "snapshot": snapshot}


static func write_file(path: String, snapshot: Dictionary) -> Error:
	var bytes: PackedByteArray = encode(snapshot)
	if bytes.is_empty():
		return ERR_INVALID_DATA
	var absolute: String = ProjectSettings.globalize_path(path)
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if directory_error != OK:
		return directory_error
	var temporary: String = absolute + ".tmp"
	var stream: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if stream == null:
		return FileAccess.get_open_error()
	stream.store_buffer(bytes)
	stream.flush()
	var write_error: Error = stream.get_error()
	stream.close()
	if write_error != OK:
		return write_error
	if not decode(FileAccess.get_file_as_bytes(temporary))["ok"]:
		return ERR_FILE_CORRUPT
	if FileAccess.file_exists(absolute):
		var backup_error: Error = DirAccess.copy_absolute(absolute, absolute + ".bak")
		if backup_error != OK:
			return backup_error
	return DirAccess.rename_absolute(temporary, absolute)


static func read_file(path: String) -> Dictionary:
	for location: String in [path, path + ".bak"]:
		if FileAccess.file_exists(location):
			var result: Dictionary = decode(FileAccess.get_file_as_bytes(location))
			if result["ok"]:
				result["recovered_backup"] = location != path
				return result
	return {"ok": false, "error": "no_valid_save"}


static func _digest(bytes: PackedByteArray) -> PackedByteArray:
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish()
