class_name LandscapeLab
extends Node3D
## A disposable art study. Author geometry and source data remain separate from rendering.

const FONT: Font = preload("res://assets/fonts/NotoSansSC-Regular.otf")
const GRASS_SHADER: Shader = preload("res://features/landscape_lab/valley_grass.gdshader")
const LOCAL: String = "res://assets/painterly_grass/local/valley/"
const IDS: Array[String] = ["blades", "detail", "puffs", "floor"]

var lab_ready: bool = false
var lab_failed: bool = false
var distribution: int = 0
var distribution_busy: bool = false
var paused: bool = false
var elapsed: float = 0.0
var terrain_adapter: LandscapeTerrainAdapter
var camera_rig: OrbitCamera
var sun: DirectionalLight3D
var environment: Environment
var layers: Array[MultiMeshInstance3D] = []
var layer_materials: Array[ShaderMaterial] = []
var scenery_materials: Array[ShaderMaterial] = []
var layer_toggles: Array[CheckButton] = []
var source_scatter: Dictionary = {}
var source_poses: Array[Array] = []
var plugin_poses: Array[Array] = []
var distribution_picker: OptionButton
var view_picker: OptionButton
var status: Label
var pause_button: Button
var reference: TextureRect
var reference_close: Button
var controls: CanvasLayer
var scenery: Node3D
var _sky: PaintedSky


func _ready() -> void:
	get_window().title = "山谷草地 · Terrain3D × ProtonScatter | 风栖小筑"
	_setup_environment()
	_setup_ui()
	_prepare.call_deferred()


# gdlint: disable=max-returns
func _prepare() -> void:
	if not FileAccess.file_exists(LOCAL + "terrain_height.r32"):
		_fail("缺少本地山谷源件，请先运行 Valley 提取工具。")
		return
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(LOCAL + "terrain_height.r32")
	if bytes.size() != 256 * 256 * 4:
		_fail("山谷高度图格式不正确。")
		return
	var image: Image = Image.create_from_data(256, 256, false, Image.FORMAT_RF, bytes)
	terrain_adapter = LandscapeTerrainAdapter.new()
	terrain_adapter.name = "ValleyTerrain"
	add_child(terrain_adapter)
	terrain_adapter.configure(image)
	terrain_adapter.set_camera(camera_rig.camera)
	var deadline: int = Time.get_ticks_msec() + 30000
	while not terrain_adapter.data_ready and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if not terrain_adapter.data_ready:
		_fail("Terrain3D 没有完成高度图导入。")
		return
	source_scatter = JSON.parse_string(FileAccess.get_file_as_string(LOCAL + "scatter_full.json"))
	if source_scatter.get("layers", []).size() != 4:
		_fail("四层草地的源数据不完整。")
		return
	var coverage: Texture2D = await _load_resource(LOCAL + "coverage4k.png") as Texture2D
	if coverage == null:
		return
	var terrain_texture: ImageTexture = ImageTexture.create_from_image(terrain_adapter.height_image)
	for kind: int in 4:
		var pack: PackedScene = await _load_resource(LOCAL + IDS[kind] + ".glb") as PackedScene
		if pack == null:
			return
		var mesh: Mesh = PainterlyGrassSamples.mesh_from(pack)
		if mesh == null:
			_fail("草地模型没有可用网格。")
			return
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = GRASS_SHADER
		material.set_shader_parameter("coverage", coverage)
		material.set_shader_parameter("conform_ground", true)
		material.set_shader_parameter("terrain_map", terrain_texture)
		material.set_shader_parameter("terrain_spacing", 0.25)
		# The floor layer joins the ground; taller tips carry the warm brush light.
		material.set_shader_parameter(
			"tip_color", Color("82954e") if kind == 3 else Color("a2aa6b")
		)
		material.set_shader_parameter("root_color", Color("495e36"))
		layer_materials.append(material)
		var view: MultiMeshInstance3D = MultiMeshInstance3D.new()
		view.name = ["GrassBlades", "DetailedPuffs", "BroadPuffs", "GroundCover"][kind]
		view.multimesh = MultiMesh.new()
		view.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		view.multimesh.use_custom_data = true
		view.multimesh.mesh = mesh
		view.material_override = material
		view.extra_cull_margin = 1.0
		view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(view)
		layers.append(view)
		var poses: Array[Transform3D] = []
		for item: Dictionary in source_scatter["layers"][kind]["instances"]:
			var b: Array = item["basis"]
			var pose: Transform3D = Transform3D(
				Basis(_vec(b[0]), _vec(b[1]), _vec(b[2])), _vec(item["position_local"])
			)
			var point: Vector2 = Vector2(pose.origin.x, pose.origin.z)
			pose.origin.y = (
				float(terrain_adapter.sample_surface(point)["height"])
				+ float(item["ground_offset_m"])
			)
			poses.append(pose)
		source_poses.append(poses)
		_publish(kind, poses)
	var texture: Texture2D = await _load_resource(LOCAL + "reference.png") as Texture2D
	if texture == null:
		return
	reference.texture = texture
	camera_rig.surface_height = _height_at
	await _setup_scenery()
	lab_ready = true
	for toggle: CheckButton in layer_toggles:
		toggle.disabled = false
	distribution_picker.disabled = false
	pause_button.disabled = false
	set_view(0)
	_update_status()


