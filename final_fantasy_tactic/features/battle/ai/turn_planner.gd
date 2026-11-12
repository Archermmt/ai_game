extends RefCounted

# All speculative writes belong to independent snapshots. Plans store intent only;
# the caller binds fresh battle/revision metadata before each real commit.
var fields: Dictionary={}
var root_state
var candidates: int=0

func plan(source) -> Array:
	root_state=source.snapshot()
	fields.clear(); candidates=0
	var options: Array=[[]]
	var actor: int=source.active
	var u: Dictionary=source.units[actor]
	var first_actions: Array=actions(root_state)
	for action in first_actions:
		options.append([action])
		if not u.moved:
			var after=root_state.snapshot()
			after.commit(after.preview(action.kind,action.p))
			if not after.result.is_empty(): continue
			for p in after.paths(actor,after.STATS[u.job][5]):
				if p!=u.p: options.append([action,{"kind":"move","p":p}])
	if not u.moved:
		for p in root_state.paths(actor,root_state.STATS[u.job][5]):
			if p==u.p: continue
			var move: Dictionary={"kind":"move","p":p}
			options.append([move])
			var after=root_state.snapshot()
			after.commit(after.preview("move",p))
			for action in actions(after): options.append([move,action])
	var best: Array=[]
	var best_score: Array=[]
	for option in options:
		var evaluation: Array=score(option)
		candidates+=1
		if best_score.is_empty() or better(evaluation,best_score):
			best=option; best_score=evaluation
	return best+[{"kind":"end","p":Vector2i.ZERO}]

func actions(s) -> Array:
	var found: Array=[]
	for target in s.units:
		for kind in ["attack","heal"]:
			var action: Dictionary=s.preview(kind,target.p)
			if action.ok: found.append({"kind":kind,"p":target.p})
	return found

func score(commands: Array) -> Array:
	var s=root_state.snapshot()
	var rank: int=0
	var amount: int=0
	var steps: int=0
	var target_order: int=99
	for command in commands:
		var action: Dictionary=s.preview(command.kind,command.p)
		if not action.ok: return [-1]
		if command.kind=="move": steps=action.path.size()
		else:
			target_order=action.target
			var target: Dictionary=s.units[action.target]
			amount=action.amount
			if command.kind=="attack": rank=5 if amount>=target.hp else 3
			else: rank=4 if target.hp*2<=s.STATS[target.job][0] and s.STATS[target.job][0]-target.hp>=18 else 2
		s.commit(action)
	var u: Dictionary=s.units[s.active] if s.result.is_empty() else s.units[root_state.active]
	var distance: int=approach_distance(s,u.p)
	# Do not shuffle without progress when no effective action is possible.
	if rank==0 and not commands.is_empty() and distance>=approach_distance(root_state,root_state.units[root_state.active].p): return [-1]
	return [rank,amount,-distance,-steps,-target_order,-u.p.y,-u.p.x]

func approach_distance(s, position: Vector2i) -> int:
	var key: String=""
	for unit in s.units:
		if unit.hp>0: key+=str(unit.id)
	if not fields.has(key):
		var scratch=s.snapshot()
		var actor: int=root_state.active
		scratch.active=actor; scratch.result=""; scratch.units[actor].acted=false
		var distance: Dictionary={}
		var queue: Array=[]
		for p in scratch.tiles:
			if not scratch.walkable(p) or (scratch.occupant(p)>=0 and scratch.occupant(p)!=actor): continue
			scratch.units[actor].p=p
			for target in scratch.units:
				if target.hp>0 and target.team!=scratch.units[actor].team and scratch.preview("attack",target.p).ok:
					distance[p]=0; queue.append(p); break
		while not queue.is_empty():
			var p: Vector2i=queue.pop_front()
			for direction in scratch.DIRS:
				var q: Vector2i=p+direction
				if distance.has(q) or not scratch.walkable(q) or absi(scratch.height(q)-scratch.height(p))>1: continue
				var occupied: int=scratch.occupant(q)
				if occupied>=0 and occupied!=actor: continue
				distance[q]=distance[p]+1; queue.append(q)
		fields[key]=distance
	return fields[key].get(position,9999)

func better(a: Array,b: Array) -> bool:
	for i in range(mini(a.size(),b.size())):
		if a[i]!=b[i]: return a[i]>b[i]
	return false
