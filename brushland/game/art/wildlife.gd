class_name Wildlife
extends Node3D
var kit=ArtKit.new()
var animals:Array=[]
var enabled:bool=true
var time:float=0
func setup() -> void:
	for i in range(4):
		var kind="cat" if i==0 else "gull";var n=kit.animal(kind);add_child(n);animals.append(n)
func _process(dt:float) -> void:
	if enabled:time+=dt
	for i in range(animals.size()):
		var n:Node3D=animals[i]
		if i==0:n.position=Vector3(28.2,1.03,35.4);n.rotation.y=-1.1
		else:
			var a=time*0.12+i*2.1
			n.position=Vector3(32+cos(a)*(12+i),4+sin(a*1.3+i)*0.6,32+sin(a)*(8+i));n.rotation.y=-a
			for child in n.get_children():
				if child.name=="WingLeft":child.rotation.z=sin(time*3+i)*0.3
				if child.name=="WingRight":child.rotation.z=-sin(time*3+i)*0.3
