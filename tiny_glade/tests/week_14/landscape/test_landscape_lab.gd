extends GutTest
## The plugin sample must use the real source geometry and current terrain.

const SCENE_PATH: String = "res://app/landscape_lab.tscn"
const TRIANGLES: Array[int] = [24, 2288, 28, 8]
const SOURCE_COUNTS: Array[int] = [366, 305, 161, 2445]
var lab: Node3D
var original_scatter: String
var original_height: PackedByteArray
var original_terrain_id: int


func before_all() -> void:
	assert_true(ResourceLoader.exists(SCENE_PATH), "The landscape lab must be runnable")
	var scene: PackedScene = load(SCENE_PATH) as PackedScene
	lab = scene.instantiate() as Node3D
	add_child(lab)
	var deadline: int = Time.get_ticks_msec() + 90000
	while (
		not bool(lab.get("lab_ready"))
		and not bool(lab.get("lab_failed"))
		and Time.get_ticks_msec() < deadline
	):
		await get_tree().process_frame
	assert_true(bool(lab.get("lab_ready")) and not bool(lab.get("lab_failed")))
	original_scatter = JSON.stringify(lab.get("source_scatter"))
	var adapter: LandscapeTerrainAdapter = lab.get("terrain_adapter")
	original_height = adapter.height_image.get_data().duplicate()
	original_terrain_id = adapter.terrain.get_instance_id()


func before_each() -> void:
	await lab.call("set_distribution", 0)
	for index: int in 4:
		lab.call("set_layer_enabled", index, true)
	lab.call("set_paused", true)


func after_all() -> void:
	lab.queue_free()
	for index: int in 12:
		await get_tree().process_frame


func test_four_evaluated_meshes_keep_the_3277_source_instances() -> void:
	if not _require_ready():
		return
	var source: Dictionary = lab.get("source_scatter")
	var source_layers: Array = source["layers"]
	var layers: Array = lab.get("layers")
	assert_eq(source_layers.size(), 4)
	assert_eq(layers.size(), 4)
	var total: int = 0
	for index: int in 4:
		var instances: Array = source_layers[index]["instances"]
		assert_eq(instances.size(), SOURCE_COUNTS[index])
		var layer: MultiMeshInstance3D = layers[index]
		assert_eq(layer.multimesh.instance_count, SOURCE_COUNTS[index])
		var mesh: Mesh = layer.multimesh.mesh
		assert_eq(mesh.get_surface_count(), 1)
		var arrays: Array = mesh.surface_get_arrays(0)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		assert_eq(indices.size() / 3, TRIANGLES[index])
		total += layer.multimesh.instance_count
	assert_eq(total, 3277)


func test_visible_root_origins_match_native_terrain_and_source_burial() -> void:
	if not _require_ready():
		return
	var adapter: LandscapeTerrainAdapter = lab.get("terrain_adapter")
	assert_true(adapter.data_ready)
	assert_eq(adapter.terrain.transform, Transform3D.IDENTITY)
	assert_eq(adapter.terrain.data.get_region_count(), 4)
	var source: Dictionary = lab.get("source_scatter")
	var source_layers: Array = source["layers"]
	var layers: Array = lab.get("layers")
	var published_poses: Array = lab.get("source_poses")
	var checked: int = 0
	for index: int in 4:
		var layer: MultiMeshInstance3D = layers[index]
		var instances: Array = source_layers[index]["instances"]
		var step: int = maxi(1, layer.multimesh.instance_count / 12)
		for item: int in range(0, layer.multimesh.instance_count, step):
			# RenderingServer's Dummy backend does not retain MultiMesh transforms.
			# The native Metal probe checks the actual server output; this checks
			# the exact source cache passed into the publisher under headless GUT.
			var pose: Transform3D = layer.global_transform * published_poses[index][item]
			var sample: Dictionary = adapter.sample_surface(Vector2(pose.origin.x, pose.origin.z))
			assert_true(bool(sample["allowed"]))
			var expected: float = (
				float(sample["height"]) + float(instances[item]["ground_offset_m"])
			)
			assert_almost_eq(
				pose.origin.y, expected, 0.02, "Keep source burial, not an all-zero root"
			)
			checked += 1
	assert_gt(checked, 40)


func test_plugin_distribution_and_independent_layers_preserve_artist_sources() -> void:
	if not _require_ready():
		return
	await lab.call("set_distribution", 1)
	assert_eq(int(lab.get("distribution")), 1)
	var layers: Array = lab.get("layers")
	assert_eq(layers.size(), 4)
	for index: int in 4:
		var layer: MultiMeshInstance3D = layers[index]
		assert_gt(layer.multimesh.instance_count, 0, "Every plugin layer must render")
		lab.call("set_layer_enabled", index, false)
		for other: int in 4:
			assert_eq((layers[other] as MultiMeshInstance3D).visible, other != index)
		lab.call("set_layer_enabled", index, true)
	await lab.call("set_distribution", 0)
	assert_eq(int(lab.get("distribution")), 0)
	assert_eq(JSON.stringify(lab.get("source_scatter")), original_scatter)
	var adapter: LandscapeTerrainAdapter = lab.get("terrain_adapter")
	assert_eq(adapter.height_image.get_data(), original_height)
	assert_eq(adapter.terrain.get_instance_id(), original_terrain_id)


func _require_ready() -> bool:
	var ready: bool = bool(lab.get("lab_ready")) and not bool(lab.get("lab_failed"))
	assert_true(ready, "Actual landscape setup must finish before its output is tested")
	return ready


func test_orbit_outside_the_source_keeps_finite_camera_without_expanding_plantable_area() -> void:
	if not _require_ready():
		return
	var rig: OrbitCamera = lab.get("camera_rig")
	var adapter: LandscapeTerrainAdapter = lab.get("terrain_adapter")
	for x: float in [-20.0, 20.0]:
		for z: float in [-20.0, 20.0]:
			for cardinal: int in 4:
				rig.target = Vector3(x, 0.0, z)
				rig.distance = 60.0
				rig.pitch = 0.3
				rig.yaw = float(cardinal) * PI * 0.5
				rig.refresh()
				assert_true(
					rig.camera.global_transform.is_finite(), "Orbit transform must stay finite"
				)
				var eye: Vector3 = rig.camera.global_position
				var camera_height: float = float(lab.call("_height_at", Vector2(eye.x, eye.z)))
				assert_true(
					is_finite(camera_height), "Only the camera helper clamps to the source edge"
				)
	var outside: Dictionary = adapter.sample_surface(Vector2(100.0, 100.0))
	assert_false(
		bool(outside["allowed"]), "Camera clamping must not allow plants outside the source"
	)
	lab.call("set_view", 0)
