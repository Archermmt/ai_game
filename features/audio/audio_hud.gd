extends "res://features/art_direction/art_hud.gd"
## Three local volume controls share the existing accessible settings scroller.

var volume_controls: Dictionary = {}
var _audio_sync: bool = false


func _ready() -> void:
	super._ready()
	var stack: VBoxContainer = settings.get_child(0).get_child(0)
	for pair: Array in [
		["ambient_volume", "环境音量"], ["effects_volume", "操作音量"], ["music_volume", "音乐音量（0 为关闭）"]
	]:
		var label: Label = Label.new()
		label.text = pair[1]
		stack.add_child(label)
		var slider: HSlider = HSlider.new()
		slider.name = String(pair[0]).to_pascal_case()
		slider.min_value = 0
		slider.max_value = 1
		slider.step = 0.05
		slider.custom_minimum_size.y = 32
		slider.accessibility_name = pair[1]
		slider.value_changed.connect(
			func(value: float) -> void:
				label.text = "%s · %d%%" % [pair[1], roundi(value * 100)]
				if not _audio_sync:
					preference_changed.emit(pair[0], value)
		)
		stack.add_child(slider)
		volume_controls[pair[0]] = slider
		stack.move_child(label, 4 + (volume_controls.size() - 1) * 2)
		stack.move_child(slider, 5 + (volume_controls.size() - 1) * 2)


func sync_preferences(value: UserPreferences) -> void:
	super.sync_preferences(value)
	_audio_sync = true
	for key: String in volume_controls:
		volume_controls[key].value = value.values.get(key, 0.0)
	_audio_sync = false


func attach_dialogs(parent: Node) -> void:
	# Run after all HUD children are ready; keep embedded windows outside its canvas scale.
	for dialog: Window in [library, settings, decision, entry]:
		var shown: bool = dialog.visible
		dialog.hide()
		dialog.reparent(parent)
		if shown:
			dialog.popup_centered()
