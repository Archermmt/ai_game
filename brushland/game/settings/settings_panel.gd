extends RefCounted
static func build(app:Node) -> void:
	var col=app.open_modal("设置与操作")
	for pair in [["music","音乐"],["waves","海浪"],["ambience","风与自然环境"],["effects","交互与生活音效"]]:
		var row=HBoxContainer.new();col.add_child(row);var label=app.hud.label(pair[1]);label.custom_minimum_size.x=160;row.add_child(label)
		var slider=HSlider.new();slider.min_value=0;slider.max_value=1;slider.step=0.05;slider.value=app.preferences.values[pair[0]];slider.custom_minimum_size=Vector2(180,28);row.add_child(slider)
		slider.value_changed.connect(func(value):app.preferences.values[pair[0]]=value;app.apply_preferences())
	for pair in [["muted","静音"],["reduced_motion","减少环境动画"],["photo_sound","拍照快门声"],["flash","绘制与心愿反馈"]]:
		var check=CheckButton.new();check.text=pair[1];check.button_pressed=app.preferences.values[pair[0]];col.add_child(check);check.toggled.connect(func(value):app.preferences.values[pair[0]]=value;app.apply_preferences())
	for pair in [["ui_scale","界面大小",[0.75,1.0,1.25,1.5],["75%","100%","125%","150%"]],["photo_resolution","照片尺寸",["1080p","window"],["1920 × 1080","当前窗口"]],["quality","画质",["medium","low"],["中等","流畅"]]]:
		var row=HBoxContainer.new();col.add_child(row);var label=app.hud.label(pair[1]);label.custom_minimum_size.x=160;row.add_child(label);var choice=OptionButton.new();row.add_child(choice)
		for text in pair[3]:choice.add_item(text)
		choice.select(pair[2].find(app.preferences.values[pair[0]]));choice.item_selected.connect(func(index):app.preferences.values[pair[0]]=pair[2][index];app.apply_preferences())
	app.hud.button(col,"更改按键",func():show_keys(app))
	app.hud.button(col,"返回",app.close_modal)
static func show_keys(app:Node) -> void:
	var col=app.open_modal("按键设置 · 点击后按新键")
	for id in app.preferences.keys:
		var row=HBoxContainer.new();col.add_child(row);var label=app.hud.label(IslandSettings.LABELS[id]);label.custom_minimum_size.x=200;row.add_child(label)
		var button=app.hud.button(row,app.preferences.key_text(id),func():app.binding_target=id;app.hud.toast("按下新的按键组合；Esc 取消"))
		button.tooltip_text=IslandSettings.LABELS[id]
	app.hud.button(col,"恢复默认按键",func():app.preferences.reset_keys();app.apply_preferences();show_keys(app))
	app.hud.button(col,"返回设置",func():build(app))
