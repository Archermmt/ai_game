extends GutTest

const ArtBoot = preload("res://app/art_boot.gd")


func test_brush_at_far_bridgehead_rebuilds_the_near_landing() -> void:
	var garden: Dictionary = WorldDocument.new("bridge-approach").snapshot()
	garden["pool"] = {"center": [0, 0], "radius": 2.0, "water_y": -0.15}
	var bridge: Dictionary = GardenStructures.allocate(
		garden, "bridge", Vector2(-3, 0), Vector2(2.8, 0), 1.0
	)
	PathGeometry.allocate(garden, [[2.8, 0, 0], [6, 0, 0]], 0.88)
	assert_eq(GardenStructures.status(garden, bridge), "")
	var geometry: Dictionary = {}
	var paths: Dictionary = {}
	var before: Dictionary = ArtBoot._evaluate_art(garden, geometry, paths)
	var raised: Dictionary = TerrainField.brush(garden, Vector2(-3, 0), 0.8, 0.5)
	assert_ne(GardenStructures.status(raised, bridge), "")
	var after: Dictionary = ArtBoot._evaluate_art(raised, geometry, paths)
	assert_ne(before["versions"]["path"], after["versions"]["path"])
	assert_ne(
		before["art_path_arrays"][Mesh.ARRAY_VERTEX], after["art_path_arrays"][Mesh.ARRAY_VERTEX]
	)
	var restored: Dictionary = ArtBoot._evaluate_art(garden, geometry, paths)
	assert_eq(
		before["art_path_arrays"][Mesh.ARRAY_VERTEX], restored["art_path_arrays"][Mesh.ARRAY_VERTEX]
	)
