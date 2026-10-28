class_name IslandData
extends RefCounted
const SIZE = 64
var tiles: Dictionary = {}
var objects: Array = []
var history: Array = []
var future: Array = []
var next_id: int = 1
var revision:int=0
func key(p: Vector2i) -> String:
	return "%d,%d" % [p.x,p.y]
func cell(p: Vector2i) -> Dictionary:
	return tiles.get(key(p), {"h":0,"surface":"water","road":false,"flower":false})
func snapshot() -> Dictionary:
	return {"tiles":tiles.duplicate(true),"objects":objects.duplicate(true),"next_id":next_id}
func restore(s: Dictionary) -> void:
	revision+=1
	tiles=s.tiles.duplicate(true); objects=s.objects.duplicate(true); next_id=int(s.next_id)
func begin() -> void:
	revision+=1
	history.append(snapshot())
	if history.size()>50: history.pop_front()
	future.clear()
func undo() -> void:
	if history.is_empty(): return
	future.append(snapshot()); restore(history.pop_back())
func redo() -> void:
	if future.is_empty(): return
	history.append(snapshot()); restore(future.pop_back())
func paint(points: Array, tool: String) -> void:
	begin()
	var visited:Dictionary={}
	for p in points:
		if visited.has(p):continue
		visited[p]=true
		if p.x<0 or p.y<0 or p.x>=SIZE or p.y>=SIZE: continue
		if BuildingRules.occupied(self,p,tool!="road"): continue
		var c: Dictionary=cell(p).duplicate()
		match tool:
			"grass","sand","rock": c.h=maxi(1,int(c.h)); c.surface=tool; c.flower=false
			"water": c={"h":0,"surface":"water","road":false,"flower":false}
			"raise": c.h=mini(4,int(c.h)+1); c.surface="grass" if c.surface=="water" else c.surface
			"lower": c.h=maxi(0,int(c.h)-1); c.surface="water" if c.h==0 else c.surface
			"road":
				if c.h>0: c.road=true
			"flower":
				if c.surface=="grass": c.flower=true
		if c.surface!="grass":c.flower=false
		tiles[key(p)]=c
func seed_island() -> void:
	for x in range(20,45):
		for z in range(22,43):
			var d=Vector2((x-32)/12.0,(z-32)/10.0).length()
			if d<1.0:
				tiles[key(Vector2i(x,z))]={"h":1 if d>0.80 else 2,"surface":"sand" if d>0.80 else "grass","road":false,"flower":false}
	history.clear()

func clear_world() -> void:
	tiles.clear();objects.clear();history.clear();future.clear();next_id=1;revision+=1
