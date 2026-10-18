class_name FoundationGeometry
extends RefCounted
## Terrain-fitted skirt, short corner supports and door-safe timber edging.


static func build(spec: Dictionary, field: TerrainField) -> Dictionary:
	var stone: BuildingGeometry = BuildingGeometry.new()
	var wood: BuildingGeometry = BuildingGeometry.new()
	var points: Array = SupportGeometry.perimeter(spec, field)
	var floor_y: float = spec["position"][1]
	for index: int in range(points.size()):
		var a: Array = points[index]
		var b: Array = points[(index + 1) % points.size()]
		var pa: Vector3 = Vector3(a[0], a[1], a[2])
		var pb: Vector3 = Vector3(b[0], b[1], b[2])
		var qa: Vector3 = Vector3(a[0], floor_y, a[2])
		var qb: Vector3 = Vector3(b[0], floor_y, b[2])
		stone._quad(
			pa, pb, qb, qa, (qb - qa).cross(Vector3.UP).normalized(), BuildingGeometry.STONE
		)
		var center: Vector2 = Vector2((qa.x + qb.x) * 0.5, (qa.z + qb.z) * 0.5)
		if not TerrainEdits.entrance_protected({"buildings": [spec]}, center):
			var along: Vector3 = qb - qa
			var n: Vector3 = along.cross(Vector3.UP).normalized() * 0.045
			wood._quad(
				qa + n,
				qb + n,
				qb + n + Vector3.UP * KitProfiles.TRIM_HEIGHT,
				qa + n + Vector3.UP * KitProfiles.TRIM_HEIGHT,
				n.normalized(),
				Color("8a6440")
			)
	if spec["shape"] == "rect":
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var p: Vector2 = Vector2(
					spec["position"][0] + sx * (float(spec["size"][0]) * 0.5 - 0.1),
					spec["position"][2] + sz * (float(spec["size"][2]) * 0.5 - 0.1)
				)
				var bottom: float = field.height_at(p)
				if floor_y - bottom > 0.18:
					MeshParts.box(
						wood,
						Vector3(p.x, (bottom + floor_y) * 0.5, p.y),
						Vector3(0.16, floor_y - bottom, 0.16),
						Color("8a6440")
					)
	return {"stone_arrays": MeshParts.arrays(stone), "wood_arrays": MeshParts.arrays(wood)}
