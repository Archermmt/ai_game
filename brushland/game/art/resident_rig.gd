class_name ResidentRig
extends Node3D
static var shared_palette:StandardMaterial3D
static func palette_material() -> StandardMaterial3D:
	if shared_palette==null:
		shared_palette=StandardMaterial3D.new();shared_palette.vertex_color_use_as_albedo=true;shared_palette.vertex_color_is_srgb=true;shared_palette.roughness=1.0
	return shared_palette
var skeleton=Skeleton3D.new()
var body=MeshInstance3D.new()
var kit=ArtKit.new()
var geometry=ArrayMesh.new()
var builders:Dictionary={}
var rests:Array=[]
var suitcase:Node3D
var watering_can:Node3D
var water_drops:Array=[]
var cup:MeshInstance3D
var last_time=-1.0
var last_state=""
var base_body_mesh:ArrayMesh
var wearables:Dictionary={}
var wardrobe_enabled:Dictionary={}
var state_age=0.0
var entering_sit=false
var leaving_sit=false
const BONES=["Pelvis","Spine","Head","ArmLeft","ArmRight","LegLeft","LegRight","ShinLeft","ShinRight"]
static func create(index:int,include_headwear:bool=true) -> ResidentRig:
	var rig=ResidentRig.new();rig.name="ResidentRig";rig.build(index,include_headwear);return rig
func bone(id:int,parent:int,position:Vector3) -> void:
	skeleton.add_bone(BONES[id]);skeleton.set_bone_parent(id,parent)
	skeleton.set_bone_rest(id,Transform3D(Basis.IDENTITY,position));skeleton.reset_bone_pose(id)
	rests.append(position+(rests[parent] if parent>=0 else Vector3.ZERO))
func part(mesh:Mesh,position:Vector3,scale_value:Vector3,color:Color,bone_id:int) -> void:
	var arrays=mesh.surface_get_arrays(0);var vertices=arrays[Mesh.ARRAY_VERTEX];var normals=arrays[Mesh.ARRAY_NORMAL];var indices=arrays[Mesh.ARRAY_INDEX]
	var key="palette";var st:SurfaceTool
	if not builders.has(key):
		st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);st.set_material(palette_material());builders[key]=st
	else:st=builders[key]
	for i in range(indices.size() if indices!=null else vertices.size()):
		var source=int(indices[i]) if indices!=null else i
		st.set_normal((normals[source]/scale_value).normalized());st.set_color(color);st.set_bones(PackedInt32Array([bone_id,0,0,0]));st.set_weights(PackedFloat32Array([1,0,0,0]))
		st.add_vertex(vertices[source]*scale_value+position+rests[bone_id])
func sphere(position:Vector3,scale_value:Vector3,color:Color,bone_id:int) -> void:
	var mesh=SphereMesh.new();mesh.radius=0.5;mesh.height=1;mesh.radial_segments=6 if maxf(scale_value.x,maxf(scale_value.y,scale_value.z))<0.2 else 12 if bone_id in [1,2] else 8;mesh.rings=1 if maxf(scale_value.x,maxf(scale_value.y,scale_value.z))<0.2 else 6 if bone_id in [1,2] else 3;part(mesh,position,scale_value,color,bone_id)
func box(position:Vector3,scale_value:Vector3,color:Color,bone_id:int) -> void:
	part(BoxMesh.new(),position,scale_value,color,bone_id)
