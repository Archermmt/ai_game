class_name WeatherPluginLab
extends ProductionLandscapePlayground
## A single isolated garden compares the pinned upstream cloud renderer.

var weather_lab_ready: bool = false
var plugin_clouds: bool = true
var lab_panel: PanelContainer
var lab_note: Label
var snow_reference: SnowMaterialReference


func _init() -> void:
	qa_mode = true


func _persist_preferences() -> void:
	pass


func _ready() -> void:
	super._ready()
	# Metal cannot write multisampled storage images in the upstream post pass.
	# Keep TAA for soft brush edges; this lab does not change the production AA.
	if RenderingServer.get_current_rendering_driver_name() == "metal":
		get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	get_window().title = "云层插件试验 · 风栖小筑"
	saves.directory = "user://qa_weather_plugins/lab/saves"
	active_slot = -1
	DirAccess.make_dir_recursive_absolute("user://qa_weather_plugins/lab/photos")
	hud.photo_directory.text = ProjectSettings.globalize_path(
		"user://qa_weather_plugins/lab/photos"
	)
	calendar.speed = 0
	calendar.automatic_weather = false
	weather_lab_ready = cloud_adapter.ready_for_clouds
	snow_reference = SnowMaterialReference.new()
	snow_reference.name = "UpstreamSnowMaterialReference"
	var field: TerrainField = TerrainField.new(document.snapshot())
	# The reference is a flat material board; keep its whole footprint above the
	# garden hill so terrain cannot occlude the material or contaminate its QA pixels.
	var reference_height: float = field.height_at(Vector2(12, 12))
	for z: int in range(-7, 8):
		for x: int in range(-7, 8):
			reference_height = maxf(
				reference_height, field.height_at(Vector2(12, 12) + Vector2(x, z) * 0.5)
			)
	snow_reference.position = Vector3(12, reference_height + 0.2, 12)
	add_child(snow_reference)
	snow_reference.hide()
	_setup_controls()
	set_lab_climate(0, true)
	set_lab_view(1)
	set_plugin_clouds(weather_lab_ready)
	if not weather_lab_ready:
		lab_note.text = "云插件尚未就绪：" + cloud_adapter.failure_message


func _setup_controls() -> void:
	lab_panel = PanelContainer.new()
	lab_panel.name = "WeatherPluginControls"
	lab_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	lab_panel.offset_left = 16
	lab_panel.offset_top = -305
	lab_panel.offset_right = 16
	lab_panel.offset_bottom = -164
	hud.add_child(lab_panel)
	var column: VBoxContainer = VBoxContainer.new()
	lab_panel.add_child(column)
	lab_note = Label.new()
	lab_note.text = "云与积雪样板 · 与主场景共用体积云和厚雪"
	column.add_child(lab_note)
	var row: HBoxContainer = HBoxContainer.new()
	column.add_child(row)
	var toggle: CheckButton = CheckButton.new()
	toggle.text = "插件体积云"
	toggle.name = "PluginCloudToggle"
	toggle.button_pressed = true
	toggle.toggled.connect(set_plugin_clouds)
	row.add_child(toggle)
	var climate: OptionButton = OptionButton.new()
	climate.name = "CloudClimate"
	for text: String in ["晴日积云", "阴天", "黄昏", "夜间", "冬日雪天"]:
		climate.add_item(text)
	climate.item_selected.connect(set_lab_climate)
	row.add_child(climate)
	var view: OptionButton = OptionButton.new()
	view.name = "CloudView"
	for text: String in ["庭园全景", "云层近观", "雪材质近看"]:
		view.add_item(text)
	view.selected = 1
	view.item_selected.connect(set_lab_view)
	row.add_child(view)
	var pause: CheckButton = CheckButton.new()
	pause.text = "暂停风与云"
	pause.toggled.connect(func(value: bool) -> void: _freeze_photo(value))
	row.add_child(pause)
	var actions: HBoxContainer = HBoxContainer.new()
	column.add_child(actions)
	var grass_walk: Button = Button.new()
	grass_walk.text = "草地漫步"
	grass_walk.pressed.connect(func() -> void: begin_immersion_demo(false))
	actions.add_child(grass_walk)
	var snow_walk: Button = Button.new()
	snow_walk.text = "冬日漫步"
	snow_walk.pressed.connect(func() -> void: begin_immersion_demo(true))
	actions.add_child(snow_walk)
	var back: Button = Button.new()
	back.text = "返回草地展示台"
	var loader: PainterlyPreviewLoader = PainterlyPreviewLoader.new()
	add_child(loader)
	loader.loading_completed.connect(
		func(resource: Resource) -> void: get_tree().change_scene_to_packed(resource as PackedScene)
	)
	back.pressed.connect(
		func() -> void: loader.request_load("res://app/painterly_grass_preview.tscn")
	)
	actions.add_child(back)


func begin_immersion_demo(winter: bool) -> void:
	set_lab_climate(4 if winter else 0, true)
	set_lab_view(0)
	if not photo_active:
		enter_photo()
	if not walk_controller.active:
		start_walk()


func set_plugin_clouds(value: bool) -> void:
	plugin_clouds = value and weather_lab_ready
	super.set_plugin_clouds(plugin_clouds)


func set_lab_climate(index: int, immediate: bool = false) -> void:
	calendar.month = 1 if index == 4 else 7
	calendar.minute_of_day = [720, 720, 1080, 1380, 720][index]
	calendar.weather = ["clear", "cloudy", "clear", "clear", "snow"][index]
	if immediate:
		atmosphere.blend.advance(WeatherBlend.DURATION, calendar.sample())
	_calendar_changed()
	hud.calendar.sync()
	_sync_plugin()


func set_lab_view(index: int) -> void:
	snow_reference.visible = index == 2
	if index == 0:
		_recommended_view(1)
	elif index == 1:
		camera_rig.target = Vector3(0, 16, 0)
		camera_rig.distance = 30
		camera_rig.pitch = -0.20
		camera_rig.yaw = 0.6
		camera_rig.refresh()
	else:
		camera_rig.target = snow_reference.position + Vector3(0, 0.5, 0)
		camera_rig.distance = 7
		camera_rig.pitch = 0.62
		camera_rig.yaw = 0.6
		camera_rig.refresh()
	lab_note.text = ("现成雪材质近看 · 纹理、法线与粗糙度 · 这个样板没有厚雪几何" if index == 2 else "云与积雪样板 · 与主场景共用体积云和厚雪")
	camera_rig.camera.attributes = null


func _process(delta: float) -> void:
	super._process(delta)
	_sync_plugin()
	if lab_panel != null:
		lab_panel.visible = not photo_active


func _sync_plugin() -> void:
	if cloud_adapter == null or atmosphere == null:
		return
	_sync_cloud_views()


func _exit_tree() -> void:
	if cloud_adapter != null:
		cloud_adapter.shutdown()
	super._exit_tree()
