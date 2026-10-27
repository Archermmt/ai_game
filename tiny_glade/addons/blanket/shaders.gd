# SPDX-FileCopyrightText: © 2026 1hue
# SPDX-License-Identifier: MIT

extends RefCounted
class_name BlanketShaders

const SHADER_PATH = "res://addons/blanket/passes/"

class BlanketShader:
	var versions: Array[StringName]
	## Empty string in case of non-versioned shaders
	var shaders: Dictionary[StringName, RID]
	## Empty string in case of non-versioned shaders
	var pipelines: Dictionary[StringName, RID]
	var rd: RenderingDevice


	func _init(path: String, specialization_constants := []) -> void:
		rd = RenderingServer.get_rendering_device()
		if rd == null:
			push_warning("Blanket addon needs Forward+ or Mobile - compute shaders are unavailable")
			return

		var shader_file: RDShaderFile = load(path)
		var spec_constants := BlanketUtil.create_spec_constants(specialization_constants)

		versions = shader_file.get_version_list()

		for version in versions:
			var rid := compile_shader(shader_file, version)

			shaders[version] = rid
			pipelines[version] = rd.compute_pipeline_create(rid, spec_constants)

	func compile_shader(shader_file: RDShaderFile, version: StringName) -> RID:
		var shader_spirv: RDShaderSPIRV = shader_file.get_spirv(version)
		var err = shader_spirv.get_stage_compile_error(RenderingDevice.SHADER_STAGE_COMPUTE)
		if err: push_error(err)

		return rd.shader_create_from_spirv(shader_spirv)

	func _notification(what) -> void:
		if what == NOTIFICATION_PREDELETE:
			for rid in pipelines.values():
				if rid:
					rd.free_rid(rid)
			for rid in shaders.values():
				if rid:
					rd.free_rid(rid)


static var rd: RenderingDevice
static var shaders: Array[RID]
static var pipelines: Array[RID]

static var select: BlanketShader
static var dedupe: BlanketShader
static var faces: BlanketShader
static var edges: BlanketShader
static var out_mesh: BlanketShader
static var shrink: BlanketShader
static var fill: BlanketShader
static var boundary_resolve: BlanketShader
static var boundary_write: BlanketShader
static var offset: BlanketShader
static var normals_sum: BlanketShader
static var normals_write: BlanketShader
static var smooth_sum: BlanketShader
static var smooth_write: BlanketShader


static func initialize() -> void:
	if select != null:
		return
	select = BlanketShader.new(SHADER_PATH + "faces/select.glsl")
	dedupe = BlanketShader.new(SHADER_PATH + "faces/dedupe.glsl")
	faces = BlanketShader.new(SHADER_PATH + "faces/faces.glsl")
	edges = BlanketShader.new(SHADER_PATH + "edges.glsl")
	out_mesh = BlanketShader.new(SHADER_PATH + "out_mesh.glsl")
	shrink = BlanketShader.new(
		SHADER_PATH + "bevel/shrink.glsl", [BlanketParams.BEVEL_WIDTH]
	)
	fill = BlanketShader.new(
		SHADER_PATH + "bevel/fill.glsl", [BlanketParams.BEVEL_SEGMENTS, BlanketParams.BEVEL_ARCS]
	)
	boundary_resolve = BlanketShader.new(
		SHADER_PATH + "boundary/boundary_resolve.glsl", [BlanketParams.BEVEL_SEGMENTS, BlanketParams.BEVEL_ARCS]
	)
	boundary_write = BlanketShader.new(
		SHADER_PATH + "boundary/boundary_write.glsl", [BlanketParams.WALL_SEGMENTS, BlanketParams.BEVEL_ARCS]
	)
	offset = BlanketShader.new(SHADER_PATH + "offset.glsl")
	normals_sum = BlanketShader.new(SHADER_PATH + "normals/normals_sum.glsl")
	normals_write = BlanketShader.new(SHADER_PATH + "normals/normals_write.glsl")
	smooth_sum = BlanketShader.new(SHADER_PATH + "smooth/smooth_sum.glsl")
	smooth_write = BlanketShader.new(
		SHADER_PATH + "smooth/smooth_write.glsl",
		[SmoothWritePass.SMOOTH_STRENGTH, SmoothWritePass.WALL_STRENGTH]
	)


static func shutdown() -> void:
	select = null
	dedupe = null
	faces = null
	edges = null
	out_mesh = null
	shrink = null
	fill = null
	boundary_resolve = null
	boundary_write = null
	offset = null
	normals_sum = null
	normals_write = null
	smooth_sum = null
	smooth_write = null
