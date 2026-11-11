extends GutTest


func test_shallows_follow_a_redrawn_pond_and_leave_the_document_untouched() -> void:
	var source: Dictionary = WoodlandLayout.create()
	var original: Dictionary = source.duplicate(true)
	var first := Node3D.new()
	WoodlandPond.add_shallows(first, source)
	assert_eq_deep(source, original)
	var old: MeshInstance3D = first.get_node("GravelShallows")
	var bounds: AABB = old.mesh.get_aabb()
	assert_true(bounds.has_volume())
	assert_lt(bounds.end.y, float(source["pool"]["water_y"]) + 0.14)
	source["pool"] = {"center": [-14, 0], "radius": 2.6, "water_y": 0.1}
	var moved := Node3D.new()
	WoodlandPond.add_shallows(moved, source)
	assert_false(bounds.intersects(moved.get_node("GravelShallows").mesh.get_aabb()))
	source["pool"] = {}
	var empty := Node3D.new()
	WoodlandPond.add_shallows(empty, source)
	assert_eq(empty.get_child_count(), 0)
	first.free()
	moved.free()
	empty.free()
