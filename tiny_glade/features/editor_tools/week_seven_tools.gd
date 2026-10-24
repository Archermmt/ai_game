class_name WeekSevenTools
extends WeekSixTools


func pick(point: Vector3) -> String:
	return AssetRegistry.pick(session.document.state, Vector2(point.x, point.z))
