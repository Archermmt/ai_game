class_name ProductionLandscapePlayground
extends "res://features/living_world/living_playground.gd"
## Production presentation. WorldDocument and existing edit transactions remain authoritative.

var landscape_ready: bool = false
var landscape_failed: bool = false
var landscape_terrain: ProductionTerrainRenderer
var snow_footprints: SnowFootprints
var cloud_adapter: SunshineCloudAdapter
var snow_cover: BlanketSnowRenderer
var _cloud_views: Dictionary = {}
var _landscape_closing: bool = false
var _landscape_environment_key: String = ""
var _footprint_source_signature: int = 0


func _create_meadow() -> MeadowRenderer:
	return ProductionGrassRenderer.new()


func _ready() -> void:
	super._ready()
	get_viewport().msaa_3d = Viewport.MSAA_4X
	_setup_plugin_clouds()
	snow_cover = BlanketSnowRenderer.new()
	world_view.add_child(snow_cover)
	snow_cover.configure(self)
	landscape_terrain = ProductionTerrainRenderer.new()
	landscape_terrain.name = "ProductionTerrain"
	terrain_root.add_child(landscape_terrain)
	landscape_terrain.published.connect(_terrain_published)
	landscape_terrain.initialize(camera_rig.camera)
	landscape_terrain.request(document.snapshot())
	snow_footprints = SnowFootprints.new()
	snow_footprints.name = "WalkSnowFootprints"
	add_child(snow_footprints)
	snow_footprints.configure(document.snapshot())
	_footprint_source_signature = _snow_contact_signature(document.state)
	hud.set_status("正在铺设林间草地……")


func _on_published(snapshot: Dictionary, prepared: Dictionary) -> void:
	super._on_published(snapshot, prepared)
	if landscape_terrain != null:
		# Preview publications and cancellation must also move the visible ground.
		landscape_terrain.request(snapshot)
		_sync_surface_visibility()
	if snow_cover != null:
		snow_cover.request(snapshot)
	if snow_footprints != null:
		var footprint_signature: int = _snow_contact_signature(snapshot)
		if footprint_signature != _footprint_source_signature:
			snow_footprints.configure(snapshot)
			_footprint_source_signature = footprint_signature


func _setup_plugin_clouds() -> void:
	cloud_adapter = SunshineCloudAdapter.new()
	cloud_adapter.name = "MainCameraClouds"
	add_child(cloud_adapter)
	if DisplayServer.get_name() != "headless":
		if RenderingServer.get_current_rendering_driver_name() == "metal":
			get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	var ready: bool = cloud_adapter.configure(world_environment, camera_rig.camera, sun)
	atmosphere.sky.material.set_shader_parameter("painted_clouds_enabled", not ready)
	if ready:
		photography.camera_created.connect(_cloud_camera_created)
		photography.camera_releasing.connect(_cloud_camera_releasing)
		_cloud_camera_created(pond_reflections.camera)
	_sync_cloud_views()


func _cloud_camera_created(camera: Camera3D) -> void:
	var adapter: SunshineCloudAdapter = SunshineCloudAdapter.new()
	adapter.name = "CloudView%d" % camera.get_instance_id()
	add_child(adapter)
	if adapter.configure(world_environment, camera, sun):
		adapter.set_enabled(cloud_adapter.clouds.enabled)
		_cloud_views[camera.get_instance_id()] = adapter
		_sync_cloud_views()
	else:
		adapter.queue_free()


func _cloud_camera_releasing(camera: Camera3D) -> void:
	var adapter: SunshineCloudAdapter = _cloud_views.get(camera.get_instance_id())
	if adapter != null:
		_cloud_views.erase(camera.get_instance_id())
		adapter.shutdown()
		adapter.queue_free()


func _sync_cloud_views() -> void:
	if cloud_adapter == null or not cloud_adapter.ready_for_clouds:
		return
	cloud_adapter.sync(
		atmosphere.elapsed, atmosphere.blend.current, atmosphere.frozen, atmosphere.reduced_motion
	)
	for adapter: SunshineCloudAdapter in _cloud_views.values():
		adapter.sync(atmosphere.elapsed, atmosphere.blend.current, true, true)
		adapter.copy_animation_from(cloud_adapter)


func set_plugin_clouds(value: bool) -> void:
	var enabled: bool = value and cloud_adapter != null and cloud_adapter.ready_for_clouds
	if cloud_adapter != null:
		cloud_adapter.set_enabled(enabled)
	for adapter: SunshineCloudAdapter in _cloud_views.values():
		adapter.set_enabled(enabled)
	atmosphere.sky.material.set_shader_parameter("painted_clouds_enabled", not enabled)
	if pond_reflections != null:
		pond_reflections.request_update()


func _snow_contact_signature(snapshot: Dictionary) -> int:
	# Fences affect walk support even though they do not affect meadow generation.
	return hash([MeadowData.signature(snapshot), snapshot.get("fences", [])])


func _process(delta: float) -> void:
	super._process(delta)
	if landscape_terrain == null or _landscape_closing:
		return
	_sync_surface_visibility()
	_sync_cloud_views()
	if snow_cover != null and atmosphere != null:
		snow_cover.sync(float(atmosphere.blend.current.get("cover", 0.0)))
		if walk_controller.active:
			var ground: float = walk_controller.surface.field.height_at(
				Vector2(walk_controller.feet.x, walk_controller.feet.z)
			)
			var standing_on_ground: bool = absf(walk_controller.feet.y - ground) < 0.04
			walk_controller.eye_height = (
				1.65
				+ (
					(
						ProductionTerrainRenderer.SNOW_DEPTH
						* float(atmosphere.blend.current.get("cover", 0.0))
					)
					if standing_on_ground
					else 0.0
				)
			)
	if snow_footprints != null and atmosphere != null:
		snow_footprints.surface_offset = (
			ProductionTerrainRenderer.SNOW_DEPTH * float(atmosphere.blend.current.get("cover", 0.0))
		)
		snow_footprints.update_contact(
			walk_controller.feet,
			walk_controller.yaw,
			walk_controller.active,
			float(atmosphere.blend.current.get("cover", 0.0)),
			delta,
			atmosphere.frozen
		)
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
	if grass != null:
		grass.set_walker_contact(
			walk_controller.feet, walk_controller.active, atmosphere != null and atmosphere.frozen
		)
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
	if landscape_terrain.terrain != null:
		var current_layers: int = landscape_terrain.terrain.render_layers
		if (current_layers & SnowFootprints.RECEIVER_LAYER) == 0:
			landscape_terrain.terrain.render_layers = current_layers | SnowFootprints.RECEIVER_LAYER
	# Keep the transaction-prepared mesh visible until the latest native maps arrive.
	# The parent remains visible and excluded from pond reflection as before.
	for view: MeshInstance3D in _terrain_views:
		view.visible = not native_current
		if (view.layers & SnowFootprints.RECEIVER_LAYER) == 0:
			view.layers |= SnowFootprints.RECEIVER_LAYER


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
	if snow_cover != null:
		snow_cover.shutdown()
	for adapter: SunshineCloudAdapter in _cloud_views.values():
		adapter.shutdown()
	_cloud_views.clear()
	if cloud_adapter != null:
		cloud_adapter.shutdown()
	if snow_footprints != null:
		snow_footprints.shutdown()
	if landscape_terrain != null:
		landscape_terrain.shutdown()
	super._exit_tree()
