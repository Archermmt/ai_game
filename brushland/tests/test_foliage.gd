extends SceneTree
func _initialize() -> void:
	var d=IslandData.new();DemoIsland.create(d);var snapshot=d.snapshot();var surface=IslandSurface.new(snapshot)
	var first=FoliageLayer.generate(surface,Vector2i(3,3))
	assert(first==FoliageLayer.generate(surface,Vector2i(3,3)))
	var count=0
	for layer in first:
		for item in layer:
			var pos=item.transform.origin;var p=Vector2i(roundi(pos.x),roundi(pos.z));var c=d.cell(p)
			assert(c.surface=="grass" and not c.road)
			for o in d.objects:assert(not p in BuildingRules.footprint(o))
			assert(absf(pos.y+0.015-surface.height_at(Vector2(pos.x,pos.z)))<0.001)
			count+=1
	assert(count>100)
	d.paint([Vector2i(5,5)],"grass");d.undo()
	assert(FoliageLayer.generate(IslandSurface.new(d.snapshot()),Vector2i(3,3))==first)
	print("PASS foliage deterministic transforms, exclusion, grounding and undo: ",count," instances")
	quit()
