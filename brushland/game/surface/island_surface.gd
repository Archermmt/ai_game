class_name IslandSurface
extends RefCounted
## Immutable derived surface. Source cells remain authoritative for gameplay.
var tiles:Dictionary
var foundations:Array=[]
var foundation_grid:Dictionary={}
var height_levels=PackedByteArray()
var objects:Array
var occupied:Dictionary={}
# Derived from the same neighborhood solution as the cottages. These swatches
# affect the drawn surface only; tile height, traversal and brushes use tiles.
var garden_ground: Dictionary
var relief := PackedFloat32Array()
const RELIEF_STRIDE := 129 # half-metre vertices from -0.5 to 63.5
const RELIEF_HEIGHT := {"meadow": 0.14, "courtyard": 0.045, "shore": -0.085}
const SWATCHES := {
	"grass": Color("#929552"), "rock": Color("#a89d8e"), "sand": Color("#d4bb90"),
	"water": Color("#8d7869"), "courtyard": Color("#c4aa84"),
	"meadow": Color("#a9ad68"), "shore": Color("#aeaa91")
}

func _init(world:Dictionary, garden: Dictionary = {}) -> void:
	garden_ground = garden
	bake_garden_relief()
	tiles=world.tiles;objects=world.objects;height_levels.resize(4096)
	for key in tiles:
		var xy=key.split(",");var x=int(xy[0]);var z=int(xy[1])
		if x>=0 and z>=0 and x<64 and z<64:height_levels[z*64+x]=int(tiles[key].h)
	for o in world.objects:
		for p in BuildingRules.footprint(o):occupied[p]=true
		if o.kind in ["house","tea","greenhouse","lighthouse"]:
			var foundation={"bounds":Rect2(Vector2(o.x-0.5,o.z-0.5),Vector2(2,2)),"height":height_at_cell(Vector2i(o.x,o.z))};foundations.append(foundation)
			for x in range(int(o.x)-1,int(o.x)+2):
				for z in range(int(o.z)-1,int(o.z)+2):
					var key=Vector2i(x,z)
					if not foundation_grid.has(key):foundation_grid[key]=[]
					foundation_grid[key].append(foundation)
# Shared edges and corners rise only if all incident cells have the same
# treatment. A road, doorway, cliff, or painted flower bed stays at source height.
func bake_garden_relief() -> void:
	if garden_ground.is_empty():
		return
	relief.resize(RELIEF_STRIDE * RELIEF_STRIDE)
	for cell_pos: Vector2i in garden_ground:
		var style: String = garden_ground[cell_pos]
		var lift: float = RELIEF_HEIGHT[style]
		var index := (cell_pos.y * 2 + 1) * RELIEF_STRIDE + cell_pos.x * 2 + 1
		relief[index] = lift
		var east: bool = garden_ground.get(cell_pos + Vector2i.RIGHT, "") == style
		var south: bool = garden_ground.get(cell_pos + Vector2i.DOWN, "") == style
		if east:
			relief[index + 1] = lift
		if south:
			relief[index + RELIEF_STRIDE] = lift
		if east and south and garden_ground.get(cell_pos + Vector2i.ONE, "") == style:
			relief[index + RELIEF_STRIDE + 1] = lift

func garden_lift(v: Vector2) -> float:
	if relief.is_empty():
		return 0.0
	var uv := v * 2.0 + Vector2.ONE
	var x := floori(uv.x)
	var z := floori(uv.y)
	if x < 0 or z < 0 or x >= RELIEF_STRIDE - 1 or z >= RELIEF_STRIDE - 1:
		return 0.0
	var i := z * RELIEF_STRIDE + x
	var top := lerpf(relief[i], relief[i + 1], uv.x - x)
	var bottom := lerpf(relief[i + RELIEF_STRIDE], relief[i + RELIEF_STRIDE + 1], uv.x - x)
	return lerpf(top, bottom, uv.y - z)

func cell(p:Vector2i) -> Dictionary:
	return tiles.get("%d,%d"%[p.x,p.y],{"h":0,"surface":"water"})
func height_at_cell(p:Vector2i) -> float:
	if p.x<0 or p.y<0 or p.x>=64 or p.y>=64:return -0.15
	var h=int(height_levels[p.y*64+p.x])
	return h*0.5 if h>0 else -0.15
func height_at(v:Vector2) -> float:
	for f in foundation_grid.get(Vector2i(floori(v.x),floori(v.y)),[]):
		if f.bounds.has_point(v):return f.height
	var p=Vector2i(floori(v.x),floori(v.y));var t=v-Vector2(p)
	t=Vector2(smoothstep(0.0,1.0,t.x),smoothstep(0.0,1.0,t.y))
	var a=height_at_cell(p);var b=height_at_cell(p+Vector2i.RIGHT)
	var c=height_at_cell(p+Vector2i.DOWN);var d=height_at_cell(p+Vector2i.ONE)
	# Keep steep gameplay barriers visibly steep rather than invent walkable slopes.
	if maxf(maxf(a,b),maxf(c,d))-minf(minf(a,b),minf(c,d))>0.66:
		return height_at_cell(Vector2i(roundi(v.x),roundi(v.y)))
	return lerpf(lerpf(a,b,t.x),lerpf(c,d,t.x),t.y) + garden_lift(v)
