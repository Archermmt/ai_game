class_name CalendarPanel
extends PanelContainer

signal changed
const MONTHS: Array[String] = [
	"Jan.", "Feb.", "Mar.", "Apr.", "May", "Jun.", "Jul.", "Aug.", "Sep.", "Oct.", "Nov.", "Dec."
]

var clock: CalendarState
var fields: Dictionary = {}
var season_label: Label
var weather_icon: OptionButton
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
	weather_icon = _choice("Weather")
	weather_icon.fit_to_longest_item = false
	weather_icon.custom_minimum_size = Vector2(48, 48)
	weather_icon.add_theme_constant_override("icon_max_width", 36)
	weather_icon.accessibility_name = "天气，点击更改"
	heading.add_child(weather_icon)
	season_label = Label.new()
	season_label.add_theme_font_size_override("font_size", 19)
	heading.add_child(season_label)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 7)
	stack.add_child(grid)
	for field: String in ["Year", "Date", "Time", "Speed"]:
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
		elif field == "Speed":
			grid.add_child(_choice(field))
		else:
			var row: HBoxContainer = HBoxContainer.new()
			row.name = "DateRow" if field == "Date" else "TimeRow"
			row.add_theme_constant_override("separation", 0)
			grid.add_child(row)
			row.add_child(_choice("Month" if field == "Date" else "Hour"))
			if field == "Time":
				var colon: Label = Label.new()
				colon.text = ":"
				row.add_child(colon)
			row.add_child(_choice("Day" if field == "Date" else "Min"))
	var note: Label = Label.new()
	note.text = "林间历 · 每月30日\n1×：每秒一游戏分钟"
	note.add_theme_font_size_override("font_size", 11)
	stack.add_child(note)
	sync()


func _choice(field: String) -> OptionButton:
	var choice: OptionButton = OptionButton.new()
	choice.expand_icon = true
	choice.add_theme_constant_override("icon_max_width", 24)
	choice.accessibility_name = field
	if field in ["Month", "Day", "Hour", "Min", "Weather"]:
		choice.flat = true
		choice.fit_to_longest_item = false
		for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
			var compact: StyleBoxFlat = StyleBoxFlat.new()
			compact.bg_color = (
				Color(0.4, 0.45, 0.3, 0.12) if state == "hover" else Color.TRANSPARENT
			)
			compact.content_margin_left = 1
			compact.content_margin_right = 1
			compact.content_margin_top = 4
			compact.content_margin_bottom = 4
			choice.add_theme_stylebox_override(state, compact)
		var blank: Image = Image.create(1, 1, false, Image.FORMAT_RGBA8)
		blank.fill(Color.TRANSPARENT)
		choice.add_theme_icon_override("arrow", ImageTexture.create_from_image(blank))
		choice.tooltip_text = {
			"Month": "选择月份", "Day": "选择日期", "Hour": "选择小时", "Min": "选择分钟", "Weather": "选择天气"
		}[field]
	fields[field] = choice
	match field:
		"Month":
			for title: String in MONTHS:
				choice.add_item(title)
		"Day":
			for day: int in range(1, 31):
				choice.add_item(_ordinal(day))
		"Hour":
			for hour: int in range(24):
				choice.add_item(str(hour))
		"Min":
			for minute: int in range(60):
				choice.add_item("%02d" % minute)
		"Weather":
			for i: int in range(4):
				choice.add_icon_item(
					IllustratedIcons.texture(CalendarState.WEATHER[i]), ["晴", "阴", "雨 / 雷", "雪"][i]
				)
		"Speed":
			for title: String in ["暂停", "1×", "5×", "20×", "60×"]:
				choice.add_item(title)
	choice.item_selected.connect(func(index: int) -> void: _selected(field, index))
	return choice


static func _ordinal(day: int) -> String:
	if day in [11, 12, 13]:
		return "%dth" % day
	return str(day) + {1: "st", 2: "nd", 3: "rd"}.get(day % 10, "th")


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
	weather_icon.text = ""
	weather_icon.tooltip_text = (
		"天气：%s，点击更改" % ["晴", "阴", "雨 / 雷", "雪"][CalendarState.WEATHER.find(clock.weather)]
	)
	season_label.text = (
		"Season\n"
		+ {"spring": "春 · 萌芽", "summer": "夏 · 盛光", "autumn": "秋 · 金叶", "winter": "冬 · 静林"}[
			clock.season()
		]
	)
	_syncing = false
