class_name ResidentRig
extends Node3D
var skeleton=Skeleton3D.new()
var body=MeshInstance3D.new()
var kit=ArtKit.new()
var geometry=ArrayMesh.new()
var builders:Dictionary={}
var rests:Array=[]
var cup:MeshInstance3D
var last_time=-1.0
const BONES=["Pelvis","Spine","Head","ArmLeft","ArmRight","LegLeft","LegRight","ShinLeft","ShinRight"]
static func create(index:int) -> ResidentRig:
	var rig=ResidentRig.new();rig.name="ResidentRig";rig.build(index);return rig
func bone(id:int,parent:int,position:Vector3) -> void:
	skeleton.add_bone(BONES[id]);skeleton.set_bone_parent(id,parent)
	skeleton.set_bone_rest(id,Transform3D(Basis.IDENTITY,position));skeleton.reset_bone_pose(id)
	rests.append(position+(rests[parent] if parent>=0 else Vector3.ZERO))
func part(mesh:Mesh,position:Vector3,scale_value:Vector3,color:Color,bone_id:int) -> void:
	var arrays=mesh.surface_get_arrays(0);var vertices=arrays[Mesh.ARRAY_VERTEX];var normals=arrays[Mesh.ARRAY_NORMAL];var indices=arrays[Mesh.ARRAY_INDEX]
	var key=color.to_html();var st:SurfaceTool
	if not builders.has(key):
		st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);st.set_material(kit.material(color));builders[key]=st
	else:st=builders[key]
	for i in range(indices.size() if indices!=null else vertices.size()):
		var source=int(indices[i]) if indices!=null else i
		st.set_normal((normals[source]/scale_value).normalized());st.set_bones(PackedInt32Array([bone_id,0,0,0]));st.set_weights(PackedFloat32Array([1,0,0,0]))
		st.add_vertex(vertices[source]*scale_value+position+rests[bone_id])
func sphere(position:Vector3,scale_value:Vector3,color:Color,bone_id:int) -> void:
	var mesh=SphereMesh.new();mesh.radius=0.5;mesh.height=1;mesh.radial_segments=12;mesh.rings=6;part(mesh,position,scale_value,color,bone_id)
func box(position:Vector3,scale_value:Vector3,color:Color,bone_id:int) -> void:
	part(BoxMesh.new(),position,scale_value,color,bone_id)
func build(index:int) -> void:
	skeleton.name="Skeleton3D";add_child(skeleton)
	bone(0,-1,Vector3(0,0.40,0));bone(1,0,Vector3(0,0.15,0));bone(2,1,Vector3(0,0.30,0))
	bone(3,1,Vector3(-0.25,0.08,0));bone(4,1,Vector3(0.25,0.08,0))
	bone(5,0,Vector3(-0.12,0,0));bone(6,0,Vector3(0.12,0,0));bone(7,5,Vector3(0,-0.18,0));bone(8,6,Vector3(0,-0.18,0))
	var cloth=[Color("d3b461"),ArtKit.GREEN,ArtKit.CORAL,ArtKit.BLUE][index%4]
	sphere(Vector3.ZERO,Vector3(0.43,0.42,0.32),cloth,1)
	sphere(Vector3.ZERO,Vector3(0.42,0.43,0.40),Color("dcb892"),2)
	for side in [-1,1]:
		var leg=5 if side<0 else 6;var shin=leg+2;var arm=3 if side<0 else 4
		box(Vector3(0,-0.09,0),Vector3(0.12,0.18,0.14),ArtKit.WOOD,leg)
		box(Vector3(0,-0.08,0),Vector3(0.11,0.16,0.13),ArtKit.WOOD,shin)
		box(Vector3(0,-0.18,0.055),Vector3(0.14,0.07,0.23),ArtKit.WOOD.darkened(0.25),shin)
		sphere(Vector3(0,-0.14,0),Vector3(0.14,0.34,0.16),cloth,arm)
		sphere(Vector3(side*0.09,0.02,0.193),Vector3(0.027,0.04,0.015),Color("4f4b40"),2)
	sphere(Vector3(0,0.20,-0.02),Vector3(0.44 if index%2 else 0.36,0.17,0.4),cloth,2)
	for st in builders.values():st.commit(geometry)
	var skin=Skin.new()
	for i in range(BONES.size()):skin.add_bind(i,Transform3D(Basis.IDENTITY,rests[i]).affine_inverse())
	body.name="SkinnedBody";body.mesh=geometry;body.skin=skin;body.skeleton=NodePath("../Skeleton3D");add_child(body)
	var hand=BoneAttachment3D.new();hand.name="CupSocket";skeleton.add_child(hand);hand.bone_name="ArmRight"
	cup=kit.cylinder(hand,Vector3(0,-0.24,0.06),0.055,0.10,ArtKit.CREAM);cup.visible=false
func animate(state:String,walking:bool,time:float) -> void:
	var old:Array=[]
	for i in range(BONES.size()):old.append(skeleton.get_bone_pose_rotation(i));skeleton.reset_bone_pose(i)
	cup.visible=state=="tea"
	if walking:
		var swing=sin(time*7.0)*0.55
		for pair in [[5,swing],[6,-swing],[3,-swing*0.75],[4,swing*0.75]]:skeleton.set_bone_pose_rotation(pair[0],Quaternion(Vector3.RIGHT,pair[1]))
		skeleton.set_bone_pose_rotation(7,Quaternion(Vector3.RIGHT,maxf(0.0,-swing)));skeleton.set_bone_pose_rotation(8,Quaternion(Vector3.RIGHT,maxf(0.0,swing)))
	elif state in ["tea","bench"]:
		for i in [5,6]:skeleton.set_bone_pose_rotation(i,Quaternion(Vector3.RIGHT,-PI/2))
		for i in [7,8]:skeleton.set_bone_pose_rotation(i,Quaternion(Vector3.RIGHT,PI/2))
		if state=="tea":skeleton.set_bone_pose_rotation(4,Quaternion(Vector3.RIGHT,-0.8-0.35*sin(time*0.8)))
	elif state in ["greenhouse","garden"]:skeleton.set_bone_pose_rotation(1,Quaternion(Vector3.RIGHT,0.25+0.08*sin(time)))
	else:skeleton.set_bone_pose_rotation(2,Quaternion(Vector3.UP,0.12*sin(time*0.6)))

	var blend=1.0 if last_time<0 else 1.0-exp(-maxf(0.0,time-last_time)*12.0)
	for i in range(BONES.size()):skeleton.set_bone_pose_rotation(i,old[i].slerp(skeleton.get_bone_pose_rotation(i),blend))
	last_time=time
