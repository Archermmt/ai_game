class_name SnapshotDto
extends RefCounted
## Portable source DTO; default presentation keeps W07 containers compatible.

const FORMAT: int = 2


static func pack(snapshot: Dictionary, title: String, presentation: Dictionary = {}) -> Dictionary:
	return {
		"format_version": FORMAT,
		"metadata":
		{
			"title": title.left(64),
			"scene_id": "SCN-01",
			"generator": snapshot["generator_version"],
			"presentation": presentation.duplicate(true)
		},
		"source": snapshot.duplicate(true)
	}


static func unpack(payload: Dictionary) -> Dictionary:
	if payload.get("format_version") != FORMAT:
		return {"ok": false, "error": "unsupported_save_format"}
	if not payload.get("metadata") is Dictionary or not payload.get("source") is Dictionary:
		return {"ok": false, "error": "invalid_save_metadata"}
	var metadata: Dictionary = payload["metadata"]
	if not metadata.get("title") is String or metadata["title"].length() > 64:
		return {"ok": false, "error": "invalid_save_metadata"}
	if (
		metadata.get("scene_id") != "SCN-01"
		or metadata.get("generator") != WorldDocument.GENERATOR_VERSION
	):
		return {"ok": false, "error": "unsupported_generator"}
	var presentation: Variant = metadata.get("presentation", {})
	if not presentation is Dictionary or not valid_presentation(presentation):
		return {"ok": false, "error": "invalid_save_presentation"}
	var source: Dictionary = payload["source"].duplicate(true)
	# Optional disposable data is never authoritative and cannot become live references.
	source.erase("generated_cache")
	var error: String = WorldDocument.validate(source)
	if not error.is_empty():
		return {"ok": false, "error": error}
	return {"ok": true, "snapshot": source, "metadata": metadata.duplicate(true)}


static func valid_presentation(value: Dictionary) -> bool:
	if (
		value.has("calendar")
		and (not value["calendar"] is Dictionary or not CalendarState.valid(value["calendar"]))
	):
		return false
	if value.has("camera") and not CameraRecord.valid(value["camera"]):
		return false
	if value.has("thumbnail"):
		if not value["thumbnail"] is String or value["thumbnail"].length() > 350000:
			return false
		var pattern: RegEx = RegEx.new()
		pattern.compile("^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$")
		if value["thumbnail"].is_empty() or pattern.search(value["thumbnail"]) == null:
			return false
		var bytes: PackedByteArray = Marshalls.base64_to_raw(value["thumbnail"])
		if (
			bytes.size() < 33
			or bytes.slice(0, 8) != PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10])
		):
			return false
		# PNG IHDR dimensions are big endian; reject oversized input before allocating.
		var width: int = (bytes[16] << 24) | (bytes[17] << 16) | (bytes[18] << 8) | bytes[19]
		var height: int = (bytes[20] << 24) | (bytes[21] << 16) | (bytes[22] << 8) | bytes[23]
		if width < 1 or width > 320 or height < 1 or height > 200:
			return false
		var image: Image = Image.new()
		if image.load_png_from_buffer(bytes) != OK:
			return false
		if image.get_width() > 320 or image.get_height() > 200:
			return false
	return true
