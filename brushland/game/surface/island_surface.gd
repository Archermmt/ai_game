class_name IslandSurface
extends RefCounted
## Immutable derived surface. Source cells remain authoritative for gameplay.
var tiles:Dictionary
var foundations:Array=[]
func _init(world:Dictionary) -> void:
	tiles=world.tiles
	for o in world.objects:
		if o.kind in ["house","tea","greenhouse","lighthouse"]:
			foundations.append({"bounds":Rect2(Vector2(o.x-0.5,o.z-0.5),Vector2(2,2)),"height":height_at_cell(Vector2i(o.x,o.z))})
func cell(p:Vector2i) -> Dictionary:
	return tiles.get("%d,%d"%[p.x,p.y],{"h":0,"surface":"water"})
func height_at_cell(p:Vector2i) -> float:
	var h=int(cell(p).h)
	return h*0.5 if h>0 else -0.15
func height_at(v:Vector2) -> float:
	for f in foundations:
		if f.bounds.has_point(v):return f.height
	var p=Vector2i(floori(v.x),floori(v.y));var t=v-Vector2(p)
	var a=height_at_cell(p);var b=height_at_cell(p+Vector2i.RIGHT)
	var c=height_at_cell(p+Vector2i.DOWN);var d=height_at_cell(p+Vector2i.ONE)
	# Keep steep gameplay barriers visibly steep rather than invent walkable slopes.
	if maxf(maxf(a,b),maxf(c,d))-minf(minf(a,b),minf(c,d))>0.66:
		return height_at_cell(Vector2i(roundi(v.x),roundi(v.y)))
	return lerpf(lerpf(a,b,t.x),lerpf(c,d,t.x),t.y)
func sample_surface(v:Vector2) -> Dictionary:
	var e=0.12
	var normal=Vector3(height_at(v-Vector2(e,0))-height_at(v+Vector2(e,0)),2*e,height_at(v-Vector2(0,e))-height_at(v+Vector2(0,e))).normalized()
	return {"height":height_at(v),"normal":normal,"land":int(cell(Vector2i(roundi(v.x),roundi(v.y))).h)>0}
func build_chunk(chunk:Vector2i) -> Array:
	var vertices=PackedVector3Array();var normals=PackedVector3Array();var colors=PackedColorArray();var uvs=PackedVector2Array()
	for z in range(16):
		for x in range(16):
			var base=Vector2(chunk*8)+Vector2(x,z)*0.5
			var points=[base,base+Vector2(0,0.5),base+Vector2(0.5,0.5),base+Vector2(0.5,0)]
			var samples:Array=[]
			for v in points:samples.append(sample_surface(v))
			if samples.all(func(s):return s.height<-0.14):continue
			for i in [0,2,1,0,3,2]:
				var v:Vector2=points[i];var s=samples[i];var c=cell(Vector2i(roundi(v.x),roundi(v.y)))
				var color=Color("a4b98a") if c.surface=="grass" else Color("b7b6a3") if c.surface=="rock" else Color("d7c9a5")
				color=color.darkened((1.0-s.normal.y)*0.2+float(posmod(floori(v.x)*17+floori(v.y)*11,7))*0.004)
				vertices.append(Vector3(v.x,s.height,v.y));normals.append(s.normal);colors.append(color);uvs.append(v*0.5)
	var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_TEX_UV]=uvs
	return arrays
