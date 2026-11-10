extends RefCounted
## Wall bays and chimney derived entirely from the editable house in local metres.

const TIMBER: Color = Color("66533f")
const STONE: Color = Color("948578")
const MORTAR: Color = Color("736b5e")


static func wall_bays(
	home: Dictionary, neighbors: Array, timber: CottageMesh, seed_value: float
) -> void:
	var width: float = home["size"][0]
	var height: float = home["size"][1]
	var depth: float = home["size"][2]
	var round_wall: bool = home["shape"] == "round"
	for facade: int in range(1 if round_wall else 4):
		var span: float = PI * width if round_wall else (width if facade % 2 == 0 else depth)
		# Project openings and adjoining walls onto this facade. All new braces,
		# rails and studs live inside the remaining clear runs, even after resizing.
		var blocked: Array[Vector2] = []
		for opening: Dictionary in home.get("openings", []):
			if int(opening.get("facade", 0)) == facade:
				var center: float = float(opening["center"]) * span
				var half: float = float(opening["width"]) * 0.5 + 0.19
				blocked.append(Vector2(center - half, center + half))
		for contact: Rect2 in BuildingContact.intervals(home, neighbors, facade):
			blocked.append(Vector2(contact.position.x - 0.08, contact.end.x + 0.08))
		blocked.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
		blocked.append(Vector2(span, span))
		var left: float = 0.09
		for interval: Vector2 in blocked:
			var right: float = minf(span - 0.09, interval.x)
			var run: float = right - left
			if run > 0.36:
				var count: int = maxi(1, ceili(run / 1.75))
				var belt: float = height * 0.59
				for index: int in range(count):
					var a: float = left + run * index / count
					var b: float = left + run * (index + 1) / count
					var key: float = seed_value + index * 4.3 + facade
					for y: float in [0.46, belt]:
						_rail(home, facade, Vector2(a, y), Vector2(b, y), timber, key, 0.10)
					if b - a > 0.84:
						var ends: Vector2 = Vector2(a + 0.055, b - 0.055)
						if (index + facade) % 2 == 1:
							ends = Vector2(ends.y, ends.x)
						_rail(
							home,
							facade,
							Vector2(ends.x, belt + 0.04),
							Vector2(ends.y, height - 0.13),
							timber,
							key,
							0.093
						)
					for u: float in [a, b] if index == count - 1 else [a]:
						if not round_wall and (u <= 0.095 or u >= span - 0.095):
							continue  # The existing corner column carries this end.
						_rail(
							home,
							facade,
							Vector2(u, 0.44),
							Vector2(u, height - 0.12),
							timber,
							key,
							0.135
						)
			left = maxf(left, interval.y)


static func _rail(
	home: Dictionary,
	facade: int,
	a: Vector2,
	b: Vector2,
	timber: CottageMesh,
	seed_value: float,
	section: float
) -> void:
	var width: float = home["size"][0]
	var depth: float = home["size"][2]
	var rounded: bool = home["shape"] == "round"
	var pieces: int = maxi(1, ceili(absf(a.x - b.x) / 0.48)) if rounded else 1
	var previous: Vector3
	# Stand the posts slightly proud of the rails at their lap joints.
	var outset: float = 0.053 if is_equal_approx(a.x, b.x) else 0.036
	for step: int in range(pieces + 1):
		var uv: Vector2 = a.lerp(b, float(step) / pieces)
		var outward: Vector3 = BuildingGeometry._normal(uv.x, facade, width, depth, rounded)
		var p: Vector3 = BuildingGeometry._point(uv.x, facade, width, depth, rounded)
		p += outward * outset + Vector3.UP * uv.y
		if step > 0:
			timber.beam(previous, p, 0.096, section, TIMBER, seed_value, outward)
		previous = p


static func chimney_mouth(home: Dictionary) -> Vector3:
	var width: float = home["size"][0]
	var depth: float = home["size"][2]
	return Vector3(
		width * 0.21, float(home["size"][1]) + RoofProfile.rise(home) + 0.95, -depth * 0.22
	)


