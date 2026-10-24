extends GutTest

var source: Dictionary
var generated: Dictionary


func before_all() -> void:
	source = ArtLayout.create()
	generated = MeadowData.generate(source)


func test_seeded_meadow_is_repeatable_and_does_not_modify_source() -> void:
	var before: Dictionary = source.duplicate(true)
	var again: Dictionary = MeadowData.generate(source)
	assert_eq_deep(again["chunks"], generated["chunks"])
	assert_eq_deep(source, before)
	assert_eq(WorldDocument.validate(source), "")


func test_meadow_has_bounded_chunks_and_simple_shared_geometry() -> void:
	assert_eq(generated["chunks"].size(), 36)
	assert_gt(generated["count"], 30000)
	assert_lte(generated["count"], 40000)
	var mesh: ArrayMesh = MeadowData.blade_mesh()
	assert_eq(mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() / 3, 9)


func test_all_blades_clear_homes_entrances_and_water() -> void:
	var houses_clear: bool = true
	var entries_clear: bool = true
	var pond_clear: bool = true
	for items: Array in generated["chunks"].values():
		for item: Dictionary in items:
			var p: Vector2 = Vector2(item["p"].x, item["p"].z)
			for home: Dictionary in source["buildings"]:
				houses_clear = houses_clear and not TerrainField.conflicts(p, 0.1, home)
			entries_clear = entries_clear and not TerrainEdits.entrance_protected(source, p)
			pond_clear = pond_clear and PondShape.distance(source["pool"], p) >= 0.55
	assert_true(houses_clear)
	assert_true(entries_clear)
	assert_true(pond_clear)


func test_meadow_grounds_follow_the_same_source_height_field() -> void:
	var field: TerrainField = TerrainField.new(source)
	var valid: bool = true
	for items: Array in generated["chunks"].values():
		for item: Dictionary in items.slice(0, 20):
			valid = (
				valid
				and (
					absf(item["p"].y - field.height_at(Vector2(item["p"].x, item["p"].z)) + 0.015)
					< 0.000001
				)
			)
	assert_true(valid)


func test_environment_changes_do_not_trigger_geometry_reseeding() -> void:
	var before: int = MeadowData.signature(source)
	var changed: Dictionary = source.duplicate(true)
	changed["environment"]["wind_strength"] = 1.0
	changed["environment"]["dusk"] = true
	assert_eq(MeadowData.signature(changed), before)
	changed = TerrainField.brush(changed, Vector2(18, 18), 0.1)
	assert_ne(MeadowData.signature(changed), before)


func test_grass_density_and_focus_preferences_validate_and_roundtrip() -> void:
	var preferences: UserPreferences = UserPreferences.new()
	preferences.values.merge({"grass_density": 0.0, "garden_focus": false})
	var path: String = "user://qa_garden_preferences.cfg"
	assert_eq(preferences.save_file(path), OK)
	var loaded: UserPreferences = UserPreferences.new()
	assert_eq(loaded.load_file(path), OK)
	assert_eq(loaded.values["grass_density"], 0.0)
	assert_false(loaded.values["garden_focus"])
	for value: Variant in [-0.1, 1.1, NAN, INF, "high"]:
		loaded.values["grass_density"] = value
		assert_false(UserPreferences.valid(loaded.values))
	loaded.values["grass_density"] = 0.5
	loaded.values["garden_focus"] = 1
	assert_false(UserPreferences.valid(loaded.values))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	preferences.reset()


func test_changed_seed_changes_grass_but_leaves_manual_content_identical() -> void:
	var changed: Dictionary = source.duplicate(true)
	changed["world_seed"] = "garden-other-seed"
	var alternate: Dictionary = MeadowData.generate(changed)
	assert_ne(alternate["chunks"], generated["chunks"])
	assert_eq_deep(changed["instances"], source["instances"])


func test_paths_are_clear_even_between_their_control_points() -> void:
	var valid: bool = true
	for path: Dictionary in source["paths"]:
		var points: Array[Vector2] = PathCurve.sample(path)
		for items: Array in generated["chunks"].values():
			for item: Dictionary in items:
				var p: Vector2 = Vector2(item["p"].x, item["p"].z)
				for i: int in range(points.size() - 1):
					if (
						p.distance_to(
							Geometry2D.get_closest_point_to_segment(p, points[i], points[i + 1])
						)
						< path["width"] * 0.5 + 0.15
					):
						valid = false
	assert_true(valid)
