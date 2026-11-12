class_name LanternController
extends Node3D
## Lanterns and light falling through woodland windows share four local lights.

const LIGHT_LIMIT: int = 4
var lights: Dictionary = {}
var active_ids: Array[String] = []
var active_window_count: int = 0
var _lamps: Array = []
var _poses: Dictionary = {}
var _views: Dictionary = {}
var _panes: Dictionary = {}
var _window_positions: Array[Vector3] = []
var _window_lights: Array[OmniLight3D] = []
var _woodland: bool = false
var _window_order_camera: Vector3 = Vector3.INF


func configure(snapshot: Dictionary, poses: Dictionary, views: Dictionary) -> void:
	_lamps = snapshot["instances"].filter(
		func(item: Dictionary) -> bool: return item["asset_id"] == "PROP-08"
	)
	_poses = poses
	_views = views
	_panes.clear()
	for item: Dictionary in _lamps:
		var view: Node3D = views.get(item["id"])
		_panes[item["id"]] = (
			view.find_children("lamp_emission*", "MeshInstance3D", true, false)
			if view != null
			else []
		)
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
		lights[item["id"]].light_energy = strength * (1.05 if _woodland else 0.65)
		for node: Node in _panes.get(item["id"], []):
			node.material_override.emission_energy_multiplier = strength * 1.1
	lit.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			var da: float = lights[a["id"]].position.distance_squared_to(camera_position)
			var db: float = lights[b["id"]].position.distance_squared_to(camera_position)
			return a["id"] < b["id"] if is_equal_approx(da, db) else da < db
	)
	for item: Dictionary in lit.slice(0, LIGHT_LIMIT):
		lights[item["id"]].visible = true
		active_ids.append(item["id"])
	_window_wash(camera_position, dusk_mix)


func configure_woodland(snapshot: Dictionary) -> void:
	_woodland = true
	_window_positions.clear()
	_window_order_camera = Vector3.INF
	for lantern: OmniLight3D in lights.values():
		lantern.omni_range = 3.6
		lantern.light_color = Color("ffd29d")
	for home: Dictionary in snapshot["buildings"]:
		var origin: Vector3 = Vector3(home["position"][0], home["position"][1], home["position"][2])
		var width: float = home["size"][0]
		var depth: float = home["size"][2]
		var round_wall: bool = home["shape"] == "round"
		for opening: Dictionary in home["openings"]:
			var height: float = opening["height"]
			var glass_door: bool = height >= 1.8 and opening.get("variant") == "glass"
			if height >= 1.8 and not glass_door:
				continue
			var facade: int = int(opening.get("facade", 0))
			var length: float = DoorRules._length(home, facade)
			var u: float = opening["center"] * length
			var p: Vector3 = BuildingGeometry._point(u, facade, width, depth, round_wall)
			var n: Vector3 = BuildingGeometry._normal(u, facade, width, depth, round_wall)
			p.y = float(opening.get("sill", 0)) + height * (0.70 if glass_door else 0.34)
			_window_positions.append(origin + p + n * 0.26)
	while _window_lights.size() < mini(LIGHT_LIMIT, _window_positions.size()):
		var light: OmniLight3D = OmniLight3D.new()
		light.light_color = Color("ffc68d")
		light.omni_range = 2.35
		light.omni_attenuation = 1.5
		light.shadow_enabled = false
		light.visible = false
		add_child(light)
		_window_lights.append(light)


func _window_wash(camera_position: Vector3, dusk_mix: float) -> void:
	active_window_count = 0
	# The player's working lanterns keep their four-light priority. Only nearby
	# lit glass uses the spare slots, so editing an opaque door adds no source.
	if dusk_mix > 0.001 and active_ids.size() < LIGHT_LIMIT:
		if _window_order_camera != camera_position:
			_window_positions.sort_custom(
				func(a: Vector3, b: Vector3) -> bool:
					var da: float = camera_position.distance_squared_to(a)
					var db: float = camera_position.distance_squared_to(b)
					return a < b if da == db else da < db
			)
			_window_order_camera = camera_position
		active_window_count = mini(_window_positions.size(), LIGHT_LIMIT - active_ids.size())
		for i: int in active_window_count:
			_window_lights[i].position = _window_positions[i]
			_window_lights[i].light_energy = dusk_mix * 0.28
	for i: int in _window_lights.size():
		_window_lights[i].visible = i < active_window_count


static func strength_for(mode: String, dusk_mix: float) -> float:
	return 1.0 if mode == "on" else (0.0 if mode == "off" else dusk_mix)
