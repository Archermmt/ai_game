extends SceneTree
## Real wall-clock mixed-source transaction soak; no accelerated-time claim.

var document: WorldDocument = WorldDocument.new("w09-soak")
var session: EditSession
var cache: Dictionary = {}
var trace: Array = []
var start: int
var passed: bool = true


func _initialize() -> void:
	_run.call_deferred()


func _prepare(source: Dictionary) -> Dictionary:
	return LocalRebuild.evaluate(source, cache)


func _same(a: Dictionary, b: Dictionary) -> bool:
	a = a.duplicate(true)
	b = b.duplicate(true)
	a.erase("revision")
	b.erase("revision")
	return a == b


func _run() -> void:
	start = Time.get_ticks_msec()
	session = EditSession.new(document)
	var initial: Dictionary = ForestTemplate.create()
	for i: int in range(20):
		var item: Dictionary = InstanceEdits.allocate(initial, Vector3(-18 + i % 5, 0, 13 + i / 5))
		item["asset_id"] = "PROP-01"
	passed = session.replace_document(initial, _prepare)["ok"]
	initial = document.snapshot()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var duration: float = float(args[0]) if not args.is_empty() else 1200.0
	for i: int in range(50):
		var draft: Dictionary = document.snapshot()
		match i % 5:
			0:
				draft = TerrainField.brush(draft, Vector2(17, -16), 0.015, 2)
			1:
				draft["environment"]["dusk"] = not draft["environment"]["dusk"]
			2:
				draft["buildings"][0]["size"][1] = 3.2 + float(i) * 0.001
			3:
				draft["environment"]["wind_strength"] = float(i) / 100
			4:
				VegetationBrush.paint(draft, Vector2(15, 11), "plants", 1.0, 0.3, {})
		var result: Dictionary = session.commit_snapshot(draft, "mixed %d" % i, _prepare)
		passed = passed and result["ok"] and WorldDocument.validate(document.state).is_empty()
		for item: Dictionary in initial["instances"]:
			if item["source"] == "manual" or item["position"][2] < -15:
				passed = passed and item in document.state["instances"]
		trace.append(
			{
				"step": i,
				"ok": passed,
				"elapsed_ms": Time.get_ticks_msec() - start,
				"revision": document.state["revision"]
			}
		)
		var wait: float = duration * float(i + 1) / 50 - float(Time.get_ticks_msec() - start) / 1000
		if wait > 0:
			await create_timer(wait).timeout
	var final: Dictionary = document.snapshot()
	for i: int in range(50):
		passed = session.request_undo(_prepare)["ok"] and passed
	passed = _same(initial, document.snapshot()) and passed
	for i: int in range(50):
		passed = session.request_redo(_prepare)["ok"] and passed
	passed = _same(final, document.snapshot()) and passed
	var path: String = args[1] if args.size() > 1 else "res://reports/week_09_soak.json"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(
		JSON.stringify(
			{
				"passed": passed,
				"elapsed_seconds": float(Time.get_ticks_msec() - start) / 1000,
				"commits": 50,
				"undos": 50,
				"redos": 50,
				"manual_props": 20,
				"trace": trace
			},
			"\t"
		)
	)
	session.dispose()
	quit(0 if passed else 1)
