extends GutTest


func test_brush_numbers_and_exact_double_neighbors_survive_container() -> void:
	var world: Dictionary = WorldDocument.new("precision").snapshot()
	VegetationBrush.paint(world, Vector2(10, 10), "plants", 6, 1, {})
	world["precision_probe"] = [1.0 + 0.0000000000000002, 0.73, -2.501]
	var result: Dictionary = SaveCodec.decode(SaveCodec.encode(world))
	assert_true(result["ok"])
	assert_true(_same(world, result["snapshot"]))


func test_legacy_plain_json_container_is_still_readable() -> void:
	var world: Dictionary = WorldDocument.new().snapshot()
	var raw: PackedByteArray = JSON.stringify(world).to_utf8_buffer()
	var compressed: PackedByteArray = raw.compress(FileAccess.COMPRESSION_DEFLATE)
	var bytes: PackedByteArray = SaveCodec.MAGIC.to_utf8_buffer()
	bytes.resize(12)
	bytes.encode_u32(8, raw.size())
	bytes.append_array(SaveCodec._digest(compressed))
	bytes.append_array(compressed)
	var result: Dictionary = SaveCodec.decode(bytes)
	assert_true(result["ok"])
	assert_true(_same(world, result["snapshot"]))


func test_bad_exact_metadata_paths_and_nan_fail_without_engine_errors() -> void:
	var world: Dictionary = WorldDocument.new().snapshot()
	for entry: Array in [
		[[[], "0000000000000000"]],
		[[["missing"], "0000000000000000"]],
		[[["revision"], "000000000000f87f"]],
		[[["revision"], "not-a-hex-value!!"]]
	]:
		var result: Dictionary = ExactFloatJson.restore(
			{"codec": ExactFloatJson.CODEC, "snapshot": world.duplicate(true), "float_bits": entry}
		)
		assert_false(result["ok"])


func test_source_extra_keys_cannot_collide_with_envelope_metadata() -> void:
	var world: Dictionary = WorldDocument.new().snapshot()
	world["codec"] = ExactFloatJson.CODEC
	world["float_bits"] = {"__float64": "ordinary source text"}
	var result: Dictionary = SaveCodec.decode(SaveCodec.encode(world))
	assert_true(result["ok"])
	assert_true(_same(world, result["snapshot"]))


func _same(a: Variant, b: Variant) -> bool:
	if (a is float or a is int) and (b is float or b is int):
		return float(a) == float(b)
	if a is Array and b is Array:
		var equal: bool = a.size() == b.size()
		if equal:
			for i: int in range(a.size()):
				equal = equal and _same(a[i], b[i])
		return equal
	if a is Dictionary and b is Dictionary:
		var equal: bool = a.size() == b.size()
		for key: String in a:
			equal = equal and b.has(key) and _same(a[key], b[key])
		return equal
	return a == b
