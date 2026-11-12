extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	Engine.time_scale=100
	var battle=load("res://features/battle/presentation/battle.tscn").instantiate()
	root.add_child(battle)
	battle.set_process(false)
	var actions: int=0
	while battle.state.result.is_empty() and actions<500:
		battle.ai_step()
		actions+=1
		while battle.busy: await process_frame
	print("Integration: ",battle.state.result,"; commands=",actions)
	var success: bool=not battle.state.result.is_empty()
	battle.restart()
	success=success and battle.state.active==2 and battle.state.units[0].hp==120 and not battle.busy
	print("Restart: ",success)
	battle.queue_free()
	quit(0 if success else 1)
