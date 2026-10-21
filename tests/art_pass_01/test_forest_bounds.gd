extends GutTest
## ENV scenery is outside the editable square; source-owned perimeter trees remain editable.


func test_derived_forest_crowns_stay_outside_the_editable_core() -> void:
	var source: Dictionary = ArtLayout.empty()
	var placements: Array[Dictionary] = ArtScenery.curtain_placements(source)
	assert_eq(placements.size(), 128)
	var ids: Dictionary = {}
	var minimum_axis: float = INF
	for item: Dictionary in placements:
		var p: Array = item["position"]
		minimum_axis = minf(minimum_axis, maxf(absf(p[0]), absf(p[2])))
		ids[item["id"]] = true
	assert_gte(
		minimum_axis, 30.0, "Every derived trunk has at least 6 m outside the 24 m half-extent"
	)
	assert_gt(
		minimum_axis - 5.2,
		24.0,
		"Even the largest 5.2 m crown radius clears the whole editable square"
	)
	assert_eq(ids.size(), placements.size())


func test_forest_placement_is_seeded_stable_and_does_not_change_player_source() -> void:
	var source: Dictionary = ArtLayout.empty()
	var before: Dictionary = source.duplicate(true)
	var first: Array[Dictionary] = ArtScenery.curtain_placements(source)
	assert_eq_deep(ArtScenery.curtain_placements(source), first)
	assert_eq_deep(source, before)
	assert_eq(source["instances"].size(), 20, "The original perimeter trees remain source-owned")
	var alternate: Dictionary = source.duplicate(true)
	alternate["world_seed"] = "a-different-forest-curtain-seed"
	var second: Array[Dictionary] = ArtScenery.curtain_placements(alternate)
	assert_ne(first, second)
	assert_eq(first.size(), second.size())
	assert_eq(
		first[0]["id"], second[0]["id"], "The same grove slots keep stable derived identities"
	)


func test_tree_feet_follow_the_actual_apron_or_terrain_surface() -> void:
	var source: Dictionary = ArtLayout.empty()
	var field: TerrainField = TerrainField.new(source)
	var placements: Array[Dictionary] = ArtScenery.curtain_placements(source)
	var all_grounded: bool = true
	var apron_count: int = 0
	for item: Dictionary in placements:
		var p: Array = item["position"]
		var outside: bool = maxf(absf(p[0]), absf(p[2])) > 32.0
		var expected: float = -0.21 if outside else field.height_at(Vector2(p[0], p[2]))
		all_grounded = all_grounded and is_equal_approx(p[1], expected)
		if outside:
			apron_count += 1
	assert_true(
		all_grounded, "Outside trees rest on the flat apron rather than an extrapolated heightfield"
	)
	assert_gt(apron_count, 0)


func test_forest_preserves_natural_groves_and_both_existing_tree_families() -> void:
	var placements: Array[Dictionary] = ArtScenery.curtain_placements(ArtLayout.empty())
	var counts: Dictionary = {"NAT-01": 0, "NAT-02": 0}
	var scales: Dictionary = {}
	var positions: Dictionary = {}
	for item: Dictionary in placements:
		counts[item["asset_id"]] += 1
		scales[item["scale"]] = true
		positions[Vector2(item["position"][0], item["position"][2])] = true
	assert_eq(counts["NAT-01"], 80)
	assert_eq(counts["NAT-02"], 48)
	assert_gt(scales.size(), 100)
	assert_eq(positions.size(), placements.size(), "Individual members retain distinct positions")
