class_name CalendarPanel
extends PanelContainer

signal changed
var clock: CalendarState
var fields: Dictionary = {}
var season_label: Label
var weather_icon: TextureRect
var _syncing: bool = false


func configure(value: CalendarState) -> void:
	clock = value
	name = "GardenCalendar"
	theme = GardenTheme.create()
	var paper: StyleBoxFlat = StyleBoxFlat.new()
	paper.bg_color = Color("eee8d6f5")
	paper.border_color = Color("a6ad8b")
	paper.set_border_width_all(1)
	paper.set_corner_radius_all(12)
	paper.content_margin_left = 15
	paper.content_margin_right = 15
	paper.content_margin_top = 12
	paper.content_margin_bottom = 12
	add_theme_stylebox_override("panel", paper)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 9)
	add_child(stack)
	var heading: HBoxContainer = HBoxContainer.new()
	stack.add_child(heading)
	weather_icon = TextureRect.new()
	weather_icon.custom_minimum_size = Vector2(48, 48)
	weather_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	weather_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	heading.add_child(weather_icon)
	season_label = Label.new()
	season_label.add_theme_font_size_override("font_size", 19)
	heading.add_child(season_label)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 7)
	stack.add_child(grid)
	for field: String in ["Year", "Month", "Day", "Hour", "Min", "Weather", "Speed"]:
		var label: Label = Label.new()
		label.text = field
		grid.add_child(label)
		if field == "Year":
			var year: SpinBox = SpinBox.new()
			year.min_value = 1
			year.max_value = 99999
			year.value_changed.connect(
				func(v: float) -> void:
					if not _syncing:
						clock.year = int(v)
						changed.emit()
			)
			fields[field] = year
			grid.add_child(year)
			continue
		var choice: OptionButton = OptionButton.new()
		choice.custom_minimum_size.x = 108
		choice.expand_icon = true
		choice.add_theme_constant_override("icon_max_width", 24)
		choice.accessibility_name = field
		fields[field] = choice
		grid.add_child(choice)
		match field:
			"Month":
				for i: int in range(1, 13):
					choice.add_item("%02d" % i)
			"Day":
				for i: int in range(1, 31):
					choice.add_item("%02d" % i)
			"Hour":
				for i: int in range(24):
					choice.add_item("%02d" % i)
			"Min":
				for i: int in range(60):
					choice.add_item("%02d" % i)
			"Weather":
				for i: int in range(4):
					choice.add_icon_item(
						IllustratedIcons.texture(CalendarState.WEATHER[i]),
						["晴", "阴", "雨 / 雷", "雪"][i]
					)
			"Speed":
				for title: String in ["暂停", "1×", "5×", "20×", "60×"]:
					choice.add_item(title)
		choice.item_selected.connect(func(index: int) -> void: _selected(field, index))
	var note: Label = Label.new()
	note.text = "林间历 · 每月30日\n1×：每秒一游戏分钟"
	note.add_theme_font_size_override("font_size", 11)
	stack.add_child(note)
	sync()


func _selected(key: String, index: int) -> void:
	if _syncing:
		return
	match key:
		"Month":
			clock.month = index + 1
		"Day":
			clock.day = index + 1
		"Hour":
			clock.minute_of_day = index * 60 + int(clock.minute_of_day) % 60
		"Min":
			clock.minute_of_day = floori(clock.minute_of_day / 60) * 60 + index
		"Weather":
			clock.weather = CalendarState.WEATHER[index]
		"Speed":
			clock.speed = CalendarState.SPEEDS[index]
	sync()
	changed.emit()


func sync() -> void:
	if clock == null:
		return
	_syncing = true
	fields["Year"].value = clock.year
	fields["Month"].select(clock.month - 1)
	fields["Day"].select(clock.day - 1)
	fields["Hour"].select(floori(clock.minute_of_day / 60))
	fields["Min"].select(floori(clock.minute_of_day) % 60)
	fields["Weather"].select(CalendarState.WEATHER.find(clock.weather))
	fields["Speed"].select(CalendarState.SPEEDS.find(clock.speed))
	weather_icon.texture = IllustratedIcons.texture(clock.weather)
	season_label.text = (
		"Season\n"
		+ {"spring": "春 · 萌芽", "summer": "夏 · 盛光", "autumn": "秋 · 金叶", "winter": "冬 · 静林"}[
			clock.season()
		]
	)
	_syncing = false
