class_name ExactFloatJson
extends RefCounted
## Versioned JSON envelope restores exact IEEE-754 values without evaluating objects.
## Legacy schema roots remain readable. No metadata is added to the source snapshot.

const CODEC: String = "exact-floats-v1"


static func encode(snapshot: Dictionary) -> String:
	var bits: Array = []
	var integers: Array = []
	_collect(snapshot, [], bits, integers)
	return JSON.stringify(
		{"codec": CODEC, "snapshot": snapshot, "float_bits": bits, "integer_paths": integers},
		"",
		true,
		true
	)


static func _collect(value: Variant, path: Array, result: Array, integers: Array) -> void:
	if value is float:
		var raw: PackedByteArray = PackedByteArray()
		raw.resize(8)
		raw.encode_double(0, value)
		result.append([path, raw.hex_encode()])
	elif value is int:
		integers.append([path, str(value)])
	elif value is Dictionary:
		for key: String in value:
			_collect(value[key], path + [key], result, integers)
	elif value is Array:
		for i: int in range(value.size()):
			_collect(value[i], path + [i], result, integers)


static func restore(data: Dictionary) -> Dictionary:
	if data.has("schema_version"):
		return {"ok": true, "snapshot": data}
	if (
		data.get("codec") != CODEC
		or not data.get("snapshot") is Dictionary
		or not data.get("float_bits") is Array
	):
		return {"ok": false}
	var source: Dictionary = data["snapshot"]
	for entry: Variant in data["float_bits"]:
		if (
			not entry is Array
			or entry.size() != 2
			or not entry[0] is Array
			or entry[0].is_empty()
			or entry[0].size() > 24
			or not entry[1] is String
			or entry[1].length() != 16
		):
			return {"ok": false}
		for character: String in entry[1]:
			if character not in "0123456789abcdef":
				return {"ok": false}
		var raw: PackedByteArray = entry[1].hex_decode()
		var number: float = raw.decode_double(0)
		if not is_finite(number):
			return {"ok": false}
		if not _assign(source, entry[0], number):
			return {"ok": false}
	if not data.get("integer_paths", []) is Array:
		return {"ok": false}
	for entry: Variant in data.get("integer_paths", []):
		if (
			not entry is Array
			or entry.size() != 2
			or not entry[0] is Array
			or not entry[1] is String
		):
			return {"ok": false}
		if not entry[1].is_valid_int() or str(int(entry[1])) != entry[1]:
			return {"ok": false}
		if not _assign(source, entry[0], int(entry[1])):
			return {"ok": false}

	return {"ok": true, "snapshot": source}


static func _assign(source: Dictionary, path: Array, value: Variant) -> bool:
	if path.is_empty() or path.size() > 24:
		return false
	var cursor: Variant = source
	for i: int in range(path.size()):
		var key: Variant = path[i]
		if cursor is Dictionary:
			if not key is String or not cursor.has(key):
				return false
		elif cursor is Array:
			if not WorldDocument._integer(key) or key < 0 or key >= cursor.size():
				return false
			key = int(key)
		else:
			return false
		if i == path.size() - 1:
			if not WorldDocument._number(cursor[key]):
				return false
			cursor[key] = value
		else:
			cursor = cursor[key]
	return true
