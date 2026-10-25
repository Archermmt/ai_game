class_name PainterlyGrassGarden
extends "res://features/living_world/living_playground.gd"
## Editable G3 derivative: inherited transactions/IO/photography, isolated before ready.

@export var preview_directory: String = "user://qa_painterly_grass/g3"
var garden_ready: bool = false
var garden_failed: bool = false
var preview_initialized: bool = false
var grass_renderer: PainterlyGardenGrassRenderer
var grass_toolbar: HBoxContainer
var grass_variant: Button
var grass_note: Label
var gallery_loader: PainterlyPreviewLoader


func _init() -> void:
	qa_mode = true


func _create_meadow() -> MeadowRenderer:
	grass_renderer = PainterlyGardenGrassRenderer.new()
	return grass_renderer


func _ready() -> void:
	if "--g3-fhd" in OS.get_cmdline_user_args():
		get_window().content_scale_size = Vector2i(1920, 1080)
		get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	super._ready()
	get_window().title = "G3 · 新草可编辑庭园预览 | 风栖小筑"
	DirAccess.make_dir_recursive_absolute(preview_directory.path_join("photos"))
	saves.directory = preview_directory.path_join("saves")
	active_slot = -1
	preview_initialized = true
	preferences.load_file(preview_directory.path_join("preferences.cfg"))
	_apply_preferences()
	hud.photo_directory.text = ProjectSettings.globalize_path(preview_directory.path_join("photos"))
	saves.request("catalog")
	_sync_wind(document.state)
	_setup_grass_controls()
	_load_grass.call_deferred()


func _persist_preferences() -> void:
	if preview_initialized:
		if preferences.save_file(preview_directory.path_join("preferences.cfg")) != OK:
			hud.settings_note.text = "预览偏好保存失败；正式偏好保持。"


func _load_grass() -> void:
	var meshes: Array[Mesh] = []
	var coverage: Texture2D
	for path: String in PainterlyGrassSamples.paths():
		if not ResourceLoader.exists(path) or ResourceLoader.load_threaded_request(path) != OK:
			garden_failed = true
			grass_note.text = "缺少G1本地草素材，未启用新草。"
			return
		while (
			ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS
		):
			await get_tree().process_frame
		if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_LOADED:
			garden_failed = true
			return
		var resource: Resource = ResourceLoader.load_threaded_get(path)
		if path.ends_with(".glb"):
			meshes.append(PainterlyGrassSamples.mesh_from(resource as PackedScene))
		else:
			coverage = resource as Texture2D
	grass_renderer.configure(meshes, coverage)
	var deadline: int = Time.get_ticks_msec() + 45000
	while (
		(queue.is_busy() or stage.is_busy() or meadow.is_busy())
		and Time.get_ticks_msec() < deadline
	):
		await get_tree().process_frame
	garden_ready = not (queue.is_busy() or stage.is_busy() or meadow.is_busy())
	garden_failed = not garden_ready
	grass_variant.disabled = not garden_ready


func _setup_grass_controls() -> void:
	# Preview actions occupy the empty header corner, above the editing dock.
	grass_toolbar = HBoxContainer.new()
	grass_toolbar.name = "GrassPreviewToolbar"
	grass_toolbar.add_theme_constant_override("separation", 8)
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "GrassPreviewControls"
	layer.layer = 9
	add_child(layer)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	margin.offset_left = 16
	margin.offset_top = 16
	margin.offset_bottom = 52
	var theme: Theme = Theme.new()
	theme.default_font = preload("res://assets/fonts/NotoSansSC-Regular.otf")
	theme.default_font_size = 16
	margin.theme = theme
	layer.add_child(margin)
	margin.add_child(grass_toolbar)
	grass_variant = Button.new()
	grass_variant.name = "GrassVariant"
	grass_variant.text = "G3预览 · 切换现有草"
	grass_variant.disabled = true
	grass_variant.pressed.connect(
		func() -> void: set_grass_variant(not grass_renderer.use_new_grass)
	)
	grass_toolbar.add_child(grass_variant)
	var gallery: Button = Button.new()
	gallery.name = "GrassGallery"
	gallery.text = "返回草木试验室"
	gallery.pressed.connect(_return_gallery)
	grass_toolbar.add_child(gallery)
	grass_note = Label.new()
	grass_note.text = "正在准备新草 · 存档/设置为预览专用"
	grass_note.add_theme_color_override("font_shadow_color", Color.BLACK)
	grass_note.add_theme_constant_override("shadow_offset_x", 1)
	grass_note.add_theme_constant_override("shadow_offset_y", 1)
	grass_toolbar.add_child(grass_note)
	gallery_loader = PainterlyPreviewLoader.new()
	gallery_loader.name = "PreviewSceneLoader"
	add_child(gallery_loader)
	gallery_loader.loading_completed.connect(_gallery_loaded)
	gallery_loader.loading_failed.connect(
		func(_path: String) -> void: grass_note.text = "展示场景读取失败，可继续编辑。"
	)


func _process(delta: float) -> void:
	super._process(delta)
	if grass_toolbar == null:
		return
	grass_toolbar.visible = not photo_active
	if garden_ready:
		grass_note.text = (
			"%s · %d簇 · %s · 预览专用存档"
			% [
				"新草" if grass_renderer.use_new_grass else "现有草",
				meadow.visible_count(),
				"重建中" if meadow.is_busy() else "可编辑"
			]
		)


func set_grass_variant(enabled: bool) -> void:
	grass_renderer.set_variant(enabled)
	grass_variant.text = "G3预览 · 切换现有草" if enabled else "G3预览 · 切换新草"


func _sync_wind(snapshot: Dictionary) -> void:
	if grass_renderer != null:
		for paint: ShaderMaterial in [grass_renderer.material, grass_renderer.old_material]:
			if paint not in wind_materials:
				wind_materials.append(paint)
	super._sync_wind(snapshot)
	if grass_renderer != null:
		grass_renderer.old_material.set_shader_parameter(
			"foliage_tint", GardenPalette.tint(snapshot["environment"], "foliage")
		)


func _return_gallery() -> void:
	if _busy() or meadow.is_busy() or session.phase != EditSession.Phase.IDLE:
		hud.set_status("正在完成操作，请稍后返回试验室")
		return
	_intent = "grass_gallery"
	if is_dirty():
		hud.decision.popup_centered()
	else:
		_continue_intent()


func _continue_intent() -> void:
	if _intent == "grass_gallery":
		_intent = ""
		gallery_loader.request_load("res://app/painterly_grass_preview.tscn")
	else:
		super._continue_intent()


func _gallery_loaded(resource: Resource) -> void:
	seasonal_music.shutdown()
	soundscape.shutdown()
	await SceneShutdown.wait_wallclock(get_tree(), 0.4)
	get_tree().change_scene_to_packed(resource as PackedScene)
