class_name CottageArt
extends RefCounted
## Presentation derived from the authoritative wall/opening mesh. No source mutation.
## Tiles, rounded timber sections and masonry are merged into three detail draws.

const MeshBuilder = preload("res://features/art_direction/architecture/cottage_mesh.gd")
const CLAY: Color = Color("bc7851")
const HONEY: Color = Color("a77c49")
const LIMESTONE: Color = Color("bdb69c")
const TILE_WIDTH: float = 0.49
const TILE_COURSE: float = 0.42


static func decorate(
	home: Dictionary, shell: ArrayMesh, snapshot: Dictionary, materials: Dictionary = {}
) -> Node3D:
	var root: MeshInstance3D = MeshInstance3D.new()
	root.name = "Cottage"
	root.mesh = _closed_gables(wall_mesh(shell), home, snapshot.get("buildings", []))
	root.material_override = _material(materials, "wall")
	root.position = Vector3(home["position"][0], home["position"][1], home["position"][2])
	root.set_meta("object_id", home["id"])
	root.set_meta("art_direction", "cottage_01")
	var roof: CottageMesh = MeshBuilder.new()
	var timber: CottageMesh = MeshBuilder.new()
	var stonework: CottageMesh = MeshBuilder.new()
	var neighbors: Array = snapshot.get("buildings", [])
	var seed_value: float = float(absi(hash(String(home["id"]))) % 100003) * 0.013
	if RoofProfile.rise(home) <= 0.02:
		_flat_roof(home, roof)
	elif home["shape"] == "round":
		_roof_underlay(shell, roof)
		_round_roof(home, roof, timber, seed_value)
	else:
		_rect_roof(home, neighbors, roof, timber, seed_value)
	_eave_soffits(home, neighbors, timber)
	_wall_details(home, neighbors, timber, stonework, seed_value)
	_opening_details(home, timber, stonework, seed_value)
	for entry: Array in [
		["HandLaidTiles", roof, "roof"],
		["HoneyTimber", timber, "wood"],
		["Limestone", stonework, "stone"]
	]:
		var builder: CottageMesh = entry[1]
		if builder.vertices.is_empty():
			continue
		var detail: MeshInstance3D = MeshInstance3D.new()
		detail.name = entry[0]
		detail.mesh = builder.mesh()
		detail.material_override = _material(materials, entry[2])
		root.add_child(detail)
	return root


static func wall_mesh(shell: ArrayMesh) -> ArrayMesh:
	# Existing shell vertex colours are its documented material categories. Retain
	# every wall, reveal and plaster gable; replace only the old thin roof prisms.
	var builder: CottageMesh = MeshBuilder.new()
	for surface: int in range(shell.get_surface_count()):
		var arrays: Array = shell.surface_get_arrays(surface)
		var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var source_colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var source_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var source_uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		for start: int in range(0, positions.size(), 3):
			if source_colors[start].g < 0.6:
				continue
			for offset: int in range(3):
				var index: int = start + offset
				builder.vertices.append(positions[index])
				builder.normals.append(source_normals[index])
				builder.colors.append(source_colors[index])
				builder.uvs.append(source_uvs[index])
	return builder.mesh()


static func _material(materials: Dictionary, key: String) -> Material:
	if materials.get(key) is Material:
		return materials[key]
	var result: StandardMaterial3D = StandardMaterial3D.new()
	result.vertex_color_use_as_albedo = true
	result.vertex_color_is_srgb = true
	result.roughness = 0.93
	return result


static func _roof_underlay(shell: ArrayMesh, roof: CottageMesh) -> void:
	# Closed, dark-clay boarding remains underneath the lapped tiles. Minute gaps
	# and clipped tile corners therefore show a roof bed rather than sky/interior.
	for surface: int in range(shell.get_surface_count()):
		var arrays: Array = shell.surface_get_arrays(surface)
		var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var source_colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var source_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var source_uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		for start: int in range(0, positions.size(), 3):
			if source_colors[start].g >= 0.6 or source_normals[start].y < 0.1:
				continue
			for offset: int in range(3):
				var index: int = start + offset
				roof.vertices.append(positions[index])
				roof.normals.append(source_normals[index])
				roof.colors.append(CLAY.darkened(0.17))
				roof.uvs.append(source_uvs[index])