static func chimney(home: Dictionary, masonry: CottageMesh, seed_value: float) -> void:
	var mouth: Vector3 = chimney_mouth(home)
	var base: float = float(home["size"][1]) + RoofProfile.rise(home) * 0.36
	var rows: int = maxi(3, ceili((mouth.y - base) / 0.23))
	var course: float = (mouth.y - base) / rows
	var half_width: float = 0.33
	for index: int in range(rows):
		var top: float = base + course * (index + 1)
		var half: float = half_width + (0.065 if index == rows - 1 else 0.0)
		for face: int in range(4):
			var outward: Vector3 = [Vector3.BACK, Vector3.RIGHT, Vector3.FORWARD, Vector3.LEFT][face]
			var along: Vector3 = Vector3.UP.cross(outward)
			var center: Vector3 = Vector3(mouth.x, top - course * 0.5, mouth.z) + outward * half
			var left: Vector3 = center - along * half
			var right: Vector3 = center + along * half
			var lift: Vector3 = Vector3.UP * course * 0.5
			masonry.quad(left - lift, right - lift, right + lift, left + lift, outward, MORTAR)
			var split: float = 0.34 if (face + index) % 2 == 0 else -0.34
			for ends: Vector2 in [Vector2(-1, split), Vector2(split, 1)]:
				var key: float = seed_value + index * 8.61 + face * 2.84 + ends.x
				var stone_center: Vector3 = center + along * (ends.x + ends.y) * 0.5 * half
				masonry.stone(
					stone_center,
					Vector3(half * (ends.y - ends.x) - 0.008, course - 0.014, 0.055),
					outward,
					STONE.lightened(sin(key) * 0.055),
					key
				)
			if index == rows - 1:
				var inner: float = half * 0.58
				var rim: Vector3 = Vector3(mouth.x, top, mouth.z)
				masonry.quad(
					rim + (outward - along) * half,
					rim + (outward + along) * half,
					rim + (outward + along) * inner,
					rim + (outward - along) * inner,
					Vector3.UP,
					STONE.lightened(0.04)
				)
				masonry.quad(
					rim + (outward - along) * inner,
					rim + (outward + along) * inner,
					rim + (outward + along) * inner - lift * 1.5,
					rim + (outward - along) * inner - lift * 1.5,
					-outward,
					Color("383632")
				)
	var floor_point: Vector3 = mouth - Vector3.UP * course * 0.75
	masonry.quad(
		floor_point + Vector3(-0.3, 0, -0.3),
		floor_point + Vector3(0.3, 0, -0.3),
		floor_point + Vector3(0.3, 0, 0.3),
		floor_point + Vector3(-0.3, 0, 0.3),
		Vector3.UP,
		Color("2f3231")
	)


static func dormer(home: Dictionary, roof: CottageMesh, timber: CottageMesh, slate: Color) -> void:
	var half: float = float(home["size"][0]) * 0.5 + 0.39
	var rise: float = RoofProfile.rise(home)
	var depth: float = home["size"][2]
	if half < 2.35 or depth < 3.9 or rise < 1.45:
		return
	# A little slate-capped attic light on the west-facing slope. Both roof
	# planes extend back into the main roof so their intersection stays closed.
	var x: float = -half * 0.61
	var z: float = depth * 0.18
	var sill: float = float(home["size"][1]) + rise * (1.0 + x / half) + 0.12
	var w: float = 0.46
	var eave: float = sill + 0.48
	var ridge: float = eave + 0.36
	var back: float = minf(-0.13, x + (ridge - sill + 0.25) * half / rise)
	var normal: Vector3 = Vector3.LEFT
	var front: Vector3 = Vector3(x, sill, z)
	var top: Vector3 = Vector3(x, ridge, z)
	timber.quad(
		front - Vector3.BACK * w,
		front + Vector3.BACK * w,
		Vector3(x, eave, z + w),
		Vector3(x, eave, z - w),
		normal,
		TIMBER
	)
	timber.triangle(
		Vector3(x, eave, z - w), Vector3(x, eave, z + w), top, normal, TIMBER.lightened(0.09)
	)
	var g: Vector3 = front + normal * 0.012
	timber.quad(
		g + Vector3(0, 0.05, -0.32),
		g + Vector3(0, 0.05, 0.32),
		g + Vector3(0, 0.43, 0.32),
		g + Vector3(0, 0.43, -0.32),
		normal,
		Color("6b8178")
	)
	timber.beam(g + Vector3(-0.016, 0.05, 0), g + Vector3(-0.016, 0.44, 0), 0.048, 0.050, TIMBER)
	for side: float in [-1.0, 1.0]:
		var edge: Vector3 = Vector3(x, eave, z + side * w)
		timber.quad(
			edge,
			Vector3(x, sill - 0.1, edge.z),
			Vector3(back, sill, edge.z),
			Vector3(back, eave, edge.z),
			Vector3.BACK * side,
			TIMBER.lightened(0.12)
		)
		var tip: Vector3 = top + Vector3(-0.065, 0.048, 0)
		var lip: Vector3 = edge + Vector3(-0.065, 0.033, side * 0.07)
		var length: Vector3 = Vector3.RIGHT * (back - x + 0.065)
		roof.quad(tip, lip, lip + length, tip + length, Vector3(0, 1, side), slate)
		timber.beam(tip + Vector3.DOWN * 0.023, lip + Vector3.DOWN * 0.023, 0.057, 0.055, TIMBER)
