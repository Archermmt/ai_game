class_name WeekFourTools
extends WorldTools


func update(point: Vector3) -> void:
	if mode not in ["raise", "lower", "smooth", "restore"]:
		super.update(point)
		return
	if session.phase != EditSession.Phase.PREVIEW:
		return
	var location: Vector2 = Vector2(point.x, point.z)
	var cell: Vector2i = Vector2i((location / 0.75).floor())
	if cell == _last_cell:
		return
	_last_cell = cell
	session.update_gesture(TerrainEdits.stroke(session.preview, location, mode))