static func _closed_gables(walls: ArrayMesh, home: Dictionary, neighbors: Array) -> ArrayMesh:
	if home["shape"] == "round" or RoofProfile.rise(home) <= 0.02:
		return walls
	var width: float = float(home["size"][0])
	var depth: float = float(home["size"][2])
	var height: float = float(home["size"][1])
	var rise: float = RoofProfile.rise(home)
	var half: float = width * 0.5
	var margins: Array[float] = _roof_margins(home, neighbors)
	# The original gable apex uses the wall span; its roof bed uses the larger
	# overhang span. Close only the resulting narrow wedge, without overlapping
	# any of the original plaster triangles or changing the actual openings.
	var builder: CottageMesh = MeshBuilder.new()
	var arrays: Array = walls.surface_get_arrays(0)
	builder.vertices = arrays[Mesh.ARRAY_VERTEX]
	builder.normals = arrays[Mesh.ARRAY_NORMAL]
	builder.colors = arrays[Mesh.ARRAY_COLOR]
	builder.uvs = arrays[Mesh.ARRAY_TEX_UV]
	for end: float in [-1.0, 1.0]:
		var facade: int = 0 if end > 0 else 2
		if margins[facade] < 0.001:
			continue
		for section: int in range(2):
			var a: float = -half if section == 0 else 0.0
			var b: float = 0.0 if section == 0 else half
			var low_a: float = height + rise * (1.0 - absf(a) / half)
			var low_b: float = height + rise * (1.0 - absf(b) / half)
			var roof_half: float = half + margins[3 if section == 0 else 1]
			var top_a: float = height + 0.02 + rise * (1.0 - absf(a) / roof_half)
			var top_b: float = height + 0.02 + rise * (1.0 - absf(b) / roof_half)
			builder.quad(
				Vector3(a, low_a, end * depth * 0.5),
				Vector3(b, low_b, end * depth * 0.5),
				Vector3(b, top_b, end * depth * 0.5),
				Vector3(a, top_a, end * depth * 0.5),
				Vector3(0, 0, end),
				BuildingGeometry.PLASTER
			)
	return builder.mesh()


