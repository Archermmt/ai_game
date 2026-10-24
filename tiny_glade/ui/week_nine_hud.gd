extends "res://ui/week_eight_hud.gd"

signal photo_requested(action: String)
signal layout_requested(kind: String)

const TEMPLATE_THUMBNAIL: Texture2D = preload("res://assets/ui/template_forest.png")

var photo_panel: PanelContainer
var photo_size: OptionButton
var photo_directory: LineEdit
var freeze: CheckBox
var photo_note: Label
var bookmarks: ItemList
var entry: Window
var overwrite: ConfirmationDialog
var hint: Label
var _overwrite_request: Array = []
var _photo_scroll: ScrollContainer


func _ready() -> void:
	super._ready()
	var parent: Node = _panels[0].get_child(0).get_child(0)
	var bar: HBoxContainer = HBoxContainer.new()
	parent.add_child(bar)
	parent.move_child(bar, 2)
	_add_button(bar, "photography", "摄影")
	_add_button(bar, "entry", "选择布局")
	for label: Node in parent.find_children("*", "Label", true, false):
		if "WEEK 08" in label.text:
			label.text = "风栖小筑 / WEEK 09"
		if "Option" in label.text or "双指" in label.text:
			label.text = "双指移动旋转 · 捏合缩放 · Option+左键平移"
	hint = Label.new()
	hint.text = "拖出小屋，再试试石径与花草；全部工具已开放。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(hint)
	var skip: Button = Button.new()
	skip.text = "跳过提示"
	skip.pressed.connect(
		func() -> void:
			hint.hide()
			skip.hide()
	)
	parent.add_child(skip)
	photo_panel = PanelContainer.new()
	photo_panel.theme = GardenTheme.create()
	photo_panel.position = Vector2(20, 20)
	photo_panel.custom_minimum_size = Vector2(360, 0)
	photo_panel.add_theme_stylebox_override("panel", GardenTheme.box(GardenTheme.CREAM))
	add_child(photo_panel)
	_photo_scroll = ScrollContainer.new()
	photo_panel.add_child(_photo_scroll)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_photo_scroll.add_child(stack)
	_label(stack, "摄影 · 双指移动旋转 / 捏合缩放")
	photo_size = OptionButton.new()
	photo_size.add_item("1920 × 1080")
	photo_size.add_item("2560 × 1440")
	stack.add_child(photo_size)
	freeze = CheckBox.new()
	freeze.text = "冻结草木与水面"
	freeze.set_pressed_no_signal(true)
	freeze.toggled.connect(func(_value: bool) -> void: photo_requested.emit("freeze"))
	stack.add_child(freeze)
	photo_directory = LineEdit.new()
	photo_directory.text = OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
	if photo_directory.text.is_empty():
		photo_directory.text = OS.get_user_data_dir()
	stack.add_child(photo_directory)
	for pair: Array in [
		["directory", "选择本地目录"],
		["export", "导出 PNG / 重试"],
		["bookmark", "保存当前构图"],
		["restore", "应用选中构图"],
		["hide", "隐藏摄影面板（Esc 返回）"],
		["exit", "返回编辑"]
	]:
		var button: Button = Button.new()
		button.text = pair[1]
		button.pressed.connect(func() -> void: photo_requested.emit(pair[0]))
		stack.add_child(button)
	bookmarks = ItemList.new()
	bookmarks.custom_minimum_size = Vector2(320, 95)
	stack.add_child(bookmarks)
	photo_note = Label.new()
	photo_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	photo_note.custom_minimum_size.x = 320
	stack.add_child(photo_note)
	photo_panel.hide()
	entry = _window("开始林间坡地", Vector2i(540, 520))
	var choices: VBoxContainer = _window_stack(entry)
	var preview: TextureRect = TextureRect.new()
	preview.custom_minimum_size = Vector2(450, 253)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists("res://assets/ui/template_forest.png"):
		preview.texture = TEMPLATE_THUMBNAIL
	choices.add_child(preview)
	_label(choices, "同一片坡地 · 可编辑示范，或保留外围树幕的空布局")
	for pair: Array in [["demo", "进入示范布局"], ["empty", "进入空布局"]]:
		var button: Button = Button.new()
		button.text = pair[1]
		button.pressed.connect(func() -> void: layout_requested.emit(pair[0]))
		choices.add_child(button)
	overwrite = ConfirmationDialog.new()
	overwrite.title = "替换已有作品"
	overwrite.dialog_text = "此槽已有作品。确认用当前作品覆盖？原作品保留三代备份。"
	add_child(overwrite)
	_layout_panels()


func refresh_bookmarks(records: Array) -> void:
	bookmarks.clear()
	for i: int in range(records.size()):
		bookmarks.add_item("%d · %s" % [i + 1, records[i]["id"]])
	if bookmarks.item_count > 0:
		bookmarks.select(bookmarks.item_count - 1)


func _select_slot() -> void:
	super._select_slot()
	if thumbnail.texture == null and ResourceLoader.exists("res://assets/ui/template_forest.png"):
		thumbnail.texture = TEMPLATE_THUMBNAIL


func _layout_panels() -> void:
	super._layout_panels()
	if _photo_scroll != null:
		var available: Vector2 = (
			get_viewport().get_visible_rect().size / _scale_value - Vector2(40, 40)
		)
		_photo_scroll.custom_minimum_size = Vector2(360, 500).min(available)
		photo_panel.size = _photo_scroll.custom_minimum_size


func sync_preferences(preferences: UserPreferences) -> void:
	super.sync_preferences(preferences)
	if entry != null:
		entry.content_scale_factor = preferences.values["ui_scale"]
		entry.size = Vector2i(Vector2(540, 520) * preferences.values["ui_scale"]).min(
			Vector2i(get_viewport().get_visible_rect().size * 0.9)
		)
