extends RefCounted
## Plank leaves, leaded panes and muntins share the dimensions of the real wall opening.

const OAK: Color = Color("6a513e")
const DARK_WOOD: Color = Color("463d35")
const HINGE: Color = Color("434743")


static func make(
	kind: String, opening: Dictionary, wood: Material, glass: Material, wall_radius: float = 0.0
) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = kind.to_pascal_case()
	var frame: CottageMesh = CottageMesh.new()
	var panes: CottageMesh = CottageMesh.new()
	var width: float = opening["width"]
	var height: float = opening["height"]
	var radius: float = width * 0.5
	if kind == "round_window":
		var center: Vector3 = Vector3(0, height * 0.5, 0.016)
		for i: int in range(24):
			var a: float = TAU * i / 24.0
			var b: float = TAU * (i + 1) / 24.0
			var p: Vector3 = center + Vector3(cos(a) * radius, sin(a) * height * 0.5, 0)
			var q: Vector3 = center + Vector3(cos(b) * radius, sin(b) * height * 0.5, 0)
			panes.triangle_uv(
				center,
				p,
				q,
				Vector3.BACK,
				Color.WHITE,
				Vector2(0.5, 0.5),
				Vector2(0.5 + cos(a) * 0.5, 0.5 + sin(a) * 0.5),
				Vector2(0.5 + cos(b) * 0.5, 0.5 + sin(b) * 0.5)
			)
			frame.beam(
				p + Vector3.BACK * 0.035, q + Vector3.BACK * 0.035, 0.066, 0.068, DARK_WOOD, i
			)
		_cross(frame, width * 0.5, 0.0, height)
	elif kind == "rect_window":
		_pane(panes, -radius, radius, 0, height)
		_cross(frame, radius, 0, height)
	else:
		var glass_door: bool = kind == "glass"
		var leaf_top: float = height * 0.55 if glass_door else height
		var boards: int = maxi(4, ceili(width / 0.16))
		for i: int in range(boards):
			var left: float = lerpf(-radius, radius, float(i) / boards)
			var right: float = lerpf(-radius, radius, float(i + 1) / boards)
			var upper_l: float = _height(left, radius, leaf_top, kind)
			var upper_r: float = _height(right, radius, leaf_top, kind)
			var pigment: Color = OAK.lightened(0.03 * sin(i * 3.2))
			frame.quad(
				Vector3(left, 0, 0),
				Vector3(right, 0, 0),
				Vector3(right, upper_r, 0),
				Vector3(left, upper_l, 0),
				Vector3.BACK,
				DARK_WOOD
			)
			frame.quad(
				Vector3(left + 0.006, 0, 0.012),
				Vector3(right - 0.005, 0, 0.012),
				Vector3(right - 0.005, upper_r - 0.003, 0.012),
				Vector3(left + 0.006, upper_l - 0.003, 0.012),
				Vector3.BACK,
				pigment
			)
		for y: float in [height * 0.18, height * (0.46 if glass_door else 0.71)]:
			frame.beam(
				Vector3(-radius + 0.03, y, 0.035),
				Vector3(-radius * 0.26, y, 0.035),
				0.035,
				0.055,
				HINGE
			)
		frame.beam(
			Vector3(radius * 0.62, height * 0.43, 0.061),
			Vector3(radius * 0.80, height * 0.43, 0.061),
			0.065,
			0.04,
			Color("a38b60")
		)
		if glass_door:
			_pane(panes, -radius, radius, leaf_top, height)
			_cross(frame, radius, leaf_top, height)
	for part: Array in [["Joinery", frame, wood], ["Panes", panes, glass]]:
		var geometry: CottageMesh = part[1]
		if not geometry.vertices.is_empty():
			var view: MeshInstance3D = MeshInstance3D.new()
			view.name = part[0]
			if wall_radius > 0.0:
				_follow_wall(geometry, wall_radius)
			view.mesh = geometry.mesh()
			view.material_override = part[2]
			root.add_child(view)
	return root


static func _follow_wall(geometry: CottageMesh, radius: float) -> void:
	# OpeningAssembly places the panel 5 cm into its wall. Project the door
	# and pane edges using the same arc length as BuildingGeometry's aperture.
	for i: int in range(geometry.vertices.size()):
		var p: Vector3 = geometry.vertices[i]
		var angle: float = p.x / radius
		var r: float = radius - OpeningAssembly.RECESS + p.z
		geometry.vertices[i] = Vector3(
			sin(angle) * r, p.y, cos(angle) * r - radius + OpeningAssembly.RECESS
		)
		geometry.normals[i] = geometry.normals[i].rotated(Vector3.UP, angle)


static func _height(x: float, radius: float, height: float, kind: String) -> float:
	if kind == "arch":
		return height - radius + sqrt(maxf(0.0, radius * radius - x * x))
	return height


static func _pane(panes: CottageMesh, left: float, right: float, bottom: float, top: float) -> void:
	for i: int in range(4):
		var u: float = i * 0.25
		var v: float = (i + 1) * 0.25
		var a: float = lerpf(left, right, u)
		var b: float = lerpf(left, right, v)
		panes.quad_uv(
			Vector3(a, bottom, 0.016),
			Vector3(b, bottom, 0.016),
			Vector3(b, top, 0.016),
			Vector3(a, top, 0.016),
			Vector3.BACK,
			Color.WHITE,
			Vector2(u, 0),
			Vector2(v, 0),
			Vector2(v, 1),
			Vector2(u, 1)
		)


static func _cross(frame: CottageMesh, radius: float, bottom: float, top: float) -> void:
	var center: float = (bottom + top) * 0.5
	frame.beam(Vector3(0, bottom, 0.045), Vector3(0, top, 0.045), 0.043, 0.044, DARK_WOOD)
	frame.beam(
		Vector3(-radius, center, 0.046), Vector3(radius, center, 0.046), 0.042, 0.046, DARK_WOOD
	)
