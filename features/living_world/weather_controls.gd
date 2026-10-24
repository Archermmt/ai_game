class_name WeatherControls
extends PanelContainer

signal changed
var clock: CalendarState
var season_choice: OptionButton
var automatic: CheckBox
var sliders: Dictionary = {}
var percentages: Dictionary = {}
var row_widgets: Dictionary = {}
var _syncing: bool = false


func configure(value: CalendarState) -> void:
	clock = value
	name = "WeatherWeights"
	theme = GardenTheme.create()
	add_theme_stylebox_override("panel", GardenTheme.box(GardenTheme.CREAM))
	var stack: VBoxContainer = VBoxContainer.new()
	add_child(stack)
	var heading: HBoxContainer = HBoxContainer.new()
	stack.add_child(heading)
	var title: Label = Label.new()
	title.text = "四季天气比例"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	season_choice = OptionButton.new()
	for label: String in ["春", "夏", "秋", "冬"]:
		season_choice.add_item(label)
	season_choice.accessibility_name = "选择要设置天气的季节"
	season_choice.select(WeatherCycle.SEASONS.find(clock.season()))
	season_choice.item_selected.connect(func(_index: int) -> void: sync())
	heading.add_child(season_choice)
	var close: Button = Button.new()
	close.icon = IllustratedIcons.texture("close")
	close.expand_icon = true
	close.custom_minimum_size = Vector2(28, 28)
	close.add_theme_constant_override("icon_max_width", 20)
	close.tooltip_text = "收起天气设置"
	close.pressed.connect(hide)
	heading.add_child(close)
	automatic = CheckBox.new()
	automatic.add_theme_color_override("font_pressed_color", GardenTheme.INK)
	automatic.add_theme_color_override("font_hover_pressed_color", GardenTheme.INK)
	automatic.text = "自动天气 · 每3游戏小时抽取，换日重新抽取"
	automatic.toggled.connect(
		func(enabled: bool) -> void:
			if not _syncing:
				clock.automatic_weather = enabled
				clock.align_weather()
				changed.emit()
	)
	stack.add_child(automatic)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 120
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stack.add_child(scroll)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("v_separation", 7)
	grid.add_theme_constant_override("h_separation", 10)
	scroll.add_child(grid)
	for i: int in range(WeatherCycle.TYPES.size()):
		var key: String = WeatherCycle.TYPES[i]
		var picture: TextureRect = TextureRect.new()
		picture.texture = IllustratedIcons.texture(key)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.custom_minimum_size = Vector2(26, 26)
		grid.add_child(picture)
		var label: Label = Label.new()
		label.text = WeatherCycle.LABELS[i]
		grid.add_child(label)
		var slider: HSlider = HSlider.new()
		slider.min_value = 0
		slider.max_value = 100
		slider.step = 1
		slider.custom_minimum_size = Vector2(200, 26)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.accessibility_name = label.text + "出现比例"
		for state: String in ["slider", "grabber_area", "grabber_area_highlight"]:
			var rail: StyleBoxFlat = StyleBoxFlat.new()
			rail.bg_color = Color("b8bda0") if state == "slider" else Color("809474")
			rail.set_corner_radius_all(3)
			rail.content_margin_top = 3
			rail.content_margin_bottom = 3
			slider.add_theme_stylebox_override(state, rail)
		row_widgets[key] = [picture, label]
		slider.value_changed.connect(func(weight: float) -> void: _weight_changed(key, weight))
		sliders[key] = slider
		grid.add_child(slider)
		var percent: Label = Label.new()
		percent.custom_minimum_size.x = 48
		percentages[key] = percent
		grid.add_child(percent)
	var note: Label = Label.new()
	note.text = "拖动一项，其余按比例分配，总和100%。灰色天气不适合该季节。"
	note.add_theme_font_size_override("font_size", 12)
	stack.add_child(note)
	sync()


func _weight_changed(key: String, weight: float) -> void:
	if _syncing:
		return
	WeatherCycle.reweight(
		clock.weather_weights, WeatherCycle.SEASONS[season_choice.selected], key, weight
	)
	sync()
	changed.emit()


func sync() -> void:
	_syncing = true
	automatic.set_pressed_no_signal(clock.automatic_weather)
	var season: String = WeatherCycle.SEASONS[season_choice.selected]
	for key: String in sliders:
		var permitted: bool = WeatherCycle.allowed(season, key)
		var slider: HSlider = sliders[key]
		slider.editable = permitted
		slider.value = clock.weather_weights[season][key]
		slider.tooltip_text = "调整比例" if permitted else "本季节不会出现"
		percentages[key].text = "%.1f%%" % clock.weather_weights[season][key]
		percentages[key].modulate.a = 1.0 if permitted else 0.35
		for widget: Control in row_widgets[key]:
			widget.modulate.a = 1.0 if permitted else 0.35
	_syncing = false
