extends SceneTree
const State=preload("res://features/battle/rules/battle_state.gd")
const Planner=preload("res://features/battle/ai/turn_planner.gd")
var failures: int=0
var checks: int=0
func check(ok: bool,description: String) -> void:
	checks+=1
	if not ok: failures+=1; printerr("FAIL: ",description)
func _initialize() -> void:
	var s=State.new()
	var before: Array=s.units.duplicate(true)
	var start: int=Time.get_ticks_usec()
	var planner=Planner.new()
	var plan: Array=planner.plan(s)
	print("Initial AI plan: ",Time.get_ticks_usec()-start," us; ",planner.candidates," candidates")
	check(s.units==before and s.revision==0,"planner does not mutate authority")
	check(plan==Planner.new().plan(s),"planner deterministic")
	check(plan.size()<=3 and plan.back().kind=="end","bounded plan ends activation")
	for command in plan:
		check(s.commit(s.preview(command.kind,command.p)).ok,"plan command remains legal")
	# Archer backs away from an adjacent foe to establish its minimum range.
	s=State.new(); s.active=3
	for unit in s.units: unit.hp=0
	s.units[3].hp=85; s.units[3].p=Vector2i(4,7)
	s.units[0].hp=120; s.units[0].p=Vector2i(4,8)
	plan=Planner.new().plan(s)
	check(plan[0].kind=="move","adjacent archer retreats before attacking")
	check(plan.any(func(c): return c.kind=="attack"),"retreat establishes legal shot")
	for command in plan: check(s.commit(s.preview(command.kind,command.p)).ok,"retreat sequence legal")
	# Critical healing outranks a nonlethal attack.
	s=State.new(); s.active=4
	s.units[4].p=Vector2i(3,7); s.units[0].p=Vector2i(2,7); s.units[0].hp=30
	s.units[1].p=Vector2i(3,6)
	plan=Planner.new().plan(s)
	check(plan.any(func(c): return c.kind=="heal" and c.p==Vector2i(2,7)),"medic prioritizes critical ally")
	print("Planner: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
