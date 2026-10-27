class_name PainterlyGrassLab
extends Node3D
## Standalone G1 display: no save service, world document or preference loading.

const FONT: Font = preload("res://assets/fonts/NotoSansSC-Regular.otf")
const LABELS: Array[String] = ["现有草 · 三叶细草", "新草 A · 扇形笔触", "新草 B · 柔软草束", "新草 C · 低矮地被"]

var loaded: bool = false
var failed: bool = false
var paused: bool = false
var rotating: bool = false
var reduced_motion: bool = false
var motion_toggle: CheckButton
var sample_paths: Array[String] = PainterlyGrassSamples.paths()
var elapsed: float = 0.0
var wind: float = 0.45
var meshes: Array[Mesh] = []
var paint: ShaderMaterial
var old_paint: ShaderMaterial
var rig: OrbitCamera
var sun: DirectionalLight3D
var environment: Environment
var panels: CanvasLayer
var pause_button: Button
var rotate_button: Button
var reset_button: Button
var light_picker: OptionButton
var wind_slider: HSlider
var view_picker: OptionButton
var status: Label
var samples: Node3D
var headers: Array[Label3D] = []
var _light_mode: int = 0


func _ready() -> void:
	get_window().title = "G1 · 新草单体展示 | 风栖小筑"
	if "--g1-fhd" in OS.get_cmdline_user_args():
		get_window().content_scale_size = Vector2i(1920, 1080)
		get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	get_viewport().use_taa = true
	_setup_world()
	_setup_ui()
	_load_samples.call_deferred()


func _setup_world() -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("dce5d7")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c4d4d0")
	environment.ambient_light_energy = 0.45
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	var world: WorldEnvironment = WorldEnvironment.new()
	world.name = "WorldEnvironment"
	world.environment = environment
	add_child(world)
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-42, -32, 0)
	sun.light_color = Color("fff8ec")
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	add_child(sun)
	var ground: MeshInstance3D = MeshInstance3D.new()
	ground.name = "StudioGround"
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(80, 80)
	ground.mesh = plane
	ground.material_override = _solid(Color("8e9f89"))
	ground.position.y = -0.15
	add_child(ground)
	rig = OrbitCamera.new()
	rig.name = "ViewRig"
	rig.touchpad_orbit = true
	add_child(rig)
	set_view(0)
	samples = Node3D.new()
	samples.name = "Samples"
	add_child(samples)
	for i: int in 4:
		var base: MeshInstance3D = MeshInstance3D.new()
		base.name = "SamplePlinth%d" % i
		var cylinder: CylinderMesh = CylinderMesh.new()
		cylinder.top_radius = 1.18
		cylinder.bottom_radius = 1.18
		cylinder.height = 0.12
		cylinder.radial_segments = 64
		base.mesh = cylinder
		base.position = Vector3(_x(i), -0.06, 0)
		base.material_override = _solid(Color("60734f"))
		samples.add_child(base)
		var label: Label3D = Label3D.new()
		label.name = "SampleLabel%d" % i
		label.font = FONT
		label.text = LABELS[i]
		label.font_size = 48
		label.pixel_size = 0.003
		label.position = Vector3(_x(i), 0.1, 1.65)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = Color("253e31")
		label.outline_size = 0
		samples.add_child(label)
		headers.append(label)
	var ruler: MeshInstance3D = MeshInstance3D.new()
	ruler.name = "OneMeterRuler"
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(0.025, 1.0, 0.025)
	ruler.mesh = box
	ruler.position = Vector3(-6.0, 0.5, -0.4)
	ruler.material_override = _solid(Color("d5b67b"))
	add_child(ruler)
	var text: Label3D = Label3D.new()
	text.name = "RulerCaption"
	text.text = "1 m"
	text.font = FONT
	text.font_size = 44
	text.pixel_size = 0.007
	text.position = Vector3(-6, 1.15, -0.4)
	text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	text.modulate = Color("253e31")
	add_child(text)


