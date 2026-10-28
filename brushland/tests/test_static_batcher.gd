extends SceneTree

const Batcher = preload("res://game/art/static_batcher.gd")
var failed := false
var checks := 0
var completed_scenarios := 0

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failed = true
		push_error(message)

func _run() -> void:
	_same_material()
	_distinct_resources()
	_unsupported_surfaces()
	_supported_multisurface()
	_chunks_and_transforms()
	_vertex_attributes()
	_overlay_and_next_pass()
	_keep_children()
	_dynamic_and_lod()
	_shadow_channels()
	_imported_shadow_mesh()
	_shadow_multisurface_and_lod()
	# Godot reports runtime script errors without changing the process exit code;
	# this also catches tests that aborted before reaching their assertions.
	check(completed_scenarios == 12, "every static batching scenario must reach its assertions")
	if "--negative-control" in OS.get_cmdline_user_args():
		check(false, "intentional negative control")
	print("%s static batcher (%d checks)" % ["FAIL" if failed else "PASS", checks])
	quit(1 if failed else 0)

func _parent() -> Node3D:
	var parent = Node3D.new()
	root.add_child(parent)
	return parent

func _material() -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.4, 0.6, 0.2)
	return material

func _instance(parent: Node3D, material: Material, position: Vector3 = Vector3(1, 0, 1), mesh: Mesh = null) -> MeshInstance3D:
	var instance = MeshInstance3D.new()
	instance.mesh = mesh if mesh != null else BoxMesh.new()
	instance.material_override = material
	instance.position = position
	parent.add_child(instance)
	return instance

func _batches(parent: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	for child in parent.get_children():
		if child is MeshInstance3D and child.has_meta("static_batch_chunk"):
			found.append(child)
	return found

func _same_material() -> void:
	var parent = _parent()
	var material = _material()
	material.vertex_color_use_as_albedo = true
	var first = _instance(parent, material)
	var second = _instance(parent, material, Vector3(2, 0, 1))
	var stats = Batcher.compact(parent)
	check(stats.merged_source_count == 2 and stats.batches == 1, "shared material in one chunk should batch")
	check(not is_instance_valid(first) and not is_instance_valid(second), "merged sources should be removed")
	var batches = _batches(parent)
	check(batches.size() == 1 and batches[0].material_override == material, "batch must retain original material resource")
	check(batches[0].position.is_equal_approx(Vector3(4, 0, 4)), "batch should use its own chunk origin")
	var repeated = Batcher.compact(parent)
	check(repeated.merged_source_count == 0 and repeated.batches == 0, "repeated compact must not consume existing batches")
	parent.free()
	completed_scenarios += 1

func _distinct_resources() -> void:
	var parent = _parent()
	var first_material = _material()
	var second_material = _material()
	var image = Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color.RED)
	first_material.albedo_texture = ImageTexture.create_from_image(image)
	image.fill(Color.BLUE)
	second_material.albedo_texture = ImageTexture.create_from_image(image)
	# Shared Mesh layout caches must never cache per-node surface overrides.
	var shared_mesh = BoxMesh.new()
	var first = _instance(parent, null, Vector3(1, 0, 1), shared_mesh)
	var second = _instance(parent, null, Vector3(2, 0, 1), shared_mesh)
	first.set_surface_override_material(0, first_material)
	second.set_surface_override_material(0, second_material)
	var stats = Batcher.compact(parent)
	check(stats.merged_source_count == 0 and stats.preserved == 2, "equal colors with different textures must not batch")
	check(is_instance_valid(first) and is_instance_valid(second), "distinct material sources must survive")
	check(first.get_active_material(0).albedo_texture != second.get_active_material(0).albedo_texture, "texture resources must remain distinct")
	parent.free()
	completed_scenarios += 1

