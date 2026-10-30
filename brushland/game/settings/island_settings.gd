class_name IslandSettings
extends RefCounted
const DEFAULT_KEYS={"rotate":KEY_R,"shorten":KEY_MINUS,"lengthen":KEY_EQUAL,"pause":KEY_SPACE,"orbit_left":KEY_Q,"orbit_right":KEY_E,"north":KEY_W,"south":KEY_S,"west":KEY_A,"east":KEY_D,"brush_down":KEY_BRACKETLEFT,"brush_up":KEY_BRACKETRIGHT,"journal":KEY_TAB,"photo":KEY_P,"capture":KEY_F12,"cancel":KEY_ESCAPE}
const LABELS={"rotate":"旋转物件","shorten":"缩短桥 / 码头","lengthen":"加长桥 / 码头","pause":"暂停","orbit_left":"相机左转","orbit_right":"相机右转","north":"相机向北","south":"相机向南","west":"相机向西","east":"相机向东","brush_down":"减小笔刷","brush_up":"增大笔刷","journal":"生活手记","photo":"摄影模式","capture":"保存照片","cancel":"取消 / 返回","undo":"撤销","redo":"重做"}
var values={"music":0.65,"waves":0.75,"photo_sound":true,"flash":true,"ambience":0.75,"effects":0.75,"muted":false,"reduced_motion":false,"ui_scale":1.0,"photo_resolution":"1080p","quality":"medium","slot_names":["海湾手记","花园手记","灯塔手记"]}
var keys:Dictionary={}
var path="user://preferences.cfg"
func _init() -> void:reset_keys()
func reset_keys() -> void:
	keys=DEFAULT_KEYS.duplicate();var command=KEY_MASK_META if OS.get_name()=="macOS" else KEY_MASK_CTRL
	keys.undo=KEY_Z|command;keys.redo=KEY_Z|command|KEY_MASK_SHIFT
func read() -> Error:
	var config=ConfigFile.new();var error=config.load(path)
	if error!=OK:return error
	var settings:Dictionary={}
	for key in values:settings[key]=config.get_value("settings",key,values[key])
	merge_values(settings)
	var stored=config.get_value("input","keys",{})
	if stored is Dictionary:
		var candidate=keys.duplicate();var valid=true;var used:Dictionary={}
		for key in candidate:
			var code=stored.get(key,candidate[key])
			if not code is int or code<=0 or used.has(code):valid=false;break
			candidate[key]=code;used[code]=true
		if valid:keys=candidate
	return OK
func write() -> Error:
	var config=ConfigFile.new()
	for key in values:config.set_value("settings",key,values[key])
	config.set_value("input","keys",keys)
	var error=config.save(path+".tmp")
	if error!=OK:return error
	return DirAccess.rename_absolute(path+".tmp",path)
func bind(id:String,code:int) -> String:
	if not keys.has(id) or code<=0:return "无法使用这个按键"
	for other in keys:
		if other!=id and keys[other]==code:return "此键已用于："+LABELS[other]
	keys[id]=code;return ""
func matches(event:InputEventKey,id:String) -> bool:
	return int(event.get_keycode_with_modifiers())==int(keys[id])
func key_text(id:String) -> String:return OS.get_keycode_string(keys[id])

func merge_values(stored:Dictionary) -> void:
	for key in values:
		var value=stored.get(key,values[key])
		if key in ["music","waves","ambience","effects","ui_scale"]:
			if not value is float and not value is int:continue
			if not is_finite(float(value)):continue
			values[key]=clampf(float(value),0.75 if key=="ui_scale" else 0.0,1.5 if key=="ui_scale" else 1.0)
		elif key in ["muted","reduced_motion","photo_sound","flash"]:
			if value is bool:values[key]=value
		elif key=="slot_names":
			if value is Array and value.size()==3 and value.all(func(name):return name is String and name.length()<=40):values[key]=value.duplicate()
		elif value in (["1080p","window"] if key=="photo_resolution" else ["medium","low"]):values[key]=value
