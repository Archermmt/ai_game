extends RefCounted

# Draw only the perimeter of a stroke so the player can see the ground it affects.
static func outline(parent: Node3D, surface: IslandSurface, area: Dictionary, valid: bool) -> void:
	if area.is_empty():
		return
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	var edges := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	for p: Vector2i in area:
		for dir: Vector2i in edges:
			if area.has(p + dir):
				continue
			var midpoint := Vector2(p) + 0.48 * Vector2(dir)
			var edge := 0.48 * Vector2(-dir.y, dir.x)
			line(builder, surface, midpoint - edge, midpoint, 0.032)
			line(builder, surface, midpoint, midpoint + edge, 0.032)
		if area[p]:
			var center := Vector2(p)
			line(builder, surface, center - Vector2(0.2, 0.2), center + Vector2(0.2, 0.2), 0.023)
			line(builder, surface, center - Vector2(0.2, -0.2), center + Vector2(0.2, -0.2), 0.023)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("fff1ca") if valid else Color("ffb894")
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var marker := MeshInstance3D.new()
	marker.mesh = builder.commit()
	marker.material_override = mat
	marker.layers = 1 << 19
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(marker)

static func line(mesh: SurfaceTool, surface: IslandSurface, a: Vector2, b: Vector2, width: float) -> void:
	var normal := (b - a).normalized().orthogonal() * width
	for p: Vector2 in [a-normal, a+normal, b+normal, a-normal, b+normal, b-normal]:
		mesh.add_vertex(Vector3(p.x, maxf(-0.04, surface.height_at(p)) + 0.036, p.y))