func _setup_ui() -> void:
	panels = CanvasLayer.new()
	panels.name = "PreviewControls"
	add_child(panels)
	var margin: MarginContainer = MarginContainer.new()
	margin.name = "HeaderMargin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 24)
	var theme: Theme = Theme.new()
	theme.default_font = FONT
	theme.default_font_size = 18
	margin.theme = theme
	panels.add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.name = "Controls"
	margin.add_child(column)
	var title: Label = Label.new()
	title.text = "草木试验室  /  G1 单体与材质"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("253e31"))
	column.add_child(title)
	var subtitle: Label = Label.new()
	subtitle.text = "单体与历史对照 · 正式庭园已采用四层草 · 可进入 G4 满容量体验"
	subtitle.add_theme_color_override("font_color", Color("476050"))
	column.add_child(subtitle)
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Toolbar"
	row.add_theme_constant_override("separation", 10)
	column.add_child(row)
	view_picker = OptionButton.new()
	view_picker.name = "ViewPicker"
	for text: String in ["全部样本", "近看新草 A", "近看新草 B", "近看地被", "低机位", "背面"]:
		view_picker.add_item(text)
	view_picker.item_selected.connect(set_view)
	row.add_child(view_picker)
	light_picker = OptionButton.new()
	light_picker.name = "LightPicker"
	for text: String in ["日间", "树荫", "逆光"]:
		light_picker.add_item(text)
	light_picker.item_selected.connect(set_light)
	row.add_child(light_picker)
	pause_button = _button(row, "暂停风", "PauseWind")
	pause_button.pressed.connect(toggle_pause)
	rotate_button = _button(row, "自动绕转", "AutoOrbit")
	rotate_button.pressed.connect(toggle_orbit)
	reset_button = _button(row, "重置", "Reset")
	reset_button.pressed.connect(reset)
	var wind_label: Label = Label.new()
	wind_label.text = "风量"
	wind_label.add_theme_color_override("font_color", Color("253e31"))
	row.add_child(wind_label)
	wind_slider = HSlider.new()
	wind_slider.name = "WindStrength"
	wind_slider.custom_minimum_size = Vector2(130, 32)
	wind_slider.max_value = 1.0
	wind_slider.step = 0.05
	wind_slider.value = wind
	wind_slider.value_changed.connect(set_wind)
	row.add_child(wind_slider)
	motion_toggle = CheckButton.new()
	motion_toggle.name = "ReduceMotion"
	motion_toggle.text = "减少动态"
	motion_toggle.add_theme_color_override("font_color", Color("253e31"))
	motion_toggle.toggled.connect(set_reduced_motion)
	row.add_child(motion_toggle)
	var patch_button: Button = _button(row, "庭园对照 G2", "OpenPatch")
	var loader: PainterlyPreviewLoader = PainterlyPreviewLoader.new()
	loader.name = "PatchSceneLoader"
	add_child(loader)
	patch_button.pressed.connect(
		func() -> void:
			patch_button.disabled = true
			loader.request_load("res://app/painterly_grass_patch.tscn")
	)
	loader.loading_failed.connect(
		func(_path: String) -> void:
			patch_button.disabled = false
			status.text = "庭园场景读取失败，可继续体验单体。"
	)
	loader.loading_completed.connect(
		func(resource: Resource) -> void: get_tree().change_scene_to_packed(resource as PackedScene)
	)
	var garden_button: Button = _button(row, "编辑庭园 G3", "OpenGarden")
	garden_button.pressed.connect(
		func() -> void: loader.request_load("res://app/painterly_grass_garden.tscn")
	)
	var landscape_row: HBoxContainer = HBoxContainer.new()
	column.add_child(landscape_row)
	var landscape_button: Button = _button(landscape_row, "山谷地形与草地样板", "OpenLandscape")
	landscape_button.pressed.connect(
		func() -> void: loader.request_load("res://app/landscape_lab.tscn")
	)
	var capacity_button: Button = _button(landscape_row, "满容量体验 G4", "OpenCapacity")
	capacity_button.pressed.connect(
		func() -> void: loader.request_load("res://app/grass_capacity.tscn")
	)
	var weather_button: Button = _button(landscape_row, "云与雪材质样板", "OpenWeather")
	weather_button.pressed.connect(
		func() -> void: loader.request_load("res://app/weather_plugin_lab.tscn")
	)
	status = Label.new()
	status.name = "LoadStatus"
	status.text = "正在准备本地草样本……"
	status.add_theme_font_size_override("font_size", 15)
	status.add_theme_color_override("font_color", Color("476050"))
	column.add_child(status)
	var footer: Label = Label.new()
	footer.name = "Instructions"
	footer.theme = theme
	footer.text = "右键拖动 / Mac 双指旋转 · 滚轮 / 捏合缩放 · 近景前方为 1.7× 单株展示 · Esc 恢复全景"
	footer.add_theme_color_override("font_color", Color("253e31"))
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_left = 24
	footer.offset_top = -45
	panels.add_child(footer)


