class_name StaticBatcher
extends RefCounted

## Conservative static batching. Unsupported render semantics keep the whole source
## node intact; material resources are never compared by a subset of their values.
const INSTANCE_PROPERTIES = [
	"layers", "cast_shadow", "gi_mode", "gi_lightmap_texel_scale",
	"gi_lightmap_scale", "extra_cull_margin", "ignore_occlusion_culling",
	"sorting_offset", "sorting_use_aabb_center",
]
const CUSTOM_ARRAYS = Mesh.ARRAY_FORMAT_CUSTOM0 | Mesh.ARRAY_FORMAT_CUSTOM1 | Mesh.ARRAY_FORMAT_CUSTOM2 | Mesh.ARRAY_FORMAT_CUSTOM3 | Mesh.ARRAY_FORMAT_BONES | Mesh.ARRAY_FORMAT_WEIGHTS

static func compact(parent: Node3D, chunk_size: float = 8.0) -> Dictionary:
	var stats = {
		"source_count": 0, "candidate_source_count": 0,
		"merged_source_count": 0, "merged_surface_count": 0,
		"merged_shadow_source_count": 0, "shadow_batches": 0,
		"batches": 0, "chunks": 0, "preserved": 0,
		"preserved_reasons": {},
	}
	if not is_instance_valid(parent) or not parent.is_inside_tree() or not is_finite(chunk_size) or chunk_size <= 0.0:
		stats["error"] = "compact requires an in-tree parent and a positive finite chunk size"
		return stats
	var groups: Dictionary = {}
	var candidates: Array = []
	# Imported scenes share many Mesh resources. Inspect their serialized formats
	# and LOD data once per call, while checking instance/material state separately.
	var mesh_layouts: Dictionary = {}
	var queue: Array = [parent]
	while not queue.is_empty():
		var item: Node = queue.pop_back()
		for child in item.get_children():
			queue.append(child)
		if item == parent or not item is MeshInstance3D or item.mesh == null:
			continue
		var node: MeshInstance3D = item
		stats.source_count += 1
		var formats: Array = []
		var reason = _preserve_reason(node, parent, formats, mesh_layouts)
		if not reason.is_empty():
			_preserve(stats, reason)
			continue
		var transform = parent.global_transform.affine_inverse() * node.global_transform
		var world_center = node.global_transform * node.mesh.get_aabb().get_center()
		var chunk = Vector2i(floori(world_center.x / chunk_size), floori(world_center.z / chunk_size))
		var render_values: Array = []
		for property in INSTANCE_PROPERTIES:
			render_values.append(node.get(property))
		var shadow = node.mesh.shadow_mesh if node.mesh is ArrayMesh else null
		var layout: Dictionary = mesh_layouts[node.mesh.get_instance_id()]
		var record = {"node": node, "group_keys": [], "transform": transform, "shadow": shadow,
			"surfaces": layout.surfaces, "shadow_surfaces": layout.get("shadow_surfaces", [])}
		for surface in range(node.mesh.get_surface_count()):
			var mat: Material = node.get_active_material(surface)
			# Identity preserves all textures, UV transforms, normal/AO/emission,
			# alpha and other material inputs, including future properties.
			var key = [chunk, mat.get_instance_id(), formats[surface], render_values]
			if not groups.has(key):
				groups[key] = {"entries": [], "material": mat, "chunk": chunk, "settings": render_values}
			groups[key].entries.append({"record": record, "surface": surface})
			record.group_keys.append(key)
		candidates.append(record)
		stats.candidate_source_count += 1

	# A singleton gains nothing. A multi-surface source is converted in full if
	# any of its surfaces has partners, so no unhandled source surface is lost.
	var selected: Dictionary = {}
	for record in candidates:
		for key in record.group_keys:
			if groups[key].entries.size() >= 2:
				selected[record.node.get_instance_id()] = record
				break
		if not selected.has(record.node.get_instance_id()):
			_preserve(stats, "singleton")
	var created: Array = []
	var used_chunks: Dictionary = {}
	for group in groups.values():
		var entries: Array = []
		for entry in group.entries:
			if selected.has(entry.record.node.get_instance_id()):
				entries.append(entry)
		if entries.is_empty():
			continue
		var combined: Array = []
		combined.resize(Mesh.ARRAY_MAX)
		var combined_shadow: Array = []
		combined_shadow.resize(Mesh.ARRAY_MAX)
		# Keep each batch's geometry close to its own chunk origin, even when the
		# boundary has a translated/rotated/scaled transform.
		var world_origin = Vector3((group.chunk.x + 0.5) * chunk_size, 0.0, (group.chunk.y + 0.5) * chunk_size)
		var local_origin = parent.global_transform.affine_inverse() * world_origin
		var to_chunk = Transform3D(Basis.IDENTITY, -local_origin)
		for entry in entries:
			var record: Dictionary = entry.record
			_append_surface(combined, record.surfaces[entry.surface], to_chunk * record.transform)
			if record.shadow != null:
				_append_surface(combined_shadow, record.shadow_surfaces[entry.surface], to_chunk * record.transform)
		var geometry = ArrayMesh.new()
		geometry.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, combined)
		var shadow_geometry: ArrayMesh = null
		if combined_shadow[Mesh.ARRAY_VERTEX] != null:
			shadow_geometry = ArrayMesh.new()
			shadow_geometry.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, combined_shadow)
		if geometry.get_surface_count() != 1 or (shadow_geometry != null and shadow_geometry.get_surface_count() != 1):
			# Do not remove any source unless every output was successfully built.
			for batch in created:
				batch.free()
			stats["error"] = "surface commit failed; all sources retained"
			stats.preserved += selected.size()
			stats.merged_surface_count = 0
			stats.shadow_batches = 0
			return stats
		if shadow_geometry != null:
			geometry.shadow_mesh = shadow_geometry
			stats.shadow_batches += 1
		var batch = MeshInstance3D.new()
		batch.name = "StaticBatch_%d_%d_%d" % [group.chunk.x, group.chunk.y, created.size()]
		batch.mesh = geometry
		batch.position = local_origin
		batch.material_override = group.material
		for index in range(INSTANCE_PROPERTIES.size()):
			batch.set(INSTANCE_PROPERTIES[index], group.settings[index])
		batch.set_meta("batch_exclude", true)
		batch.set_meta("static_batch_chunk", group.chunk)
		parent.add_child(batch)
		created.append(batch)
		used_chunks[group.chunk] = true
		stats.merged_surface_count += entries.size()
	for record in selected.values():
		var node: MeshInstance3D = record.node
		if record.shadow != null:
			stats.merged_shadow_source_count += 1
		if node.get_child_count() > 0:
			# Keep the transform carrier, attached lights and unsupported children.
			node.mesh = null
		else:
			node.free()
	stats.merged_source_count = selected.size()
	stats.batches = created.size()
	stats.chunks = used_chunks.size()
	return stats

