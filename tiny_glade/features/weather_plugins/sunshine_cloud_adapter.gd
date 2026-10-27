class_name SunshineCloudAdapter
extends Node
## Lab adapter for pinned SunshineClouds2; all cloud generation stays upstream.
## One WorldEnvironment effect is shared by PhotoExport/reflection World3Ds. Its
## temporal buffers are viewport-sized, so multi-viewport rendering requires native QA.

@export_group("Cloud layer")
@export_range(100.0, 10000.0, 50.0) var cloud_base: float = 1500.0
@export_range(200.0, 30000.0, 50.0) var cloud_top: float = 9000.0
@export_range(0.0, 1.0, 0.01) var clear_coverage: float = 0.82
@export_range(0.0, 1.0, 0.01) var overcast_coverage: float = 0.91
@export var soft_cartoon: bool = true
@export_group("Sampling")
@export_enum("Native", "Half", "Quarter", "Eighth") var resolution_scale: int = 1
@export_range(16, 256, 8) var march_steps: int = 96
@export_range(4, 24, 1) var lighting_steps: int = 12

var ready_for_clouds: bool = false
var failure_message: String = ""
var driver: SunshineCloudsDriverGD
var clouds: SunshineCloudsGD
var _environment: WorldEnvironment
var _camera: Camera3D
var _sun: DirectionalLight3D
var _previous_compositor: Compositor
var _previous_effects: Array[CompositorEffect] = []
var _owned_compositor: Compositor
var _last_elapsed: float = -1.0
var _enabled: bool = true


func configure(environment: WorldEnvironment, camera: Camera3D, sun: DirectionalLight3D) -> bool:
	shutdown()
	failure_message = ""
	if not is_inside_tree():
		failure_message = "Cloud adapter must enter the scene before configuration."
		return false
	if (
		not is_instance_valid(environment)
		or not is_instance_valid(camera)
		or not is_instance_valid(sun)
		or environment.environment == null
	):
		failure_message = "Clouds require the garden's WorldEnvironment, camera and sun."
		return false
	if DisplayServer.get_name() == "headless" or RenderingServer.get_rendering_device() == null:
		failure_message = "SunshineClouds requires a native RenderingDevice; headless is unverified."
		return false
	_environment = environment
	_camera = camera
	_sun = sun
	_previous_compositor = environment.compositor
	_previous_effects.clear()
	if _previous_compositor != null:
		_previous_effects.assign(_previous_compositor.compositor_effects)
	clouds = SunshineCloudsGD.new()
	_apply_preset()
	# Assign before entering the tree: bypass the driver's whole-scene environment
	# search. The adapter owns attachment to the specific garden environment.
	driver = SunshineCloudsDriverGD.new()
	driver.name = "SunshineCloudsDriver"
	driver.clouds_resource = clouds
	driver.ambience_sample_environment = environment.environment
	driver.tracked_directional_lights.assign([sun])
	driver.tracked_directional_light_shadow_steps.assign([lighting_steps])
	add_child(driver)
	driver.update_continuously = true
	driver.set_process(false)
	_owned_compositor = Compositor.new()
	var effects: Array[CompositorEffect] = _previous_effects.duplicate()
	effects.append(clouds)
	_owned_compositor.compositor_effects = effects
	environment.compositor = _owned_compositor
	_last_elapsed = -1.0
	_enabled = true
	ready_for_clouds = true
	return true


func sync(
	elapsed: float, visual: Dictionary, frozen: bool = false, reduced_motion: bool = false
) -> void:
	var delta: float = 0.0 if _last_elapsed < 0.0 else maxf(0.0, elapsed - _last_elapsed)
	_last_elapsed = elapsed
	if not ready_for_clouds or clouds == null or not is_instance_valid(driver):
		return
	if not _enabled:
		return
	if frozen or reduced_motion:
		delta = 0.0
	var overcast: float = clampf((float(visual.get("cloud", 0.18)) - 0.18) / 0.82, 0, 1)
	var severe: float = maxf(
		float(visual.get("rain", 0.0)),
		maxf(float(visual.get("snow", 0.0)), float(visual.get("dust", 0.0)))
	)
	clouds.clouds_coverage = lerpf(clear_coverage, overcast_coverage, overcast)
	clouds.clouds_density = lerpf(0.65, 1.0, clampf(severe, 0, 1))
	clouds.cloud_floor = cloud_base
	clouds.cloud_ceiling = maxf(cloud_base + 100.0, cloud_top)
	var daylight: float = clampf(_sun.light_energy / 1.22, 0.025, 1.0)
	clouds.cloud_ambient_color = Color("889dbb").lerp(Color("fff5e3"), daylight)
	clouds.cloud_ambient_color *= lerpf(0.25, 1.0, daylight)
	clouds.cloud_ambient_tint = Color("536b89").lerp(Color("697d91"), overcast)
	clouds.atmosphere_color = _environment.environment.fog_light_color
	# Use the upstream wind/light update with the existing scene clock. Calling it
	# explicitly avoids a second free-running timer during photography and reduced motion.
	driver._process(delta)


