class_name IslandHud
extends CanvasLayer
signal tool_selected(tool:String)
signal action_requested(action:String)
signal wish_toggled(id:String)
var root=Control.new()
var status=Label.new()
var toast_label=Label.new()
var subbar=HFlowContainer.new()
var journal=VBoxContainer.new()
var card:PanelContainer
var photo_mode=false
var ui_scale=1.0
var actions:Control
var title_panel:Control
var bottom:Control
var guide:Label
var help:Label
var toast_time:float=0
var tool_buttons:Dictionary={}
const NAMES={"grass":"草地","sand":"沙滩","rock":"岩台","water":"海水","raise":"抬高","lower":"降低","flower":"花圃","road":"小路","house":"小屋","bridge":"木桥","dock":"码头","tea":"茶屋","greenhouse":"温室","lighthouse":"灯塔","bench":"长椅","pot":"盆栽","tree":"树木","move":"移动","erase":"移除","lock":"定形","color":"配色"}
const JOURNAL={"bench":["海风座位","在连通的小路旁放一张长椅"],"garden":["第一簇花","在小屋周围画至少三格花圃"],"tea":["茶还温着","接通茶屋，邀请两位邻居喝茶"],"bridge":["桥的另一头","用木桥接通两岸，让居民走过"],"greenhouse":["玻璃里的绿意","让居民走到温室赏花"],"lighthouse":["今晚有灯","切换日落，等居民到灯塔旁"]}
func style(color:Color,border:Color=Color.TRANSPARENT) -> StyleBoxFlat:
	var s=StyleBoxFlat.new();s.bg_color=color;s.border_color=border
	s.set_corner_radius_all(12);s.set_content_margin_all(12)
	if border.a>0:s.set_border_width_all(1)
	return s
func _ready() -> void:
	add_child(root);root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var font=preload("res://game/ui/fonts/noto_sans_cjk_sc_regular.otf")
	var theme=Theme.new();theme.default_font=font;theme.default_font_size=18
	theme.set_color("font_color","Label",Color("405c54"));theme.set_color("font_color","Button",Color("466158"))
	theme.set_color("font_hover_color","Button",Color("274b40"));theme.set_color("font_pressed_color","Button",Color("f8f1dc"))
	theme.set_stylebox("normal","Button",style(Color("f6f0de"),Color("dfdfca")))
	theme.set_stylebox("hover","Button",style(Color("e8e8d3")))
	theme.set_stylebox("pressed","Button",style(Color("6f8d79")))
	theme.set_stylebox("focus","Button",style(Color(0.9,0.9,0.8,0.1),Color("7b9b89")))
	root.theme=theme
	title_panel=panel(Vector2(24,24),Vector2(345,104));var title_col=VBoxContainer.new();title_panel.add_child(title_col)
	var title=label("风屿手记",28);title_col.add_child(title)
	title_col.add_child(label("B R E E Z E L Y   I S L E S",11));title_col.add_child(status)
	actions=HFlowContainer.new();root.add_child(actions);actions.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT);actions.offset_left=-676;actions.offset_right=-24;actions.offset_top=24;actions.offset_bottom=68
	for item in [["journal","手记"],["residents","入住"],["undo","撤销"],["redo","重做"],["pause","暂停"],["sunset","日落"],["photo","拍照"],["menu","存档"]]:
		var b=button(actions,item[1],func():action_requested.emit(item[0]))
		if item[0] in ["undo","redo","photo"]:b.icon=load("res://game/ui/vectors/UI_002_%02d.svg"%{"undo":0,"redo":1,"photo":5}[item[0]]);b.add_theme_constant_override("icon_max_width",18)
	card=panel(Vector2(-268,98),Vector2(244,356));card.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT);card.offset_left=-268;card.offset_right=-24;card.offset_top=98;card.offset_bottom=454;var journal_scroll=ScrollContainer.new();journal_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;card.add_child(journal_scroll);journal_scroll.add_child(journal);journal.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	refresh_journal([]);card.visible=false
	bottom=PanelContainer.new();bottom.name="ToolBar";root.add_child(bottom);bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);bottom.offset_left=24;bottom.offset_right=-24;bottom.offset_top=-166;bottom.offset_bottom=-42
	bottom.add_theme_stylebox_override("panel",style(Color("f7f1df")))
	var col=VBoxContainer.new();bottom.add_child(col);col.add_theme_constant_override("separation",8)
	var categories=HBoxContainer.new();col.add_child(categories)
	for item in [["land","地貌"],["build","建造"],["nature","花草与摆件"],["edit","整理"]]:button(categories,item[1],func():show_category(item[0]))
	guide=label("一笔一座岛 · 慢慢画，不必着急",13);guide.size_flags_horizontal=Control.SIZE_EXPAND_FILL;guide.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;categories.add_child(guide)
	col.add_child(subbar);show_category("land")
	toast_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;root.add_child(toast_label);toast_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);toast_label.offset_top=-205;toast_label.offset_bottom=-165
	help=label("左键绘制 / 放置   右键取消   WASD 平移   Q/E 转相机   R 转物件   滚轮缩放   [ ] 笔刷   −/+ 桥长   Tab 手记",13)
	root.add_child(help);help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);help.offset_left=30;help.offset_top=-27;help.offset_bottom=-7