static func _append_surface(destination: Array, source: Array, transform: Transform3D) -> void:
	var vertex_offset = 0 if destination[Mesh.ARRAY_VERTEX] == null else destination[Mesh.ARRAY_VERTEX].size()
	var vertices: PackedVector3Array = source[Mesh.ARRAY_VERTEX].duplicate()
	for index in range(vertices.size()):
		vertices[index] = transform * vertices[index]
	_append_channel(destination, Mesh.ARRAY_VERTEX, vertices)
	if source[Mesh.ARRAY_NORMAL] != null:
		# SurfaceTool.append_from uses the position basis for normals; explicitly
		# use inverse-transpose so nonuniform scale and shear preserve shading.
		var normal_basis = transform.basis.inverse().transposed()
		var normals: PackedVector3Array = source[Mesh.ARRAY_NORMAL].duplicate()
		for index in range(normals.size()):
			normals[index] = (normal_basis * normals[index]).normalized()
		_append_channel(destination, Mesh.ARRAY_NORMAL, normals)
	if source[Mesh.ARRAY_TANGENT] != null:
		var tangents: PackedFloat32Array = source[Mesh.ARRAY_TANGENT].duplicate()
		for index in range(0, tangents.size(), 4):
			var tangent = (transform.basis * Vector3(tangents[index], tangents[index + 1], tangents[index + 2])).normalized()
			tangents[index] = tangent.x
			tangents[index + 1] = tangent.y
			tangents[index + 2] = tangent.z
			# Mirrored transforms bypass batching, so handedness stays unchanged.
		_append_channel(destination, Mesh.ARRAY_TANGENT, tangents)
	for channel in [Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2]:
		if source[channel] != null:
			_append_channel(destination, channel, source[channel])
	if source[Mesh.ARRAY_INDEX] != null:
		var indices: PackedInt32Array = source[Mesh.ARRAY_INDEX].duplicate()
		for index in range(indices.size()):
			indices[index] += vertex_offset
		_append_channel(destination, Mesh.ARRAY_INDEX, indices)

