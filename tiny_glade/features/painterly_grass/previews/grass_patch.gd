class_name PainterlyGrassPatch
extends "res://features/living_world/living_playground.gd"
## Read-only G2 derivative. qa_mode is set before all inherited preference/save setup.

const FONT: Font = preload("res://assets/fonts/NotoSansSC-Regular.otf")
var patch_ready: bool = false
var patch_failed: bool = false
var use_new_grass: bool = true
var patch_paused: bool = false
var patch_time: float = 0.0
var patch_material: ShaderMaterial
var patch_data: Dictionary = {}
var patch_views: Array[MultiMeshInstance3D] = []
var patch_meshes: Array[Mesh] = []
var patch_layer: CanvasLayer
var variant_button: Button
var view_picker: OptionButton
var time_picker: OptionButton
var pause_button: Button
var walk_button: Button
var gallery_button: Button
var patch_status: Label
var baseline: Dictionary = {}
var blocked_save_attempts: int = 0
var preview_loader: PainterlyPreviewLoader


func _init() -> void:
	qa_mode = true


func _ready() -> void:
	if "--g2-fhd" in OS.get_cmdline_user_args():
		get_window().content_scale_size = Vector2i(1920, 1080)
		get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	super._ready()
	get_window().title = "G2 · 屋前新旧草对照 | 风栖小筑"
	saves.directory = "user://qa_painterly_grass/g2"
	active_slot = -1
	photo_active = true
	hud.hide()
	gizmo_root.hide()
	preview_root.hide()
	camera_rig.camera.attributes = null
	calendar.speed = 0
	calendar.automatic_weather = false
	calendar.month = 5
	calendar.weather = "clear"
	calendar.minute_of_day = 690
	seasonal_music.configure(0.0)
	_setup_patch_ui()
	_prepare_patch.call_deferred()


func _prepare_patch() -> void:
	var deadline: int = Time.get_ticks_msec() + 30000
	while (
		(queue.is_busy() or stage.is_busy() or meadow.is_busy())
		and Time.get_ticks_msec() < deadline
	):
		await get_tree().process_frame
	if queue.is_busy() or stage.is_busy() or meadow.is_busy():
		patch_failed = true
		patch_status.text = "庭园准备超时；请重新打开预览，未改写作品。"
		return
	for path: String in PainterlyGrassSamples.paths():
		if not ResourceLoader.exists(path):
			patch_failed = true
			patch_status.text = "本地草素材未准备，请先完成G1提取。"
			return
		if ResourceLoader.load_threaded_request(path) != OK:
			patch_failed = true
			return
		while (
			ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS
		):
			await get_tree().process_frame
		if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_LOADED:
			patch_failed = true
			return
		var resource: Resource = ResourceLoader.load_threaded_get(path)
		if path.ends_with(".glb"):
			patch_meshes.append(PainterlyGrassSamples.mesh_from(resource as PackedScene))
		else:
			patch_material = PainterlyGrassSamples.material(resource as Texture2D)
	baseline = document.snapshot()
	patch_data = PainterlyGrassPatchData.generate(baseline)
	patch_material.set_shader_parameter("conform_ground", true)
	patch_material.set_shader_parameter("garden_colors", true)
	patch_material.set_shader_parameter(
		"terrain_map", ImageTexture.create_from_image(patch_data["image"])
	)
	patch_material.set_shader_parameter("terrain_origin", PainterlyGrassPatchData.MAP_ORIGIN)
	patch_material.set_shader_parameter("root_color", Color("4e683e"))
	patch_material.set_shader_parameter("tip_color", Color("7e985c"))
	for kind: int in 3:
		var items: Array = patch_data["groups"][kind]
		var view: MultiMeshInstance3D = MultiMeshInstance3D.new()
		view.name = "PainterlyPatch%d" % kind
		view.multimesh = MultiMesh.new()
		view.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		view.multimesh.use_custom_data = true
		view.multimesh.mesh = patch_meshes[kind]
		view.multimesh.instance_count = items.size()
		for i: int in items.size():
			view.multimesh.set_instance_transform(i, items[i]["pose"])
			view.multimesh.set_instance_custom_data(
				i, Color(items[i]["phase"], 0.08 if kind == 2 else 1.0, 0, 1)
			)
		view.material_override = patch_material
		view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		view.extra_cull_margin = 0.5
		meadow.add_child(view)
		patch_views.append(view)
	meadow.material.set_shader_parameter("preview_patch_rect", Vector4(0, 2, 8, 8))
	patch_ready = true
	set_variant(true)
	set_patch_view(0)
	set_patch_light(0)
	variant_button.disabled = false
	walk_button.disabled = false
	pause_button.disabled = false


