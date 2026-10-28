extends Node3D
## Native GPU comparison; this deliberately does not use a headless viewport.
## Rows: albedo textures / normal maps; shader / mixed / alpha / overlay;
## transformed parent / shared multi-surface / next pass / excluded shader.
const BACKGROUND = Color("25302c")
const SIZE = Vector2i(960, 640)
const PIXEL_TOLERANCE = 3.0 / 255.0
var camera = Camera3D.new()
var props = Node3D.new()
var checks: Dictionary = {}
var red_material: StandardMaterial3D
var negative = false
var normal_negative = false

func solid_texture(color: Color) -> ImageTexture:
	var image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)

func checker_texture(a: Color, b: Color) -> ImageTexture:
	var image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in range(16):
		for x in range(16):
			image.set_pixel(x, y, a if (x / 4 + y / 4) % 2 == 0 else b)
	return ImageTexture.create_from_image(image)

func standard(color: Color = Color.WHITE, lit: bool = false) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL if lit else BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat

func shader_material(color: Color) -> ShaderMaterial:
	var shader = Shader.new()
	shader.code = "shader_type spatial; render_mode unshaded; uniform vec4 tint : source_color; void fragment(){ALBEDO=tint.rgb;}"
	var mat = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("tint", color)
	return mat

func quad(parent: Node3D, pos: Vector3, mat: Material, size: Vector2 = Vector2(0.85, 1.25)) -> MeshInstance3D:
	var node = MeshInstance3D.new()
	node.mesh = QuadMesh.new()
	node.mesh.size = size
	node.position = pos
	node.material_override = mat
	parent.add_child(node)
	return node

func pair(pos: Vector3, mat: Material, parent: Node3D = null) -> void:
	var target = props if parent == null else parent
	quad(target, pos + Vector3(-0.47, 0, 0), mat)
	quad(target, pos + Vector3(0.47, 0, 0), mat)

func mixed_mesh(a: Material, b: Material) -> ArrayMesh:
	var mesh = ArrayMesh.new()
	for half in range(2):
		var st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var left = -0.9 + half * 0.9
		var right = left + 0.9
		var points = [Vector3(left, -0.625, 0), Vector3(left, 0.625, 0), Vector3(right, 0.625, 0), Vector3(left, -0.625, 0), Vector3(right, 0.625, 0), Vector3(right, -0.625, 0)]
		var uvs = [Vector2(0, 1), Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 0), Vector2(1, 1)]
		for i in range(points.size()):
			st.set_normal(Vector3(0, 0, 1))
			st.set_uv(uvs[i])
			st.add_vertex(points[i])
		st.set_material(a if half == 0 else b)
		st.commit(mesh)
	return mesh

func tilted_mesh() -> ArrayMesh:
	# Bake the tilt into geometry, not the node basis. The local normal is then
	# non-axis-aligned and inverse-transpose handling matters under parent scale.
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tilt = Basis(Vector3.UP, 0.65)
	var points = [Vector3(-0.425, -0.625, 0), Vector3(-0.425, 0.625, 0), Vector3(0.425, 0.625, 0), Vector3(-0.425, -0.625, 0), Vector3(0.425, 0.625, 0), Vector3(0.425, -0.625, 0)]
	var uvs = [Vector2(0, 1), Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 0), Vector2(1, 1)]
	for i in range(points.size()):
		st.set_normal(tilt * Vector3(0, 0, 1))
		st.set_uv(uvs[i])
		st.add_vertex(tilt * points[i])
	st.generate_tangents()
	var mesh = st.commit()
	var arrays = mesh.surface_get_arrays(0)
	var shadow_arrays: Array = []
	shadow_arrays.resize(Mesh.ARRAY_MAX)
	shadow_arrays[Mesh.ARRAY_VERTEX] = arrays[Mesh.ARRAY_VERTEX].duplicate()
	if arrays[Mesh.ARRAY_INDEX] != null:
		shadow_arrays[Mesh.ARRAY_INDEX] = arrays[Mesh.ARRAY_INDEX].duplicate()
	var shadow = ArrayMesh.new()
	shadow.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, shadow_arrays)
	mesh.shadow_mesh = shadow
	return mesh

