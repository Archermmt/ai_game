extends "res://examples/shared/exhibit.gd"

func _ready() -> void:
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://street/rendering/camera_fit.json"))
	var axes: Array = cfg.basis
	camera.transform = Transform3D(Basis(_vec(axes[0]), _vec(axes[1]), _vec(axes[2])), _vec(cfg.position))
	camera.fov = cfg.fov
	camera.near = .1
	camera.far = 120.
	super()

func _vec(a: Array) -> Vector3:
	return Vector3(a[0],a[1],a[2])
