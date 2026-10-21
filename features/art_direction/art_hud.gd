extends "res://ui/week_nine_hud.gd"
## The entry preview follows the current, actually editable art scene.

const ART_THUMBNAIL: Texture2D = preload("res://assets/ui/art_pass_01/template_forest.png")


func _ready() -> void:
	super._ready()
	for preview: TextureRect in entry.find_children("*", "TextureRect", true, false):
		preview.texture = ART_THUMBNAIL
	for label: Label in find_children("*", "Label", true, false):
		if "WEEK 09" in label.text:
			label.text = "风栖小筑 / 手绘林间"


func _select_slot() -> void:
	super._select_slot()
	if thumbnail.texture == TEMPLATE_THUMBNAIL:
		thumbnail.texture = ART_THUMBNAIL
