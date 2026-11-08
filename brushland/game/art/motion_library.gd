class_name MotionLibrary
extends RefCounted
static var cached:AnimationLibrary
static var prefer_resource=true
static func rotation(animation:Animation,path:String,axis:Vector3,angles:Array) -> void:
	var track=animation.add_track(Animation.TYPE_ROTATION_3D);animation.track_set_path(track,NodePath(path))
	for i in range(angles.size()):animation.rotation_track_insert_key(track,float(i)*animation.length/(angles.size()-1),Quaternion(axis,float(angles[i])))
static func make(name:String,length:float=1.0,loop:bool=true) -> Animation:
	var animation=Animation.new();animation.resource_name=name;animation.length=length;animation.loop_mode=Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	cached.add_animation(name,animation);return animation
static func library() -> AnimationLibrary:
	if cached!=null:return cached
	if prefer_resource and ResourceLoader.exists("res://game/art/animations/motions.tres"):
		cached=load("res://game/art/animations/motions.tres");return cached
	cached=AnimationLibrary.new()
	var idle=make("idle",3);rotation(idle,"Skeleton3D:Head",Vector3.UP,[0,0.12,0,-0.12,0])
	for name in ["walk","dragcase"]:
		var walk=make(name)
		for pair in [["LegLeft",1],["LegRight",-1],["ArmLeft",-0.75],["ArmRight",0.75]]:
			var v=pair[1]*0.55;rotation(walk,"Skeleton3D:"+pair[0],Vector3.RIGHT,[0,v,0,-v,0])
		rotation(walk,"Skeleton3D:ShinLeft",Vector3.RIGHT,[0,0,0,0.55,0]);rotation(walk,"Skeleton3D:ShinRight",Vector3.RIGHT,[0,0.55,0,0,0])
	var drag=cached.get_animation("dragcase");rotation(drag,"Skeleton3D:ArmRight",Vector3.RIGHT,[0.32,0.28,0.32])
	var wave=make("wave",2,false);rotation(wave,"Skeleton3D:ArmRight",Vector3.FORWARD,[1.6,2.1,1.7,2.1,1.6])
	for name in ["sit_down","sit_idle","stand_up","drink"]:
		var sit=make(name,0.4 if name in ["sit_down","stand_up"] else 4.0 if name=="drink" else 3.0,name in ["sit_idle","drink"])
		var values=[0.0,-PI/2] if name=="sit_down" else [-PI/2,0.0] if name=="stand_up" else [-PI/2,-PI/2]
		for bone in ["LegLeft","LegRight"]:rotation(sit,"Skeleton3D:"+bone,Vector3.RIGHT,values)
		for bone in ["ShinLeft","ShinRight"]:rotation(sit,"Skeleton3D:"+bone,Vector3.RIGHT,[-values[0],-values[1]])
		if name=="drink":rotation(sit,"Skeleton3D:ArmRight",Vector3.RIGHT,[-0.8,-1.1,-0.8])
	for name in ["water","admire","carrylantern","carrypot"]:
		var action=make(name,2)
		rotation(action,"Skeleton3D:Spine",Vector3.RIGHT,[0.20,0.30,0.20])
		rotation(action,"Skeleton3D:"+("ArmRight" if name=="carrylantern" else "ArmLeft"),Vector3.RIGHT,[-0.35,-0.4,-0.35] if name=="carrylantern" else [-0.8,-0.9,-0.8])
		if name=="carrypot":rotation(action,"Skeleton3D:ArmRight",Vector3.RIGHT,[-0.8,-0.9,-0.8])
	for name in ["gull_fly","gull_takeoff","gull_land","gull_stand"]:
		var action=make(name,3.0 if name=="gull_stand" else 1.0,name in ["gull_fly","gull_stand"])
		var amount=0.035 if name=="gull_stand" else 0.35
		rotation(action,"Skeleton3D:ArmLeft",Vector3.FORWARD,[-1.1,-1.06,-1.1] if name=="gull_stand" else [-amount,amount,-amount]);rotation(action,"Skeleton3D:ArmRight",Vector3.FORWARD,[1.1,1.06,1.1] if name=="gull_stand" else [amount,-amount,amount])
	for name in ["cat_walk","cat_sleep","cat_stretch"]:
		var action=make(name,1.0 if name=="cat_walk" else 2.0 if name=="cat_stretch" else 3.0,name!="cat_stretch")
		for i in range(4):
			var amount=0.35 if name=="cat_walk" else 0.15
			rotation(action,"Skeleton3D:"+["LegLeft","LegRight","ShinLeft","ShinRight"][i],Vector3.RIGHT,([-amount,amount,-amount] if i in [0,3] else [amount,-amount,amount]) if name=="cat_walk" else [0.7,1.0,0.7] if name=="cat_sleep" else [-0.6,-0.9,-0.6])
	var sea=make("sea_seated",3);rotation(sea,"Skeleton3D:Head",Vector3.UP,[0,0.2,0,-0.2,0])
	for bone in ["LegLeft","LegRight"]:rotation(sea,"Skeleton3D:"+bone,Vector3.RIGHT,[-PI/2,-PI/2])
	for bone in ["ShinLeft","ShinRight"]:rotation(sea,"Skeleton3D:"+bone,Vector3.RIGHT,[1.45,1.6,1.45])
	return cached
static func sample(animation:Animation,time:float) -> Dictionary:
	var pose:Dictionary={}
	var t=fposmod(time,animation.length) if animation.loop_mode==Animation.LOOP_LINEAR else clampf(time,0.0,animation.length)
	for i in range(animation.get_track_count()):pose[String(animation.track_get_path(i))]=animation.rotation_track_interpolate(i,t)
	return pose
