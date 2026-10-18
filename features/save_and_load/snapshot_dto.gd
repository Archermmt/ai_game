class_name SnapshotDto
extends RefCounted
## W07 opening slice of T051: source-only, bounded, versioned container DTO.

const FORMAT: int = 2


static func pack(snapshot: Dictionary, title: String) -> Dictionary:
	return {
		"format_version": FORMAT,
		"metadata":
		{"title": title.left(64), "scene_id": "SCN-01", "generator": snapshot["generator_version"]},
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
	var source: Dictionary = payload["source"].duplicate(true)
	# Optional disposable data is never authoritative and cannot become live references.
	source.erase("generated_cache")
	var error: String = WorldDocument.validate(source)
	if not error.is_empty():
		return {"ok": false, "error": error}
	return {"ok": true, "snapshot": source, "metadata": metadata.duplicate(true)}
