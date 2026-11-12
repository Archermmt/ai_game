extends GutTest


func _opening(kind: String, at: float, width: float, height: float, sill: float) -> Dictionary:
	return {"facade": 0, "kind": kind, "center": at, "width": width, "height": height, "sill": sill}


func test_rect_and_arch_mortar_back_the_joints_and_leave_the_actual_door_clear() -> void:
	var garden: Dictionary = WorldDocument.new("entry-joints").snapshot()
	var home: Dictionary = WorldDocument.allocate_building(garden, Vector3.ZERO, Vector3(6, 3, 4))
	for kind: String in ["rect", "arch"]:
		for at: float in [0.25, 0.68]:
			home["openings"] = [_opening(kind, at, 1.0, 2.05, 0)]
			var masonry: CottageMesh = CottageMesh.new()
			CottageArt._opening_details(home, CottageMesh.new(), masonry, 0.3)
			var bed: int = 0
			var flashing: int = 0
			var intrusions: int = 0
			var left: float = at * 6.0 - 3.0
			for i: int in masonry.vertices.size():
				if masonry.colors[i] != CottageArt.Joinery.MORTAR:
					continue
				bed += 1
				var p: Vector3 = masonry.vertices[i]
				var x: float = absf(p.x - left)
				if p.z <= 2.001 or p.z >= 2.08:
					flashing += 1
				if x < 0.499:
					var opening_top: float = 2.05
					if kind == "arch":
						opening_top = 1.55 + sqrt(0.25 - x * x)
					if p.y < opening_top - 0.002:
						intrusions += 1
			assert_gt(bed, 12)
			assert_eq(flashing, 0, "Mortar sits between stone faces and the exterior plaster")
			assert_eq(intrusions, 0, "Opening remains clear after moving the door")


func test_window_spill_tracks_the_opening_and_only_falls_from_glass() -> void:
	var source: Dictionary = WorldDocument.new("side-light").snapshot()
	var home: Dictionary = WorldDocument.allocate_building(
		source, Vector3(3, 0.4, 2), Vector3(6, 3, 4)
	)
	home["openings"] = [_opening("rect", 0.2, 1, 2, 0), _opening("rect", 0.75, 0.8, 1, 1)]
	var lights: LanternController = LanternController.new()
	var before: Dictionary = source.duplicate(true)
	lights.configure_woodland(source)
	lights.advance(Vector3.ZERO, 0.0)
	assert_eq(lights.active_window_count, 0)
	lights.advance(Vector3.ZERO, 0.8)
	assert_eq(lights.active_window_count, 1)
	var first: Vector3 = lights._window_lights[0].position
	assert_gt(first.z, 4.0)
	assert_eq_deep(source, before)
	home["openings"][1]["facade"] = 1
	lights.configure_woodland(source)
	lights.advance(Vector3.ZERO, 0.8)
	var moved: Vector3 = lights._window_lights[0].position
	assert_gt(moved.x, 6.0)
	assert_ne(moved, first)
	home["openings"].pop_back()
	lights.configure_woodland(source)
	lights.advance(Vector3.ZERO, 1.0)
	assert_eq(lights.active_window_count, 0)
	assert_false(lights._window_lights[0].visible)
	home["openings"][0]["variant"] = "glass"
	lights.configure_woodland(source)
	lights.advance(Vector3.ZERO, 1.0)
	assert_eq(lights.active_window_count, 1)
	assert_gt(lights._window_lights[0].position.y, 1.5)
	lights.free()


func test_woodland_lantern_positions_modes_and_combined_light_limit() -> void:
	var source: Dictionary = WorldDocument.new("warm-light-limits").snapshot()
	var home: Dictionary = WorldDocument.allocate_building(source, Vector3.ZERO, Vector3(8, 3, 4))
	home["openings"] = [_opening("rect", 0.1, 0.8, 1, 1), _opening("rect", 0.8, 1, 1, 1)]
	var poses: Dictionary = {}
	for i: int in 5:
		var id_value: String = "lamp%d" % i
		source["instances"].append({"id": id_value, "asset_id": "PROP-08", "lamp_mode": "on"})
		poses[id_value] = Transform3D(Basis.IDENTITY, Vector3(i, 0, 2))
	var controller: LanternController = LanternController.new()
	controller.configure(source, poses, {})
	controller.configure_woodland(source)
	controller.advance(Vector3.ZERO, 1)
	assert_eq(controller.active_ids.size(), 4)
	assert_eq(controller.active_window_count, 0)
	assert_eq(controller.lights["lamp0"].position, Vector3(0, 0.28, 2))
	for i: int in 3:
		source["instances"][i]["lamp_mode"] = "off"
	controller.configure(source, poses, {})
	controller.configure_woodland(source)
	controller.advance(Vector3.ZERO, 1)
	assert_eq(controller.active_ids.size(), 2)
	assert_eq(controller.active_window_count, 2)
	controller.advance(Vector3.ZERO, 0)
	assert_eq(controller.active_ids.size(), 2)
	assert_eq(controller.active_window_count, 0)
	controller.free()