static func _rect_roof(
	home: Dictionary, neighbors: Array, roof: CottageMesh, timber: CottageMesh, seed_value: float
) -> void:
	var width: float = float(home["size"][0])
	var height: float = float(home["size"][1])
	var depth: float = float(home["size"][2])
	var margins: Array[float] = _roof_margins(home, neighbors)
	var front: float = depth * 0.5 + margins[0]
	var back: float = depth * 0.5 + margins[2]
	var span_depth: float = front + back
	var ridge: float = height + RoofProfile.rise(home)
	var columns: int = ceili(span_depth / TILE_WIDTH)
	for side: float in [-1.0, 1.0]:
		var facade: int = 1 if side > 0 else 3
		var half_width: float = width * 0.5 + margins[facade]
		var trim: bool = margins[facade] < 0.001
		var slope_length: float = Vector2(half_width, ridge - height).length()
		var rows: int = ceili(slope_length / TILE_COURSE)
		var mapper: Callable = func(across: float, down: float) -> Vector3:
			return _roof_point(side, down, across, half_width, height, ridge, seed_value)
		# The bed and the laid tiles use the same per-side envelope. This keeps
		# a tall house's eaves over a lower wing and closes their tiny tile gaps.
		roof.quad(
			Vector3(0, ridge + 0.02, -back),
			Vector3(side * half_width, height + 0.02, -back),
			Vector3(side * half_width, height + 0.02, front),
			Vector3(0, ridge + 0.02, front),
			Vector3(side, 1, 0),
			CLAY.darkened(0.17)
		)
		for row: int in range(rows):
			var low: float = float(row) / rows
			var high: float = minf(
				1.0 + (0.0 if trim else 0.06 / half_width), float(row + 1.23) / rows
			)
			var stagger: float = 0.48 if row % 2 == 1 else 0.0
			for column: int in range(-1 if stagger > 0 else 0, columns):
				var a: float = maxf(-back, -back + (float(column) + stagger) * span_depth / columns)
				var b: float = minf(
					front, -back + (float(column + 1) + stagger) * span_depth / columns
				)
				if b - a < 0.06:
					continue
				var key: float = seed_value + row * 19.17 + column * 7.31 + side * 3.1
				_tile(roof, mapper, a + 0.002, b - 0.002, low, high, _tile_color(key), key)
		var contacts: Array[Rect2] = BuildingContact.intervals(home, neighbors, facade)
		var eave_count: int = ceili(span_depth / 0.9)
		for index: int in range(eave_count):
			var a: float = lerpf(-back, front, float(index) / eave_count)
			var b: float = lerpf(-back, front, float(index + 1) / eave_count)
			var u: float = depth * 0.5 - (a + b) * 0.5 if side > 0 else depth * 0.5 + (a + b) * 0.5
			if trim and _contact(contacts, u, height - 0.05):
				continue
			var down: float = 1.0 + (0.0 if trim else 0.025 / half_width)
			var first: Vector3 = _roof_point(side, down, a, half_width, height, ridge, seed_value)
			var last: Vector3 = _roof_point(side, down, b, half_width, height, ridge, seed_value)
			timber.beam(
				first + Vector3.DOWN * 0.065,
				last + Vector3.DOWN * 0.065,
				0.18,
				0.17,
				HONEY.darkened(0.10),
				seed_value
			)
		if not trim:
			# A few visible rafter ends explain the width and weight of the eaves.
			# They stay beneath the roof and outside the authoritative wall plane.
			var tail_count: int = maxi(2, ceili(span_depth / 1.18))
			for index: int in range(tail_count):
				var z: float = lerpf(-back + 0.16, front - 0.16, (index + 0.5) / tail_count)
				var inner: Vector3 = _roof_point(
					side,
					(width * 0.5 - 0.015) / half_width,
					z,
					half_width,
					height,
					ridge,
					seed_value
				)
				var outer: Vector3 = _roof_point(
					side, 1.0 - 0.07 / half_width, z, half_width, height, ridge, seed_value
				)
				timber.beam(
					inner + Vector3.DOWN * 0.12,
					outer + Vector3.DOWN * 0.12,
					0.085,
					0.11,
					HONEY.darkened(0.08),
					seed_value + index * 1.3
				)
		for end: float in [-1.0, 1.0]:
			var margin: float = margins[0 if end > 0 else 2]
			if margin < 0.001:
				continue
			var z: float = front - 0.04 if end > 0 else -back + 0.04
			var previous: Vector3 = _roof_point(side, 0.0, z, half_width, height, ridge, seed_value)
			for step: int in range(1, 5):
				var point: Vector3 = _roof_point(
					side,
					float(step) * (1.0 + 0.02 / half_width) / 4.0,
					z,
					half_width,
					height,
					ridge,
					seed_value
				)
				timber.beam(
					previous + Vector3.DOWN * 0.09,
					point + Vector3.DOWN * 0.09,
					0.18,
					0.20,
					HONEY,
					seed_value + end
				)
				previous = point
	var caps: int = ceili(span_depth / 0.49)
	for index: int in range(caps):
		var a: float = lerpf(
			-back - (0.045 if margins[2] > 0 else 0.0),
			front + (0.045 if margins[0] > 0 else 0.0),
			float(index) / caps
		)
		var b: float = minf(
			front + (0.07 if margins[0] > 0 else 0.0), a + span_depth / caps + 0.055
		)
		_ridge_cap(roof, a, b, ridge + 0.035, _tile_color(seed_value + index * 2.71))
	for end: float in [-1.0, 1.0]:
		if margins[0 if end > 0 else 2] < 0.001:
			continue
		var z: float = end * (depth * 0.5 + 0.045)
		timber.beam(
			Vector3(-width * 0.5, height - 0.03, z),
			Vector3(width * 0.5, height - 0.03, z),
			0.17,
			0.15,
			HONEY,
			seed_value
		)
		timber.beam(
			Vector3(0, height, z),
			Vector3(0, ridge - 0.06, z),
			0.13,
			0.13,
			HONEY.lightened(0.04),
			seed_value + 9.0
		)
		for side: float in [-1.0, 1.0]:
			timber.beam(
				Vector3(side * width * 0.33, height + 0.04, z),
				Vector3(side * width * 0.055, ridge - width * 0.07, z),
				0.085,
				0.095,
				HONEY.lightened(0.05),
				seed_value + side
			)


static func _roof_margins(home: Dictionary, neighbors: Array) -> Array[float]:
	var result: Array[float] = [0.36, 0.39, 0.36, 0.39]
	var own_x: float = float(home["position"][0])
	var own_top: float = float(home["position"][1]) + float(home["size"][1])
	var own_half: float = float(home["size"][0]) * 0.5
	var own_rise: float = RoofProfile.rise(home)
	for facade: int in range(4):
		for other: Dictionary in neighbors:
			if other["id"] == home["id"] or other["shape"] != "rect":
				continue
			var contact: Array[Rect2] = BuildingContact.intervals(home, [other], facade)
			if contact.is_empty():
				continue
			var other_half: float = float(other["size"][0]) * 0.5
			var other_rise: float = RoofProfile.rise(other)
			var other_top: float = float(other["position"][1]) + float(other["size"][1])
			if facade % 2 == 1:
				# Test the neighboring roof at the far edge of our possible eave.
				# A low wing does not cut the main cottage's clear, high roof.
				var neighbor_roof: float = (
					other_top
					+ other_rise * (1.0 - maxf(0.0, other_half - 0.45) / (other_half + 0.39))
				)
				if neighbor_roof >= own_top - 0.05:
					result[facade] = 0.0
			else:
				var other_x: float = float(other["position"][0])
				var left: float = maxf(own_x - own_half, other_x - other_half)
				var right: float = minf(own_x + own_half, other_x + other_half)
				for x: float in [left, (left + right) * 0.5, right]:
					var own_roof: float = (
						own_top + own_rise * (1.0 - absf(x - own_x) / (own_half + 0.39))
					)
					var neighbor_roof: float = (
						other_top + other_rise * (1.0 - absf(x - other_x) / (other_half + 0.39))
					)
					if neighbor_roof >= own_roof - 0.05:
						result[facade] = 0.0
	return result


