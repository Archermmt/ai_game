class_name ArtScenery
extends RefCounted
## Derived ENV-02 tree curtain and pond-bank details. Editable core objects stay in source.


static func curtain_placements(source: Dictionary) -> Array[Dictionary]:
	# Derived ENV trees never occupy the editable 48 m square. Place the grove
	# centres against a square envelope first, then retain their loose offsets.
	# The 35.8 m inner centre minus the largest 5.6 m offset leaves >6 m for
	# a scaled crown outside the editable boundary, including at square corners.
	var result: Array[Dictionary] = []
	var field: TerrainField = TerrainField.new(source)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = (str(source["world_seed"]) + ":forest-curtain").hash()
	for asset: String in ["NAT-01", "NAT-02"]:
		for sector: int in range(16):
			var angle: float = TAU * (float(sector) + 0.35) / 16
			var direction: Vector2 = Vector2(sin(angle), cos(angle))
			var center_axis: float = 35.8 + float(sector % 3) * 2.2
			var center: Vector2 = (
				direction * center_axis / maxf(absf(direction.x), absf(direction.y))
			)
			for member: int in range(5 if asset == "NAT-01" else 3):
				var offset_angle: float = float(member) * 2.4 + float(sector) * 0.83
				var offset: Vector2 = Vector2(sin(offset_angle), cos(offset_angle))
				offset *= 1.6 + float(member % 3) * 1.7
				var p: Vector2 = center + offset
				if asset == "NAT-02":
					p += center.normalized() * 4.0
				p += Vector2(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.6, 0.6))
				var y: float = -0.21 if maxf(absf(p.x), absf(p.y)) > 32.0 else field.height_at(p)
				var key: String = "forest:%s:%d:%d" % [asset, sector, member]
				result.append(
					{
						"id": key,
						"asset_id": asset,
						"position": [p.x, y, p.y],
						"seed": key.sha256_text(),
						"scale": rng.randf_range(1.35, 2.15),
						"yaw": rng.randf_range(0, TAU)
					}
				)
	return result


static func curtain(
	source: Dictionary, wood: Material, stone: Material, terrain: Material
) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "ForestCurtain"
	var floor_builder: BuildingGeometry = BuildingGeometry.new()
	var field: TerrainField = TerrainField.new(source)
	for rect: Rect2 in [
		Rect2(-192, -192, 384, 160),
		Rect2(-192, 32, 384, 160),
		Rect2(-192, -32, 160, 64),
		Rect2(32, -32, 160, 64)
	]:
		var p: Vector2 = rect.position
		var e: Vector2 = rect.end
		floor_builder._quad(
			Vector3(p.x, -0.21, p.y),
			Vector3(p.x, -0.21, e.y),
			Vector3(e.x, -0.21, e.y),
			Vector3(e.x, -0.21, p.y),
			Vector3.UP,
			Color(0, 0, 0, 1)
		)
	# Close the heightfield/apron seam, including the field's half-metre edge
	# samples. A small height difference must not expose a line of sky at dusk.
	var corners: Array[Vector2] = [
		Vector2(-32, -32), Vector2(32, -32), Vector2(32, 32), Vector2(-32, 32)
	]
	for edge: int in range(4):
		var a: Vector2 = corners[edge]
		var b: Vector2 = corners[(edge + 1) % 4]
		for index: int in range(128):
			var p: Vector2 = a.lerp(b, float(index) / 128)
			var q: Vector2 = a.lerp(b, float(index + 1) / 128)
			var normal: Vector2 = (b - a).orthogonal().normalized()
			floor_builder._quad(
				Vector3(p.x, field.height_at(p), p.y),
				Vector3(q.x, field.height_at(q), q.y),
				Vector3(q.x, -0.21, q.y),
				Vector3(p.x, -0.21, p.y),
				Vector3(normal.x, 0, normal.y),
				Color(0, 0, 0, 1)
			)
			floor_builder._quad(
				Vector3(p.x, -0.21, p.y),
				Vector3(q.x, -0.21, q.y),
				Vector3(q.x, field.height_at(q), q.y),
				Vector3(p.x, field.height_at(p), p.y),
				Vector3(-normal.x, 0, -normal.y),
				Color(0, 0, 0, 1)
			)
	var floor_view: MeshInstance3D = MeshInstance3D.new()
	floor_view.mesh = BuildingGeometry.mesh_from_arrays(MeshParts.arrays(floor_builder))
	floor_view.material_override = terrain
	root.add_child(floor_view)
	var placements: Array[Dictionary] = curtain_placements(source)
	for asset: String in ["NAT-01", "NAT-02"]:
		var items: Array = []
		var poses: Dictionary = {}
		for item: Dictionary in placements:
			if item["asset_id"] != asset:
				continue
			items.append(item)
			var p: Array = item["position"]
			poses[item["id"]] = Transform3D(
				Basis(Vector3.UP, item["yaw"]).scaled(Vector3.ONE * float(item["scale"])),
				Vector3(p[0], p[1], p[2])
			)
		var parts: Array[Dictionary] = ArtViewPlan.describe(asset, wood, stone)
		var cells: Dictionary = {}
		for item: Dictionary in items:
			var p: Array = item["position"]
			var cell: Vector2i = Vector2i(floori(p[0] / 12), floori(p[2] / 12))
			if not cells.has(cell):
				cells[cell] = []
			cells[cell].append(item)
		# Visibility ranges apply to a batch, not to individual instances. Keep
		# nearby groves detailed instead of forcing the entire curtain to LOD1.
		for cell: Vector2i in cells:
			root.add_child(ArtViewPlan.build_batch(cells[cell], poses, wood, stone, parts))
	return root