static func _append_channel(destination: Array, channel: int, values: Variant) -> void:
	if destination[channel] == null:
		destination[channel] = values.duplicate()
	else:
		destination[channel].append_array(values)

static func _preserve(stats: Dictionary, reason: String) -> void:
	stats.preserved += 1
	stats.preserved_reasons[reason] = int(stats.preserved_reasons.get(reason, 0)) + 1

static func _preserve_reason(node: MeshInstance3D, boundary: Node3D, formats: Array, mesh_layouts: Dictionary) -> String:
	var ancestor: Node = node
	while ancestor != null:
		if bool(ancestor.get_meta("batch_exclude", false)) or ancestor.is_in_group("dynamic_visual"):
			return "explicit_dynamic_or_excluded"
		if ancestor is Node3D and not ancestor.visible:
			return "hidden_branch"
		if ancestor is Skeleton3D or ancestor is BoneAttachment3D or ancestor is AnimationMixer:
			return "animated_branch"
		if ancestor != boundary and ancestor.get_script() != null:
			return "scripted_branch"
		for child in ancestor.get_children():
			if child is AnimationMixer:
				return "animated_branch"
		if ancestor == boundary:
			break
		ancestor = ancestor.get_parent()
	if node.material_overlay != null:
		return "material_overlay"
	if node.skin != null or RenderingServer.mesh_get_blend_shape_count(node.mesh.get_rid()) > 0:
		return "skinned_or_blend_shapes"
	if not is_zero_approx(node.transparency):
		return "instance_transparency"
	if not is_equal_approx(node.lod_bias, 1.0):
		return "instance_lod"
	if not is_zero_approx(node.visibility_range_begin) or not is_zero_approx(node.visibility_range_end) or not is_zero_approx(node.visibility_range_begin_margin) or not is_zero_approx(node.visibility_range_end_margin):
		return "visibility_range"
	if node.custom_aabb != AABB() or not node.visibility_parent.is_empty():
		return "custom_visibility"
	if node.global_transform.basis.determinant() <= 0.000001:
		return "mirrored_or_singular_transform"
	var mesh_id = node.mesh.get_instance_id()
	if not mesh_layouts.has(mesh_id):
		mesh_layouts[mesh_id] = _mesh_layout(node.mesh)
	var layout: Dictionary = mesh_layouts[mesh_id]
	if not layout.reason.is_empty():
		return layout.reason
	formats.assign(layout.formats)
	for surface in range(node.mesh.get_surface_count()):
		var mat = node.get_active_material(surface)
		if not mat is StandardMaterial3D:
			return "custom_or_missing_material"
		if mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			return "transparent_material"
		if mat.next_pass != null:
			return "material_next_pass"
		if mat.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED or mat.grow or mat.proximity_fade_enabled or mat.distance_fade_mode != BaseMaterial3D.DISTANCE_FADE_DISABLED or mat.uv1_triplanar or mat.uv2_triplanar:
			return "origin_sensitive_material"
	return ""

static func _mesh_layout(mesh: Mesh) -> Dictionary:
	var layout = _geometry_layout(mesh)
	if not layout.reason.is_empty():
		return layout
	var shadow: ArrayMesh = mesh.shadow_mesh if mesh is ArrayMesh else null
	if shadow == null:
		return layout
	# A shadow surface uses the corresponding main surface's render semantics.
	# Keep this one-to-one mapping and the full available shadow vertex channels.
	if shadow.shadow_mesh != null or shadow.get_surface_count() != mesh.get_surface_count():
		return {"reason": "shadow_surface_layout", "formats": []}
	var shadow_layout = _geometry_layout(shadow, true)
	if not shadow_layout.reason.is_empty():
		return {"reason": "shadow_" + shadow_layout.reason, "formats": []}
	for surface in range(layout.formats.size()):
		# Sources with and without shadow geometry cannot share one batch.
		layout.formats[surface] = [layout.formats[surface], shadow_layout.formats[surface]]
	layout["shadow_surfaces"] = shadow_layout.surfaces
	return layout

