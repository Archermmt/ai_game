extends RefCounted
const IDEAS := [
	["joined","屋檐连起来","沿一间小屋的侧墙再添一间，看看共同屋脊。","house"],
	["shaped","自己的屋顶","保持同类建造笔，点一次屋顶，给这一户换个轮廓。","house"],
	["corner","街道拐弯了","在长屋的一端向侧面加建；门口朝向外面的空地。","house"],
	["court","屋里围着花园","沿空地四周合建，留一块中庭；内侧会长出檐廊。","house"],
	["arrival","有人走进新家","从新屋门口接路，连到通海码头，等一位新邻居。","road"]
]

static func describe(data: IslandData, sim: ResidentSim, state: Dictionary) -> Dictionary:
	var done := {"joined":false,"shaped":false,"corner":false,"court":not state.get("courts",[]).is_empty(),"arrival":false}
	for person in sim.people:
		var home := sim.object_by_id(data,int(person.home))
		if not home.is_empty() and not sim.arrival_info(data,home).route.is_empty():
			done.arrival = true
	for object in data.objects:
		done.shaped = done.shaped or int(object.get("form",0)) > 0
	for seams: Array in state.seams.values():
		done.joined = done.joined or not seams.is_empty()
	for layout: Dictionary in state.get("layouts",{}).values():
		done.corner = done.corner or layout.role in ["corner","junction"]
	var next: Array = []
	for idea in IDEAS:
		if not done[idea[0]]:
			next = idea.duplicate()
			break
	if not next.is_empty() and next[0] == "arrival":
		for object in data.objects:
			if object.kind != "house":continue
			var info := sim.arrival_info(data,object)
			match String(info.reason):
				"需要一座通海码头":
					next[2] = "从一至二级海岸添一座通海码头，再接上门前的小路。"
					next[3] = "dock"
				"码头入口还没接路":next[2] = "码头已经有了，给它的岸边入口接一格小路。"
				"码头与小屋尚未连通":next[2] = "把码头入口的小路一直接到新屋门前。"
				"泊位通道未通向外海":
					next[2] = "泊位外面还被陆地挡着，用海水笔打开通向外海的航道。"
					next[3] = "water"
				"已连通外海，等待来客":next[2] = "小路已经通了。保持时间流动，稍等一位乘船来的邻居。"
			break
	return {"done":done,"next":next}
