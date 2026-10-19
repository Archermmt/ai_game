extends "res://ui/week_seven_hud.gd"
## Five named works and local preferences, in scrollable scene-owned dialogs.

signal slot_requested(operation: String, index: int, title: String)
signal preference_changed(key: String, value: Variant)
signal binding_requested(action: String, event: InputEventKey)
signal preferences_reset
signal decision_made(decision: String)

var library: Window
var settings: Window
var slots: ItemList
var title_entry: LineEdit
var thumbnail: TextureRect
var save_note: Label
var settings_note: Label
var scale_caption: Label
var scale_control: HSlider
var dof_control: CheckBox
var motion_control: CheckBox
var decision: ConfirmationDialog
var _feedback: PanelContainer
var _binding: String = ""
var _binding_buttons: Dictionary = {}
var _objects_signature: int = 0
var _cards: Dictionary = {}
var _settings_sync: bool = false


func _ready() -> void:
	super._ready()
	for node: Node in _panels[0].find_children("*", "Label", true, false):
		if "WEEK 07" in node.text:
			node.text = "风栖小筑 / WEEK 08"
	for node: Node in _panels[0].find_children("*", "OptionButton", true, false):
		if node.item_count == 3 and node.get_item_text(0) == "100%":
			node.hide()
	for node: Node in _panels[0].find_children("*", "Label", true, false):
		if node.text == "界面缩放":
			node.text = "界面缩放与动态偏好请打开顶部「设置」"
	var parent: Node = _panels[0].get_child(0).get_child(0)
	var bar: HBoxContainer = HBoxContainer.new()
	parent.add_child(bar)
	parent.move_child(bar, 1)
	_add_button(bar, "library", "我的作品")
	_add_button(bar, "preferences", "设置")
	_add_button(bar, "view_day", "远景")
	_add_button(bar, "view_garden", "庭院")
	_feedback = PanelContainer.new()
	_feedback.name = "StatusBar"
	_feedback.theme = GardenTheme.create()
	_feedback.add_theme_stylebox_override("panel", GardenTheme.box(GardenTheme.CREAM))
	_feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_feedback)
	status_label.reparent(_feedback)
	status_label.custom_minimum_size = Vector2(0, 40)
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	library = _window("我的作品 · 五个存档槽", Vector2i(540, 650))
	var stack: VBoxContainer = _window_stack(library)
	slots = ItemList.new()
	slots.custom_minimum_size = Vector2(450, 135)
	for i: int in range(SlotStore.COUNT):
		slots.add_item("%d · 空作品" % (i + 1))
	slots.select(0)
	slots.item_selected.connect(func(_i: int) -> void: _select_slot())
	stack.add_child(slots)
	title_entry = LineEdit.new()
	title_entry.placeholder_text = "给作品起个名字"
	title_entry.max_length = 64
	title_entry.text = "林间作品"
	stack.add_child(title_entry)
	thumbnail = TextureRect.new()
	thumbnail.custom_minimum_size = Vector2(320, 200)
	thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	stack.add_child(thumbnail)
	var row: HBoxContainer = HBoxContainer.new()
	stack.add_child(row)
	for operation: String in ["save", "load"]:
		var button: Button = Button.new()
		button.text = "保存到此槽" if operation == "save" else "载入此槽 / 自动恢复备份"
		button.pressed.connect(
			func() -> void: slot_requested.emit(operation, selected_slot(), title_entry.text)
		)
		row.add_child(button)
	save_note = _note(stack, "空闲 60 秒自动保存到当前作品；保留三代备份。")
	_label(stack, "损坏的主文件不会被覆盖；恢复后请另存到空槽。")
	settings = _window("本机设置", Vector2i(540, 650))
	settings.window_input.connect(_capture_binding)
	var options: VBoxContainer = _window_stack(settings)
	scale_caption = _note(options, "界面缩放 · 100%")
	scale_control = HSlider.new()
	scale_control.min_value = 1.0
	scale_control.max_value = 1.5
	scale_control.step = 0.05
	scale_control.value_changed.connect(
		func(value: float) -> void:
			if not _settings_sync:
				preference_changed.emit("ui_scale", value)
	)
	options.add_child(scale_control)
	dof_control = CheckBox.new()
	dof_control.text = "柔和景深（关闭时全景清晰）"
	dof_control.toggled.connect(func(value: bool) -> void: preference_changed.emit("dof", value))
	options.add_child(dof_control)
	motion_control = CheckBox.new()
	motion_control.text = "减少动态 · 停止草木与布幔摆动"
	motion_control.toggled.connect(
		func(value: bool) -> void: preference_changed.emit("reduce_motion", value)
	)
	options.add_child(motion_control)
	_label(options, "点击快捷键后按新组合；Esc 取消，重复组合会提示冲突。")
	for i: int in range(UserPreferences.ACTIONS.size()):
		var action: String = UserPreferences.ACTIONS[i]
		var button: Button = Button.new()
		button.pressed.connect(
			func() -> void:
				_binding = action
				settings_note.text = "请按新的组合键（Esc 取消）"
		)
		options.add_child(button)
		_binding_buttons[action] = button
	var reset_button: Button = Button.new()
	reset_button.text = "恢复默认设置与快捷键"
	reset_button.pressed.connect(func() -> void: preferences_reset.emit())
	options.add_child(reset_button)
	settings_note = _note(options, "设置自动保存到本机。")
	decision = ConfirmationDialog.new()
	decision.title = "作品尚未保存"
	decision.dialog_text = "保存当前作品后继续？"
	decision.ok_button_text = "保存并继续"
	decision.cancel_button_text = "取消"
	decision.add_button("放弃修改并继续", false, "discard")
	decision.confirmed.connect(func() -> void: decision_made.emit("save"))
	decision.canceled.connect(func() -> void: decision_made.emit("cancel"))
	decision.custom_action.connect(
		func(_a: StringName) -> void:
			decision.hide()
			decision_made.emit("discard")
	)
	add_child(decision)
	_layout_panels()


