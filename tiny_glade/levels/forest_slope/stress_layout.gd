class_name StressLayout
extends RefCounted
## Fixed capacity fixture. Generated resources are never serialized into the source.


static func create(density: float = 1.0) -> Dictionary:
	var source: Dictionary = ForestTemplate.empty()
	source["instances"].clear()
	for z: int in range(4):
		for x: int in range(6):
			WorldDocument.allocate_building(
				source,
				Vector3(-19 + x * 7, 0.2, -18 + z * 8),
				Vector3(3, 2.4, 3),
				"round" if x % 2 else "rect"
			)
	source = PondShape.draw(source, [[-5, 14], [5, 14], [5, 18], [-5, 18]])
	GardenStructures.allocate(source, "bridge", Vector2(-2, 13.5), Vector2(-2, 18.5))
	GardenStructures.allocate(source, "bridge", Vector2(2, 13.5), Vector2(2, 18.5))
	var points: Array[Vector2] = []
	for z: int in range(-46, 47):
		for x: int in range(-46, 47):
			var p: Vector2 = Vector2(x, z) * 0.5
			if VegetationBrush.geometry_clear(source, p):
				points.append(p)
	# A fixed seed permutes legal candidates without altering global RNG state.
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 902024
	for i: int in range(points.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var p: Vector2 = points[i]
		points[i] = points[j]
		points[j] = p
	var counts: Array[int] = [roundi(80 * density), roundi(800 * density), roundi(120 * density)]
	var cursor: int = 0
	for group: int in range(3):
		for i: int in range(counts[group]):
			var p: Vector2 = points[cursor]
			cursor += 1
			var item: Dictionary = InstanceEdits.allocate(source, Vector3(p.x, 0, p.y), group == 2)
			item["asset_id"] = (
				("NAT-%02d" % (1 + i % 3) if group == 0 else "NAT-%02d" % (4 + i % 6))
				if group < 2
				else "PROP-%02d" % (1 + i % 8)
			)
			item["yaw"] = rng.randf_range(0, TAU)
			item["scale"] = 0.8
			if group < 2:
				item["category"] = "trees" if group == 0 else ("rocks" if i % 6 >= 4 else "plants")
	return source
