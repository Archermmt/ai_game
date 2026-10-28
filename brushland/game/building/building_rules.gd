class_name BuildingRules
extends RefCounted
const DIRS=[Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]
static func footprint(o:Dictionary) -> Array:
	var out:Array=[]
	var p=Vector2i(int(o.x),int(o.z))
	if o.kind in ["bridge","dock"]:
		var dir=DIRS[int(o.get("rotation",0))%4]
		for i in range(int(o.get("length",3))+1):out.append(p+dir*i)
	else:
		for x in range(2):
			for z in range(2):out.append(p+Vector2i(x,z))
	return out
static func occupied(d:IslandData,p:Vector2i) -> bool:
	for o in d.objects:
		if p in footprint(o):return true
	return false
static func variant(d:IslandData,o:Dictionary) -> String:
	if o.get("locked",false):return o.get("variant","basic")
	var flowers=0;var coast=false
	for x in range(-2,4):
		for z in range(-2,4):
			var p=Vector2i(int(o.x)+x,int(o.z)+z)
			if x>=-1 and x<=2 and z>=-1 and z<=2 and not (x>=0 and x<2 and z>=0 and z<2):
				if d.cell(p).flower:flowers+=1
			var dist=maxi(0,maxi(-x,x-1))+maxi(0,maxi(-z,z-1))
			if dist<=2 and d.cell(p).h==0:coast=true
	return "garden" if flowers>=3 else "coast" if coast else "basic"
static func place(d:IslandData,p:Vector2i,kind:String,rotation:int=0,length:int=3) -> String:
	var o={"id":d.next_id,"x":p.x,"z":p.y,"kind":kind,"rotation":rotation,"length":length,"locked":false}
	var h=int(d.cell(p).h)
	for q in footprint(o):
		if q.x<0 or q.y<0 or q.x>=64 or q.y>=64 or occupied(d,q):return "Occupied or outside map"
	if kind in ["bridge","dock"]:
		if h<1 or h>2:return "Anchor needs height 1–2"
		if kind=="bridge" and (length<2 or length>6):return "Bridge span must be 2–6"
		if kind=="dock" and (length<2 or length>4):return "Dock length must be 2–4"
		var dir=DIRS[rotation%4]
		for i in range(1,length+1):
			if d.cell(p+dir*i).h!=0:return "Span needs clear water"
		if kind=="bridge" and d.cell(p+dir*(length+1)).h!=h:return "Bridge ends must have equal height"
	else:
		if h==0:return "Needs dry land"
		for q in footprint(o):
			if d.cell(q).h!=h:return "Needs a flat 2 × 2 foundation"
	d.begin();d.objects.append(o);d.next_id+=1
	return "Placed " + kind