static func _roof_point(
	side: float,
	down: float,
	across: float,
	half_width: float,
	height: float,
	ridge: float,
	seed_value: float
) -> Vector3:
	var sag: float = sin(clampf(down, 0, 1) * PI) * 0.065
	var wave: float = sin(across * 0.93 + seed_value) * 0.036 * down * down
	return Vector3(
		side * half_width * down, lerpf(ridge, height, down) + sag + wave + 0.035, across
	)


static func _tile(
	mesh: CottageMesh,
	mapper: Callable,
	a: float,
	b: float,
	low: float,
	high: float,
	tint: Color,
	seed_value: float
) -> void:
	# A fired-clay edge has real thickness, but a quiet lip. Repeated deep ridges
	# read as plastic scales at the garden camera and overwhelm the roof colour.
	var outline: Array[Vector2] = [
		Vector2(0.025, 0),
		Vector2(0.975, 0),
		Vector2(1, 0.035),
		Vector2(1, 0.97),
		Vector2(0.96, 1),
		Vector2(0.04, 1),
		Vector2(0, 0.97),
		Vector2(0, 0.035)
	]
	var top: Array[Vector3] = []
	var underside: Array[Vector3] = []
	var lift: float = sin(seed_value * 2.1) * 0.008
	var tile_high: float = high - (0.5 + sin(seed_value * 1.37) * 0.5) * (high - low) * 0.045
	for p: Vector2 in outline:
		var point: Vector3 = mapper.call(lerpf(a, b, p.x), lerpf(low, tile_high, p.y))
		point.y += 0.025 + p.y * p.y * 0.022 + sin(p.x * PI) * 0.011 + lift
		top.append(point)
		underside.append(point + Vector3.DOWN * 0.044)
	var center: Vector3 = mapper.call((a + b) * 0.5, (low + tile_high) * 0.5)
	center.y += 0.045 + lift
	for index: int in range(8):
		var next: int = (index + 1) % 8
		mesh.triangle_uv(
			center,
			top[index],
			top[next],
			Vector3.UP,
			tint,
			Vector2(0.5, 0.5),
			outline[index],
			outline[next]
		)
		var outward: Vector3 = ((top[index] + top[next]) * 0.5 - center).normalized()
		mesh.quad_uv(
			top[index],
			underside[index],
			underside[next],
			top[next],
			outward,
			tint.darkened(0.055),
			Vector2(0, 0),
			Vector2(0, 0.12),
			Vector2(1, 0.12),
			Vector2(1, 0)
		)


static func _ridge_cap(mesh: CottageMesh, a: float, b: float, y: float, tint: Color) -> void:
	var radius: float = 0.13
	for segment: int in range(6):
		var first: float = float(segment) * PI / 6.0
		var second: float = float(segment + 1) * PI / 6.0
		var p: Vector3 = Vector3(cos(first) * radius, y + sin(first) * radius + 0.06, a)
		var q: Vector3 = Vector3(cos(second) * radius, y + sin(second) * radius + 0.06, a)
		var span: Vector3 = Vector3(0, 0.018, b - a)
		mesh.quad_uv(
			p,
			q,
			q + span,
			p + span,
			Vector3(cos((first + second) * 0.5), sin((first + second) * 0.5), 0),
			tint,
			Vector2(first / PI, 0),
			Vector2(second / PI, 0),
			Vector2(second / PI, 1),
			Vector2(first / PI, 1)
		)
		mesh.triangle(Vector3(0, y + 0.055, a), q, p, Vector3.FORWARD, tint.darkened(0.045))
		mesh.triangle(Vector3(0, y + 0.073, b), p + span, q + span, Vector3.BACK, tint)


