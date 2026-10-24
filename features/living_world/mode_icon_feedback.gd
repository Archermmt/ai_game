class_name ModeIconFeedback
extends RefCounted
## Visual enlargement, without changing the toolbar's layout or hit target order.


static func apply(button: Button, selected: bool) -> void:
	button.pivot_offset = button.size * 0.5
	button.scale = Vector2.ONE * (1.12 if selected else 1.0)
	button.add_theme_constant_override("icon_max_width", 42 if selected else 34)
