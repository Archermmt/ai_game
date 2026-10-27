extends GutTest

const FOOTPRINTS: Script = preload("res://features/immersion/snow_footprints.gd")
var emitter: Variant


func before_each() -> void:
	emitter = _emitter(WorldDocument.new().snapshot())


func after_each() -> void:
	emitter.shutdown()


func _emitter(source: Dictionary) -> Variant:
	var value: Variant = FOOTPRINTS.new()
	add_child_autofree(value)
	value.configure(source)
	return value


func _line(
	value: Variant,
	from: Vector3,
	to: Vector3,
	parts: int = 20,
	cover: float = 1.0,
	yaw: float = 0.0
) -> void:
	value.update_contact(from, yaw, true, cover, 0.0)
	for index: int in range(1, parts + 1):
		value.update_contact(from.lerp(to, float(index) / parts), yaw, true, cover, 0.02)


func test_distance_drives_alternating_steps_and_only_ground_receives_decals() -> void:
	_line(emitter, Vector3(0, 0, 6), Vector3(0, 0, 3.4))
	var records: Array[Dictionary] = emitter.contact_records()
	assert_eq(records.size(), 4)
	for index: int in records.size():
		var left: bool = index % 2 == 0
		assert_eq(records[index]["left"], left)
		var point: Vector3 = records[index]["point"]
		assert_almost_eq(point.x, -0.1 if left else 0.1, 0.0001)
		assert_almost_eq(point.z, 6.0 - (index + 1) * FOOTPRINTS.STEP_LENGTH, 0.0001)
	var decals: Array[Decal] = emitter.get_decals()
	for decal: Decal in decals:
		assert_eq(decal.cull_mask, 1 << 17)
		assert_not_null(decal.texture_albedo)
		assert_not_null(decal.texture_normal)
		assert_not_null(decal.texture_orm)
		assert_true(decal.global_transform.is_finite())
	assert_ne(decals[0].texture_albedo, decals[1].texture_albedo, "Right sole must be mirrored")


func test_frame_partition_does_not_change_distance_or_foot_sequence() -> void:
	var other: Variant = _emitter(WorldDocument.new().snapshot())
	_line(emitter, Vector3(8, 0, 12), Vector3(8, 0, 2), 100)
	_line(other, Vector3(8, 0, 12), Vector3(8, 0, 2), 10)
	var fine: Array[Dictionary] = emitter.contact_records()
	var coarse: Array[Dictionary] = other.contact_records()
	assert_eq(fine.size(), 15)
	assert_eq(coarse.size(), fine.size())
	for index: int in fine.size():
		assert_lt(Vector3(fine[index]["point"]).distance_to(coarse[index]["point"]), 0.0001)
		assert_eq(fine[index]["left"], coarse[index]["left"])
	other.shutdown()


func test_bare_ground_standing_turns_and_teleports_make_no_phantom_steps() -> void:
	_line(emitter, Vector3.ZERO, Vector3(0, 0, -2), 20, 0.0)
	assert_eq(emitter.active_count(), 0)
	assert_eq(emitter.allocated_count(), 0)
	emitter.update_contact(Vector3.ZERO, 0.0, true, 1.0, 0.02)
	for index: int in 20:
		emitter.update_contact(Vector3.ZERO, float(index) * 0.2, true, 1.0, 0.05)
	assert_eq(emitter.active_count(), 0)
	emitter.update_contact(Vector3(10, 0, 0), 0.0, true, 1.0, 0.02)
	assert_eq(emitter.active_count(), 0, "A reset/teleport must not draw the skipped segment")
	_line(emitter, Vector3(10, 0, 0), Vector3(10, 0, -0.7))
	assert_eq(emitter.active_count(), 1)
	emitter.update_contact(Vector3(10, 0, -0.7), 0.0, true, 0.0, 0.02)
	assert_eq(emitter.active_count(), 0, "Melted snow must not retain visible impressions")


func test_house_pond_and_road_areas_reject_impressions() -> void:
	var house: Dictionary = WorldDocument.new().snapshot()
	WorldDocument.allocate_building(house, Vector3.ZERO, Vector3(4, 3, 4))
	var pond: Dictionary = TerrainField.pond(WorldDocument.new().snapshot(), Vector2.ZERO, 2.3)
	var road: Dictionary = WorldDocument.new().snapshot()
	PathGeometry.allocate(road, [[-3, 0, 0], [3, 0, 0]], 1.2)
	for source: Dictionary in [house, pond, road]:
		var original: Dictionary = source.duplicate(true)
		emitter.configure(source)
		_line(emitter, Vector3(-1, 0, 0), Vector3(1, 0, 0))
		assert_eq(emitter.active_count(), 0)
		assert_gt(emitter.rejected_contacts, 0)
		assert_eq_deep(source, original)