static func _geometry_layout(mesh: Mesh, shadow_readback: bool = false) -> Dictionary:
	var formats: Array = []
	var surfaces: Array = []
	var layout = {"reason": "", "formats": formats, "surfaces": surfaces}
	if mesh.get_surface_count() == 0:
		layout.reason = "empty_mesh"
		return layout
	if RenderingServer.mesh_get_blend_shape_count(mesh.get_rid()) > 0:
		layout.reason = "blend_shapes"
		return layout
	if mesh is ArrayMesh and mesh.custom_aabb != AABB():
		layout.reason = "custom_mesh_aabb"
		return layout
	for surface in range(mesh.get_surface_count()):
		# RenderingServer's public serialized surface descriptor includes LODs.
		# It also exposes the primitive/format for both PrimitiveMesh and ArrayMesh.
		# Verified against both a plain mesh and a real reduced-index LOD on 4.7.
		var descriptor = RenderingServer.mesh_get_surface(mesh.get_rid(), surface)
		if descriptor.is_empty():
			layout.reason = "unknown_surface_descriptor"
			return layout
		if descriptor.get("primitive", -1) != Mesh.PRIMITIVE_TRIANGLES:
			layout.reason = "non_triangle_surface"
			return layout
		var format = int(descriptor.get("format", 0))
		if format & (CUSTOM_ARRAYS | Mesh.ARRAY_FLAG_USE_2D_VERTICES):
			layout.reason = "custom_or_skin_vertex_channels"
			return layout
		formats.append(format)
		if not descriptor.get("lods", []).is_empty():
			layout.reason = "mesh_lod"
			return layout
		var arrays = _read_surface_arrays(mesh, surface, descriptor, shadow_readback)
		if arrays.is_empty() or not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array:
			layout.reason = "unreadable_vertex_arrays"
			return layout
		surfaces.append(arrays)
	return layout

static func _read_surface_arrays(mesh: Mesh, surface: int, descriptor: Dictionary, shadow_readback: bool) -> Array:
	var arrays = mesh.surface_get_arrays(surface)
	if arrays.size() != Mesh.ARRAY_MAX:
		return []
	if arrays[Mesh.ARRAY_VERTEX] != null:
		return arrays
	# Godot 4.7's compressed position-only readback branch skips assigning its
	# decoded vertices to the result. Decode this verified layout using public
	# surface bytes/stride/offset, retaining the original indices and attributes.
	# https://github.com/godotengine/godot/blob/5b4e0cb0f/servers/rendering/rendering_server.cpp#L1455
	var format = int(descriptor.get("format", 0))
	var channels = format & ((1 << Mesh.ARRAY_MAX) - 1)
	if not shadow_readback or channels != (Mesh.ARRAY_FORMAT_VERTEX | Mesh.ARRAY_FORMAT_INDEX) or not format & Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES or format & Mesh.ARRAY_FLAG_USE_2D_VERTICES:
		return []
	var count = int(descriptor.get("vertex_count", 0))
	var stride = RenderingServer.mesh_surface_get_format_vertex_stride(format, count)
	var offset = RenderingServer.mesh_surface_get_format_offset(format, count, Mesh.ARRAY_VERTEX)
	var bytes: PackedByteArray = descriptor.get("vertex_data", PackedByteArray())
	if count <= 0 or stride != 8 or offset != 0 or bytes.size() != count * stride:
		return []
	var bounds: AABB = descriptor.aabb
	if not bounds.position.is_finite() or not bounds.size.is_finite() or bounds.size.x < 0.0 or bounds.size.y < 0.0 or bounds.size.z < 0.0:
		return []
	var vertices = PackedVector3Array()
	vertices.resize(count)
	for index in range(count):
		var cursor = index * stride + offset
		var unit = Vector3(bytes.decode_u16(cursor), bytes.decode_u16(cursor + 2), bytes.decode_u16(cursor + 4)) / 65535.0
		vertices[index] = unit * bounds.size + bounds.position
	arrays[Mesh.ARRAY_VERTEX] = vertices
	return arrays