static func _round_roof(
	home: Dictionary, roof: CottageMesh, timber: CottageMesh, seed_value: float
) -> void:
	var width: float = float(home["size"][0])
	var height: float = float(home["size"][1])
	var radius: float = width * 0.5 + 0.39
	var rise: float = RoofProfile.rise(home)
	var rows: int = ceili(Vector2(radius, rise).length() / TILE_COURSE)
	for row: int in range(rows):
		var low: float = maxf(0.09, float(row) / rows)
		var high: float = minf(1.025, float(row + 1.23) / rows)
		if high <= low:
			continue
		var columns: int = maxi(7, ceili(TAU * radius * (low + high) * 0.5 / TILE_WIDTH))
		var stagger: float = 0.5 * TAU / columns if row % 2 else 0.0
		var mapper: Callable = func(across: float, down: float) -> Vector3:
			var r: float = radius * down
			return Vector3(
				sin(across) * r,
				height + rise * (1.0 - down) + sin(down * PI) * 0.065 + 0.04,
				cos(across) * r
			)
		for column: int in range(columns):
			var a: float = float(column) * TAU / columns + stagger
			var b: float = float(column + 1) * TAU / columns + stagger
			var key: float = seed_value + row * 17.13 + column * 4.27
			_tile(roof, mapper, a + 0.0008, b - 0.0008, low, high, _tile_color(key), key)
	# A small fired-clay apex closes the only area without individually laid tiles.
	var tip: Vector3 = Vector3(0, height + rise + 0.17, 0)
	for index: int in range(16):
		var a: float = float(index) * TAU / 16
		var b: float = float(index + 1) * TAU / 16
		var p: Vector3 = Vector3(
			sin(a) * radius * 0.115, height + rise * 0.91, cos(a) * radius * 0.115
		)
		var q: Vector3 = Vector3(
			sin(b) * radius * 0.115, height + rise * 0.91, cos(b) * radius * 0.115
		)
		roof.triangle(p, q, tip, Vector3(sin(a), 0.5, cos(a)), CLAY.lightened(0.03))
	for index: int in range(48):
		var a: float = float(index) * TAU / 48
		var b: float = float(index + 1) * TAU / 48
		timber.beam(
			Vector3(sin(a) * radius, height - 0.055, cos(a) * radius),
			Vector3(sin(b) * radius, height - 0.055, cos(b) * radius),
			0.13,
			0.13,
			HONEY.darkened(0.08),
			seed_value + index
		)


static func _eave_soffits(home: Dictionary, neighbors: Array, timber: CottageMesh) -> void:
	# Only the exposed overhang gets wooden boarding. A complete downward roof
	# prism would cut through the plaster gable and into the editable openings.
	var half: float = float(home["size"][0]) * 0.5
	var depth: float = float(home["size"][2]) * 0.5
	var height: float = float(home["size"][1])
	var rise: float = RoofProfile.rise(home)
	var flat: bool = rise <= 0.02
	var clearance: float = 0.032 if flat else 0.012
	if home["shape"] == "round":
		var radius: float = half + (0.35 if flat else 0.39)
		for index: int in range(48):
			var a: float = float(index) * TAU / 48.0
			var b: float = float(index + 1) * TAU / 48.0
			var points: Array[Vector3] = []
			for corner: Vector2 in [
				Vector2(half, a), Vector2(radius, a), Vector2(radius, b), Vector2(half, b)
			]:
				var y: float = height + clearance
				if not flat:
					y += rise * (1.0 - corner.x / radius)
				points.append(Vector3(sin(corner.y) * corner.x, y, cos(corner.y) * corner.x))
			timber.solid_panel(points, 0.07, HONEY.darkened(0.09))
		return
	var margins: Array[float] = [0.35, 0.35, 0.35, 0.35]
	if not flat:
		margins = _roof_margins(home, neighbors)
	for side: float in [-1.0, 1.0]:
		var roof_half: float = half + margins[1 if side > 0.0 else 3]
		# Rectangles partition the overhang ring; corners are only covered once.
		var strips: Array[Rect2] = []
		if roof_half > half + 0.001:
			strips.append(
				Rect2(
					half,
					-depth - margins[2],
					roof_half - half,
					depth * 2.0 + margins[0] + margins[2]
				)
			)
		if margins[0] > 0.001:
			strips.append(Rect2(0.0, depth, half, margins[0]))
		if margins[2] > 0.001:
			strips.append(Rect2(0.0, -depth - margins[2], half, margins[2]))
		for strip: Rect2 in strips:
			var points: Array[Vector3] = []
			for corner: Vector2 in [
				strip.position,
				Vector2(strip.end.x, strip.position.y),
				strip.end,
				Vector2(strip.position.x, strip.end.y)
			]:
				var y: float = height + clearance
				if not flat:
					y += rise * (1.0 - corner.x / roof_half)
				points.append(Vector3(side * corner.x, y, corner.y))
			timber.solid_panel(points, 0.07, HONEY.darkened(0.09))