func _load_resource(path: String) -> Resource:
	if not ResourceLoader.exists(path) or ResourceLoader.load_threaded_request(path) != OK:
		_fail("无法读取本地资产：" + path.get_file())
		return null
	while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
	if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_LOADED:
		_fail("资产加载失败：" + path.get_file())
		return null
	return ResourceLoader.load_threaded_get(path)


func _setup_environment() -> void:
	get_viewport().msaa_3d = Viewport.MSAA_4X
	get_viewport().use_taa = true
	get_viewport().positional_shadow_atlas_size = 4096
	camera_rig = OrbitCamera.new()
	camera_rig.name = "LandscapeCamera"
	add_child(camera_rig)
	camera_rig.camera.far = 240
	environment = Environment.new()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b9cbdc")
	environment.ambient_light_energy = 0.48
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.ssao_enabled = true
	environment.ssao_radius = 0.7
	environment.ssao_intensity = 1.5
	environment.ssao_light_affect = 0.25
	environment.fog_enabled = true
	environment.fog_light_color = Color("adbfc3")
	environment.fog_density = 0.0025
	_sky = PaintedSky.new()
	_sky.configure(environment)
	_sky.sync(0.0, 1.0, 10.5, true, {"cloud": 0.2, "dust": 0.0})
	var world: WorldEnvironment = WorldEnvironment.new()
	world.name = "LandscapeAtmosphere"
	world.environment = environment
	add_child(world)
	sun = DirectionalLight3D.new()
	sun.name = "ValleySun"
	sun.rotation_degrees = Vector3(-34, -52, 0)
	sun.light_color = Color("fff7e5")
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 100
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.shadow_bias = 0.025
	sun.shadow_normal_bias = 0.45
	add_child(sun)


func _setup_ui() -> void:
	controls = CanvasLayer.new()
	controls.name = "LandscapeControls"
	add_child(controls)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 14)
	var theme: Theme = Theme.new()
	theme.default_font = FONT
	theme.default_font_size = 17
	margin.theme = theme
	controls.add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	margin.add_child(column)
	var title: Label = Label.new()
	title.text = "山谷草地 · 地形与四层植被样板"
	title.add_theme_font_size_override("font_size", 25)
	column.add_child(title)
	var row: HBoxContainer = HBoxContainer.new()
	column.add_child(row)
	distribution_picker = OptionButton.new()
	distribution_picker.name = "Distribution"
	distribution_picker.add_item("Demo 原始布局")
	distribution_picker.add_item("ProtonScatter 布局")
	distribution_picker.disabled = true
	distribution_picker.item_selected.connect(set_distribution)
	row.add_child(distribution_picker)
	view_picker = OptionButton.new()
	view_picker.name = "LandscapeView"
	for text: String in ["Demo 机位", "山谷俯瞰", "草丛近景"]:
		view_picker.add_item(text)
	view_picker.item_selected.connect(set_view)
	row.add_child(view_picker)
	pause_button = _button(row, "暂停风", "PauseWind")
	pause_button.disabled = true
	pause_button.pressed.connect(func() -> void: set_paused(not paused))
	var ref_button: Button = _button(row, "查看官方参考", "ShowReference")
	ref_button.pressed.connect(func() -> void: show_reference(true))
	var reset: Button = _button(row, "重置视角", "ResetView")
	reset.pressed.connect(func() -> void: set_view(view_picker.selected))
	var back_button: Button = _button(row, "返回草地展示", "BackToGrassLab")
	var loader: PainterlyPreviewLoader = PainterlyPreviewLoader.new()
	loader.name = "PreviewSceneLoader"
	add_child(loader)
	back_button.pressed.connect(
		func() -> void: loader.request_load("res://app/painterly_grass_preview.tscn")
	)
	loader.loading_completed.connect(
		func(resource: Resource) -> void: get_tree().change_scene_to_packed(resource as PackedScene)
	)
	var layers_row: HBoxContainer = HBoxContainer.new()
	column.add_child(layers_row)
	for i: int in 4:
		var toggle: CheckButton = CheckButton.new()
		toggle.name = "GrassLayer%d" % i
		toggle.text = ["细草叶", "细节草团", "蓬松草团", "地被"][i]
		toggle.button_pressed = true
		toggle.disabled = true
		toggle.toggled.connect(func(enabled: bool) -> void: set_layer_enabled(i, enabled))
		layers_row.add_child(toggle)
		layer_toggles.append(toggle)
	status = Label.new()
	status.text = "正在导入源地形与草地……"
	column.add_child(status)
	var hint: Label = Label.new()
	hint.text = "右键拖动环绕 · 滚轮或双指缩放 · 中键平移 · Esc 关闭参考图"
	hint.add_theme_font_size_override("font_size", 14)
	column.add_child(hint)
	for label: Label in [title, status, hint]:
		label.add_theme_color_override("font_color", Color("f8f4e2"))
		label.add_theme_color_override("font_shadow_color", Color("233228"))
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
	var reference_layer: CanvasLayer = CanvasLayer.new()
	reference_layer.name = "OfficialReference"
	reference_layer.layer = 10
	add_child(reference_layer)
	reference = TextureRect.new()
	reference.name = "ValleyReference"
	reference.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	reference.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	reference.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	reference.hide()
	reference_layer.add_child(reference)
	reference_close = Button.new()
	reference_close.text = "关闭参考图"
	reference_close.theme = theme
	reference_close.position = Vector2(20, 20)
	reference_close.hide()
	reference_close.pressed.connect(func() -> void: show_reference(false))
	reference_layer.add_child(reference_close)