func _load_samples() -> void:
	var paths: Array[String] = sample_paths
	for path: String in paths:
		if not ResourceLoader.exists(path):
			failed = true
			status.text = "本机派生素材未准备；请先运行 extract_painterly_grass.py。没有加载替代旧草。"
			return
		var error: Error = ResourceLoader.load_threaded_request(path)
		if error != OK:
			failed = true
			status.text = "无法准备草素材：%s" % path
			return
		while (
			ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS
		):
			await get_tree().process_frame
		if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_LOADED:
			failed = true
			status.text = "草素材导入失败：%s" % path
			return
		if path.ends_with(".glb"):
			var packed: PackedScene = ResourceLoader.load_threaded_get(path) as PackedScene
			meshes.append(PainterlyGrassSamples.mesh_from(packed))
		else:
			paint = PainterlyGrassSamples.material(
				ResourceLoader.load_threaded_get(path) as Texture2D
			)
	old_paint = ShaderMaterial.new()
	old_paint.shader = PainterlyGrassSamples.OLD_SHADER
	old_paint.set_shader_parameter("freeze_time", true)
	for i: int in 4:
		var mesh: Mesh = MeadowData.blade_mesh() if i == 0 else meshes[i - 1]
		var material: ShaderMaterial = old_paint if i == 0 else paint
		var view: MultiMeshInstance3D = PainterlyGrassSamples.batch(mesh, material, i)
		view.name = "GrassPatch%d" % i
		view.position.x = _x(i)
		samples.add_child(view)
		if i > 0:
			var hero: MultiMeshInstance3D = PainterlyGrassSamples.batch(mesh, material, i, true)
			hero.name = "SingleSample%d" % i
			hero.position = Vector3(_x(i), 0.0, 2.65)
			samples.add_child(hero)
	loaded = true
	status.text = "已就绪：3 种新草 / 每种 8 三角 / 1 张共享 2K 遮罩 · 暂停后可检查侧面与刷痕"
	_sync_materials()


func _process(delta: float) -> void:
	if not paused:
		elapsed += delta
	if rotating:
		rig.yaw += delta * 0.25
		rig.refresh()
	if loaded:
		_sync_materials()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		reset()
		get_viewport().set_input_as_handled()


func _sync_materials() -> void:
	paint.set_shader_parameter("sample_time", elapsed)
	paint.set_shader_parameter("wind_strength", wind)
	old_paint.set_shader_parameter("sample_time", elapsed)
	old_paint.set_shader_parameter("wind_strength", wind)
	paint.set_shader_parameter("reduce_motion", reduced_motion)
	old_paint.set_shader_parameter("reduce_motion", reduced_motion)


func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	if enabled:
		rotating = false
		rotate_button.text = "自动绕转"
	rotate_button.disabled = enabled
	if loaded:
		_sync_materials()


func set_wind(value: float) -> void:
	wind = clampf(value, 0, 1)
	if loaded:
		_sync_materials()


func toggle_pause() -> void:
	paused = not paused
	pause_button.text = "继续风动" if paused else "暂停风"


func toggle_orbit() -> void:
	rotating = not rotating
	rotate_button.text = "停止绕转" if rotating else "自动绕转"


func set_light(index: int) -> void:
	_light_mode = index
	sun.visible = index != 1
	sun.rotation_degrees = Vector3(-16, 145, 0) if index == 2 else Vector3(-42, -32, 0)
	environment.ambient_light_color = Color("a6c0cb") if index == 1 else Color("c4d4d0")
	environment.ambient_light_energy = 0.65 if index == 1 else 0.45


func set_view(index: int) -> void:
	rig.target = Vector3(0, 0.15, 0.6)
	rig.distance = 14.5
	rig.yaw = 0.12
	rig.pitch = 0.72
	if index in [1, 2, 3]:
		rig.target = Vector3(_x(index), 0.2, 1.1)
		rig.distance = 7.0
		rig.yaw = 0.20
		rig.pitch = 0.45
	elif index == 4:
		rig.distance = 13.0
		rig.pitch = 0.16
	elif index == 5:
		rig.distance = 16.0
		rig.yaw = PI
		rig.pitch = 0.35
	for label: Label3D in headers:
		label.visible = index == 0
	rig.refresh()


func reset() -> void:
	paused = false
	rotating = false
	elapsed = 0.0
	pause_button.text = "暂停风"
	rotate_button.text = "自动绕转"
	wind_slider.value = 0.45
	motion_toggle.button_pressed = false
	set_reduced_motion(false)
	view_picker.select(0)
	light_picker.select(0)
	set_light(0)
	set_view(0)


static func _x(index: int) -> float:
	return (index - 1.5) * 2.8


static func _solid(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	return material


static func _button(parent: Control, text: String, name_value: String) -> Button:
	var button: Button = Button.new()
	button.name = name_value
	button.text = text
	parent.add_child(button)
	return button