static func _wall_details(
	home: Dictionary,
	neighbors: Array,
	timber: CottageMesh,
	stonework: CottageMesh,
	seed_value: float
) -> void:
	var width: float = float(home["size"][0])
	var height: float = float(home["size"][1])
	var depth: float = float(home["size"][2])
	var rounded: bool = home["shape"] == "round"
	for facade: int in range(1 if rounded else 4):
		var length: float = PI * width if rounded else (width if facade % 2 == 0 else depth)
		var contacts: Array[Rect2] = BuildingContact.intervals(home, neighbors, facade)
		var eave_steps: int = ceili(length / (0.45 if rounded else 0.9))
		for index: int in range(eave_steps):
			var a: float = length * float(index) / eave_steps
			var b: float = length * float(index + 1) / eave_steps
			if _contact(contacts, (a + b) * 0.5, height - 0.10):
				continue
			var na: Vector3 = BuildingGeometry._normal(a, facade, width, depth, rounded)
			var nb: Vector3 = BuildingGeometry._normal(b, facade, width, depth, rounded)
			var p: Vector3 = BuildingGeometry._point(a, facade, width, depth, rounded) + na * 0.033
			var q: Vector3 = BuildingGeometry._point(b, facade, width, depth, rounded) + nb * 0.033
			p.y = height - 0.07
			q.y = height - 0.07
			timber.beam(
				p,
				q,
				0.14,
				0.12,
				HONEY.lightened(0.015 * sin(seed_value + index)),
				seed_value + index
			)
		# Two staggered courses with individual rounded corners avoid a flat slab base.
		for row: int in range(2):
			var count_value: int = ceili(length / 0.51)
			var stagger: float = 0.5 if row % 2 else 0.0
			for index: int in range(-1 if stagger > 0 else 0, count_value):
				var course_seed: float = seed_value + row * 4.73 + facade * 1.9
				var a: float = maxf(
					0,
					(
						(float(index) + stagger) * length / count_value
						+ sin(index * 2.31 + course_seed) * 0.055
					)
				)
				var b: float = minf(
					length,
					(
						(float(index + 1) + stagger) * length / count_value
						+ sin((index + 1) * 2.31 + course_seed) * 0.055
					)
				)
				var u: float = (a + b) * 0.5
				var y: float = 0.115 + row * 0.218
				if (
					b - a < 0.08
					or _contact(contacts, u, y)
					or _near_opening(home, facade, u, y, length, 0.25)
				):
					continue
				var normal: Vector3 = BuildingGeometry._normal(u, facade, width, depth, rounded)
				var point: Vector3 = (
					BuildingGeometry._point(u, facade, width, depth, rounded) + normal * 0.032
				)
				point.y = y
				var key: float = seed_value + index * 2.21 + row * 4.73 + facade * 1.9
				stonework.stone(
					point,
					Vector3(b - a - 0.016, 0.207, 0.10),
					normal,
					LIMESTONE.darkened(0.06 * (0.5 + sin(key) * 0.5)),
					key
				)
		if not rounded:
			for edge: float in [0.045, length - 0.045]:
				var normal: Vector3 = BuildingGeometry._normal(edge, facade, width, depth, rounded)
				var point: Vector3 = (
					BuildingGeometry._point(edge, facade, width, depth, rounded) + normal * 0.025
				)
				var low: float = 0.43
				for contact: Rect2 in contacts:
					if edge >= contact.position.x - 0.1 and edge <= contact.end.x + 0.1:
						low = maxf(low, contact.end.y)
				if low >= height - 0.2:
					continue
				timber.beam(
					point + Vector3.UP * low,
					point + Vector3.UP * (height - 0.08),
					0.115,
					0.125,
					HONEY.darkened(0.025),
					seed_value + edge
				)


static func _contact(contacts: Array[Rect2], u: float, y: float) -> bool:
	for contact: Rect2 in contacts:
		if (
			u >= contact.position.x - 0.025
			and u <= contact.end.x + 0.025
			and y >= contact.position.y - 0.03
			and y <= contact.end.y + 0.03
		):
			return true
	return false


