class_name Wildlife
extends Node3D
var animals:Array=[]
var enabled:bool=true
var time:float=0
var surface:IslandSurface
func setup(amount:int=4) -> void:
	for i in range(amount):
		var n=AnimalRig.make("cat" if i==0 else "gull");add_child(n);animals.append(n)
func _process(dt:float) -> void:
	if enabled:time+=dt
	for i in range(animals.size()):
		var n=animals[i]
		if i==0:
			var phase=fposmod(time,28.0);var walk=minf(phase,8.0)
			var lane=33
			if surface!=null:
				for z in [33,32,37]:
					if surface.cell(Vector2i(27,z)).get("road",false) and surface.cell(Vector2i(29,z)).get("road",false):lane=z;break
			var p=Vector2(28+cos(walk*TAU/8.0)*1.2,lane)
			var y=surface.height_at(p) if surface!=null else 1.0
			n.position=Vector3(p.x,y,p.y);n.rotation.y=-PI/2 if phase<4 else PI/2
			n.animate("walk" if phase<8 else "sleep" if phase<23 else "stretch",phase<8,time if phase<23 else (phase-23)/5.0*2.0)
		else:
			var phase=fposmod(time+i*4,24.0);var angle=time*0.12+i*2.1
			var flying=Vector3(32+cos(angle)*(12+i),4+sin(angle*1.3+i)*0.6,32+sin(angle)*(8+i))
			var p=Vector2(24+i,39)
			if surface!=null and surface.occupied.has(Vector2i(p)):
				for offset in BuildingRules.DIRS:
					var q=Vector2i(p)+offset
					if int(surface.cell(q).h)>0 and not surface.occupied.has(q):p=Vector2(q);break
			var ground=surface.height_at(p) if surface!=null else 0.5
			var landed=Vector3(p.x,ground,p.y)
			if phase<14:n.position=flying;n.animate("fly",false,time)
			elif phase<17:n.position=flying.lerp(landed,smoothstep(14,17,phase));n.animate("land",false,(phase-14)/3.0)
			elif phase<21:n.position=landed;n.animate("stand",false,time)
			else:n.position=landed.lerp(flying,smoothstep(21,24,phase));n.animate("takeoff",false,(phase-21)/3.0)
			n.rotation.y=-angle
