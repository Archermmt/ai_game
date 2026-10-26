class_name ProductionLandscapePlayground
extends "res://features/living_world/living_playground.gd"
## Production presentation. WorldDocument and existing edit transactions remain authoritative.

var landscape_ready: bool = false
var landscape_failed: bool = false
var landscape_terrain: ProductionTerrainRenderer
var _landscape_closing: bool = false
var _landscape_environment_key: String = ""


func _create_meadow() -> MeadowRenderer:
	return ProductionGrassRenderer.new()


func _ready() -> void:
	super._ready()
	get_viewport().msaa_3d = Viewport.MSAA_4X
	landscape_terrain = ProductionTerrainRenderer.new()
	landscape_terrain.name = "ProductionTerrain"
	terrain_root.add_child(landscape_terrain)
	landscape_terrain.published.connect(_terrain_published)
	landscape_terrain.initialize(camera_rig.camera)
	landscape_terrain.request(document.snapshot())
	hud.set_status("正在铺设林间草地……")


func _on_published(snapshot: Dictionary, prepared: Dictionary) -> void:
	super._on_published(snapshot, prepared)
	if landscape_terrain != null:
		# Preview publications and cancellation must also move the visible ground.
		landscape_terrain.request(snapshot)
		_sync_surface_visibility()


func _process(delta: float) -> void:
	super._process(delta)
	if landscape_terrain == null or _landscape_closing:
		return
	_sync_surface_visibility()
	if atmosphere != null:
		var visual: Dictionary = atmosphere.blend.current
		var key: String = JSON.stringify(
			[
				document.state["environment"].get("palette", {}),
				snappedf(float(visual.get("rain", 0.0)), 0.005)
			]
		)
		if key != _landscape_environment_key:
			landscape_terrain.sync_environment(document.state["environment"], visual)
			_landscape_environment_key = key
	var grass: ProductionGrassRenderer = meadow as ProductionGrassRenderer
	if (
		not landscape_failed
		and ((grass != null and grass.failed) or not landscape_terrain.last_error.is_empty())
	):
		landscape_failed = true
		hud.set_status("林间素材未准备完成，请查看项目验证报告。")
	if not landscape_ready and not landscape_failed:
		if (
			(grass == null or grass.ready_for_grass)
			and not meadow.is_busy()
			and landscape_terrain.data_ready
			and not landscape_terrain.is_busy()
			and not queue.is_busy()
			and not stage.is_busy()
		):
			landscape_ready = true
			hud.set_status("林间庭园 · 点示意图建造，或进入相机在草地间漫步")


func _sync_surface_visibility() -> void:
	var native_current: bool = landscape_terrain.data_ready and not landscape_terrain.is_busy()
	landscape_terrain.visible = native_current
	# Keep the transaction-prepared mesh visible until the latest native maps arrive.
	# The parent remains visible and excluded from pond reflection as before.
	for view: MeshInstance3D in _terrain_views:
		view.visible = not native_current


func _terrain_published(_snapshot: Dictionary) -> void:
	_sync_surface_visibility()


func _delivery_metrics() -> Dictionary:
	var result: Dictionary = super._delivery_metrics()
	result["landscape_ready"] = landscape_ready
	result["landscape_failed"] = landscape_failed
	result["terrain_renderer"] = "Terrain3D"
	result["grass_renderer"] = (
		"Valley four layers / ProtonScatter"
		if meadow is ProductionGrassRenderer
		else "Legacy meadow comparison"
	)
	return result


func _exit_tree() -> void:
	_landscape_closing = true
	if landscape_terrain != null:
		landscape_terrain.shutdown()
	super._exit_tree()