static func bank_signature(source: Dictionary) -> int:
	# Bank positions are at most 0.48 + 0.60 m outside the contour.
	# field_key adds two grid cells for bilinear interpolation, including edges.
	if source["pool"].is_empty():
		return hash([])
	var contour: PackedVector2Array = PondShape.contour(source["pool"])
	var region: Rect2 = Rect2(contour[0], Vector2.ZERO)
	for point: Vector2 in contour:
		region = region.expand(point)
	return hash(
		[
			source["world_seed"],
			source["pool"],
			source.get("bridges", []),
			DirtyGraph.field_key(source, region.grow(1.1))
		]
	)


static func bank(source: Dictionary, wood: Material, stone: Material) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "LivingPondBank"
	if source["pool"].is_empty():
		return root
	var contour: PackedVector2Array = PondShape.contour(source["pool"])
	var field: TerrainField = TerrainField.new(source)
	var groups: Dictionary = {"NAT-08": [], "NAT-09": [], "NAT-04": [], "NAT-06": []}
	var poses: Dictionary = {}
	for edge: int in range(contour.size()):
		var a: Vector2 = contour[edge]
		var b: Vector2 = contour[(edge + 1) % contour.size()]
		var count_value: int = maxi(1, ceili(a.distance_to(b) / 0.72))
		for i: int in range(count_value):
			var key: String = "bank:%d:%d" % [edge, i]
			var rng: RandomNumberGenerator = RandomNumberGenerator.new()
			rng.seed = (str(source["world_seed"]) + key).hash()
			# Broken rock groups leave grass/water transitions visible.
			if posmod(edge * 5 + i, 9) in [2, 3, 6]:
				continue
			var t: float = (float(i) + rng.randf_range(0.25, 0.75)) / count_value
			var p: Vector2 = a.lerp(b, t)
			var direction: Vector2 = (b - a).orthogonal().normalized()
			if PondShape.distance(source["pool"], p + direction * 0.4) < 0:
				direction = -direction
			p += direction * rng.randf_range(0.18, 0.48)
			if not _bridge_clear(source, p):
				continue
			var asset: String = "NAT-09" if i % 3 == 0 else "NAT-08"
			var scale_value: float = rng.randf_range(0.4, 0.76)
			groups[asset].append(
				{"id": key, "asset_id": asset, "position": [p.x, 0, p.y], "seed": key.sha256_text()}
			)
			poses[key] = Transform3D(
				Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(
					Vector3(1.0, 0.55, rng.randf_range(0.75, 1.1)) * scale_value
				),
				Vector3(p.x, field.height_at(p) - 0.16, p.y)
			)
			if i % 2 == 0:
				var plant: Vector2 = p + direction * rng.randf_range(0.25, 0.6)
				var plant_key: String = key + ":plant"
				var plant_asset: String = "NAT-04" if i % 4 == 0 else "NAT-06"
				groups[plant_asset].append(
					{
						"id": plant_key,
						"asset_id": plant_asset,
						"position": [plant.x, 0, plant.y],
						"seed": plant_key.sha256_text()
					}
				)
				poses[plant_key] = Transform3D(
					Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(
						Vector3.ONE * rng.randf_range(0.4, 0.7)
					),
					Vector3(plant.x, field.height_at(plant), plant.y)
				)
	for asset: String in groups:
		if not groups[asset].is_empty():
			root.add_child(
				ArtViewPlan.build_batch(
					groups[asset], poses, wood, stone, ArtViewPlan.describe(asset, wood, stone)
				)
			)
	return root


static func _bridge_clear(source: Dictionary, point: Vector2) -> bool:
	for bridge: Dictionary in source.get("bridges", []):
		var nearest: Vector2 = Geometry2D.get_closest_point_to_segment(
			point, Vector2(bridge["a"][0], bridge["a"][1]), Vector2(bridge["b"][0], bridge["b"][1])
		)
		if point.distance_to(nearest) < bridge["width"] * 0.7:
			return false
	return true
