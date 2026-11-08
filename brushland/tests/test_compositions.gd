extends SceneTree
func _initialize() -> void:
	var hashes:Array=[]
	for id in IslandCompositions.IDS:
		var d=IslandData.new();IslandCompositions.create(d,id)
		assert(d.history.is_empty());var original=d.snapshot()
		var sim=ResidentSim.new()
		for i in range(1000):sim.tick(d,0.25)
		assert(sim.people.size()==4)
		var restored=IslandData.new();restored.restore(JSON.parse_string(JSON.stringify(original)))
		assert(restored.tiles==d.tiles)
		var other=IslandData.new();IslandCompositions.create(other,id);assert(original==other.snapshot())
		hashes.append(JSON.stringify(original).sha256_text())
	assert(hashes[0]!=hashes[1] and hashes[1]!=hashes[2])
	print("PASS three reproducible compositions, four residents and reload")
	quit()
