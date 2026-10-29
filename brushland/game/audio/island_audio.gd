class_name IslandAudio
extends Node
const EFFECTS=["paint","road","place","move","remove","undo","journal","photo","click"]
const LIFE=["step_wood","step_stone","boat","cup","greet","cat","lighthouse"]
var enabled=true
var music=AudioStreamPlayer.new()
var sea=AudioStreamPlayer.new()
var fx=AudioStreamPlayer.new()
var layers:Array=[]
var voices:Array=[]
var clips:Dictionary={}
var day_track:AudioStream
var evening_track:AudioStream
var last_fx:Dictionary={}
var last_life:Dictionary={}
var previous:Dictionary={}
var steps:Dictionary={}
var clock=0.0
var life_gain=0.75
var photo_sound=true
func loop(player:AudioStreamPlayer) -> void:
	add_child(player);player.finished.connect(func():if enabled:player.play())
func _ready() -> void:
	for id in EFFECTS+LIFE:clips[id]=load("res://game/audio/clips/"+id+".wav")
	day_track=load("res://game/audio/clips/day.wav");evening_track=load("res://game/audio/clips/sunset.wav")
	loop(music);loop(sea);add_child(fx);music.stream=day_track;sea.stream=load("res://game/audio/clips/sea.wav");music.play();sea.play()
	for id in ["wind","leaves","birds"]:
		var player=AudioStreamPlayer.new();loop(player);player.stream=load("res://game/audio/clips/"+id+".wav");layers.append(player);player.play()
	for i in range(8):
		var player=AudioStreamPlayer3D.new();player.unit_size=5;player.max_distance=28;player.volume_db=-14;add_child(player);voices.append(player)
func set_evening(value:bool) -> void:
	var track=evening_track if value else day_track
	if music.stream==track:return
	music.stream=track
	if enabled:music.play()
func effect(id:String) -> void:
	if not enabled or (id=="photo" and not photo_sound):return
	var now=Time.get_ticks_msec()
	if now-int(last_fx.get(id,-1000))<130:return
	last_fx[id]=now;fx.stream=clips.get(id,clips.click);fx.play()
func life(id:String,position:Vector3) -> void:
	if not enabled or life_gain<=0 or clock-float(last_life.get(id,-10.0))<0.18:return
	var same=0;var free:AudioStreamPlayer3D
	for voice in voices:
		if voice.playing and voice.stream==clips[id]:same+=1
		if not voice.playing:free=voice
	if same>=2 or free==null:return
	last_life[id]=clock;free.stream=clips[id];free.position=position;free.play()
func update_residents(data:IslandData,sim:ResidentSim,delta:float,active:bool) -> void:
	if not active:
		for voice in voices:voice.stop()
		return
	clock+=delta
	var alive:Dictionary={}
	for person in sim.people:
		var id=int(person.id);alive[id]=true;var position=Vector3(person.x,float(data.cell(Vector2i(roundi(person.x),roundi(person.z))).h)*0.5,person.z)
		var old=String(previous.get(id,person.state));var state=String(person.state)
		if old!=state:
			if state=="tea":life("cup",position)
			elif state=="home":life("boat" if old=="arriving" else "greet",position)
			elif state=="lighthouse":life("lighthouse",position)
		previous[id]=state
		steps[id]=float(steps.get(id,0))+delta
		if not person.route.is_empty() and steps[id]>=0.55:
			steps[id]=0.0;var wooden=false
			for object in data.objects:
				if object.kind in ["bridge","dock"] and Vector2i(roundi(person.x),roundi(person.z)) in BuildingRules.footprint(object):wooden=true;break
			life("step_wood" if wooden else "step_stone",position)
	for id in previous.keys():
		if not alive.has(id):previous.erase(id);steps.erase(id)
	if int(clock/24)>int((clock-delta)/24):life("cat",Vector3(28,1,33))
func toggle() -> void:
	enabled=not enabled
	for player in [music,sea,fx]+layers:
		if enabled and player!=fx:player.play()
		else:player.stop()
	if not enabled:
		for voice in voices:voice.stop()
func apply_settings(values:Dictionary) -> void:
	music.volume_db=linear_to_db(maxf(0.0001,float(values.music)))-12
	sea.volume_db=linear_to_db(maxf(0.0001,float(values.waves)))-9
	for player in layers:player.volume_db=linear_to_db(maxf(0.0001,float(values.ambience)))-15
	life_gain=values.effects;photo_sound=values.photo_sound;fx.volume_db=linear_to_db(maxf(0.0001,float(values.effects)))-10
	for voice in voices:voice.volume_db=linear_to_db(maxf(0.0001,life_gain))-10
	var active=not values.muted
	if active!=enabled:toggle()
