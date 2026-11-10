extends RefCounted
## Water lilies and exposed stones are regenerated from the editable shore.
## One small vertex-coloured mesh per chunk keeps each group in its own bay.

static func add_to(parent: Node3D, surface: IslandSurface, chunk: Vector2i) -> void:
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := 0
	for z in range(chunk.y * 8, chunk.y * 8 + 8):
		for x in range(chunk.x * 8, chunk.x * 8 + 8):
			var p := Vector2i(x, z)
			if not BuildingRules.inside(p) or surface.occupied.has(p):
				continue
			var tile := surface.cell(p)
			var rng := RandomNumberGenerator.new()
			rng.seed = (x + 71) * 7919 + (z + 19) * 104729
			if tile.h == 0:
				var near_grass := false
				for direction in BuildingRules.DIRS:
					var bank := surface.cell(p + direction)
					if bank.h == 1 and bank.surface == "grass":
						near_grass = true
						break
				if not near_grass or rng.randf() > 0.46:
					continue
				for i in range(rng.randi_range(3, 7)):
					var spot := Vector2(p) + Vector2(rng.randf_range(-0.45, 0.45), rng.randf_range(-0.45, 0.45))
					if surface.height_at(spot) > -0.065:
						continue
					var origin := Vector3(spot.x, -0.023 + 0.001 * i, spot.y)
					pad(mesh, origin, rng.randf_range(0.055, 0.17), rng.randf() * TAU, Color("85894c").lightened(rng.randf() * 0.18))
					if i == 2 and rng.randf() < 0.4:
						blossom(mesh, origin, rng.randf() * TAU)
					count += 1
			elif tile.surface == "grass" and not tile.road and not tile.flower and tile.h == 1:
				var coast := Vector2.ZERO
				for direction in BuildingRules.DIRS:
					if surface.cell(p + direction).h == 0:
						coast += Vector2(direction)
				if not coast.is_zero_approx():
					meadow_edge(mesh, surface, Vector2(p), coast.normalized(), rng)
					count += 1
			elif tile.road:
				paving(mesh, surface, p, rng)
				count += 1
			elif tile.surface == "rock" and not tile.road and rng.randf() < 0.65:
				var spot := Vector2(p)
				boulder(mesh, Vector3(spot.x, surface.height_at(spot) - 0.07, spot.y), rng)
				count += 1
	if count == 0:
		return
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.97
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.set_material(material)
	var result := MeshInstance3D.new()
	result.mesh = mesh.commit()
	parent.add_child(result)

