extends GutTest
## Bounded contact timing and the real renderer's public shader hand-off.


func _nonzero(samples: PackedVector4Array) -> int:
	var count: int = 0
	for contact: Vector4 in samples:
		count += int(contact.w > 0)
	return count


func test_idle_and_stationary_contact_do_not_build_a_trail() -> void:
	var state: GrassWalkerContact = GrassWalkerContact.new()
	state.advance(0.5)
	assert_eq(state.samples().size(), 4)
	assert_eq(_nonzero(state.samples()), 0)
	state.set_contact(Vector3(12, 0.4, 9), true)
	for index: int in 100:
		state.advance(0.016)
	assert_eq(_nonzero(state.samples()), 1)
	assert_eq(state.samples()[0], Vector4(12, 0.4, 9, 1))


func test_moving_contact_is_bounded_and_returns_after_exit() -> void:
	var state: GrassWalkerContact = GrassWalkerContact.new()
	for index: int in 20:
		state.set_contact(Vector3(index * 0.36, 0, 0), true)
		state.advance(0.12)
	assert_eq(_nonzero(state.samples()), 4)
	assert_almost_eq(state.samples()[0].x, 6.84, 0.0001)
	assert_eq(state.samples()[0].w, 1.0)
	assert_lt(state.samples()[3].w, state.samples()[1].w)
	state.set_contact(Vector3.ZERO, false)
	state.advance(0.4)
	assert_gt(state.samples()[0].w, 0.0)
	assert_lt(state.samples()[0].w, 1.0)
	state.advance(0.61)
	assert_eq(_nonzero(state.samples()), 0)


func test_freeze_holds_shape_and_teleport_does_not_leave_a_stretched_trail() -> void:
	var state: GrassWalkerContact = GrassWalkerContact.new()
	state.set_contact(Vector3.ZERO, true)
	state.advance(0.1)
	var frozen: PackedVector4Array = state.samples()
	state.set_contact(Vector3(8, 0, 4), true, true)
	state.advance(5)
	assert_eq(state.samples(), frozen)
	state.set_contact(Vector3(8, 0, 4), true)
	state.advance(5, false, true)
	assert_eq(state.samples(), frozen)
	state.advance(0)
	assert_eq(_nonzero(state.samples()), 1)
	assert_eq(state.samples()[0], Vector4(8, 0, 4, 1))


func test_reduced_motion_clears_contact_and_resume_uses_current_feet() -> void:
	var state: GrassWalkerContact = GrassWalkerContact.new()
	state.set_contact(Vector3.ZERO, true)
	state.advance(0.1)
	state.advance(0.1, true)
	assert_eq(_nonzero(state.samples()), 0)
	state.set_contact(Vector3(1, 0, 0), true)
	state.advance(0.1, true)
	assert_eq(_nonzero(state.samples()), 0)
	state.advance(0)
	assert_eq(_nonzero(state.samples()), 1)
	assert_eq(state.samples()[0], Vector4(1, 0, 0, 1))


func test_invalid_inputs_never_poison_contact_uniforms() -> void:
	var state: GrassWalkerContact = GrassWalkerContact.new()
	state.set_contact(Vector3(2, 0, 3), true)
	state.advance(0.1)
	var original: PackedVector4Array = state.samples()
	state.advance(NAN)
	state.advance(-0.1)
	assert_eq(state.samples(), original)
	state.set_contact(Vector3(INF, 0, 0), true)
	state.advance(0.2)
	for contact: Vector4 in state.samples():
		assert_true(contact.is_finite())
	assert_lt(state.samples()[0].w, 1.0)


func test_renderer_updates_shared_uniforms_and_stops_work_when_contact_expires() -> void:
	# Keep the renderer outside the tree: no imported grass loading or worker job.
	var renderer: ProductionGrassRenderer = ProductionGrassRenderer.new()
	assert_false(renderer.material.get_shader_parameter("walker_interaction_active"))
	renderer.set_walker_contact(Vector3(1, 0, 2), true)
	renderer._process(0.016)
	assert_true(renderer.material.get_shader_parameter("walker_interaction_active"))
	assert_eq(renderer.get_walker_contacts()[0], Vector4(1, 0, 2, 1))
	assert_almost_eq(renderer.material.get_shader_parameter("walker_contact_extent"), 1.15, 0.0001)
	var frozen: PackedVector4Array = renderer.get_walker_contacts()
	renderer.material.set_shader_parameter("freeze_time", true)
	renderer.set_walker_contact(Vector3(2, 0, 2), true)
	renderer._process(0.8)
	assert_eq(renderer.get_walker_contacts(), frozen)
	renderer.material.set_shader_parameter("freeze_time", false)
	renderer._process(0.05)
	assert_eq(renderer.get_walker_contacts()[0], Vector4(2, 0, 2, 1))
	assert_gt(renderer.material.get_shader_parameter("walker_contact_extent"), 1.15)
	renderer.material.set_shader_parameter("reduce_motion", true)
	renderer._process(0.05)
	assert_false(renderer.material.get_shader_parameter("walker_interaction_active"))
	assert_eq(_nonzero(renderer.get_walker_contacts()), 0)
	renderer.material.set_shader_parameter("reduce_motion", false)
	renderer._process(0.05)
	renderer.set_walker_contact(Vector3.ZERO, false)
	renderer._process(0.4)
	assert_true(renderer.material.get_shader_parameter("walker_interaction_active"))
	renderer._process(0.7)
	assert_false(renderer.material.get_shader_parameter("walker_interaction_active"))
	renderer.free()


func test_exit_returns_grass_while_restored_photo_time_remains_frozen() -> void:
	var renderer: ProductionGrassRenderer = ProductionGrassRenderer.new()
	renderer.set_walker_contact(Vector3(1, 0, 2), true)
	renderer._process(0.016)
	assert_true(renderer.material.get_shader_parameter("walker_interaction_active"))
	var strength: float = renderer.get_walker_contacts()[0].w
	renderer.material.set_shader_parameter("freeze_time", true)
	renderer.set_walker_contact(Vector3.ZERO, false, true)
	renderer._process(0.4)
	assert_true(renderer.material.get_shader_parameter("walker_interaction_active"))
	assert_gt(renderer.get_walker_contacts()[0].w, 0.0)
	assert_lt(renderer.get_walker_contacts()[0].w, strength)
	assert_true(renderer.material.get_shader_parameter("freeze_time"))
	renderer._process(0.61)
	assert_eq(_nonzero(renderer.get_walker_contacts()), 0)
	assert_false(renderer.material.get_shader_parameter("walker_interaction_active"))
	assert_true(renderer.material.get_shader_parameter("freeze_time"))
	renderer.free()
