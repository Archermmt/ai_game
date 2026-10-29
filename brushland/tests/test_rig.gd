extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	for variant in range(4):
		var rig=ResidentRig.create(variant);root.add_child(rig)
		assert(rig.skeleton.get_bone_count()==9 and rig.body.skin.get_bind_count()==9)
		var arrays=rig.body.mesh.surface_get_arrays(0)
		assert(arrays[Mesh.ARRAY_BONES].size()>0 and arrays[Mesh.ARRAY_WEIGHTS].size()>0)
		rig.animate("walking",true,0.7);assert(not rig.skeleton.get_bone_pose_rotation(5).is_equal_approx(Quaternion.IDENTITY))
		rig.animate("tea",false,1.3);assert(rig.cup.visible)
		assert(absf(rig.skeleton.get_bone_pose_rotation(5).get_euler().x+PI/2)<0.02)
		var pose=rig.skeleton.get_bone_pose_rotation(4);rig.animate("tea",false,1.3);assert(rig.skeleton.get_bone_pose_rotation(4).is_equal_approx(pose))
		rig.animate("bench",false,1.8);assert(not rig.cup.visible)
		rig.free()
	print("PASS four shared skinned rigs, walking, sitting and cup visibility")
	quit()
