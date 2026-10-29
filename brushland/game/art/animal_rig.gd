class_name AnimalRig
extends ResidentRig
var species="cat"
static func make(kind:String) -> AnimalRig:
	var rig=AnimalRig.new();rig.species=kind;rig.name=kind.capitalize();rig.build_animal();return rig
func build_animal() -> void:
	skeleton.name="Skeleton3D";add_child(skeleton)
	var cat=species=="cat"
	bone(0,-1,Vector3(0,0.23 if cat else 0.14,0));bone(1,0,Vector3(0,0,-0.18));bone(2,0,Vector3(0,0.23 if cat else 0.16,0.25 if cat else 0.18))
	bone(3,0,Vector3(-0.14,0.02,0));bone(4,0,Vector3(0.14,0.02,0))
	bone(5,0,Vector3(-0.12 if cat else -0.06,-0.08 if cat else -0.09,0.19 if cat else 0));bone(6,0,Vector3(0.12 if cat else 0.06,-0.08 if cat else -0.09,0.19 if cat else 0))
	bone(7,0,Vector3(-0.12,-0.08,-0.20));bone(8,0,Vector3(0.12,-0.08,-0.20))
	sphere(Vector3.ZERO,Vector3(0.38,0.42,0.65) if cat else Vector3(0.23,0.25,0.44),Color("d9c8a6") if cat else ArtKit.CREAM,0)
	sphere(Vector3.ZERO,Vector3(0.36,0.32,0.32) if cat else Vector3(0.22,0.22,0.22),ArtKit.CREAM,2)
	skeleton.add_bone("Eyelids");skeleton.set_bone_parent(9,2);skeleton.set_bone_rest(9,Transform3D.IDENTITY);skeleton.reset_bone_pose(9);rests.append(rests[2])
	for side in [-1,1]:sphere(Vector3(side*0.07,0.02,0.15 if cat else 0.09),Vector3(0.026,0.04,0.02),Color("4e4a40"),9)
	if cat:
		for side in [-1,1]:
			var ear=CylinderMesh.new();ear.bottom_radius=0.085;ear.top_radius=0;ear.height=0.16;ear.radial_segments=8
			part(ear,Vector3(side*0.12,0.17,0),Vector3.ONE,Color("c79b78"),2)
		for id in [5,6,7,8]:sphere(Vector3(0,-0.07,0),Vector3(0.09,0.19,0.11),ArtKit.CREAM,id)
		sphere(Vector3(0.15,0.17,-0.13),Vector3(0.12,0.45,0.15),Color("c79b78"),1)
	else:
		box(Vector3(0,-0.01,0.15),Vector3(0.08,0.06,0.18),Color("d4b162"),2)
		for id in [3,4]:sphere(Vector3(-0.13 if id==3 else 0.13,0,-0.02),Vector3(0.5,0.05,0.24),Color("abb8b4"),id)
		for id in [5,6]:box(Vector3(0,-0.03,0.02),Vector3(0.05,0.05,0.10),Color("c9a156"),id)
	finish_body()
func animate(state:String,_walking:bool,time:float) -> void:
	for i in range(skeleton.get_bone_count()):skeleton.reset_bone_pose(i)
	var animation=MotionLibrary.library().get_animation(species+"_"+state)
	for path in MotionLibrary.sample(animation,time):
		var id=skeleton.find_bone(String(path).get_slice(":",1))
		if id>=0:skeleton.set_bone_pose_rotation(id,MotionLibrary.sample(animation,time)[path])
	skeleton.set_bone_pose_scale(9,Vector3(1,0.06 if state=="sleep" or fposmod(time+1.0,5.0)<0.12 else 1.0,1))
	scale=Vector3(1,0.65,1.08) if state=="sleep" else Vector3(1,0.85,1.12) if state=="stretch" else Vector3.ONE
