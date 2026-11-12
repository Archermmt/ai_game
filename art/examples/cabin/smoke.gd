extends MeshInstance3D
## Animate the chimney in live views while capture mode fixes the smoke phase.
var elapsed := 0.0
var fixed_capture := false

func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			fixed_capture = true
			return

func _process(delta: float) -> void:
	if fixed_capture:
		return
	elapsed += delta
	var plume := material_override as ShaderMaterial
	plume.set_shader_parameter("smoke_time", elapsed)
