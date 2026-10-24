extends SceneTree


func _initialize() -> void:
	var source: Dictionary = StressLayout.create()
	var cache: Dictionary = {}
	LocalRebuild.evaluate(source, cache)
	var draft: Dictionary = TerrainField.brush(source, Vector2(12, 8), 0.03)
	var result: Dictionary = {}
	for pair: Array in [
		["validate", func() -> Variant: return WorldDocument.validate(draft)],
		["reconcile", func() -> Variant: return VegetationBrush.reconcile(draft)],
		["worker", func() -> Variant: return LocalRebuild.evaluate(draft, cache)],
		["transition", func() -> Variant: return GardenStructures.transition_error(source, draft)],
		["dirty", func() -> Variant: return DirtyGraph.changed(source, draft)],
		["instances", func() -> Variant: return InstanceEdits.validate(draft, {})],
		["terrain", func() -> Variant: return TerrainField.validate(draft)],
		["garden", func() -> Variant: return GardenStructures.validate(draft, {})]
	]:
		var start: int = Time.get_ticks_usec()
		for index: int in range(5):
			pair[1].call()
		result[pair[0]] = (Time.get_ticks_usec() - start) / 5000.0
	print(JSON.stringify(result))
	quit()
