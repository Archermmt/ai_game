extends ProductionLandscapePlayground
## G4 isolated capacity scene; identical source/Terrain3D for old/new grass.

var legacy_comparison: bool = false
var capacity_panel: PanelContainer
var capacity_stats: Label
var capacity_loader: PainterlyPreviewLoader


func _init() -> void:
	qa_mode = true
	legacy_comparison = "--g4-legacy" in OS.get_cmdline_user_args()


func _enter_tree() -> void:
	if get_tree().has_meta("g4_legacy"):
		legacy_comparison = bool(get_tree().get_meta("g4_legacy"))


func _create_meadow() -> MeadowRenderer:
	return MeadowRenderer.new() if legacy_comparison else super._create_meadow()


func _setup_initial_buildings() -> void:
	_show_result(session.replace_document(StressLayout.create(), _prepare_views), "满容量草地预览")


func _ready() -> void:
	super._ready()
	get_window().title = "G4 · 满容量草地预览 | 风栖小筑"
	var directory: String = "user://qa_painterly_grass/g4"
	saves.directory = directory.path_join("saves")
	active_slot = -1
	DirAccess.make_dir_recursive_absolute(directory.path_join("photos"))
	hud.photo_directory.text = ProjectSettings.globalize_path(directory.path_join("photos"))
	calendar.speed = 0
	calendar.automatic_weather = false
	calendar.month = 7
	calendar.minute_of_day = 720
	calendar.weather = "clear"
	preferences.values["grass_density"] = 0.45
	_apply_preferences()
	capacity_loader = PainterlyPreviewLoader.new()
	add_child(capacity_loader)
	capacity_loader.loading_completed.connect(
		func(resource: Resource) -> void: get_tree().change_scene_to_packed(resource as PackedScene)
	)
	_create_capacity_panel()


func _persist_preferences() -> void:
	# Preview settings are session-local; inherited IO never reaches real preferences.
	pass


func _create_capacity_panel() -> void:
	capacity_panel = PanelContainer.new()
	capacity_panel.name = "CapacityControls"
	capacity_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	capacity_panel.offset_left = 16
	capacity_panel.offset_top = -242
	capacity_panel.offset_right = 16
	capacity_panel.offset_bottom = -162
	hud.add_child(capacity_panel)
	var column: VBoxContainer = VBoxContainer.new()
	capacity_panel.add_child(column)
	capacity_stats = Label.new()
	capacity_stats.add_theme_font_size_override("font_size", 16)
	column.add_child(capacity_stats)
	var row: HBoxContainer = HBoxContainer.new()
	column.add_child(row)
	var variant: Button = _capacity_button(row, "切到新草" if legacy_comparison else "切到原草")
	variant.pressed.connect(
		func() -> void:
			get_tree().set_meta("g4_legacy", not legacy_comparison)
			capacity_loader.request_load("res://app/grass_capacity.tscn")
	)
	for density_value: float in [0.45, 1.0]:
		var density_button: Button = _capacity_button(row, "%d%% 草" % roundi(density_value * 100))
		density_button.pressed.connect(func() -> void: set_capacity_density(density_value))
	var weather_picker: OptionButton = OptionButton.new()
	weather_picker.name = "CapacityWeather"
	for text: String in ["晴天", "暴风雨", "暴风雪", "沙尘暴"]:
		weather_picker.add_item(text)
	weather_picker.item_selected.connect(set_capacity_weather)
	row.add_child(weather_picker)
	var back: Button = _capacity_button(row, "返回草地展示台")
	back.pressed.connect(
		func() -> void:
			get_tree().remove_meta("g4_legacy")
			capacity_loader.request_load("res://app/painterly_grass_preview.tscn")
	)


func set_capacity_density(value: float) -> void:
	preferences.values["grass_density"] = value
	_apply_preferences()


func set_capacity_weather(index: int) -> void:
	calendar.month = 1 if index == 2 else 7
	calendar.weather = ["clear", "storm", "blizzard", "duststorm"][index]
	_calendar_changed()
	hud.calendar.sync()


func _process(delta: float) -> void:
	super._process(delta)
	if capacity_panel != null:
		capacity_panel.visible = not photo_active
		capacity_stats.text = (
			"G4 满容量预览 · 24栋 / 1000物件 · %s · %d%%草 · %d FPS"
			% [
				"原草" if legacy_comparison else "新草",
				roundi(meadow.density * 100),
				Engine.get_frames_per_second()
			]
		)


func _capacity_button(parent: Node, text: String) -> Button:
	var button: Button = Button.new()
	button.text = text
	parent.add_child(button)
	return button
