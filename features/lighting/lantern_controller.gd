class_name LanternController
extends Node3D
## Actual lantern model panes and nearest four lights share the source mode.

var lights: Dictionary = {}
var active_ids: Array[String] = []
var _lamps: Array = []
var _poses: Dictionary = {}
var _views: Dictionary = {}


func configure(snapshot: Dictionary, poses: Dictionary, views: Dictionary) -> void:
	_lamps = snapshot["instances"].filter(
		func(item: Dictionary) -> bool: return item["asset_id"] == "PROP-08"
	)
	_poses = poses
	_views = views
	var alive: Dictionary = {}
	for item: Dictionary in _lamps:
		alive[item["id"]] = true
		if not lights.has(item["id"]):
			var light: OmniLight3D = OmniLight3D.new()
			light.light_color = Color("f2c878")
			light.omni_range = 3
			light.shadow_enabled = false
			add_child(light)
			lights[item["id"]] = light
		lights[item["id"]].position = _poses[item["id"]] * Vector3(0, 0.28, 0)
	for key: String in lights.keys():
		if not alive.has(key):
			lights[key].free()
			lights.erase(key)


func advance(camera_position: Vector3, dusk_mix: float) -> void:
	var lit: Array = []
	active_ids.clear()
	for item: Dictionary in _lamps:
		var strength: float = strength_for(item.get("lamp_mode", "auto"), dusk_mix)
		lights[item["id"]].visible = false
		if strength > 0.001:
			lit.append(item)
		lights[item["id"]].light_energy = strength * 0.65
		var view: Node3D = _views.get(item["id"])
		if view != null:
			for node: Node in view.find_children("lamp_emission*", "MeshInstance3D", true, false):
				node.material_override.emission_energy_multiplier = strength * 1.1
	lit.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			var da: float = lights[a["id"]].position.distance_squared_to(camera_position)
			var db: float = lights[b["id"]].position.distance_squared_to(camera_position)
			return a["id"] < b["id"] if is_equal_approx(da, db) else da < db
	)
	for item: Dictionary in lit.slice(0, 4):
		lights[item["id"]].visible = true
		active_ids.append(item["id"])


static func strength_for(mode: String, dusk_mix: float) -> float:
	return 1.0 if mode == "on" else (0.0 if mode == "off" else dusk_mix)