func test_bridge_decks_do_not_receive_terrain_footprints() -> void:
	var source: Dictionary = TerrainField.pond(WorldDocument.new().snapshot(), Vector2.ZERO, 2.3)
	GardenStructures.allocate(source, "bridge", Vector2(0, -3), Vector2(0, 3))
	var surface: WalkSurface = WalkSurface.new()
	surface.configure(source)
	emitter.configure(source)
	for index: int in 31:
		var z: float = -1.5 + float(index) * 0.1
		var height: Variant = surface.ground_at(Vector2(0, z))
		assert_not_null(height, "The bridge must be a real walkable support")
		if height != null:
			emitter.update_contact(Vector3(0, float(height), z), 0.0, true, 1.0, 0.02)
	assert_eq(emitter.active_count(), 0)
	assert_gt(emitter.rejected_contacts, 0)


func test_sloped_ground_controls_position_and_projector_orientation() -> void:
	var source: Dictionary = TerrainField.brush(
		WorldDocument.new().snapshot(), Vector2.ZERO, 0.8, 4
	)
	var field: TerrainField = TerrainField.new(source)
	emitter.configure(source)
	for index: int in 31:
		var x: float = -3.0 + float(index) * 0.1
		emitter.update_contact(
			Vector3(x, field.height_at(Vector2(x, 0)), 0), -PI * 0.5, true, 1.0, 0.02
		)
	var records: Array[Dictionary] = emitter.contact_records()
	assert_gt(records.size(), 2)
	var tilted: bool = false
	for record: Dictionary in records:
		var point: Vector3 = record["point"]
		var normal: Vector3 = field.normal_at(Vector2(point.x, point.z))
		assert_almost_eq(point.y, field.height_at(Vector2(point.x, point.z)), 0.0001)
		assert_lt(normal.distance_to(record["normal"]), 0.0001)
		tilted = tilted or normal.distance_to(Vector3.UP) > 0.01
	assert_true(tilted, "The test must exercise sloped terrain")
	for decal: Decal in emitter.get_decals():
		var point: Vector3 = decal.global_position
		assert_gt(decal.global_basis.y.dot(field.normal_at(Vector2(point.x, point.z))), 0.999)


func test_freeze_pauses_fading_and_exit_releases_all_projectors() -> void:
	_line(emitter, Vector3.ZERO, Vector3(0, 0, -0.7))
	assert_eq(emitter.active_count(), 1)
	var before: Array[Dictionary] = emitter.contact_records()
	emitter.update_contact(Vector3(0, 0, -0.7), 0.0, true, 1.0, 30.0, true)
	assert_eq_deep(emitter.contact_records(), before)
	emitter.update_contact(Vector3(0, 0, -0.7), 0.0, true, 1.0, 15.0)
	var opacity: float = emitter.contact_records()[0]["opacity"]
	assert_between(opacity, 0.01, 0.99)
	emitter.update_contact(Vector3(0, 0, -0.7), 0.0, true, 1.0, 20.0)
	assert_eq(emitter.active_count(), 0)
	assert_eq(emitter.allocated_count(), 1, "Expired nodes may be reused within the fixed pool")
	emitter.update_contact(Vector3.ZERO, 0.0, false, 1.0, 0.02, true)
	assert_eq(emitter.allocated_count(), 0)
	assert_eq(emitter.get_child_count(), 0)


func test_pool_is_bounded_when_a_long_trail_wraps_through_the_scene() -> void:
	var source: Dictionary = WorldDocument.new().snapshot()
	var original: Dictionary = source.duplicate(true)
	emitter.configure(source)
	for index: int in 500:
		var angle: float = float(index) * 0.12
		var feet: Vector3 = Vector3(sin(angle) * 5, 0, cos(angle) * 5)
		emitter.update_contact(feet, angle, true, 1.0, 0.01)
		assert_lte(emitter.allocated_count(), FOOTPRINTS.MAX_PRINTS)
	assert_gt(emitter.total_emitted, FOOTPRINTS.MAX_PRINTS * 2)
	assert_eq(emitter.active_count(), FOOTPRINTS.MAX_PRINTS)
	assert_eq(emitter.get_child_count(), FOOTPRINTS.MAX_PRINTS)
	assert_eq_deep(source, original)
	emitter.configure(source)
	assert_eq(emitter.active_count(), 0)
	assert_eq(emitter.allocated_count(), 0)
