extends SceneTree
const State=preload("res://features/battle/rules/battle_state.gd")
var failures: int=0
var checks: int=0
func check(ok: bool, description: String) -> void:
	checks+=1
	if not ok: failures+=1; printerr("FAIL: ",description)
func _initialize() -> void:
	var s=State.new()
	check(s.active==2 and s.tick==9 and s.units[2].ct==108,"CT first activation")
	s.commit(s.preview("end",Vector2i.ZERO))
	check(s.active==3 and s.units[2].ct==8 and s.tick==9,"CT overflow and tie order")
	s.commit(s.preview("end",Vector2i.ZERO))
	check(s.active==0 and s.tick==10,"CT knights after archers")
	check(s.paths(0).size()>1,"initial unit not trapped")
	var before=s.units.duplicate(true)
	var move=s.preview("move",Vector2i(3,6))
	check(move.ok and s.units==before,"preview does not mutate state")
	check(not s.preview("move",s.units[4].p).ok,"occupied destination rejected")
	s.commit(move)
	check(s.units[0].p==Vector2i(3,6) and s.units[0].moved,"move commits once")
	check(not s.commit(move).ok,"stale command rejected")
	check(not s.preview("move",Vector2i(3,7)).ok,"cannot split move")
	s=State.new(); s.active=0
	s.units[0].p=Vector2i(3,7); s.units[3].p=Vector2i(3,6)
	var attack=s.preview("attack",s.units[3].p)
	check(attack.ok and attack.amount==26,"guard attacks archer for 26")
	s.units[3].hp=10
	attack=s.preview("attack",s.units[3].p); s.commit(attack)
	check(s.units[3].hp==0 and s.occupant(Vector2i(3,6))==-1,"lethal damage clamps and releases tile")
	s=State.new(); s.active=4
	check(not s.preview("heal",s.units[4].p).ok,"full health heal rejected")
	s.units[4].hp=70
	var heal=s.preview("heal",s.units[4].p)
	check(heal.ok and heal.amount==10,"self heal caps at max HP")
	s.commit(heal)
	check(s.units[4].mp==18 and s.units[4].hp==80,"heal spends exactly six MP")
	s.units[4].acted=false; s.units[4].hp=50; s.units[4].mp=5
	check(not s.preview("heal",s.units[4].p).ok,"insufficient MP rejected")
	check(not s.line_clear(Vector2i(4,7),Vector2i(6,7)),"wall blocks same-level ray")
	check(s.line_clear(Vector2i(0,8),Vector2i(3,8)),"units do not block ray")
	var timeline: String=s.timeline()
	check(timeline.split(" → ").size()==8,"eight predicted activations")

	# Cross-battle identity prevents old previews from succeeding at revision zero.
	var old=State.new()
	var old_move: Dictionary=old.preview("move",Vector2i(3,8))
	var fresh=State.new()
	check(not fresh.commit(old_move).ok,"old battle request rejected despite same revision")
	check(not fresh.commit({"kind":"end"}).ok,"missing metadata rejected")
	var snap=old.snapshot()
	snap.units[0].hp=1; snap.tiles[Vector2i(3,7)].h=3
	check(old.units[0].hp==120 and old.height(Vector2i(3,7))==0,"snapshot owns units and tiles")
	# Closed-corner LOS fixture.
	s=State.new(); s.tiles.clear()
	for z in range(3):
		for x in range(3): s.tiles[Vector2i(x,z)]={"h":0,"blocked":false}
	s.tiles[Vector2i(1,0)].blocked=true
	check(not s.line_clear(Vector2i(0,0),Vector2i(2,2)),"corner touching solid blocks")
	s.tiles[Vector2i(1,0)].blocked=false
	check(s.line_clear(Vector2i(0,0),Vector2i(2,2)),"clear diagonal passes")
	# Height modifies both bow reach and damage, using the same preview.
	s=State.new(); s.active=2
	s.units[2].p=Vector2i(0,0); s.units[1].p=Vector2i(5,0)
	s.tiles[Vector2i(0,0)]={"h":3,"blocked":false}; s.tiles[Vector2i(5,0)]={"h":0,"blocked":false}
	check(s.preview("attack",Vector2i(5,0)).get("amount",0)==22,"high bow reaches five and adds four damage")
	s.tiles[Vector2i(0,0)].h=0
	check(not s.preview("attack",Vector2i(5,0)).ok,"level bow cannot reach five")
	# Victory is atomic and terminal; result timeline must not loop.
	s=State.new(); s.active=0
	for unit in s.units: unit.hp=0
	s.units[0].hp=120; s.units[0].p=Vector2i(3,7)
	s.units[3].hp=1; s.units[3].p=Vector2i(3,6)
	s.commit(s.preview("attack",Vector2i(3,6)))
	check(not s.result.is_empty() and s.timeline()==s.result,"victory terminal timeline")
	check(not s.preview("end",Vector2i.ZERO).ok,"terminal battle rejects commands")
	print("Rules: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
