extends SceneTree
var failures: int=0
var checks: int=0
func check(ok: bool, text: String) -> void:
	checks+=1
	if not ok: failures+=1; printerr("FAIL: ",text)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var battle=load("res://features/battle/presentation/battle.tscn").instantiate()
	root.add_child(battle); battle.set_process(false)
	check(battle.phase=="title" and battle.paused,"starts at title")
	battle.continue_flow()
	check(battle.phase=="briefing","title opens briefing")
	battle.continue_flow()
	check(battle.phase=="battle" and not battle.paused,"briefing starts fresh battle")
	var old_request: Dictionary=battle.state.request("move",Vector2i(3,8))
	battle.candidate=old_request
	battle.confirm_candidate(); battle.confirm_candidate()
	check(battle.state.revision==1 and battle.busy,"double confirmation commits once")
	battle.toggle_pause()
	var position: Vector3=battle.actors[2].position
	await create_timer(0.25).timeout
	check(battle.actors[2].position==position and battle.busy,"pause freezes playback")
	battle.restart()
	await process_frame
	check(not battle.busy and battle.state.revision==0 and not battle.paused,"restart from paused playback clears locks")
	check(not battle.state.commit(old_request).ok,"old same-revision request rejected after restart")
	battle.state.active=0
	for u in battle.state.units: u.hp=0
	battle.state.units[0].hp=120; battle.state.units[0].p=Vector2i(3,7)
	battle.state.units[3].hp=1; battle.state.units[3].p=Vector2i(3,6)
	battle.execute(battle.state.request("attack",Vector2i(3,6)))
	while battle.busy: await process_frame
	check(battle.phase=="result" and battle.state.result.begins_with("胜利"),"victory reaches result overlay")
	battle.show_flow("title")
	check(battle.phase=="title" and battle.overlay.visible,"result returns to title")
	battle.continue_flow(); battle.continue_flow()
	check(battle.state.active==2 and battle.state.units[0].hp==120,"reentry restores full initial state")
	print("Lifecycle: %d checks, %d failures"%[checks,failures])
	battle.queue_free(); quit(1 if failures else 0)
