class_name ArchitecturalKit
extends RefCounted
## Repeated, beveled source sections. Opening panels keep their authored metre dimensions.

const TRIM: PackedScene = preload("res://assets/week_06/timber_trim.glb")
const POST: PackedScene = preload("res://assets/week_06/wood_post.glb")


static func assemble(spec: Dictionary, wood: Material, world: Array = []) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "TimberKit"
	var width: float = spec["size"][0]
	var depth: float = spec["size"][2]
	var height: float = spec["size"][1]
	var rounded: bool = spec["shape"] == "round"
	var facades: int = 1 if rounded else 4
	for facade: int in range(facades):
		var length: float = PI * width if rounded else (width if facade % 2 == 0 else depth)
		var steps: int = ceili(length / (0.6 if rounded else 1.0))
		for i: int in range(steps):
			var u: float = length * (float(i) + 0.5) / steps
			var hidden: bool = false
			for contact: Rect2 in BuildingContact.intervals(spec, world, facade):
				hidden = (
					hidden
					or (
						u >= contact.position.x
						and u <= contact.end.x
						and contact.end.y >= height - 0.09
					)
				)
			if hidden:
				continue
			var normal: Vector3 = BuildingGeometry._normal(u, facade, width, depth, rounded)
			var part: Node3D = TRIM.instantiate() as Node3D
			part.position = (
				BuildingGeometry._point(u, facade, width, depth, rounded) + normal * 0.025
			)
			part.position.y = height - 0.09
			part.rotation.y = atan2(normal.x, normal.z)
			part.scale.x = length / steps + 0.012
			WeekFourCatalog._paint(part, "trim", wood, wood)
			root.add_child(part)
	if not rounded:
		for x: float in [-width * 0.5, width * 0.5]:
			for z: float in [-depth * 0.5, depth * 0.5]:
				var span: Vector2 = _post_span(spec, Vector2(x, z), world)
				if span == Vector2.ZERO:
					continue
				var count_value: int = ceili(span.y / 0.9)
				for i: int in range(count_value):
					var post: Node3D = POST.instantiate() as Node3D
					post.position = Vector3(x, span.x + span.y * float(i) / count_value, z)
					post.scale.y = span.y / count_value / 0.9
					post.set_meta("kit_part", "wood_post")
					WeekFourCatalog._paint(post, "post", wood, wood)
					root.add_child(post)
	return root


static func _post_span(spec: Dictionary, corner: Vector2, world: Array) -> Vector2:
	var point: Vector2 = corner + Vector2(spec["position"][0], spec["position"][2])
	var bottom: float = spec["position"][1]
	var top: float = bottom + spec["size"][1]
	for other: Dictionary in world:
		if other["id"] == spec["id"] or other["shape"] != "rect":
			continue
		var shared: bool = false
		for x: float in [-0.5, 0.5]:
			for z: float in [-0.5, 0.5]:
				var p: Vector2 = Vector2(
					other["position"][0] + x * other["size"][0],
					other["position"][2] + z * other["size"][2]
				)
				shared = shared or point.distance_to(p) < 0.001
		if (
			shared
			and other["position"][1] <= top
			and other["position"][1] + other["size"][1] >= bottom
		):
			if other["id"] < spec["id"]:
				return Vector2.ZERO
			bottom = minf(bottom, other["position"][1])
			top = maxf(top, other["position"][1] + other["size"][1])
	return Vector2(bottom - spec["position"][1], top - bottom)
