extends Node3D

func _ready() -> void:
	for desc in [
		["WestHouse",Vector3(-8.2,1.12,5.25),Vector3(3.7,2.24,2.3)],
		["MiddleHouse",Vector3(-3.95,1.35,6.38),Vector3(2.5,2.7,2.0)],
		["EastHouse",Vector3(.66,.92,6.55),Vector3(2.15,1.84,1.8)],
		["Platform",Vector3(-2.6,.63,-4.2),Vector3(11.2,1.26,2.55)],
		["Rails",Vector3(0,.10,-1.15),Vector3(21,.2,1.6)],
		["Car",Vector3(7.1,1.25,-1.15),Vector3(5.5,2.5,1.65)],
		["SakuraCanopy",Vector3(2.4,3.65,4.35),Vector3(4.45,4.05,3.5)]]:
		var node := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = desc[2]
		node.name = desc[0]
		node.mesh = mesh
		node.position = desc[1]
		add_child(node)