func inject_legacy_normal_error(mesh: ArrayMesh, parent_basis: Basis, material: Material) -> void:
	# Reproduce the known incorrect append_from normal transform in an isolated
	# negative control after real production batching, retaining its shadow mesh.
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(mesh, 0, Transform3D(parent_basis, Vector3.ZERO))
	var bad_normal: Vector3 = st.commit().surface_get_arrays(0)[Mesh.ARRAY_NORMAL][0]
	for child in props.get_children():
		if child is MeshInstance3D and child.material_override == material:
			var arrays = child.mesh.surface_get_arrays(0)
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for i in range(normals.size()):
				normals[i] = bad_normal
			arrays[Mesh.ARRAY_NORMAL] = normals
			var corrupted = ArrayMesh.new()
			corrupted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			corrupted.shadow_mesh = child.mesh.shadow_mesh
			child.mesh = corrupted

func sample(image: Image, pos: Vector3) -> Color:
	var pixel = camera.unproject_position(pos)
	return image.get_pixel(clampi(int(pixel.x), 0, image.get_width() - 1), clampi(int(pixel.y), 0, image.get_height() - 1))

func difference(a: Color, b: Color) -> float:
	return maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b)))

func settle() -> void:
	for i in range(12):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("MATERIAL_PROBE_FAIL native GPU required; do not run with --headless")
		get_tree().quit(1)
		return
	negative = "--negative-control" in OS.get_cmdline_user_args()
	normal_negative = "--normal-negative-control" in OS.get_cmdline_user_args()
	negative = negative or normal_negative
	get_window().content_scale_size = Vector2i.ZERO
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_window().size = SIZE
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	var world = WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = BACKGROUND
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color.WHITE
	world.environment.ambient_light_energy = 0.15
	add_child(world)
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-20, -35, 0)
	light.light_energy = 1.0
	light.shadow_enabled = true
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	light.directional_shadow_max_distance = 25.0
	light.shadow_bias = 0.02
	light.shadow_normal_bias = 0.1
	add_child(light)
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 7.0
	camera.position = Vector3(0, 0, 12)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	add_child(props)
	# Outside the batching boundary: a lit receiver proves shadow geometry is
	# actually consumed by the GPU, rather than merely present in a resource.
	var receiver = quad(self, Vector3(0, 0, -0.8), standard(Color("a5aaa5"), true), Vector2(10.2, 6.6))
	receiver.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Matching albedo colors with different textures must remain separate.
	red_material = standard()
	red_material.albedo_texture = checker_texture(Color("df614e"), Color("a93539"))
	var blue = standard()
	blue.albedo_texture = checker_texture(Color("508bd6"), Color("255394"))
	pair(Vector3(-3.6, 2.05, 0), red_material)
	pair(Vector3(-1.2, 2.05, 0), blue)
	# Same color/roughness/albedo texture; only the normal texture differs.
	var common_albedo = solid_texture(Color("b9b4ac"))
	var normal_flat = standard(Color.WHITE, true)
	normal_flat.albedo_texture = common_albedo
	normal_flat.normal_enabled = true
	normal_flat.normal_texture = solid_texture(Color(0.5, 0.5, 1.0))
	var normal_tilted = normal_flat.duplicate()
	normal_tilted.normal_texture = solid_texture(Color(0.9, 0.5, 0.8))
	pair(Vector3(1.2, 2.05, 0), normal_flat)
	pair(Vector3(3.6, 2.05, 0), normal_tilted)
	var green = shader_material(Color("68cd7e"))
	pair(Vector3(-3.6, 0, 0), green)
	checks.shader = Vector3(-4.07, 0, 0)
	# The whole mixed Standard/Shader node must survive batching.
	var mixed = MeshInstance3D.new()
	mixed.mesh = mixed_mesh(blue, shader_material(Color("efd36c")))
	mixed.position = Vector3(-1.2, 0, 0)
	props.add_child(mixed)
	checks.mixed_left = Vector3(-1.65, 0, 0)
	checks.mixed_right = Vector3(-0.75, 0, 0)
	# Alpha draws over a visible backplate, overlay over its own mesh.
	quad(props, Vector3(1.2, 0, -0.2), standard(Color("623975")), Vector2(1.8, 1.25))
	var alpha = standard(Color(0.1, 0.9, 0.8, 0.65))
	alpha.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pair(Vector3(1.2, 0, 0), alpha)
	checks.alpha = Vector3(0.73, 0, 0)
	var overlay = shader_material(Color("c47dc9"))
	for offset in [-0.47, 0.47]:
		var node = quad(props, Vector3(3.6 + offset, 0, 0), blue)
		node.material_overlay = overlay
	checks.overlay = Vector3(3.13, 0, 0)
	# Nonuniform parent transform must not change the output coordinates.
	var transformed = Node3D.new()
	transformed.position = Vector3(-3.6, -2.05, 0)
	transformed.rotation.z = 0.18
	transformed.scale = Vector3(1.15, 0.9, 0.38)
	props.add_child(transformed)
	var tilted = tilted_mesh()
	var transformed_material = red_material.duplicate()
	transformed_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	# Keep this cell's geometric normal directly visible; top-row cells exercise
	# normal textures separately so those cannot mask a geometric-normal fault.
	for offset in [-0.47, 0.47]:
		var node = MeshInstance3D.new()
		node.mesh = tilted
		node.material_override = transformed_material
		node.position.x = offset
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
		transformed.add_child(node)
	checks.transformed = transformed.to_global(Vector3(-0.47, 0, 0))
	# Two fully supported multi-surface nodes exercise surface retention.
	var shared_mesh = mixed_mesh(red_material, blue)
	for offset in [-0.47, 0.47]:
		var node = MeshInstance3D.new()
		node.mesh = shared_mesh
		node.position = Vector3(-1.2 + offset, -2.05, 0)
		node.scale.x = 0.47
		props.add_child(node)
	checks.standard_multi = Vector3(-1.88, -2.05, 0)
	var next_pass = standard(Color("b08b55"))
	next_pass.next_pass = shader_material(Color("d9a44f"))
	pair(Vector3(1.2, -2.05, 0), next_pass)
	checks.next_pass = Vector3(0.73, -2.05, 0)
	var excluded = Node3D.new()
	excluded.set_meta("batch_exclude", true)
	props.add_child(excluded)
	pair(Vector3(3.6, -2.05, 0), green, excluded)
	checks.excluded = Vector3(3.13, -2.05, 0)
	await settle()
	var before = get_viewport().get_texture().get_image()
	# Show that the custom-shadow caster creates visible shading in its own
	# projected region, below/right of the lower-left two tilted quads.
	# Keep the light's shadow shader path fixed; toggle casters instead of the
	# light so the reference changes occlusion alone.
	var casters: Array = []
	var queue: Array = [props]
	while not queue.is_empty():
		var node = queue.pop_back()
		for child in node.get_children():
			queue.append(child)
		if node is MeshInstance3D:
			casters.append([node, node.cast_shadow])
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	await settle()
	var shadow_off = get_viewport().get_texture().get_image()
	for caster in casters:
		caster[0].cast_shadow = caster[1]
	await settle()
	before = get_viewport().get_texture().get_image()
	var direction = -light.global_basis.z
	var shadow_center = transformed.global_position + direction * (-0.8 / direction.z)
	var shadow_pixel = camera.unproject_position(shadow_center)
	var shadow_pixels = 0
	for y in range(maxi(0, int(shadow_pixel.y) - 90), mini(SIZE.y, int(shadow_pixel.y) + 90)):
		for x in range(maxi(0, int(shadow_pixel.x) - 135), mini(SIZE.x, int(shadow_pixel.x) + 135)):
			var lit_color = shadow_off.get_pixel(x, y)
			var shaded_color = before.get_pixel(x, y)
			if (lit_color.r + lit_color.g + lit_color.b - shaded_color.r - shaded_color.g - shaded_color.b) / 3.0 > 0.03:
				shadow_pixels += 1
	var shadow_visible = shadow_pixels > 30
	var before_red = sample(before, Vector3(-4.07, 2.05, 0))
	var before_blue = sample(before, Vector3(-1.67, 2.05, 0))
	var flat = sample(before, Vector3(0.73, 2.05, 0))
	var tilted_color = sample(before, Vector3(3.13, 2.05, 0))
	var content_visible = before_red.r > before_red.b + 0.2 and before_blue.b > before_blue.r + 0.2
	content_visible = content_visible and difference(flat, tilted_color) > 0.025
	var sample_report: Dictionary = {}
	for id in checks:
		var color = sample(before, checks[id])
		sample_report[id] = {"before": color.to_html(false)}
		content_visible = content_visible and difference(color, BACKGROUND) > 0.08
	var stats = StaticBatcher.compact(props)
	if normal_negative:
		inject_legacy_normal_error(tilted, transformed.global_basis, transformed_material)
	if negative and not normal_negative:
		# A real visual corruption after batching must trip the pixel gate.
		red_material.albedo_texture = solid_texture(Color("22e7d1"))
	await settle()
	var after = get_viewport().get_texture().get_image()
	var total_delta = 0.0
	var changed = 0
	for y in range(before.get_height()):
		for x in range(before.get_width()):
			var a = before.get_pixel(x, y)
			var b = after.get_pixel(x, y)
			total_delta += (absf(a.r-b.r) + absf(a.g-b.g) + absf(a.b-b.b)) / 3.0
			if difference(a, b) > PIXEL_TOLERANCE:
				changed += 1
	for id in checks:
		sample_report[id].after = sample(after, checks[id]).to_html(false)
	var pixels = before.get_width() * before.get_height()
	var mean_delta = total_delta / pixels
	var changed_fraction = float(changed) / pixels
	var visual_match = mean_delta <= 0.001 and changed_fraction <= 0.005
	var exercised = int(stats.get("merged_source_count", 0)) >= 8 and int(stats.get("preserved", 0)) >= 8 and int(stats.get("shadow_batches", 0)) > 0 and int(stats.get("merged_shadow_source_count", 0)) >= 2
	var method = RenderingServer.get_current_rendering_method()
	var label = method + ("_normal_negative" if normal_negative else "_negative" if negative else "")
	var folder = "res://snapshots/art_i1/materials/"
	DirAccess.make_dir_recursive_absolute(folder)
	if before.save_png(folder + label + "_before.png") != OK or after.save_png(folder + label + "_after.png") != OK:
		print("MATERIAL_PROBE_FAIL screenshot write failed")
		get_tree().quit(1)
		return
	shadow_off.save_png(folder + label + "_shadow_off.png")
	var report = {"renderer": method, "driver": RenderingServer.get_current_rendering_driver_name(), "resolution": [SIZE.x, SIZE.y], "native_gpu": true, "negative_control": negative, "corruption": "legacy_normal_transform" if normal_negative else "albedo_texture" if negative else "none", "content_visible": content_visible, "shadow_visible": shadow_visible, "shadow_region_pixels": shadow_pixels, "shadow_off": folder + label + "_shadow_off.png", "normal_lighting_difference": difference(flat, tilted_color), "nonuniform_parent_scale": [1.15, 0.9, 0.38], "geometry_y_tilt": 0.65, "real_batch_exercised": exercised, "batch_stats": stats, "mean_rgb_error": mean_delta, "changed_pixel_fraction": changed_fraction, "pixel_tolerance": PIXEL_TOLERANCE, "mean_error_limit": 0.001, "changed_fraction_limit": 0.005, "visual_match": visual_match, "samples": sample_report, "before": folder + label + "_before.png", "after": folder + label + "_after.png"}
	DirAccess.make_dir_recursive_absolute("res://docs/reports/art_i1")
	var file = FileAccess.open("res://docs/reports/art_i1/materials_" + label + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	if negative:
		print("MATERIAL_PROBE_NEGATIVE ", JSON.stringify(report))
		get_tree().quit(1 if content_visible and shadow_visible and exercised and not visual_match else 2)
	else:
		var passed = content_visible and shadow_visible and exercised and visual_match
		print("MATERIAL_PROBE_PASS " if passed else "MATERIAL_PROBE_FAIL ", JSON.stringify(report))
		get_tree().quit(0 if passed else 1)