func label(text:String,size:int=18) -> Label:
	var n=Label.new();n.text=text;n.add_theme_font_size_override("font_size",size);return n
func panel(pos:Vector2,size:Vector2) -> PanelContainer:
	var n=PanelContainer.new();n.position=pos;n.size=size;n.add_theme_stylebox_override("panel",style(Color("f7f1df")));root.add_child(n);return n
func button(parent:Node,text:String,callback:Callable) -> Button:
	var b=Button.new();b.text=text;b.custom_minimum_size=Vector2(70,36);b.pressed.connect(callback);b.pressed.connect(b.release_focus);parent.add_child(b);return b
func show_category(category:String) -> void:
	for n in subbar.get_children():n.queue_free()
	tool_buttons.clear()
	var items={"land":["grass","sand","rock","water","raise","lower","road"],"build":["house","tea","greenhouse","lighthouse","bridge","dock"],"nature":["flower","bench","pot","tree"],"edit":["move","erase","lock","color"]}[category]
	for id in items:
		var b=button(subbar,NAMES[id],func():tool_selected.emit(id);highlight(id))
		var brush_ids=["grass","sand","rock","water","raise","lower","road","flower"]
		b.icon=load("res://game/ui/vectors/UI_001_%02d.svg"%brush_ids.find(id)) if id in brush_ids else load("res://game/ui/icons/"+id+".png");b.add_theme_constant_override("icon_max_width",30);b.custom_minimum_size=Vector2(88,50);b.tooltip_text=NAMES[id]
		if id in ["move","erase","lock"]:
			b.icon=load("res://game/ui/vectors/"+("UI_004_02" if id=="lock" else "UI_002_02" if id=="move" else "UI_002_03")+".svg")
		tool_buttons[id]=b
func highlight(id:String) -> void:
	for key in tool_buttons:tool_buttons[key].modulate=Color("c6d6c2") if key==id else Color.WHITE
func toast(text:String) -> void:
	toast_label.text=text;toast_time=5.0
func refresh_status(population:int,tool:String,radius:int,span:int,paused:bool) -> void:
	status.text="%d 位岛民   ·   %s %s%s"%[population,NAMES.get(tool,tool),str(span)+" 格" if tool in ["bridge","dock"] else str(radius)+" 号笔", "   已暂停" if paused else ""]
func refresh_journal(completed:Array,hidden:Array=[]) -> void:
	for n in journal.get_children():n.queue_free()
	journal.add_child(label("岛上的小心愿",21))
	journal.add_child(label("%d / 6 个日常片段   ·   没有期限"%completed.size(),12))
	for key in JOURNAL:
		var info=JOURNAL[key]
		if key in hidden:
			button(journal,"展开 · "+info[0],func():wish_toggled.emit(key));continue
		var row=VBoxContainer.new();journal.add_child(row)
		var heading=HBoxContainer.new();row.add_child(heading);var icon=TextureRect.new();icon.texture=load("res://game/ui/vectors/UI_003_%02d.svg"%JOURNAL.keys().find(key));icon.custom_minimum_size=Vector2(22,22);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;heading.add_child(icon);heading.add_child(label(("●  " if key in completed else "○  ")+info[0],18))
		var detail=label("已记在手记里" if key in completed else info[1],11);detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;detail.custom_minimum_size.x=210;row.add_child(detail)
		if not key in completed:button(row,"收起这条心愿",func():wish_toggled.emit(key))
func layout() -> void:
	if not is_instance_valid(root) or not is_instance_valid(bottom):return
	root.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);root.scale=Vector2.ONE*ui_scale;root.size=get_viewport().get_visible_rect().size/ui_scale
	var compact=root.size.x<1050
	guide.visible=not compact
	actions.offset_left=24 if compact else -676;actions.anchor_left=0 if compact else 1;actions.offset_top=138 if compact else 24;actions.offset_bottom=224 if compact else 68
	bottom.offset_top=-maxf(166,bottom.get_combined_minimum_size().y+42)
	card.offset_top=230 if compact else 98;card.offset_bottom=minf(root.size.y-42,card.offset_top+356);card.custom_minimum_size=Vector2.ZERO
func _process(dt:float) -> void:
	layout()
	if toast_time>0:toast_time-=dt
	elif not photo_mode:toast_label.text=""
