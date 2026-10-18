class_name WeekSixTools
extends WeekFourTools

var category: String = "plants"
var radius: float = 2.5
var densities: Dictionary = {"trees": 0.45, "plants": 0.65, "rocks": 0.35}
var changed_count: int = 0


func begin(point: Vector3, additive: bool = false) -> bool:
	changed_count = 0
	return super.begin(point, additive)


func update(point: Vector3) -> void:
	if mode not in ["plant_brush", "plant_erase"]:
		super.update(point)
		return
	if session.phase != EditSession.Phase.PREVIEW:
		return
	var draft: Dictionary = session.preview.duplicate(true)
	changed_count += VegetationBrush.paint(
		draft,
		Vector2(point.x, point.z),
		category,
		radius,
		densities[category],
		_visited,
		mode == "plant_erase"
	)
	session.update_gesture(draft)