func _setup_scenery() -> void:
	scenery = Node3D.new()
	scenery.name = "ExistingForestAssets"
	add_child(scenery)
	ArtFoliageCatalog.configure(
		preload("res://features/art_direction/materials/painted_foliage.gdshader")
	)
	var scatter: LandscapeScatterAdapter = LandscapeScatterAdapter.new()
	var poses: Array[Transform3D] = await scatter.generate(
		self,
		Rect2(-27, -27, 54, 54),
		95,
		251025,
		func(point: Vector2) -> Dictionary:
			var sample: Dictionary = terrain_adapter.sample_surface(point)
			sample["allowed"] = point.length() > 20.0 and sample["normal"].y > 0.75
			return sample,
		{"scale_min": 1.5, "scale_max": 2.6, "normal_alignment": 0.0}
	)
	for i: int in poses.size():
		var tree: Node3D = ArtFoliageCatalog.create(
			"NAT-02" if i % 3 else "NAT-01", "landscape:%d" % i, null, null
		)
		tree.transform = poses[i]
		scenery.add_child(tree)
		for part: MeshInstance3D in tree.find_children("*", "MeshInstance3D", true, false):
			var material: ShaderMaterial = part.material_override as ShaderMaterial
			if material != null and material not in scenery_materials:
				material.set_shader_parameter("freeze_time", true)
				scenery_materials.append(material)


func set_distribution(index: int) -> void:
	if not lab_ready or distribution_busy or index < 0 or index > 1:
		return
	distribution_busy = true
	distribution_picker.disabled = true
	if index == 1 and plugin_poses.is_empty():
		status.text = "ProtonScatter 正在生成四层草地……"
		for kind: int in 4:
			var values: Array = source_scatter["layers"][kind]["instances"]
			var scale_sum: float = 0.0
			var offset_sum: float = 0.0
			for item: Dictionary in values:
				scale_sum += _vec(item["basis"][1]).length()
				offset_sum += float(item["ground_offset_m"])
			var scale_mean: float = scale_sum / values.size()
			var scatter: LandscapeScatterAdapter = LandscapeScatterAdapter.new()
			var poses: Array[Transform3D] = await scatter.generate(
				self,
				_layer_region(values),
				values.size(),
				251026 + kind * 601,
				terrain_adapter.sample_surface,
				{
					"scale_min": scale_mean * 0.78,
					"scale_max": scale_mean * 1.22,
					"normal_alignment": 0.92,
					"root_offset_m": offset_sum / values.size(),
					"max_slope_degrees": 48.0
				}
			)
			plugin_poses.append(poses)
			await get_tree().process_frame
	distribution = index
	var all_poses: Array[Array] = source_poses if index == 0 else plugin_poses
	for kind: int in 4:
		_publish(kind, all_poses[kind])
		layer_materials[kind].set_shader_parameter("conform_ground", true)
	distribution_picker.select(index)
	distribution_picker.disabled = false
	distribution_busy = false
	_update_status()