func build(index:int,include_headwear:bool=true) -> void:
	skeleton.name="Skeleton3D";add_child(skeleton)
	bone(0,-1,Vector3(0,0.40,0));bone(1,0,Vector3(0,0.15,0));bone(2,1,Vector3(0,0.30,0))
	bone(3,1,Vector3(-0.25,0.08,0));bone(4,1,Vector3(0.25,0.08,0))
	bone(5,0,Vector3(-0.12,0,0));bone(6,0,Vector3(0.12,0,0));bone(7,5,Vector3(0,-0.18,0));bone(8,6,Vector3(0,-0.18,0))
	var cloth=[Color("d3b461"),ArtKit.GREEN,ArtKit.CORAL,ArtKit.BLUE][index%4]
	sphere(Vector3.ZERO,Vector3(0.40,0.40,0.29),Color("dcb892"),1)
	sphere(Vector3.ZERO,Vector3(0.42,0.43,0.40),Color("dcb892"),2)
	for side in [-1,1]:
		var leg=5 if side<0 else 6;var shin=leg+2;var arm=3 if side<0 else 4
		box(Vector3(0,-0.09,0),Vector3(0.12,0.18,0.14),ArtKit.WOOD,leg)
		box(Vector3(0,-0.08,0),Vector3(0.11,0.16,0.13),ArtKit.WOOD,shin)
		box(Vector3(0,-0.18,0.055),Vector3(0.14,0.07,0.23),ArtKit.WOOD.darkened(0.25),shin)
		sphere(Vector3(0,-0.14,0),Vector3(0.14,0.34,0.16),cloth,arm)
		sphere(Vector3(side*0.09,0.02,0.193),Vector3(0.027,0.04,0.015),Color("4f4b40"),2)
	if include_headwear:build_headwear(index)
	finish_body();build_wardrobe(index,cloth)
	var left_hand=BoneAttachment3D.new();left_hand.name="LeftHandSocket";skeleton.add_child(left_hand);left_hand.bone_name="ArmLeft"
	watering_can=Node3D.new();watering_can.position=Vector3(0,-0.25,0.10);left_hand.add_child(watering_can)
	kit.cylinder(watering_can,Vector3.ZERO,0.08,0.13,ArtKit.BLUE);kit.beam(watering_can,Vector3(0,0.03,0),Vector3(0,0.06,0.18),0.035,ArtKit.BLUE)
	for i in range(4):water_drops.append(kit.sphere(watering_can,Vector3(0,-0.1,0.18),Vector3.ONE*0.02,Color("87c6cb")))
	watering_can.visible=false
	var hand=BoneAttachment3D.new();hand.name="RightHandSocket";skeleton.add_child(hand);hand.bone_name="ArmRight"
	suitcase=ArtExtras.create("PROP_012",0);suitcase.position=Vector3(0,-0.62,0.02);hand.add_child(suitcase);suitcase.visible=false
	var seat=BoneAttachment3D.new();seat.name="SeatSocket";seat.bone_name="Pelvis";skeleton.add_child(seat)
	cup=kit.cylinder(hand,Vector3(0,-0.24,0.06),0.055,0.10,ArtKit.CREAM);cup.visible=false
func build_headwear(index:int) -> void:
	var blue=ArtKit.BLUE;var cream=Color("d8bd79")
	var crown=SphereMesh.new();crown.radius=0.5;crown.height=1;crown.radial_segments=10;crown.rings=3
	if index==2:
		box(Vector3(0,0.13,0.02),Vector3(0.42,0.045,0.37),ArtKit.CREAM,2)
		box(Vector3(0.23,0.13,-0.02),Vector3(0.08,0.07,0.1),ArtKit.CREAM,2)
	else:
		part(crown,Vector3(0,0.20,-0.02),Vector3(0.42,0.18,0.4),cream if index==1 else blue,2)
		var brim=CylinderMesh.new();brim.bottom_radius=0.31 if index==1 else 0.22;brim.top_radius=brim.bottom_radius;brim.height=0.035;brim.radial_segments=12;brim.rings=0
		part(brim,Vector3(0,0.15,0.01),Vector3(1,1,0.85),cream if index==1 else blue,2)
		if index==3:box(Vector3(0,0.17,0.17),Vector3(0.35,0.045,0.13),blue,2)