func _window(caption: String, dimensions: Vector2i) -> Window:
	var window: Window = Window.new()
	window.title = caption
	window.size = dimensions
	window.transient = true
	window.exclusive = true
	window.theme = GardenTheme.create()
	window.close_requested.connect(
		func() -> void:
			_binding = ""
			window.hide()
	)
	add_child(window)
	window.hide()
	return window


func _window_stack(window: Window) -> VBoxContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	window.add_child(scroll)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 12)
	scroll.add_child(stack)
	return stack


func selected_slot() -> int:
	return slots.get_selected_items()[0] if not slots.get_selected_items().is_empty() else 0


func update_catalog(entries: Array) -> void:
	for entry: Dictionary in entries:
		var index: int = entry["index"]
		slots.set_item_text(
			index,
			(
				"%d · %s%s"
				% [
					index + 1,
					entry["metadata"].get(
						"title", "空作品" if entry["error"] == "no_valid_save" else "无法读取"
					),
					" · 已恢复备份" if entry["backup"] > 0 else ""
				]
			)
		)
		slots.set_item_metadata(index, entry)
	_select_slot()


func _select_slot() -> void:
	var entry: Variant = slots.get_item_metadata(selected_slot())
	thumbnail.texture = null
	if not entry is Dictionary:
		return
	title_entry.text = entry["metadata"].get("title", "林间作品")
	var encoded: String = entry["metadata"].get("presentation", {}).get("thumbnail", "")
	if not encoded.is_empty():
		var image: Image = Image.new()
		if image.load_png_from_buffer(Marshalls.base64_to_raw(encoded)) == OK:
			thumbnail.texture = ImageTexture.create_from_image(image)


func sync_preferences(preferences: UserPreferences) -> void:
	_settings_sync = true
	for window: Window in [library, settings]:
		window.content_scale_factor = preferences.values["ui_scale"]
		var available: Vector2 = get_viewport().get_visible_rect().size * 0.9
		window.size = Vector2i(Vector2(540, 650) * preferences.values["ui_scale"]).min(
			Vector2i(available)
		)
	scale_control.set_value_no_signal(preferences.values["ui_scale"])
	scale_caption.text = "界面缩放 · %d%%（100–150%%）" % roundi(preferences.values["ui_scale"] * 100)
	dof_control.set_pressed_no_signal(preferences.values["dof"])
	motion_control.set_pressed_no_signal(preferences.values["reduce_motion"])
	for i: int in range(UserPreferences.ACTIONS.size()):
		var action: String = UserPreferences.ACTIONS[i]
		var events: Array[InputEvent] = InputMap.action_get_events(action)
		_binding_buttons[action].text = (
			UserPreferences.LABELS[i]
			+ "："
			+ (
				events[0]
				. as_text()
				. replace(" - Physical", "")
				. replace(" (Physical)", "")
				. replace("Command", "⌘")
				. replace("Shift", "⇧")
				. replace("Alt", "⌥")
			)
		)
	_settings_sync = false


func _input(event: InputEvent) -> void:
	_capture_binding(event)


func _capture_binding(event: InputEvent) -> void:
	if not _binding.is_empty() and event is InputEventKey and event.pressed and not event.echo:
		settings.set_input_as_handled()
		get_viewport().set_input_as_handled()
		if event.keycode != KEY_ESCAPE:
			binding_requested.emit(_binding, event)
		_binding = ""


func sync_objects(snapshot: Dictionary, selected: Array[String]) -> void:
	# Inherited publication/selection hooks can ask three times for the same card.
	var signature: int = hash(
		[snapshot["instances"], selected, snapshot["environment"].get("palette", {})]
	)
	if signature == _objects_signature:
		return
	_objects_signature = signature
	super.sync_objects(snapshot, selected)


func set_ui_scale(value: float) -> void:
	super.set_ui_scale(value)
	if scale_control != null and not _settings_sync:
		preference_changed.emit("ui_scale", _scale_value)


func _note(parent: Node, text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 450
	parent.add_child(label)
	return label


func sync(snapshot: Dictionary, selected: Array[String]) -> void:
	if not _card_changed("buildings", [snapshot["buildings"], snapshot["attachments"], selected]):
		return
	super.sync(snapshot, selected)


func sync_extra(snapshot: Dictionary, selected: Array[String], path_id: String) -> void:
	if not _card_changed("paths", [snapshot["paths"], snapshot["buildings"], selected, path_id]):
		return
	super.sync_extra(snapshot, selected, path_id)


func sync_garden(snapshot: Dictionary, issues: Array) -> void:
	if not _card_changed(
		"garden",
		[
			snapshot.get("bridges", []),
			snapshot.get("stairs", []),
			snapshot.get("fences", []),
			issues
		]
	):
		return
	super.sync_garden(snapshot, issues)


func _card_changed(key: String, content: Array) -> bool:
	var signature: int = hash(content)
	if _cards.get(key, 0) == signature:
		return false
	_cards[key] = signature
	return true


func _layout_panels() -> void:
	super._layout_panels()
	if _feedback != null:
		var dimensions: Vector2 = get_viewport().get_visible_rect().size / _scale_value
		_feedback.size.x = minf(460, maxf(120, dimensions.x - 656))
		_feedback.position = Vector2((dimensions.x - _feedback.size.x) * 0.5, 16)