func _publish(kind: int, poses: Array) -> void:
	var batch: MultiMesh = layers[kind].multimesh
	batch.instance_count = poses.size()
	for i: int in poses.size():
		batch.set_instance_transform(i, poses[i])
		var phase: float = float(posmod(("%s:%d" % [IDS[kind], i]).hash(), 10000)) / 10000.0
		var tint: float = float(posmod(("color:%d:%d" % [kind, i]).hash(), 10000)) / 10000.0
		batch.set_instance_custom_data(
			i, Color(phase, 0.08 if kind == 3 else 1.0, float(kind), tint)
		)


func set_layer_enabled(index: int, enabled: bool) -> void:
	if index >= 0 and index < layers.size():
		layers[index].visible = enabled
		layer_toggles[index].set_pressed_no_signal(enabled)


func set_paused(enabled: bool) -> void:
	paused = enabled
	pause_button.text = "继续风" if enabled else "暂停风"


func set_view(index: int) -> void:
	if not lab_ready:
		return
	view_picker.select(index)
	camera_rig.camera.attributes = null
	camera_rig.camera.keep_aspect = Camera3D.KEEP_HEIGHT
	if index == 0:
		var matrix: Array = source_scatter["source_camera"]["matrix_blender"]
		var center: Array = source_scatter["source_center_blender"]
		var basis: Basis = Basis(
			Vector3(matrix[0][0], matrix[2][0], -matrix[1][0]),
			Vector3(matrix[0][1], matrix[2][1], -matrix[1][1]),
			Vector3(matrix[0][2], matrix[2][2], -matrix[1][2])
		)
		var origin: Vector3 = Vector3(
			matrix[0][3] - center[0], matrix[2][3] - center[2], center[1] - matrix[1][3]
		)
		camera_rig.camera.transform = Transform3D(basis, origin)
		camera_rig.camera.keep_aspect = Camera3D.KEEP_WIDTH
		camera_rig.camera.fov = rad_to_deg(2.0 * atan(36.0 / (2.0 * 17.0)))
		camera_rig.target = origin - basis.z * 22.0
		camera_rig.distance = 22.0
		camera_rig.yaw = atan2(basis.z.x, basis.z.z)
		camera_rig.pitch = asin(basis.z.y)
	elif index == 1:
		camera_rig.target = Vector3(0, -1.5, 0)
		camera_rig.distance = 52
		camera_rig.yaw = -1.1
		camera_rig.pitch = 0.75
		camera_rig.camera.fov = 52
		camera_rig.refresh()
	else:
		var foot: Vector2 = Vector2(-8, -2)
		var eye: Vector3 = Vector3(foot.x, _height_at(foot) + 1.65, foot.y)
		camera_rig.camera.position = eye
		camera_rig.camera.fov = 65
		camera_rig.camera.look_at(Vector3(1, _height_at(Vector2(1, 4)) + 0.35, 4))
		var back: Vector3 = camera_rig.camera.basis.z
		camera_rig.target = eye - back * 12
		camera_rig.distance = 12
		camera_rig.yaw = atan2(back.x, back.z)
		camera_rig.pitch = asin(back.y)


func show_reference(enabled: bool) -> void:
	reference.visible = enabled
	reference_close.visible = enabled
	camera_rig.set_process_unhandled_input(not enabled)


func _process(delta: float) -> void:
	if not paused:
		elapsed += delta
	for material: ShaderMaterial in layer_materials:
		material.set_shader_parameter("sample_time", elapsed)
	for material: ShaderMaterial in scenery_materials:
		material.set_shader_parameter("sample_time", elapsed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cancel_edit"):
		show_reference(false)
		get_viewport().set_input_as_handled()


func _height_at(point: Vector2) -> float:
	# Orbit views can put the camera outside the finite study surface.
	var sample: Dictionary = terrain_adapter.sample_surface(
		point.clamp(Vector2(-31.5, -31.5), Vector2(31.5, 31.5))
	)
	return float(sample["height"])


func _update_status() -> void:
	status.text = (
		"%s · 四层可分别开关 · 只读美术样板" % ("Demo 原始植被位置" if distribution == 0 else "ProtonScatter 散布与贴地")
	)


func _fail(message: String) -> void:
	lab_failed = true
	status.text = message
	push_error(message)


static func _vec(values: Array) -> Vector3:
	return Vector3(values[0], values[1], values[2])


static func _button(parent: Control, text: String, node_name: String) -> Button:
	var button: Button = Button.new()
	button.name = node_name
	button.text = text
	parent.add_child(button)
	return button


static func _layer_region(values: Array) -> Rect2:
	var first: Array = values[0]["position_local"]
	var region: Rect2 = Rect2(Vector2(first[0], first[2]), Vector2.ZERO)
	for item: Dictionary in values:
		var point: Array = item["position_local"]
		region = region.expand(Vector2(point[0], point[2]))
	return region
