class_name AssetRegistry
extends RefCounted
## Stable asset IDs, explicit inherited wrappers and source-authoritative picking.

const WRAPPERS: Dictionary = {
	"NAT-01": preload("res://features/assets/wrappers/nat_01.tscn"),
	"NAT-02": preload("res://features/assets/wrappers/nat_02.tscn"),
	"NAT-03": preload("res://features/assets/wrappers/nat_03.tscn"),
	"NAT-04": preload("res://features/assets/wrappers/nat_04.tscn"),
	"NAT-05": preload("res://features/assets/wrappers/nat_05.tscn"),
	"NAT-06": preload("res://features/assets/wrappers/nat_06.tscn"),
	"NAT-07": preload("res://features/assets/wrappers/nat_07.tscn"),
	"NAT-08": preload("res://features/assets/wrappers/nat_08.tscn"),
	"NAT-09": preload("res://features/assets/wrappers/nat_09.tscn"),
	"PROP-01": preload("res://features/assets/wrappers/prop_01.tscn"),
	"PROP-02": preload("res://features/assets/wrappers/prop_02.tscn"),
	"PROP-03": preload("res://features/assets/wrappers/prop_03.tscn"),
	"PROP-04": preload("res://features/assets/wrappers/prop_04.tscn"),
	"PROP-05": preload("res://features/assets/wrappers/prop_05.tscn"),
	"PROP-06": preload("res://features/assets/wrappers/prop_06.tscn"),
	"PROP-07": preload("res://features/assets/wrappers/prop_07.tscn"),
	"PROP-08": preload("res://features/assets/wrappers/prop_08.tscn"),
}
const LABELS: Dictionary = {
	"NAT-01": "阔叶树",
	"NAT-02": "针叶树",
	"NAT-03": "果树",
	"NAT-04": "林下蕨",
	"NAT-05": "野花",
	"NAT-06": "矮灌木",
	"NAT-07": "绿篱",
	"NAT-08": "苔石",
	"NAT-09": "扁石",
	"PROP-01": "长凳",
	"PROP-02": "信箱",
	"PROP-03": "盆栽",
	"PROP-04": "晾衣架",
	"PROP-05": "木箱",
	"PROP-06": "浇水壶",
	"PROP-07": "茶具",
	"PROP-08": "提灯"
}


static func dimensions(asset_id: String) -> Vector3:
	return AssetFootprints.dimensions(asset_id)


static func create(
	item: Dictionary, snapshot: Dictionary, wood: Material, stone: Material
) -> Node3D:
	if not WRAPPERS.has(item["asset_id"]):
		return WeekSixCatalog.create(item["asset_id"], item["id"], wood, stone)
	var wrapper: GardenAssetWrapper = WRAPPERS[item["asset_id"]].instantiate()
	wrapper.configure(item, snapshot, wood, stone)
	return wrapper


static func pick(snapshot: Dictionary, point: Vector2) -> String:
	var selected: String = ""
	var best: float = INF
	for item: Dictionary in snapshot["instances"]:
		var center: Vector2 = Vector2(item["position"][0], item["position"][2])
		var distance_value: float = point.distance_to(center)
		var hit: bool = false
		if item.has("hedge"):
			distance_value = HedgeRules.distance(item, point)
			hit = distance_value < item["hedge"]["width"] * item["scale"] * 0.5 + 0.25
		else:
			var local: Vector3 = (
				Basis(Vector3.UP, -item["yaw"]) * Vector3(point.x - center.x, 0, point.y - center.y)
			)
			var size: Vector3 = dimensions(item["asset_id"]) * item["scale"]
			hit = absf(local.x) <= size.x * 0.5 + 0.2 and absf(local.z) <= size.z * 0.5 + 0.2
		if hit and distance_value < best:
			selected = item["id"]
			best = distance_value
	return selected
