class_name OpeningAssembly
extends RefCounted
## Five formal opening packs; sizes remain authored metres on flat and curved walls.

const PACKS: Dictionary = {
	"plank": preload("res://assets/buildings/door_plank.glb"),
	"arch": preload("res://assets/buildings/door_arch.glb"),
	"glass": preload("res://assets/buildings/door_glass.glb"),
	"rect_window": preload("res://assets/buildings/window_rect.glb"),
	"round_window": preload("res://assets/week_07/window_round.glb")
}


static func attach(view: Node3D, spec: Dictionary, paint: Callable) -> void:
	for opening: Dictionary in spec["openings"]:
		var is_window: bool = opening["height"] < 1.8
		var kind: String = "round_window" if opening["kind"] == "round" else "rect_window"
		if not is_window:
			kind = "arch" if opening["kind"] == "arch" else "plank"
			if opening.get("variant") == "glass":
				kind = "glass"
		var node: Node3D = PACKS[kind].instantiate() as Node3D
		node.set_meta("opening_kind", kind)
		var width: float = spec["size"][0]
		var depth: float = spec["size"][2]
		var facade: int = int(opening.get("facade", 0))
		var rounded: bool = spec["shape"] == "round"
		var length: float = PI * width if rounded else (width if facade % 2 == 0 else depth)
		var u: float = opening["center"] * length
		var normal: Vector3 = BuildingGeometry._normal(u, facade, width, depth, rounded)
		node.position = (
			BuildingGeometry._point(u, facade, width, depth, rounded)
			- normal * 0.05
			+ Vector3.UP * opening.get("sill", 0)
		)
		node.rotation.y = atan2(normal.x, normal.z)
		view.add_child(node)
		paint.call(node)
