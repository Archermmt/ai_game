class_name GrassWalkerContact
extends RefCounted
## A bounded presentation trail. It never owns or edits terrain/plant source state.

const MAX_CONTACTS: int = 4
const SAMPLE_SPACING: float = 0.3
const RETURN_SECONDS: float = 1.0
const TELEPORT_DISTANCE: float = 2.5
const RADIUS: float = 1.15

var _points: Array[Vector3] = []
var _ages: Array[float] = []
var _feet: Vector3 = Vector3.ZERO
var _anchor: Vector3 = Vector3.ZERO
var _active: bool = false
var _frozen: bool = false


func set_contact(feet: Vector3, active: bool, frozen: bool = false) -> void:
	_frozen = frozen
	_active = active and feet.is_finite()
	if _active:
		_feet = feet


func advance(delta: float, reduced_motion: bool = false, frozen: bool = false) -> void:
	if not is_finite(delta) or delta < 0:
		return
	# An active frozen walk retains its composition. Returning to the photo
	# camera must still release the departed walker, even if photo time stays held.
	if _active and (_frozen or frozen):
		return
	if reduced_motion:
		clear()
		return
	for index: int in range(_ages.size() - 1, -1, -1):
		_ages[index] += delta
		if _ages[index] >= RETURN_SECONDS:
			_ages.remove_at(index)
			_points.remove_at(index)
	if not _active:
		return
	if not _points.is_empty() and _feet.distance_to(_anchor) > TELEPORT_DISTANCE:
		clear()
	if _points.is_empty() or _feet.distance_to(_anchor) >= SAMPLE_SPACING:
		_points.push_front(_feet)
		_ages.push_front(0.0)
		_anchor = _feet
		if _points.size() > MAX_CONTACTS:
			_points.pop_back()
			_ages.pop_back()
	else:
		_points[0] = _feet
		_ages[0] = 0.0


func clear() -> void:
	_points.clear()
	_ages.clear()
	_anchor = _feet


func samples() -> PackedVector4Array:
	var result: PackedVector4Array = PackedVector4Array()
	result.resize(MAX_CONTACTS)
	for index: int in _points.size():
		var point: Vector3 = _points[index]
		var strength: float = pow(1.0 - clampf(_ages[index] / RETURN_SECONDS, 0, 1), 2)
		result[index] = Vector4(point.x, point.y, point.z, strength)
	return result
