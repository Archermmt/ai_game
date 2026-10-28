class_name IslandAudio
extends Node
var enabled:bool=true
var music=AudioStreamPlayer.new()
var sea=AudioStreamPlayer.new()
var fx=AudioStreamPlayer.new()
var day_track:AudioStream
var evening_track:AudioStream
var clips:Dictionary={}
var last_fx:int=0
func _ready() -> void:
	add_child(music);add_child(sea);add_child(fx)
	day_track=load("res://game/audio/clips/day.wav");evening_track=load("res://game/audio/clips/sunset.wav")
	for id in ["paint","place","undo","journal","click"]:clips[id]=load("res://game/audio/clips/"+id+".wav")
	music.volume_db=-16;sea.volume_db=-12;fx.volume_db=-13
	sea.stream=load("res://game/audio/clips/sea.wav")
	music.finished.connect(func():if enabled:music.play())
	sea.finished.connect(func():if enabled:sea.play())
	music.stream=day_track;music.play();sea.play()
func set_evening(value:bool) -> void:
	music.stream=evening_track if value else day_track
	if enabled:music.play()
func effect(id:String) -> void:
	if not enabled or Time.get_ticks_msec()-last_fx<130:return
	last_fx=Time.get_ticks_msec();fx.stream=clips.get(id,clips.get("click"));fx.play()
func toggle() -> void:
	enabled=not enabled
	if enabled:music.play();sea.play()
	else:music.stop();sea.stop();fx.stop()