static func _near_opening(
	home: Dictionary, facade: int, u: float, y: float, length: float, margin: float
) -> bool:
	for opening: Dictionary in home.get("openings", []):
		if int(opening.get("facade", 0)) != facade:
			continue
		if (
			(
				absf(u - float(opening.get("center", 0.5)) * length)
				< float(opening["width"]) * 0.5 + margin
			)
			and y >= float(opening.get("sill", 0)) - margin
			and y <= float(opening.get("sill", 0)) + float(opening["height"]) + margin
		):
			return true
	return false


static func _opening_details(
	home: Dictionary, timber: CottageMesh, stonework: CottageMesh, seed_value: float
) -> void:
	var width: float = float(home["size"][0])
	var depth: float = float(home["size"][2])
	var rounded: bool = home["shape"] == "round"
	for opening: Dictionary in home.get("openings", []):
		var facade: int = int(opening.get("facade", 0))
		var length: float = PI * width if rounded else (width if facade % 2 == 0 else depth)
		var u: float = float(opening.get("center", 0.5)) * length
		var normal: Vector3 = BuildingGeometry._normal(u, facade, width, depth, rounded)
		var tangent: Vector3 = Vector3.UP.cross(normal)
		var center: Vector3 = (
			BuildingGeometry._point(u, facade, width, depth, rounded) + normal * 0.055
		)
		var span: float = float(opening["width"])
		var rise: float = float(opening["height"])
		var sill: float = float(opening.get("sill", 0.0))
		var trim: float = _trim_allowance(home, opening, facade, length)
		center.y = sill
		var mapper: Callable = func(x: float, y: float, push: float) -> Vector3:
			var outward: Vector3 = BuildingGeometry._normal(u + x, facade, width, depth, rounded)
			return (
				BuildingGeometry._point(u + x, facade, width, depth, rounded)
				+ outward * push
				+ Vector3.UP * (sill + y)
			)
		if rise < 1.8:
			# A little stone sill has a worn bright top and never crosses the aperture.
			stonework.stone(
				center + Vector3.UP * -0.072 + normal * 0.035,
				Vector3(span + trim * 2.0, 0.115, 0.21),
				normal,
				LIMESTONE.lightened(0.05),
				seed_value + u
			)
			if opening["kind"] == "round":
				continue
			for side: float in [-1.0, 1.0]:
				var offset: float = (span * 0.5 + trim * 0.5) * side
				var p: Vector3 = mapper.call(offset, 0.0, 0.055)
				var outward: Vector3 = BuildingGeometry._normal(
					u + offset, facade, width, depth, rounded
				)
				timber.beam(
					p,
					p + Vector3.UP * (rise + trim * 0.5),
					trim * 0.8,
					trim * 0.8,
					HONEY,
					seed_value + side,
					Vector3.UP.cross(outward)
				)
			var top_steps: int = 4 if rounded else 1
			for step: int in range(top_steps):
				var left: float = lerpf(
					-span * 0.5 - trim * 0.9, span * 0.5 + trim * 0.9, float(step) / top_steps
				)
				var right: float = lerpf(
					-span * 0.5 - trim * 0.9, span * 0.5 + trim * 0.9, float(step + 1) / top_steps
				)
				var a: Vector3 = mapper.call(left, rise + trim * 0.5, 0.055)
				var b: Vector3 = mapper.call(right, rise + trim * 0.5, 0.055)
				timber.beam(a, b, trim * 0.8, trim * 0.8, HONEY, seed_value)
			continue
		var radius: float = span * 0.5
		var arch_spring: float = rise - radius if opening["kind"] == "arch" else rise
		var count_value: int = ceili(arch_spring / 0.29)
		for side: float in [-1.0, 1.0]:
			for index: int in range(count_value):
				var offset: float = (radius + trim * 0.55) * side
				var p: Vector3 = mapper.call(
					offset, (float(index) + 0.5) * arch_spring / count_value, 0.055
				)
				var outward: Vector3 = BuildingGeometry._normal(
					u + offset, facade, width, depth, rounded
				)
				stonework.stone(
					p,
					Vector3(trim * 0.9, arch_spring / count_value - 0.013, 0.145),
					outward,
					LIMESTONE.lightened(0.025 * sin(seed_value + index)),
					seed_value + index
				)
		if opening["kind"] != "arch":
			stonework.stone(
				center + Vector3.UP * (rise + trim * 0.55),
				Vector3(span + trim * 2.0, trim * 0.9, 0.16),
				normal,
				LIMESTONE.lightened(0.02),
				seed_value
			)
			continue
		# Voussoirs follow the same analytic opening boundary, all outside its radius.
		for index: int in range(11):
			var a: float = float(index) * PI / 11 + 0.012
			var b: float = float(index + 1) * PI / 11 - 0.012
			var inner_a: Vector3 = mapper.call(
				cos(a) * (radius + 0.012), arch_spring + sin(a) * (radius + 0.012), 0.055
			)
			var inner_b: Vector3 = mapper.call(
				cos(b) * (radius + 0.012), arch_spring + sin(b) * (radius + 0.012), 0.055
			)
			var outer_a: Vector3 = mapper.call(
				cos(a) * (radius + trim), arch_spring + sin(a) * (radius + trim), 0.055
			)
			var outer_b: Vector3 = mapper.call(
				cos(b) * (radius + trim), arch_spring + sin(b) * (radius + trim), 0.055
			)
			stonework.quad(
				inner_a + normal * 0.07,
				inner_b + normal * 0.07,
				outer_b + normal * 0.07,
				outer_a + normal * 0.07,
				normal,
				LIMESTONE.lightened(0.03 * sin(seed_value + index))
			)
			stonework.quad(
				inner_a,
				inner_a + normal * 0.07,
				outer_a + normal * 0.07,
				outer_a,
				-tangent * sin(a),
				LIMESTONE.darkened(0.06)
			)
			stonework.quad(
				outer_a,
				outer_a + normal * 0.07,
				outer_b + normal * 0.07,
				outer_b,
				Vector3.UP,
				LIMESTONE.lightened(0.03)
			)