static func triangle(mesh: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	var normal := (c - a).cross(b - a).normalized()
	if normal.y < 0.0:
		normal = -normal
	mesh.set_normal(normal)
	mesh.set_color(color)
	for point in [a, b, c]:
		mesh.add_vertex(point)

static func pad(mesh: SurfaceTool, point: Vector3, radius: float, yaw: float, color: Color) -> void:
	# Leave a slim opening in each pad; this reads even at the low camera angle.
	for i in range(8):
		var a := yaw + float(i) * 0.735
		var b := a + 0.735
		triangle(mesh, point, point + Vector3(cos(a), 0, sin(a) * 0.86) * radius,
			point + Vector3(cos(b), 0, sin(b) * 0.86) * radius, color)

static func blossom(mesh: SurfaceTool, point: Vector3, yaw: float) -> void:
	var heart := point + Vector3.UP * 0.017
	for i in range(6):
		var angle := yaw + i * TAU / 6.0
		var stem := Vector3(cos(angle), 0, sin(angle))
		var wing := Vector3(-stem.z, 0, stem.x) * 0.024
		var mid := heart + stem * 0.03 + Vector3.UP * 0.024
		var tip := heart + stem * 0.055 + Vector3.UP * 0.043
		triangle(mesh, heart, mid - wing, tip, Color("e8c9b4"))
		triangle(mesh, heart, tip, mid + wing, Color("fff0d4"))

static func boulder(mesh: SurfaceTool, point: Vector3, rng: RandomNumberGenerator) -> void:
	var radius := rng.randf_range(0.32, 0.62)
	var base := PackedVector3Array()
	var rim := PackedVector3Array()
	var top := point + Vector3(0, radius * 0.95, 0)
	for i in range(7):
		var a := (float(i) + rng.randf_range(-0.13, 0.13)) * TAU / 7.0
		var side := Vector3(cos(a) * radius, 0, sin(a) * radius * 0.75)
		base.append(point + side)
		rim.append(point + side * rng.randf_range(0.57, 0.86) + Vector3.UP * radius * rng.randf_range(0.56, 0.8))
	for i in range(7):
		var j := (i + 1) % 7
		var shade := Color("a99d8c").darkened(rng.randf() * 0.07)
		triangle(mesh, base[i], base[j], rim[j], shade)
		triangle(mesh, base[i], rim[j], rim[i], shade)
		triangle(mesh, rim[i], rim[j], top, shade.lightened(0.14))

# Stepping stones follow the same links the residents walk. Leave turf between
# them and follow the continuous surface where two road cells meet on a slope.
static func paving(mesh: SurfaceTool, surface: IslandSurface, p: Vector2i, rng: RandomNumberGenerator) -> void:
	var links: Array[Vector2] = [Vector2.ZERO]
	for direction in BuildingRules.DIRS:
		var neighbor := p + Vector2i(direction)
		if surface.cell(neighbor).get("road", false) and absi(int(surface.cell(neighbor).h) - int(surface.cell(p).h)) <= 1:
			links.append(Vector2(direction) * 0.31)
	for offset in links:
		var center := Vector2(p) + offset
		var side := offset.normalized().orthogonal()
		var positions := [center] if offset == Vector2.ZERO else [center + side * 0.13, center - side * 0.13]
		for xy: Vector2 in positions:
			xy += Vector2(rng.randf_range(-0.023, 0.023), rng.randf_range(-0.023, 0.023))
			var width := Vector2(0.24, 0.18) if offset == Vector2.ZERO else Vector2(0.16, 0.11)
			var yaw := rng.randf_range(-0.45, 0.45) + offset.angle()
			var color := Color("bda98f").lerp(Color("d8c6a2"), rng.randf())
			var middle := Vector3(xy.x, surface.height_at(xy) + 0.035, xy.y)
			var rim := PackedVector3Array()
			for i in range(7):
				var angle := i * TAU / 7 + rng.randf_range(-0.16, 0.16)
				var v := xy + (Vector2(cos(angle), sin(angle)) * width).rotated(yaw)
				rim.append(Vector3(v.x, surface.height_at(v) + 0.020, v.y))
			for i in range(7):
				triangle(mesh, middle, rim[i], rim[(i+1)%7], color)

# Dense little groups grow out across the edge of the soil. Gaps between groups
# keep the waterline and the feet of the residents readable.
static func meadow_edge(mesh: SurfaceTool, surface: IslandSurface, p: Vector2, coast: Vector2, rng: RandomNumberGenerator) -> void:
	var along := coast.orthogonal()
	var lavender := rng.randf() < 0.21
	for i in range(rng.randi_range(12, 29)):
		var xy := p + along * rng.randf_range(-0.49, 0.49) + coast * rng.randf_range(0.04, 0.53)
		var base := Vector3(xy.x, surface.height_at(xy) - 0.018, xy.y)
		var green := Color("859255").lerp(Color("b7af6a"), rng.randf())
		for blade in range(3):
			var a := rng.randf() * TAU
			var side := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.013, 0.031)
			var height := rng.randf_range(0.09, 0.24)
			var tip := base + Vector3(coast.x * 0.065 + side.z, height, coast.y * 0.065 - side.x)
			triangle(mesh, base - side, tip, base + side, green)
		if lavender and i % 3 == 0:
			var stem := base + Vector3.UP * rng.randf_range(0.18, 0.32)
			triangle(mesh, base - Vector3.RIGHT * 0.012, stem, base + Vector3.RIGHT * 0.012, green)
			var petal_color := Color("cda6bb").lerp(Color("e6c9ce"), rng.randf())
			for j in range(4):
				var direction := Vector3(cos(j * PI * 0.5), 0, sin(j * PI * 0.5))
				var petal := stem + direction * 0.048 + Vector3.UP * 0.035
				var w := Vector3(-direction.z, 0, direction.x) * 0.024
				triangle(mesh, stem, petal - w, petal + w, petal_color)