func _unsupported_surfaces() -> void:
	var parent = _parent()
	var standard = _material()
	var shader = ShaderMaterial.new()
	shader.shader = Shader.new()
	shader.shader.code = "shader_type spatial; void fragment() { ALBEDO = vec3(0.7); }"
	var custom = _instance(parent, shader)
	var mixed_mesh = ArrayMesh.new()
	var box = BoxMesh.new()
	mixed_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, box.surface_get_arrays(0))
	mixed_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, box.surface_get_arrays(0))
	mixed_mesh.surface_set_material(0, standard)
	mixed_mesh.surface_set_material(1, shader)
	mixed_mesh.shadow_mesh = ArrayMesh.new()
	mixed_mesh.shadow_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, box.surface_get_arrays(0))
	mixed_mesh.shadow_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, box.surface_get_arrays(0))
	var mixed = _instance(parent, null, Vector3(2, 0, 1), mixed_mesh)
	_instance(parent, standard, Vector3(3, 0, 1))
	_instance(parent, standard, Vector3(4, 0, 1))
	var stats = Batcher.compact(parent)
	check(stats.merged_source_count == 2 and stats.preserved == 2, "only fully supported sources should batch")
	check(is_instance_valid(custom) and custom.mesh != null, "ShaderMaterial must survive whole")
	check(is_instance_valid(mixed) and mixed.mesh.get_surface_count() == 2, "mixed source must retain every surface")
	check(mixed.get_active_material(0) == standard and mixed.get_active_material(1) == shader, "mixed materials must be unchanged")
	parent.free()
	completed_scenarios += 1

func _chunks_and_transforms() -> void:
	var parent = _parent()
	var material = _material()
	for x in [1.0, 2.0, 17.0, 18.0]:
		_instance(parent, material, Vector3(x, 0, 1))
	var stats = Batcher.compact(parent)
	check(stats.merged_source_count == 4 and stats.batches == 2 and stats.chunks == 2, "spatial chunks must stay separate")
	var centers: Array = []
	for batch in _batches(parent):
		centers.append(batch.global_position)
	check(Vector3(4, 0, 4) in centers and Vector3(20, 0, 4) in centers, "chunk origin positions should match spatial keys")
	parent.free()
	parent = _parent()
	parent.position = Vector3(18, 2, 18)
	parent.rotation = Vector3(0.1, 0.3, 0.05)
	parent.scale = Vector3(1.1, 0.8, 1.3)
	var holder = Node3D.new()
	parent.add_child(holder)
	holder.position = Vector3(1.0, 0.0, 1.0)
	holder.rotation = Vector3(0.0, -0.2, 0.0)
	_instance(holder, material, Vector3.ZERO)
	_instance(holder, material, Vector3(1.0, 0.0, 0.0))
	var before = _corners(parent)
	stats = Batcher.compact(parent)
	check(stats.merged_source_count == 2 and stats.batches == 1, "nested transformed sources should batch")
	check(_same_corners(before, _corners(parent)), "parent transforms and normals must retain world-space geometry")
	parent.free()
	completed_scenarios += 1

func _supported_multisurface() -> void:
	var parent = _parent()
	var shared = _material()
	var unique = _material()
	unique.albedo_color = Color(0.2, 0.4, 0.8)
	var mesh = ArrayMesh.new()
	var box = BoxMesh.new()
	for material in [shared, unique]:
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, box.surface_get_arrays(0))
		mesh.surface_set_material(mesh.get_surface_count() - 1, material)
	_instance(parent, null, Vector3(1, 0, 1), mesh)
	_instance(parent, shared, Vector3(2, 0, 1))
	var before = _corners(parent)
	var stats = Batcher.compact(parent)
	check(stats.merged_source_count == 2 and stats.batches == 2 and stats.merged_surface_count == 3, "a supported source must retain even its unshared material surface")
	check(_same_corners(before, _corners(parent)), "supported multi-surface triangles must not be lost")
	var materials: Array = []
	for batch in _batches(parent):
		materials.append(batch.material_override)
	check(shared in materials and unique in materials, "every supported source material must reach an output batch")
	parent.free()
	completed_scenarios += 1

func _quad(lods: bool = false) -> ArrayMesh:
	var mesh = ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(0, 1, 0)])
	# A non-axis-aligned normal reveals incorrect normal transforms under scale.
	var normal = Vector3(-0.3, -0.4, 1.0).normalized()
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([normal, normal, normal, normal])
	var tangent = Vector3(1.0, 0.0, 0.3).normalized()
	arrays[Mesh.ARRAY_TANGENT] = PackedFloat32Array([tangent.x, tangent.y, tangent.z, 1.0, tangent.x, tangent.y, tangent.z, 1.0, tangent.x, tangent.y, tangent.z, 1.0, tangent.x, tangent.y, tangent.z, 1.0])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0.1, 0.2), Vector2(0.9, 0.2), Vector2(0.9, 0.8), Vector2(0.1, 0.8)])
	arrays[Mesh.ARRAY_TEX_UV2] = PackedVector2Array([Vector2(0.0, 0.1), Vector2(0.5, 0.1), Vector2(0.5, 0.6), Vector2(0.0, 0.6)])
	arrays[Mesh.ARRAY_COLOR] = PackedColorArray([Color.RED, Color.GREEN, Color.BLUE, Color.WHITE])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh_lods = {10.0: PackedInt32Array([0, 1, 2])} if lods else {}
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], mesh_lods)
	return mesh

