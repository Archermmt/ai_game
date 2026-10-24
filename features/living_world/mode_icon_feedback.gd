class_name ModeIconFeedback
extends RefCounted
## Visual enlargement, without changing the toolbar's layout or hit target order.


static func apply(button: Button, selected: bool) -> void:
	button.pivot_offset = button.size * 0.5
	button.scale = Vector2.ONE * (1.12 if selected else 1.0)
	# Changing minimum-size theme constants here schedules another container sort
	# that resets scale; selected transforms are reapplied after each sort instead.
