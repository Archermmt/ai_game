class_name LightRig
extends Node3D
## Model-independent lamp adapter: at most four nearby local lights, all emissive.

var views: Dictionary = {}
var active_ids: Array[String] = []


func sync(probes: Array, camera_position: Vector3, mix_value: float) -> void:
	var alive: Dictionary = {}
	var ordered: Array = probes.duplicate(true)
	ordered.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			var da: float = _point(a).distance_squared_to(camera_position)
			var db: float = _point(b).distance_squared_to(camera_position)
			return a["id"] < b["id"] if is_equal_approx(da, db) else da < db
	)
	active_ids.clear()
	for index: int in range(ordered.size()):
		var probe: Dictionary = ordered[index]
		var key: String = probe["id"]
		alive[key] = true
		if not views.has(key):
			var root: Node3D = Node3D.new()
			var mesh: MeshInstance3D = MeshInstance3D.new()
			var sphere: SphereMesh = SphereMesh.new()
			sphere.radius = 0.07
			sphere.height = 0.18
			mesh.mesh = sphere
			var paint: StandardMaterial3D = StandardMaterial3D.new()
			paint.albedo_color = Color("9c7750")
			paint.emission_enabled = true
			paint.emission = Color("ffbd6b")
			mesh.material_override = paint
			root.add_child(mesh)
			var light: OmniLight3D = OmniLight3D.new()
			light.light_color = Color("ffd49b")
			light.omni_range = 3.0
			light.shadow_enabled = false
			root.add_child(light)
			add_child(root)
			views[key] = root
		var root: Node3D = views[key]
		root.position = _point(probe)
		root.get_child(0).material_override.emission_energy_multiplier = mix_value * 1.1
		var light: OmniLight3D = root.get_child(1)
		light.visible = index < 4 and mix_value > 0.001
		light.light_energy = mix_value * 0.65
		if light.visible:
			active_ids.append(key)
	for key: String in views.keys():
		if not alive.has(key):
			views[key].free()
			views.erase(key)


static func _point(probe: Dictionary) -> Vector3:
	return Vector3(probe["position"][0], probe["position"][1], probe["position"][2])