func set_enabled(value: bool) -> void:
	var changed: bool = _enabled != value
	_enabled = value
	if clouds != null:
		if changed and value:
			# A hidden camera may have moved; do not reproject stale cloud history.
			clouds.refresh_compute()
		clouds.enabled = value


func shutdown() -> void:
	ready_for_clouds = false
	_last_elapsed = -1.0
	var retiring_clouds: SunshineCloudsGD = clouds
	if clouds != null:
		clouds.enabled = false
	if is_instance_valid(driver):
		driver.set_process(false)
	_detach_effect()
	if is_instance_valid(driver):
		# The resource setter searches the whole tree. Let queued node destruction
		# release its reference after our explicit detach, without invoking that search
		# or removing children from inside an exit-tree notification.
		driver.queue_free()
	if retiring_clouds != null:
		# CompositorEffect render callbacks can retain the resource beyond scene
		# deletion. Release its GPU state explicitly while the device is still alive;
		# the script-owned static callable survives removal of this adapter node.
		RenderingServer.call_on_render_thread(
			SunshineCloudAdapter._release_plugin_resources.bind(retiring_clouds)
		)
	driver = null
	clouds = null
	_owned_compositor = null
	_previous_compositor = null
	_previous_effects.clear()
	_environment = null
	_camera = null
	_sun = null


static func _release_plugin_resources(effect: SunshineCloudsGD) -> void:
	if effect == null or effect.rd == null:
		return
	# These sets are created by the plugin. Clear them before their shader/sampler
	# dependencies; clear_compute handles the rest of its owned RID allocations.
	for uniform_set: RID in effect.uniform_sets:
		if uniform_set.is_valid() and effect.rd.uniform_set_is_valid(uniform_set):
			effect.rd.free_rid(uniform_set)
	effect.uniform_sets.clear()
	effect.clear_compute()
	# RenderSceneBuffers and its color-image RIDs belong to the viewport/engine.
	# Drop borrowed references without freeing any of those engine-owned textures.
	effect.buffers = null
	effect.color_images.clear()


func _detach_effect() -> void:
	if not is_instance_valid(_environment) or _environment.compositor == null:
		return
	var current: Compositor = _environment.compositor
	var effects: Array[CompositorEffect] = current.compositor_effects.duplicate()
	if clouds not in effects:
		return
	effects.erase(clouds)
	if current == _owned_compositor and effects == _previous_effects:
		_environment.compositor = _previous_compositor
	else:
		# Preserve effects that another system added or removed while clouds ran.
		current.compositor_effects = effects


func _apply_preset() -> void:
	clouds.cloud_floor = cloud_base
	clouds.cloud_ceiling = maxf(cloud_base + 100.0, cloud_top)
	clouds.clouds_coverage = clear_coverage
	clouds.clouds_density = 0.65
	clouds.clouds_sharpness = 0.65 if soft_cartoon else 0.85
	clouds.clouds_detail_power = 0.15 if soft_cartoon else 1.0
	clouds.lighting_sharpness = 0.28 if soft_cartoon else 0.55
	clouds.clouds_powder = 0.65
	# The upstream default AO tint is diagnostic red; use the garden's cool shadows.
	clouds.ambient_occlusion_color = Color(0.16, 0.22, 0.30, 0.55)
	clouds.extra_large_noise_scale = 180000.0
	clouds.large_noise_scale = 60000.0
	clouds.medium_noise_scale = 14000.0
	clouds.small_noise_scale = 5000.0
	clouds.curl_noise_strength = 3000.0
	clouds.max_step_count = march_steps
	clouds.max_lighting_steps = lighting_steps
	clouds.resolution_scale = resolution_scale
	clouds.min_step_distance = 120.0
	clouds.max_step_distance = 480.0
	clouds.lighting_travel_distance = 6500.0
	clouds.accumulation_decay = 0.8
	clouds.fog_effect_ground = 0.0
	clouds.use_environment_fog = 0.0


func _exit_tree() -> void:
	shutdown()
