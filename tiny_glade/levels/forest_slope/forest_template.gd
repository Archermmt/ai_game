class_name ForestTemplate
extends RefCounted
## T052 opening source layout. Both builders share the same terrain and outer trees.


static func empty() -> Dictionary:
	var draft: Dictionary = WorldDocument.new("forest-slope-scn-01").snapshot()
	draft["terrain"]["base_profile"] = "forest_slope_v1"
	draft["environment"]["palette"] = GardenPalette.DEFAULTS.duplicate()
	draft["environment"]["wind_direction"] = 0.4
	for i: int in range(12):
		var angle: float = TAU * float(i) / 12
		var item: Dictionary = InstanceEdits.allocate(
			draft, Vector3(sin(angle) * 21, 0, cos(angle) * 21)
		)
		item["asset_id"] = ["NAT-01", "NAT-02", "NAT-03"][i % 3]
		item["scale"] = 0.85 + 0.08 * (i % 3)
	draft["camera_bookmarks"] = [
		{
			"id": "recommended_day",
			"target": [0, 1, 1],
			"distance": 31.0,
			"yaw": 0.65,
			"pitch": 0.68
		},
		{
			"id": "recommended_garden",
			"target": [-3, 0.7, 4],
			"distance": 19.0,
			"yaw": 1.1,
			"pitch": 0.56
		}
	]
	return draft


static func create() -> Dictionary:
	var draft: Dictionary = empty()
	var home: Dictionary = WorldDocument.allocate_building(
		draft, Vector3(-2, 0.15, -1), Vector3(5, 3.2, 5)
	)
	home["openings"] = [
		{
			"kind": "rect",
			"center": 0.5,
			"width": 1.1,
			"height": 2.05,
			"source": "manual",
			"sill": 0.0
		},
		{
			"kind": "rect",
			"center": 0.5,
			"width": 1.0,
			"height": 1.0,
			"sill": 1.1,
			"facade": 1,
			"source": "manual"
		},
		{
			"kind": "round",
			"center": 0.5,
			"width": 1.0,
			"height": 1.0,
			"sill": 1.2,
			"facade": 3,
			"source": "manual"
		},
		{
			"kind": "rect",
			"center": 0.5,
			"width": 1.1,
			"height": 2.05,
			"variant": "glass",
			"facade": 2,
			"source": "manual"
		}
	]
	var round_home: Dictionary = WorldDocument.allocate_building(
		draft, Vector3(-8, 0.1, -4), Vector3(3.5, 3.0, 3.5), "round"
	)
	round_home["openings"] = [
		{"kind": "arch", "center": 0.15, "width": 1.2, "height": 2.1, "source": "manual"}
	]
	PathGeometry.allocate(draft, [[-2, 0, 9], [-2, 0, 5], [-2, 0, 3.2]])
	draft["paths"][0]["curved"] = true
	draft = PondShape.draw(
		draft, [[5.6, -2.5], [8.4, -2.5], [8.8, -0.5], [8.4, 1.5], [5.6, 1.5], [5.2, -0.5]]
	)
	GardenStructures.allocate(draft, "bridge", Vector2(7, -3), Vector2(7, 2))
	GardenStructures.allocate(draft, "stair", Vector2(-2, 1.55), Vector2(-2, 3.2))
	FenceGeometry.allocate(draft, [[-11, 0, 3], [-11, 0, 8], [-5, 0, 8]])
	var bench_id: String = ""
	for entry: Array in [
		["PROP-01", -6, 4],
		["PROP-02", -3.5, 6],
		["PROP-03", -5, 4],
		["PROP-04", 2.8, 6],
		["PROP-05", 0, 5],
		["PROP-06", 1.5, 5],
		["PROP-07", -6, 4],
		["PROP-08", -5, 5.2],
		["NAT-04", -7, 5],
		["NAT-05", -7.8, 5.2],
		["NAT-06", -9, 6],
		["NAT-08", 10.5, 5],
		["NAT-09", 11.2, 4]
	]:
		var item: Dictionary = InstanceEdits.allocate(draft, Vector3(entry[1], 0, entry[2]))
		item["asset_id"] = entry[0]
		if entry[0] == "PROP-01":
			bench_id = item["id"]
		if entry[0] == "PROP-07":
			item["support_id"] = bench_id
	HedgeRules.allocate(draft, [[-10, 10], [-6, 10], [-6, 12]])
	VegetationBrush.paint(draft, Vector2(9, 9), "plants", 3, 0.7, {})
	return draft