func build_wardrobe(index:int,_cloth:Color) -> void:
	base_body_mesh=geometry
	var previous=builders
	for item in ["cloak","overalls","apron","scarf","sweater"]:
		builders={}
		match item:
			"cloak":
				var cape=CylinderMesh.new();cape.top_radius=0.15;cape.bottom_radius=0.30;cape.height=0.46;cape.radial_segments=10;cape.rings=0
				part(cape,Vector3(0,-0.03,0),Vector3(1,1,0.82),Color("d3b461"),1)
				box(Vector3(0,0.15,0.16),Vector3(0.045,0.045,0.025),ArtKit.WOOD,1)
			"overalls":
				box(Vector3(0,-0.05,0.17),Vector3(0.30,0.30,0.035),ArtKit.GREEN,1)
				for side in [-1,1]:
					box(Vector3(side*0.1,0.12,0.17),Vector3(0.045,0.18,0.035),ArtKit.GREEN,1)
					box(Vector3(0,-0.09,0.01),Vector3(0.13,0.18,0.16),ArtKit.GREEN,5 if side<0 else 6)
			"apron":
				box(Vector3(0,-0.05,0.17),Vector3(0.32,0.39,0.035),ArtKit.CORAL,1)
				box(Vector3(0,-0.12,0.195),Vector3(0.18,0.09,0.02),ArtKit.CORAL.lightened(0.15),1)
			"scarf":
				box(Vector3(0,0.15,0.02),Vector3(0.40,0.06,0.30),ArtKit.BLUE,1);box(Vector3(0.1,0.03,0.18),Vector3(0.07,0.22,0.03),ArtKit.BLUE,1)
			"sweater":
				box(Vector3.ZERO,Vector3(0.42,0.39,0.32),ArtKit.BLUE,1)
				for id in [3,4]:box(Vector3(0,-0.11,0),Vector3(0.15,0.25,0.18),ArtKit.BLUE,id)
		var mesh=ArrayMesh.new()
		for st in builders.values():st.commit(mesh)
		wearables[item]=mesh;wardrobe_enabled[item]=item in [["cloak"],["overalls"],["apron","scarf"],["sweater"]][index%4]
	builders=previous;rebuild_wardrobe()
func set_wearable(id:String,enabled:bool) -> void:
	assert(wearables.has(id));wardrobe_enabled[id]=enabled;rebuild_wardrobe()
func rebuild_wardrobe() -> void:
	var meshes:Array=[base_body_mesh]
	for id in wearables:
		if wardrobe_enabled[id]:meshes.append(wearables[id])
	var groups:Dictionary={}
	for mesh in meshes:
		for surface in range(mesh.get_surface_count()):
			var material=mesh.surface_get_material(surface);var key=material.get_instance_id()
			if not groups.has(key):
				var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);st.set_material(material);groups[key]=st
			groups[key].append_from(mesh,surface,Transform3D.IDENTITY)
	var combined=ArrayMesh.new()
	for st in groups.values():st.commit(combined)
	body.mesh=combined
func finish_body() -> void:
	for st in builders.values():st.commit(geometry)
	var skin=Skin.new()
	for i in range(skeleton.get_bone_count()):skin.add_bind(i,Transform3D(Basis.IDENTITY,rests[i]).affine_inverse())
	body.name="SkinnedBody";body.mesh=geometry;body.skin=skin;body.skeleton=NodePath("../Skeleton3D");add_child(body)
func animate(state:String,walking:bool,time:float) -> void:
	var old:Array=[]
	for i in range(BONES.size()):old.append(skeleton.get_bone_pose_rotation(i));skeleton.reset_bone_pose(i)
	cup.visible=state=="tea"
	suitcase.visible=state=="arriving"
	watering_can.visible=state=="greenhouse"
	for i in range(water_drops.size()):water_drops[i].position=Vector3(0,-fposmod(time*0.25+i*0.08,0.28),0.18)
	var delta=0.0 if last_time<0 else maxf(0.0,time-last_time)
	if last_state!=state:
		entering_sit=state in ["bench","tea"] and not last_state in ["bench","tea"]
		leaving_sit=last_state in ["bench","tea"] and not state in ["bench","tea"]
		state_age=0.0
	else:state_age+=delta
	var clip="dragcase" if walking and state=="arriving" else "walk" if walking else "drink" if state=="tea" else "sit_idle" if state=="bench" else "water" if state=="greenhouse" else "admire" if state=="garden" else "wave" if fposmod(time,14)<2.0 else "idle"
	if entering_sit and state_age<0.4:clip="sit_down"
	if leaving_sit and state_age<0.4 and not walking:clip="stand_up"
	var animation=MotionLibrary.library().get_animation(clip)
	var pose=MotionLibrary.sample(animation,state_age if clip in ["sit_down","stand_up"] else fposmod(time,14.0) if clip=="wave" else time)
	for path in pose:
		var bone_id=skeleton.find_bone(String(path).get_slice(":",1))
		if bone_id>=0:skeleton.set_bone_pose_rotation(bone_id,pose[path])
	last_state=state

	var blend=1.0 if last_time<0 else 1.0-exp(-maxf(0.0,time-last_time)*12.0)
	for i in range(BONES.size()):skeleton.set_bone_pose_rotation(i,old[i].slerp(skeleton.get_bone_pose_rotation(i),blend))
	last_time=time