func _vertex_attributes() -> void:
	var parent = _parent()
	var material = _material()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.uv1_scale = Vector3(0.75, 0.5, 1)
	var first_mesh = _quad()
	first_mesh.surface_set_material(0, material)
	var first = _instance(parent, null, Vector3(1, 0, 1), first_mesh)
	first.rotation = Vector3(0.3, 0.5, 0.1)
	first.scale = Vector3(1.4, 0.7, 1.0)
	var second = _instance(parent, material, Vector3(2, 0, 1), _quad())
	second.rotation = Vector3(-0.2, -0.3, 0.2)
	second.scale = Vector3(0.6, 1.3, 0.9)
	var before = _corners(parent)
	var stats = Batcher.compact(parent)
	check(stats.merged_source_count == 2, "surface material and matching override should batch")
	check(_same_corners(before, _corners(parent)), "UV/UV2/color/normal/tangent channels must survive nonuniform source transforms")
	check(_batches(parent)[0].material_override == material, "UV transforms and sRGB vertex color setting must remain on same resource")
	parent.free()
	completed_scenarios += 1

func _overlay_and_next_pass() -> void:
	var parent = _parent()
	var standard = _material()
	var overlay = _instance(parent, standard)
	overlay.material_overlay = _material()
	var multi_pass_material = _material()
	multi_pass_material.next_pass = _material()
	var multi_pass = _instance(parent, multi_pass_material, Vector3(2, 0, 1))
	_instance(parent, standard, Vector3(3, 0, 1))
	_instance(parent, standard, Vector3(4, 0, 1))
	var stats = Batcher.compact(parent)
	check(stats.merged_source_count == 2 and stats.preserved == 2, "overlay and next_pass should bypass batching")
	check(is_instance_valid(overlay) and overlay.material_overlay != null, "overlay must be retained")
	check(is_instance_valid(multi_pass) and multi_pass.get_active_material(0).next_pass != null, "next_pass must be retained")
	parent.free()
	completed_scenarios += 1

func _keep_children() -> void:
	var parent = _parent()
	var material = _material()
	var first = _instance(parent, material)
	first.rotation.y = 0.35
	var light = OmniLight3D.new()
	first.add_child(light)
	light.position = Vector3(0.25, 2, -0.25)
	var unsupported = _instance(first, ShaderMaterial.new(), Vector3(0.3, 0.5, 0.2))
	var light_transform = light.global_transform
	var child_transform = unsupported.global_transform
	_instance(parent, material, Vector3(2, 0, 1))
	var stats = Batcher.compact(parent)
	check(stats.merged_source_count == 2 and stats.preserved == 1, "source with children can retain its transform carrier")
	check(is_instance_valid(first) and first.mesh == null and light.get_parent() == first, "attached nonmesh children must survive")
	check(light.global_transform.is_equal_approx(light_transform), "attached light world transform must be unchanged")
	check(is_instance_valid(unsupported) and unsupported.mesh != null and unsupported.global_transform.is_equal_approx(child_transform), "unsupported nested mesh must survive in place")
	parent.free()
	completed_scenarios += 1

func _dynamic_and_lod() -> void:
	var parent = _parent()
	var material = _material()
	var dynamic = Node3D.new()
	parent.add_child(dynamic)
	dynamic.add_to_group("dynamic_visual")
	var moving = _instance(dynamic, material)
	var excluded = _instance(parent, material)
	excluded.set_meta("batch_exclude", true)
	var animated = Node3D.new()
	parent.add_child(animated)
	animated.add_child(AnimationPlayer.new())
	var animated_mesh = _instance(animated, material)
	var transparent = _material()
	transparent.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var transparent_mesh = _instance(parent, transparent)
	var lod_mesh = _instance(parent, material, Vector3(2, 0, 1), _quad(true))
	check(not RenderingServer.mesh_get_surface(lod_mesh.mesh.get_rid(), 0).get("lods", []).is_empty(), "LOD fixture must contain a real reduced-index LOD")
	_instance(parent, material, Vector3(3, 0, 1))
	_instance(parent, material, Vector3(4, 0, 1))
	var stats = Batcher.compact(parent)
	check(stats.merged_source_count == 2 and stats.preserved == 5, "dynamic, transparent, animated and LOD sources must bypass")
	for node in [moving, excluded, animated_mesh, transparent_mesh, lod_mesh]:
		check(is_instance_valid(node) and node.mesh != null, "unsupported source must survive")
	check(stats.preserved_reasons.get("mesh_lod", 0) == 1, "LOD preservation must be recorded")
	parent.free()
	completed_scenarios += 1

