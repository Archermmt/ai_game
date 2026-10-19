class_name ForestLayout
extends Resource
## Source DTO encoded explicitly: text ResourceSaver rounds Dictionary double values.

@export_multiline var source_json: String = ""


func snapshot() -> Dictionary:
	var parser: JSON = JSON.new()
	if parser.parse(source_json) != OK or not parser.data is Dictionary:
		return {}
	var restored: Dictionary = ExactFloatJson.restore(parser.data)
	return restored.get("snapshot", {}) if restored.get("ok", false) else {}