static func _tile_color(seed_value: float) -> Color:
	# Individual tiles remain legible near the eaves; broad painted clay washes
	# carry the roof from the normal camera instead of a checkerboard of colours.
	var shade: float = sin(seed_value * 3.17) * 0.016 + cos(seed_value * 0.89) * 0.010
	return CLAY.lightened(shade) if shade >= 0 else CLAY.darkened(-shade)


static func _trim_allowance(
	home: Dictionary, selected: Dictionary, facade: int, length: float
) -> float:
	var center: float = float(selected.get("center", 0.5)) * length
	var half: float = float(selected["width"]) * 0.5
	var result: float = minf(0.19, minf(center - half, length - center - half) * 0.85)
	for other: Dictionary in home.get("openings", []):
		if other == selected or int(other.get("facade", 0)) != facade:
			continue
		var gap: float = (
			absf(float(other.get("center", 0.5)) * length - center)
			- half
			- float(other["width"]) * 0.5
		)
		result = minf(result, gap * 0.43)
	return maxf(0.025, result)


static func _flat_roof(home: Dictionary, roof: CottageMesh) -> void:
	var y: float = home["size"][1] + 0.04
	var half: Vector2 = Vector2(home["size"][0], home["size"][2]) * 0.5 + Vector2.ONE * 0.35
	if home["shape"] == "round":
		for i: int in range(64):
			var a: float = i * TAU / 64
			var b: float = (i + 1) * TAU / 64
			var p: Vector3 = Vector3(sin(a) * half.x, y, cos(a) * half.x)
			var q: Vector3 = Vector3(sin(b) * half.x, y, cos(b) * half.x)
			roof.triangle(Vector3(0, y, 0), p, q, Vector3.UP, CLAY)
			roof.quad(
				p,
				q,
				q - Vector3.UP * 0.15,
				p - Vector3.UP * 0.15,
				Vector3(sin(a), 0, cos(a)),
				CLAY.darkened(0.15)
			)
	else:
		var columns: int = ceili(half.x * 2 / TILE_WIDTH)
		var rows: int = ceili(half.y * 2 / TILE_COURSE)
		for x: int in range(columns):
			for z: int in range(rows):
				var a: Vector2 = Vector2(
					lerpf(-half.x, half.x, float(x) / columns),
					lerpf(-half.y, half.y, float(z) / rows)
				)
				var b: Vector2 = Vector2(
					lerpf(-half.x, half.x, float(x + 1) / columns),
					lerpf(-half.y, half.y, float(z + 1) / rows)
				)
				roof.quad(
					Vector3(a.x, y, a.y),
					Vector3(b.x, y, a.y),
					Vector3(b.x, y, b.y),
					Vector3(a.x, y, b.y),
					Vector3.UP,
					_tile_color(x * 3.71 + z * 17.2)
				)
		for side: int in range(4):
			var corners: Array[Vector3] = [
				Vector3(-half.x, y, -half.y),
				Vector3(half.x, y, -half.y),
				Vector3(half.x, y, half.y),
				Vector3(-half.x, y, half.y)
			]
			var a: Vector3 = corners[side]
			var b: Vector3 = corners[(side + 1) % 4]
			roof.quad(
				a,
				b,
				b - Vector3.UP * 0.15,
				a - Vector3.UP * 0.15,
				(a + b).normalized(),
				CLAY.darkened(0.15)
			)