# Compare expanded triangle corners independently of vertex indexing.
# Normals are checked in world space with inverse-transpose, including nonuniform
# scale. UV and color are checked together with each corner's position.
func _corners(parent: Node, use_shadow: bool = false) -> Array:
	var result: Array = []
	var queue: Array = [parent]
	while not queue.is_empty():
		var node: Node = queue.pop_back()
		queue.append_array(node.get_children())
		if not node is MeshInstance3D or node.mesh == null:
			continue
		var mesh: Mesh = node.mesh
		if use_shadow:
			mesh = mesh.shadow_mesh if mesh is ArrayMesh else null
			if mesh == null:
				continue
		var normal_basis = node.global_basis.inverse().transposed()
		for surface in range(mesh.get_surface_count()):
			var arrays = mesh.surface_get_arrays(surface)
			var indices = arrays[Mesh.ARRAY_INDEX]
			var order = indices if indices != null and not indices.is_empty() else range(arrays[Mesh.ARRAY_VERTEX].size())
			for index in order:
				var position = node.global_transform * arrays[Mesh.ARRAY_VERTEX][index]
				var normal = (normal_basis * arrays[Mesh.ARRAY_NORMAL][index]).normalized() if arrays[Mesh.ARRAY_NORMAL] != null else Vector3.ZERO
				var uv = arrays[Mesh.ARRAY_TEX_UV][index] if arrays[Mesh.ARRAY_TEX_UV] != null else Vector2.ZERO
				var uv2 = arrays[Mesh.ARRAY_TEX_UV2][index] if arrays[Mesh.ARRAY_TEX_UV2] != null else Vector2.ZERO
				var color = arrays[Mesh.ARRAY_COLOR][index] if arrays[Mesh.ARRAY_COLOR] != null else Color.WHITE
				var tangent = Vector3.ZERO
				var handedness = 1.0
				if arrays[Mesh.ARRAY_TANGENT] != null:
					var tangents = arrays[Mesh.ARRAY_TANGENT]
					tangent = (node.global_basis * Vector3(tangents[index * 4], tangents[index * 4 + 1], tangents[index * 4 + 2])).normalized()
					handedness = tangents[index * 4 + 3]
				result.append([position, normal, uv, color, uv2, tangent, handedness])
	return result

func _shadow_channels() -> void:
	var parent = _parent()
	parent.position = Vector3(18, 2, 18)
	parent.rotation = Vector3(0.1, 0.2, 0.1)
	parent.scale = Vector3(0.9, 1.2, 0.8)
	var material = _material()
	var mesh = _quad()
	mesh.shadow_mesh = _quad()
	var first = _instance(parent, material, Vector3(1, 0, 1), mesh)
	first.rotation = Vector3(0.2, -0.3, 0.1)
	first.scale = Vector3(1.3, 0.7, 1.1)
	_instance(parent, material, Vector3(2, 0, 1), mesh)
	var before = _corners(parent)
	var shadow_before = _corners(parent, true)
	var stats = Batcher.compact(parent)
	check(stats.merged_source_count == 2 and stats.merged_shadow_source_count == 2 and stats.shadow_batches == 1, "opaque sources with compatible shadow geometry should batch")
	check(_same_corners(before, _corners(parent)), "shadow-enabled batches must retain full main geometry")
	check(_same_corners(shadow_before, _corners(parent, true)), "shadow positions/normal/tangent/UV/UV2/color must retain transformed geometry")
	check(_batches(parent)[0].mesh.shadow_mesh != null, "batch must retain a real shadow mesh")
	parent.free()
	completed_scenarios += 1