func _setup_patch_ui() -> void:
	patch_layer = CanvasLayer.new()
	patch_layer.name = "GrassComparisonControls"
	patch_layer.layer = 20
	add_child(patch_layer)
	var margin: MarginContainer = MarginContainer.new()
	margin.name = "PreviewMargin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 18)
	var theme: Theme = Theme.new()
	theme.default_font = FONT
	theme.default_font_size = 17
	margin.theme = theme
	patch_layer.add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	margin.add_child(column)
	var title: Label = Label.new()
	title.text = "G2 · 屋前 8×8m 新旧草对照"
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", Color("f4f0df"))
	title.add_theme_color_override("font_shadow_color", Color("23382c"))
	title.add_theme_constant_override("shadow_offset_x", 1)
	title.add_theme_constant_override("shadow_offset_y", 1)
	column.add_child(title)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	variant_button = _patch_button(row, "切换为现有草", "GrassVariant")
	variant_button.disabled = true
	variant_button.pressed.connect(func() -> void: set_variant(not use_new_grass))
	view_picker = OptionButton.new()
	view_picker.name = "PatchView"
	for text: String in ["屋前俯视", "屋前低机位", "路径边缘", "树荫", "逆光构图"]:
		view_picker.add_item(text)
	view_picker.item_selected.connect(set_patch_view)
	row.add_child(view_picker)
	time_picker = OptionButton.new()
	time_picker.name = "PatchLight"
	time_picker.add_item("日间")
	time_picker.add_item("黄昏")
	time_picker.item_selected.connect(set_patch_light)
	row.add_child(time_picker)
	pause_button = _patch_button(row, "暂停动态", "PausePatch")
	pause_button.disabled = true
	pause_button.pressed.connect(func() -> void: set_patch_paused(not patch_paused))
	walk_button = _patch_button(row, "进入漫步", "WalkPatch")
	walk_button.disabled = true
	walk_button.pressed.connect(toggle_patch_walk)
	var reset_button: Button = _patch_button(row, "重置机位", "ResetPatch")
	reset_button.pressed.connect(func() -> void: set_patch_view(0))
	gallery_button = _patch_button(row, "单体展示 G1", "OpenGallery")
	gallery_button.pressed.connect(_open_gallery)
	patch_status = Label.new()
	patch_status.text = "正在准备同一庭园的局部对照……"
	patch_status.add_theme_color_override("font_shadow_color", Color("23382c"))
	patch_status.add_theme_constant_override("shadow_offset_x", 1)
	patch_status.add_theme_constant_override("shadow_offset_y", 1)
	column.add_child(patch_status)
	preview_loader = PainterlyPreviewLoader.new()
	preview_loader.name = "PreviewSceneLoader"
	add_child(preview_loader)
	preview_loader.loading_completed.connect(_gallery_loaded)
	preview_loader.loading_failed.connect(
		func(_path: String) -> void:
			gallery_button.disabled = false
			patch_status.text = "展示场景读取失败，可继续体验局部对照。"
	)


func _process(delta: float) -> void:
	super._process(delta)
	if not patch_ready:
		return
	if not patch_paused:
		patch_time += delta
	patch_material.set_shader_parameter("sample_time", patch_time)
	patch_material.set_shader_parameter(
		"wind_strength", document.state["environment"]["wind_strength"]
	)


