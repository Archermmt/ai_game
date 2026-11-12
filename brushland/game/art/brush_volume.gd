extends MeshInstance3D
## Draw the predicted volumes while the authoritative island stays untouched.
var signature: Array = []
var ghost: StandardMaterial3D

func _init() -> void:
	layers = 1 << 19
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	set_meta("batch_exclude", true)
	ghost = StandardMaterial3D.new()
	ghost.albedo_color = Color(0.79,0.88,0.73,0.55)
	ghost.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost.roughness = 1.0
	ghost.cull_mode = BaseMaterial3D.CULL_DISABLED

func reset(key: Array) -> bool:
	show()
	if signature == key:
		return false
	signature = key.duplicate()
	for child in get_children():child.free()
	return true

func buildings(view: IslandView, world: IslandData, objects: Array, key: Array) -> void:
	if not reset(key):
		return
	var state := BuildingRules.neighborhood(world)
	for object in objects:
		var node := view.create_building_model(object, state)
		node.position = Vector3(object.x+0.5, float(world.cell(Vector2i(object.x,object.z)).h)*0.5, object.z+0.5)
		node.rotation.y = -float(object.rotation)*PI/2
		add_child(node)
		for part: MeshInstance3D in node.find_children("*","MeshInstance3D",true,false):
			part.material_override = ghost
			part.layers = layers
			part.cast_shadow = cast_shadow

func terrain(data: IslandData, cells: Array, tool: String, key: Array) -> void:
	if cells.is_empty() or not reset(key):
		return
	var draft := IslandData.new()
	draft.tiles = data.tiles.duplicate(true)
	draft.objects = data.objects
	draft.paint(cells, tool)
	var surface := IslandSurface.new(draft.snapshot(),BuildingRules.neighborhood(draft).ground)
	var vertices := SurfaceTool.new()
	vertices.begin(Mesh.PRIMITIVE_TRIANGLES)
	var amount := 0
	for cell: Vector2i in cells:
		if not BuildingRules.inside(cell) or BuildingRules.occupied(data,cell,true):
			continue
		for z in range(2):
			for x in range(2):
				var base := Vector2(cell) - Vector2.ONE*0.5 + Vector2(x,z)*0.5
				for offset in [Vector2.ZERO,Vector2(0.5,0.5),Vector2(0,0.5),Vector2.ZERO,Vector2(0.5,0),Vector2(0.5,0.5)]:
					var p: Vector2 = base + offset
					var sample := surface.sample_surface(p)
					vertices.set_normal(sample.normal)
					vertices.set_color(surface.ground_color(p,sample) if sample.land else Color("7eaaa7"))
					vertices.add_vertex(Vector3(p.x,maxf(0.025,sample.height+0.018),p.y))
					amount += 1
	if amount == 0:
		return
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1,1,1,0.64)
	# A lowered future surface lies behind the current terrain until release.
	material.no_depth_test = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var result := MeshInstance3D.new()
	result.mesh = vertices.commit()
	result.material_override = material
	result.layers = layers
	result.cast_shadow = cast_shadow
	add_child(result)