func _imported_shadow_mesh() -> void:
	var imported = load("res://game/art/models/bench.glb").instantiate()
	var queue: Array = [imported]
	var mesh: ArrayMesh = null
	while not queue.is_empty():
		var node = queue.pop_back()
		queue.append_array(node.get_children())
		if node is MeshInstance3D and node.mesh is ArrayMesh and node.mesh.shadow_mesh != null:
			var base = RenderingServer.mesh_get_surface(node.mesh.get_rid(), 0)
			var shadow = RenderingServer.mesh_get_surface(node.mesh.shadow_mesh.get_rid(), 0)
			if base.get("lods", []).is_empty() and shadow.get("lods", []).is_empty():
				mesh = node.mesh
				break
	check(mesh != null, "real imported GLB must provide an opaque non-LOD shadow fixture")
	if mesh == null:
		imported.free()
		return
	check(mesh.shadow_mesh.surface_get_array_len(0) < mesh.surface_get_array_len(0), "imported shadow fixture must use fused vertices")
	var parent = _parent()
	parent.rotation.y = 0.15
	parent.scale = Vector3(1.1, 0.8, 1.2)
	var first = _instance(parent, null, Vector3(1, 0, 1), mesh)
	first.rotation = Vector3(0.1, 0.3, 0.05)
	_instance(parent, null, Vector3(2, 0, 1), mesh)
	var before = _corners(parent)
	# Auto-generated fused shadow geometry must contain the same triangle corner
	# positions as its main mesh. This independent expected geometry avoids the
	# engine's compressed position-only surface_get_arrays readback bug.
	var shadow_before = _positions_only(before)
	var stats = Batcher.compact(parent)
	check(stats.merged_shadow_source_count == 2 and stats.shadow_batches == 1, "ordinary imported GLB shadow meshes must no longer bypass batching")
	check(_same_corners(before, _corners(parent)), "imported main triangles and material attributes must survive")
	check(_same_corners(shadow_before, _corners(parent, true)), "fused imported shadow triangles must survive transforms")
	check(_batches(parent)[0].mesh.shadow_mesh.surface_get_array_len(0) == mesh.shadow_mesh.surface_get_array_len(0) * 2, "shadow batching must preserve fused vertex topology")
	parent.free()
	imported.free()
	completed_scenarios += 1

func _positions_only(corners: Array) -> Array:
	var result: Array = []
	for corner in corners:
		result.append([corner[0], Vector3.ZERO, Vector2.ZERO, Color.WHITE, Vector2.ZERO, Vector3.ZERO, 1.0])
	return result

func _shadow_multisurface_and_lod() -> void:
	var parent = _parent()
	var shared = _material()
	var unique = _material()
	var mesh = _quad()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _quad().surface_get_arrays(0))
	mesh.surface_set_material(0, shared)
	mesh.surface_set_material(1, unique)
	mesh.shadow_mesh = _quad()
	mesh.shadow_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _quad().surface_get_arrays(0))
	_instance(parent, null, Vector3(1, 0, 1), mesh)
	var other = _quad()
	other.shadow_mesh = _quad()
	_instance(parent, shared, Vector3(2, 0, 1), other)
	var shadow_before = _corners(parent, true)
	var stats = Batcher.compact(parent)
	check(stats.merged_shadow_source_count == 2 and stats.shadow_batches == 2, "supported multi-surface shadow geometry must preserve main/shadow mapping")
	check(_same_corners(shadow_before, _corners(parent, true)), "unshared shadow surfaces must not be dropped")
	parent.free()
	parent = _parent()
	var lod_mesh = _quad()
	lod_mesh.shadow_mesh = _quad(true)
	var source = _instance(parent, shared, Vector3(1, 0, 1), lod_mesh)
	_instance(parent, shared, Vector3(2, 0, 1), lod_mesh)
	stats = Batcher.compact(parent)
	check(stats.merged_source_count == 0 and stats.preserved_reasons.get("shadow_mesh_lod", 0) == 2, "shadow LODs must preserve the entire source")
	check(is_instance_valid(source) and source.mesh.shadow_mesh != null, "shadow LOD bypass must retain its shadow resource")
	parent.free()
	completed_scenarios += 1

func _same_corners(first: Array, second: Array) -> bool:
	if first.size() != second.size():
		return false
	var remaining = second.duplicate()
	for expected in first:
		var found = false
		for index in range(remaining.size()):
			var actual = remaining[index]
			if expected[0].distance_to(actual[0]) < 0.001 and expected[1].distance_to(actual[1]) < 0.001 and expected[2].distance_to(actual[2]) < 0.001 and expected[3].is_equal_approx(actual[3]) and expected[4].distance_to(actual[4]) < 0.001 and expected[5].distance_to(actual[5]) < 0.001 and expected[6] == actual[6]:
				remaining.remove_at(index)
				found = true
				break
		if not found:
			print("unmatched triangle corner: ", expected)
			return false
	return true