func set_variant(enabled: bool) -> void:
	use_new_grass = enabled
	if not patch_ready:
		return
	meadow.material.set_shader_parameter("preview_patch_enabled", enabled)
	for view: MultiMeshInstance3D in patch_views:
		view.visible = enabled
	variant_button.text = "切换为现有草" if enabled else "切换为新草"
	var count: int = 0
	for view: MultiMeshInstance3D in patch_views:
		count += view.multimesh.instance_count
	patch_status.text = (
		"%s · 屋前/石径右侧 8×8m · 原草 %d / 新草 %d 簇 · 区域外保留原草 · 只读预览"
		% ["新草" if enabled else "现有草", patch_data["old_visible_origins"], count]
	)


func set_patch_paused(enabled: bool) -> void:
	patch_paused = enabled
	_freeze_photo(enabled)
	if enabled:
		patch_time = 0.0
		for material: ShaderMaterial in wind_materials:
			material.set_shader_parameter("sample_time", 0.0)
		water_material.set_shader_parameter("sample_time", 0.0)
	pause_button.text = "继续动态" if enabled else "暂停动态"


func set_patch_light(index: int) -> void:
	time_picker.select(index)
	calendar.minute_of_day = 690 if index == 0 else 1098
	atmosphere.blend.advance(0, calendar.sample())
	atmosphere.blend.advance(18, calendar.sample())
	atmosphere.elapsed = 0
	atmosphere.phase = Vector3.ZERO
	atmosphere.update(0, calendar.sample())
	pond_reflections.request_update()


func set_patch_view(index: int) -> void:
	if walk_controller.active:
		stop_walk()
		set_patch_paused(patch_paused)
	walk_button.text = "进入漫步"
	camera_rig.camera.attributes = null
	camera_rig.camera.fov = 43
	camera_rig.camera.near = 0.1
	camera_rig.target = Vector3(4, 0.7, 5)
	camera_rig.distance = 15
	camera_rig.yaw = 0.25
	camera_rig.pitch = 0.65
	camera_rig.refresh()
	if index > 0:
		walk_controller.surface.configure(document.snapshot())
		var foot: Vector2 = [
			Vector2.ZERO, Vector2(7.5, 10), Vector2(2, 9), Vector2(8, 9.3), Vector2(5.0, 10)
		][index]
		var spawn: Variant = walk_controller.surface.find_spawn(foot)
		if spawn != null:
			camera_rig.camera.global_position = spawn + Vector3.UP * 1.65
			camera_rig.camera.fov = 65
			camera_rig.camera.near = 0.06
			camera_rig.camera.look_at(
				[
					Vector3.ZERO,
					Vector3(5, 0.25, 3),
					Vector3(1, 0.3, 3),
					Vector3(5.7, 0.3, 6),
					Vector3(1, 2, -4)
				][index]
			)
	view_picker.select(index)
	pond_reflections.request_update()


func toggle_patch_walk() -> void:
	if walk_controller.active:
		set_patch_view(0)
	else:
		if start_walk():
			walk_button.text = "返回俯视"
			set_patch_paused(patch_paused)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		set_patch_view(0)
		get_viewport().set_input_as_handled()
		return
	super._input(event)


func _unhandled_input(_event: InputEvent) -> void:
	pass


func _on_action(_action: StringName) -> void:
	pass


func _start_save(_index: int, _title: String, _preserve_dialogs: bool = false) -> void:
	blocked_save_attempts += 1


func _persist_preferences() -> void:
	pass


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and soundscape != null:
		_request_quit()
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and walk_controller != null:
		walk_controller.reset_input()


func _open_gallery() -> void:
	gallery_button.disabled = true
	preview_loader.request_load("res://features/painterly_grass/previews/grass_lab.tscn")


func _gallery_loaded(resource: Resource) -> void:
	if walk_controller.active:
		stop_walk()
	seasonal_music.shutdown()
	soundscape.shutdown()
	await SceneShutdown.wait_wallclock(get_tree(), 0.4)
	get_tree().change_scene_to_packed(resource as PackedScene)


static func _patch_button(parent: Control, text: String, name_value: String) -> Button:
	var button: Button = Button.new()
	button.name = name_value
	button.text = text
	parent.add_child(button)
	return button