func sample_surface(v:Vector2) -> Dictionary:
	var e=0.12
	var normal=Vector3(height_at(v-Vector2(e,0))-height_at(v+Vector2(e,0)),2*e,height_at(v-Vector2(0,e))-height_at(v+Vector2(0,e))).normalized()
	return {"height":height_at(v),"normal":normal,"land":int(cell(Vector2i(roundi(v.x),roundi(v.y))).h)>0}
func ground_color(position: Vector2, sample: Dictionary) -> Color:
	var p := Vector2i(roundi(position.x), roundi(position.y))
	var tile := cell(p)
	var source := position - Vector2.ONE * 0.5
	var base := Vector2i(floori(source.x), floori(source.y))
	var blend := source - Vector2(base)
	blend = Vector2(smoothstep(0,1,blend.x),smoothstep(0,1,blend.y))
	var a: Color = SWATCHES.get(cell(base).surface, SWATCHES.water)
	var b: Color = SWATCHES.get(cell(base+Vector2i.RIGHT).surface, SWATCHES.water)
	var c: Color = SWATCHES.get(cell(base+Vector2i.DOWN).surface, SWATCHES.water)
	var d: Color = SWATCHES.get(cell(base+Vector2i.ONE).surface, SWATCHES.water)
	var color: Color = a.lerp(b,blend.x).lerp(c.lerp(d,blend.x),blend.y)
	var influence: String = garden_ground.get(p, "")
	if SWATCHES.has(influence):
		color = color.lerp(SWATCHES[influence], 0.72)
	# Warm loam shows through the turf on the bank and at the waterline.
	var bank := (1.0 - smoothstep(0.02, 0.38, sample.height)) * 0.66
	if tile.surface == "grass":
		bank = maxf(bank, (1.0 - smoothstep(0.45, 0.9, sample.normal.y)) * 0.78)
	color = color.lerp(Color("#92785e"), bank)
	var patch := sin(position.x * 1.17 + position.y * 0.44) * sin(position.y * 0.94 - 0.4 * position.x)
	return color.darkened((1.0 - sample.normal.y) * 0.13 + 0.043 * (1.0 + patch))

# Keep the paving and gravel in the terrain mesh so they share its dirty area,
# lighting, batching and undo behavior. World-space seeds agree across chunks.
func add_stones(chunk: Vector2i, vertices: PackedVector3Array, normals: PackedVector3Array,
		colors: PackedColorArray, uvs: PackedVector2Array) -> void:
	var origin := chunk * 8
	for z in range(origin.y, origin.y + 8):
		for x in range(origin.x, origin.x + 8):
			var cell_position := Vector2i(x, z)
			var style: String = garden_ground.get(cell_position, "")
			if style != "courtyard" and style != "shore":
				continue
			for chip in range(2):
				var seed_value := posmod((x * 73 + z * 131 + chip * 277) * 109, 997)
				var center := Vector2(cell_position) + Vector2(
						-0.20 + 0.40 * chip, float(seed_value % 23) / 38.0 - 0.29)
				var radius := Vector2(0.14, 0.085) if style == "courtyard" else Vector2(0.072, 0.056)
				var tint := Color("#bda789") if style == "courtyard" else Color("#a49e8d")
				tint = tint.lightened(float(seed_value % 7) * 0.018)
				var top := Vector3(center.x, height_at(center) + 0.028, center.y)
				var angle := float(seed_value % 61) / 61.0 * TAU
				for side in range(5):
					var a := center + Vector2.from_angle(angle + side * TAU / 5.0) * radius
					var b := center + Vector2.from_angle(angle + (side + 1) * TAU / 5.0) * radius
					for v in [top, Vector3(a.x, height_at(a) + 0.010, a.y), Vector3(b.x, height_at(b) + 0.010, b.y)]:
						vertices.append(v)
						normals.append(Vector3.UP)
						colors.append(tint)
						uvs.append(Vector2(v.x, v.z) * 0.5)

func build_chunk(chunk:Vector2i) -> Array:
	var vertices:=PackedVector3Array();var normals:=PackedVector3Array();var colors:=PackedColorArray();var uvs:=PackedVector2Array()
	# Each 0.5 m sample belongs to up to four quads. Evaluate it once, including
	# the outside row so adjacent chunks evaluate exactly the same border.
	var positions := PackedVector3Array()
	var surface_normals := PackedVector3Array()
	var swatches := PackedColorArray()
	for z in range(33):
		for x in range(33):
			var point := Vector2(chunk * 8) + Vector2(x, z) * 0.25
			var sample := sample_surface(point)
			positions.append(Vector3(point.x, sample.height, point.y))
			surface_normals.append(sample.normal)
			swatches.append(ground_color(point, sample))
	for z in range(32):
		for x in range(32):
			var base := z * 33 + x
			if maxf(maxf(positions[base].y, positions[base+1].y), maxf(positions[base+33].y, positions[base+34].y)) < -0.14:
				continue
			for offset in [0, 34, 33, 0, 1, 34]:
				var index: int = base + offset
				var v := positions[index]
				vertices.append(v)
				normals.append(surface_normals[index])
				colors.append(swatches[index])
				uvs.append(Vector2(v.x, v.z) * 0.5)
	add_stones(chunk, vertices, normals, colors, uvs)
	var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_TEX_UV]=uvs
	return arrays
