class_name HeightDeltaIndex
extends RefCounted
## Worker-local, read-only queries over one immutable snapshot's height entries.

const BUCKET_SIZE: float = 8.0

var _entries: Array
var _points: PackedVector2Array = PackedVector2Array()
var _buckets: Dictionary = {}
var _low: Vector2
var _high: Vector2


func _init(snapshot: Dictionary) -> void:
	_entries = snapshot["terrain"]["height_deltas"]
	var spacing: float = float(snapshot["terrain"].get("spacing", 0.5))
	for ordinal: int in range(_entries.size()):
		var entry: Array = _entries[ordinal]
		var point: Vector2 = Vector2(entry[0], entry[1]) * spacing - Vector2.ONE * 32
		_points.append(point)
		_low = point if ordinal == 0 else _low.min(point)
		_high = point if ordinal == 0 else _high.max(point)
		var bucket: Vector2i = Vector2i((point / BUCKET_SIZE).floor())
		if not _buckets.has(bucket):
			_buckets[bucket] = []
		_buckets[bucket].append(ordinal)


func entries_within(region: Rect2) -> Array:
	if _entries.is_empty():
		return []
	var low: Vector2 = region.position
	var high: Vector2 = region.end
	# Clamp before integer conversion: even huge queries visit only occupied bounds.
	var query_low: Vector2 = low.max(_low)
	var query_high: Vector2 = high.min(_high)
	if query_low.x > query_high.x or query_low.y > query_high.y:
		return []
	var first: Vector2i = Vector2i((query_low / BUCKET_SIZE).floor())
	var last: Vector2i = Vector2i((query_high / BUCKET_SIZE).floor())
	var ordinals: Array[int] = []
	for z: int in range(first.y, last.y + 1):
		for x: int in range(first.x, last.x + 1):
			for ordinal: int in _buckets.get(Vector2i(x, z), []):
				var point: Vector2 = _points[ordinal]
				if (
					point.x >= low.x
					and point.y >= low.y
					and point.x <= high.x
					and point.y <= high.y
				):
					ordinals.append(ordinal)
	# Bucket order differs from source order; exact signatures retain source order.
	ordinals.sort()
	var result: Array = []
	for ordinal: int in ordinals:
		result.append(_entries[ordinal])
	return result
