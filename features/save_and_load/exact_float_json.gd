class_name ExactFloatJson
extends RefCounted
## Versioned JSON envelope restores exact IEEE-754 values without evaluating objects.
## Legacy schema roots remain readable. No metadata is added to the source snapshot.

const CODEC: String = "exact-floats-v1"


static func encode(snapshot: Dictionary) -> String:
	var bits: Array = []
	_collect(snapshot, [], bits)
	return JSON.stringify(
		{"codec": CODEC, "snapshot": snapshot, "float_bits": bits}, "", true, true
	)


static func _collect(value: Variant, path: Array, result: Array) -> void:
	if value is float:
		var raw: PackedByteArray = PackedByteArray()
		raw.resize(8)
		raw.encode_double(0, value)
		result.append([path, raw.hex_encode()])
	elif value is Dictionary:
		for key: String in value:
			_collect(value[key], path + [key], result)
	elif value is Array:
		for i: int in range(value.size()):
			_collect(value[i], path + [i], result)


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
		var cursor: Variant = source
		for i: int in range(entry[0].size()):
			var key: Variant = entry[0][i]
			if cursor is Dictionary:
				if not key is String or not cursor.has(key):
					return {"ok": false}
			elif cursor is Array:
				if not WorldDocument._integer(key) or key < 0 or key >= cursor.size():
					return {"ok": false}
				key = int(key)
			else:
				return {"ok": false}
			if i == entry[0].size() - 1:
				if not WorldDocument._number(cursor[key]):
					return {"ok": false}
				cursor[key] = number
			else:
				cursor = cursor[key]
	return {"ok": true, "snapshot": source}
