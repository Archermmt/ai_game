extends Node3D
## Modelled at the reference camera's scale, with X along the rails and +Z toward the street.

const TRACK_Z := -1.03
const TRACK_WEST := -8.65
const TRACK_EAST := 9.62
const CROSS_X := 6.25

const TIMBER := "826653"
const WOOD_DARK := "5c4f4d"
const CREAM := "fff7e5"
const SLATE := "555f65"
const STEEL := "797e85"
const INK := "404150"

var _batches: Dictionary = {}
var _emit_colors := {
	"ff552c": 0.4, "ffdc50": 0.3, "fff8ed": 0.52, "c9c5bd": 0.18, "fff3e1": 0.25,
	"e8eae8": 0.24, "d9dbdc": 0.29, "d94e76": 0.24, "59b9a5": 0.24,
	"c2d1db": 0.18, "b8b5aa": 0.23, "e9ebe5": 0.17, "a9b4ba": 0.16
}
var _part_frame := Transform3D.IDENTITY


func _ready() -> void:
	_track_and_crossing()
	_platform()
	_station_house()
	_platform_shelter()
	_platform_furniture()
	_commuter_car()
	_crossing_signals()
	_wire_network()
	_commit_meshes()


func _track_and_crossing() -> void:
	var mid_x := (TRACK_WEST + TRACK_EAST) * 0.5
	var length := TRACK_EAST - TRACK_WEST
	_box(Vector3(mid_x, 0.042, TRACK_Z), Vector3(length, 0.09, 2.62), "918b87")
	_box(Vector3(mid_x, 0.102, TRACK_Z), Vector3(length, 0.05, 2.36), "a8a19a")
	var rng := RandomNumberGenerator.new()
	rng.seed = 19493
	# The exposed ballast reads as fine broken specks between the larger, even sleepers.
	for index in 235:
		var x := rng.randf_range(TRACK_WEST + 0.1, TRACK_EAST - 0.1)
		var z := TRACK_Z + rng.randf_range(-1.13, 1.13)
		var size := rng.randf_range(0.025, 0.090)
		_box(Vector3(x, 0.138, z), Vector3(size, 0.018, size * 0.65),
			["96918b", "bdb7ac", "868585"][index % 3], Basis(Vector3.UP, rng.randf_range(-1.3, 1.3)))
	for index in range(33):
		var x := TRACK_WEST + 0.20 + index * 0.548
		_box(Vector3(x, 0.155, TRACK_Z), Vector3(0.215, 0.095, 2.09),
			[WOOD_DARK, "675852", "736058"][index % 3], Basis(Vector3.UP, rng.randf_range(-0.016, 0.016)))
	for z_offset: float in [-0.716, 0.716]:
		_box(Vector3(mid_x, 0.21, TRACK_Z + z_offset), Vector3(length, 0.095, 0.105), "59585b")
		_box(Vector3(mid_x, 0.271, TRACK_Z + z_offset), Vector3(length, 0.035, 0.105), "b4b4b3")
	# Separate planks at the crossing leave the two bright rail heads visible.
	for index in 10:
		var x := CROSS_X - 1.92 + index * 0.425
		for lane: Vector3 in [Vector3(-1.06, 0, 0.55), Vector3(0, 0, 1.22), Vector3(1.06, 0, 0.55)]:
			_box(Vector3(x, 0.189, TRACK_Z + lane.x), Vector3(0.415, 0.145, lane.z), "737377")
	# West cutting and its shaded entrance, tucked into the flank of the turf.
	var portal_base := Vector3(-8.63, 0, TRACK_Z)
	_collect("portal", portal_base, Vector3(0.48, 3.65, 2.86), "c4c4b6", Basis.IDENTITY)
	_collect("portal", portal_base + Vector3(0.259,0,0), Vector3(0.05, 3.51, 2.48), "302f3d", Basis.IDENTITY)
	for side: float in [-1.0, 1.0]:
		_box(portal_base + Vector3(0.48, 0.65, side*1.34), Vector3(1.00, 1.30, 0.17), "b9b9ac")
	_box(Vector3(9.53, 0.53, TRACK_Z - 1.34), Vector3(0.60, 1.06, 0.22), "b2b1a6")
	_box(Vector3(9.53, 0.53, TRACK_Z + 1.35), Vector3(0.60, 1.06, 0.22), "b2b1a6")
	# Low safety railing glimpsed between the front garden trees and the line.
	for index in 13:
		var x := -8.0 + index * 0.88
		_cylinder(Vector3(x, 0.53, 0.60), Vector3(0.055, 1.06, 0.055), "979a89")
	for y: float in [0.53, 0.93]:
		_tube(Vector3(-8.0, y, 0.60), Vector3(2.56, y, 0.60), 0.045, "a4a69a")


func _platform() -> void:
	const LEFT := -6.91
	const RIGHT := 3.37
	const FRONT := -2.32
	const BACK := -6.88
	var mid := Vector3((LEFT + RIGHT) * 0.5, 0, (FRONT + BACK) * 0.5)
	_box(mid + Vector3.UP * 0.47, Vector3(RIGHT - LEFT, 0.94, FRONT - BACK), "c9c5bd")
	_box(mid + Vector3.UP * 0.956, Vector3(RIGHT - LEFT + 0.12, 0.11, FRONT - BACK + 0.12), "fff8ed")
	_box(mid + Vector3(0, 0.78, (FRONT - BACK) * 0.5), Vector3(RIGHT - LEFT, 0.055, 0.055), "9d9993")
	for column in 8:
		var x := LEFT + 0.5 + 1.31 * column
		_box(Vector3(x, 0.46, FRONT + 0.015), Vector3(0.025, 0.73, 0.024), "a9a69f")
		_box(Vector3(x + 0.58, 0.17, FRONT + 0.025), Vector3(0.14, 0.095, 0.033), "777779")
	var edge_z := FRONT - 0.11
	_box(Vector3(mid.x, 1.019, edge_z), Vector3(RIGHT - LEFT, 0.021, 0.19), "f9d34c")
	_box(Vector3(mid.x, 1.02, edge_z - 0.13), Vector3(RIGHT - LEFT, 0.023, 0.034), "fff4bc")
	# Isolated back fence leaves most of the platform open under the canopy.
	for x: float in [-7.00, -5.55, -4.10, -2.65, -1.20, 0.25, 1.70, 3.15]:
		_box(Vector3(x, 1.36, BACK + 0.12), Vector3(0.058, 0.75, 0.063), "8c8e88")
	_box(Vector3(-1.92, 1.69, BACK + 0.12), Vector3(10.14, 0.055, 0.063), "aaa99d")


func _station_house() -> void:
	# Small street-facing timber waiting room behind the west half of the platform.
	const X := -5.68
	const Z := -4.77
	_box(Vector3(X, 1.86, Z), Vector3(2.39, 1.70, 2.26), "fff3e1")
	var facade := Z + 1.145
	_box(Vector3(X, 1.29, facade), Vector3(2.40, 0.53, 0.07), "96785c")
	_box(Vector3(X, 2.16, facade + 0.037), Vector3(1.96, 0.63, 0.033), "b0c1c2")
	for dx: float in [-1.13, -0.31, 0.54, 1.13]:
		_box(Vector3(X + dx, 1.87, facade + 0.086), Vector3(0.073, 1.70, 0.10), TIMBER)
	for y: float in [1.77, 2.47, 2.70]:
		_box(Vector3(X, y, facade + 0.080), Vector3(2.36, 0.060, 0.082), TIMBER)
	_box(Vector3(X+1.197, 2.05, Z), Vector3(0.045, 0.84, 1.22), "91a7a8")
	# The dark triangular gable faces the tracks. The ridge points back into the station.
	_part_frame = Transform3D(Basis(Vector3.UP, PI/2.0), Vector3(X, 2.72, Z))
	_collect("gable", Vector3(0, 0.45, 0), Vector3(2.30, 0.90, 2.55), "3c555a", Basis.IDENTITY)
	_pitched_roof(Vector3.ZERO, 2.40, 2.91, 0.92, "638083", "3a545a", 0.37, "526f70")
	_part_frame = Transform3D.IDENTITY
	_bench(Vector3(X, 1.02, facade + 0.39), 1.84)


func _platform_shelter() -> void:
	const X := -1.98
	const Z := -4.99
	# One broad folded-metal slope; the back edge sits slightly above the front eave.
	const DEPTH := 2.35
	const WIDTH := 4.42
	const RISE := 0.34
	_part_frame = Transform3D(Basis(Vector3.RIGHT, Vector3.UP, Vector3(-0.12,0,1)), Vector3(X,0,Z))
	for x: float in [-2.00, 0, 2.00]:
		for z: float in [-0.99, 0.99]:
			var height := 3.32 - z * RISE/DEPTH - 1.0
			_box(Vector3(x, 1.0 + height * 0.5, z), Vector3(0.093, height, 0.10), "918f85")
	var slope := Basis(Vector3.RIGHT, atan2(RISE, DEPTH))
	var length := Vector2(DEPTH,RISE).length()
	_box(Vector3(0,3.41,0), Vector3(WIDTH,0.095,length), "e9ebe5", slope)
	for rib in 18:
		var x := (rib + 0.52) * WIDTH/18.0 - WIDTH * 0.5
		_box(Vector3(x,3.47,0), Vector3(0.032,0.043,length), "acb3ad", slope)
	for x: float in [-WIDTH * 0.5, WIDTH * 0.5]:
		_box(Vector3(x,3.39,0), Vector3(0.065,0.125,length), "a2afa8", slope)
	for side: float in [-1.0, 1.0]:
		_box(Vector3(0,3.40-side*RISE*0.5, side*DEPTH*0.5), Vector3(WIDTH+.06,.12,.07), "959e99")
	_part_frame = Transform3D.IDENTITY
	# Low roof extension reads as a second thin eave beside the main roof.
	_box(Vector3(0.99, 2.83, Z), Vector3(1.61, 0.13, 1.82), "bdc7c1")
	for z: float in [Z - 0.69, Z + 0.69]:
		_box(Vector3(1.69, 1.94, z), Vector3(0.088, 1.83, 0.093), "8e958d")


func _pitched_roof(base: Vector3, width: float, depth: float, rise: float,
		color: String, trim: String, seam_pitch: float, seam_color: String) -> void:
	var half_depth := depth * 0.5
	var slope_length := Vector2(half_depth, rise).length()
	for direction: float in [-1.0, 1.0]:
		var rot := Basis(Vector3.RIGHT, direction * atan2(rise, half_depth))
		var center := base + Vector3(0, rise * 0.5, direction * half_depth * 0.5)
		_box(center, Vector3(width, 0.10, slope_length), color, rot)
		var count := floori(width / seam_pitch)
		for i in count:
			var x := -width * 0.5 + (i + 0.5) * width / count
			_box(center + Vector3(x, 0.060, 0), Vector3(0.023, 0.026, slope_length),
				seam_color, rot)
		_box(base + Vector3(0, -0.009, direction * half_depth), Vector3(width, 0.112, 0.070), trim)
		for dx: float in [-0.5, 0.5]:
			_box(center + Vector3(dx * width, 0, 0), Vector3(0.047, 0.13, slope_length), trim, rot)
	_box(base + Vector3.UP * (rise + 0.055), Vector3(width + 0.05, 0.088, 0.142), trim)


func _platform_furniture() -> void:
	_bench(Vector3(0.32, 1.03, -5.34), 1.98)
	# Station board: white panel with green route band and small dark station marks.
	for x: float in [0.02, 1.64]:
		_box(Vector3(x, 1.67, -3.29), Vector3(0.07, 1.33, 0.08), "8b9391")
	_box(Vector3(0.83, 2.04, -3.29), Vector3(2.00, 0.72, 0.095), "8c9694")
	_box(Vector3(0.83, 2.04, -3.228), Vector3(1.92, 0.63, 0.022), "f8f4e7")
	_box(Vector3(0.83, 1.95, -3.210), Vector3(1.92, 0.074, 0.02), "719d90")
	for dx: float in [-0.14, 0.05, 0.22]:
		_box(Vector3(0.83 + dx, 2.15, -3.207), Vector3(0.083, 0.069, 0.01), "646d70")
	# Compact drinks kiosk in the shade of the canopy.
	var machine := Vector3(-3.26, 1.84, -5.06)
	_box(machine, Vector3(0.62, 1.68, 0.57), "97485a")
	_box(machine + Vector3(0, 0.28, 0.30), Vector3(0.50, 0.69, 0.033), "d1d8d2")
	for row in 2:
		for col in 4:
			var x := -0.165 + col * 0.11
			_box(machine + Vector3(x, 0.13 + 0.24 * row, 0.330), Vector3(0.068, 0.15, 0.018),
				["9bb9c2", "bc6972", "91a985", "e2c688"][col])
	_box(machine + Vector3(0, -0.53, 0.304), Vector3(0.37, 0.12, 0.030), "443f48")
	for i in 2:
		var bin := Vector3(1.85 + 0.32 * i, 1.28, -5.05)
		_box(bin, Vector3(0.28, 0.55, 0.32), ["7faaa1", "6c9aa9"][i])
		_box(bin + Vector3.UP * 0.29, Vector3(0.30, 0.04, 0.33), "798b86")


func _bench(ground: Vector3, width: float) -> void:
	for dx: float in [-0.36, 0.36]:
		_box(ground + Vector3(dx * width, 0.19, 0), Vector3(0.105, 0.36, 0.36), "727371")
	for j in 3:
		_box(ground + Vector3(0, 0.38, -0.13 + 0.13 * j), Vector3(width, 0.066, 0.115), "ab8060")
	for j in 2:
		_box(ground + Vector3(0, 0.64 + 0.15 * j, -0.14), Vector3(width, 0.105, 0.069), "9d7259")


func _commuter_car() -> void:
	# Short visible section of a silver local train traversing the eastern crossing.
	# Separate window, door and stripe geometry keeps the livery clean at grazing angles.
	const X := 6.45
	const Z := TRACK_Z
	const LENGTH := 5.08
	const WIDTH := 2.08
	var skin_z := Z + WIDTH * 0.5
	for dx: float in [-1.57, 1.57]:
		for dz: float in [-0.68, 0.68]:
			_cylinder(Vector3(X + dx, 0.42, Z + dz), Vector3(0.36, 0.13, 0.36),
				"44444d", Basis(Vector3.RIGHT, PI / 2.0))
	_part_frame = Transform3D(Basis.IDENTITY, Vector3.UP * 0.31)
	_box(Vector3(X, 0.44, Z), Vector3(LENGTH - 0.22, 0.55, WIDTH - 0.36), "52545b")
	_box(Vector3(X, 1.65, Z), Vector3(LENGTH, 2.05, WIDTH), "e8eae8")
	_box(Vector3(X, 0.66, Z), Vector3(LENGTH + 0.015, 0.075, WIDTH + 0.018), "818889")
	# Custom roof profile forms the continuous rounded shoulders of a commuter car.
	_collect("car_roof", Vector3(X, 2.68, Z), Vector3(LENGTH + 0.04, 0.65, WIDTH + 0.02),
		"a9b4ba", Basis.IDENTITY)
	_box(Vector3(X - 0.25, 3.39, Z - 0.14), Vector3(1.18, 0.18, 0.67), "88949a")
	for i in 8:
		_box(Vector3(X - 0.745 + i * 0.135, 3.49, Z - 0.14), Vector3(0.043, 0.035, 0.52), "687781")
	for side: float in [-1.0, 1.0]:
		var side_z := Z + side * WIDTH * 0.5
		for band: Vector2 in [Vector2(1.50, 0.17), Vector2(1.36, 0.095)]:
			var color := "d94e76" if band.x > 1.4 else "59b9a5"
			_box(Vector3(X, band.x, side_z + side * 0.018), Vector3(LENGTH, band.y, 0.032), color)
		# Left sliding doors are solid cream panels; only the wide passenger windows carry blue glass.
		for leaf: float in [-0.26, 0.26]:
			var d := Vector3(X - 1.38 + leaf, 1.64, side_z + side * 0.048)
			_box(d, Vector3(0.509, 1.82, 0.040), "d9dbdc")
			var grip := leaf * -0.82
			_box(d + Vector3(grip, 0.026, side * 0.032), Vector3(0.032, 0.195, 0.026), "545861")
		_box(Vector3(X - 1.38, 1.64, side_z + side * 0.080), Vector3(0.020, 1.82, 0.016), "8a9094")
		var center := Vector3(X + 0.67, 2.03, side_z + side * 0.032)
		_box(center, Vector3(2.62, 0.65, 0.067), "879298")
		_box(center + Vector3(0, 0, side * 0.043), Vector3(2.51, 0.55, 0.039), "a7bdca")
		_box(center + Vector3(0.03, 0, side * 0.072), Vector3(0.065, 0.58, 0.020), "8e999e")
		_box(center + Vector3(0, 0.075, side * 0.075), Vector3(2.48, 0.22, 0.013), "c2d1db")
	for i in 4:
		_box(Vector3(X - 2.20, 1.82 + i * 0.08, skin_z + 0.035),
			Vector3(0.25, 0.030, 0.018), "8a9498")
	_part_frame = Transform3D.IDENTITY


func _crossing_signals() -> void:
	var near_base := Vector3(8.15, 0, 1.96)
	var far_base := Vector3(3.64, 0, -2.83)
	_signal(near_base, 4.18, true)
	_signal(far_base, 3.75, true)
	# One lowered boom runs across the road in front of the train.
	var pivot := near_base + Vector3(-0.15, 2.19, -0.22)
	_box(pivot + Vector3(-2.18, 0, 0), Vector3(4.42, 0.093, 0.11), "ece6d7")
	for i in 7:
		_box(pivot + Vector3(-0.35 - i * 0.61, 0, 0), Vector3(0.23, 0.10, 0.118), "963e4c")
	for i in 3:
		var x := -1.08 - i * 1.23
		_tube(pivot + Vector3(x,0.01,0), pivot + Vector3(x,-0.183,0), 0.025, INK)
		_box(pivot + Vector3(x, -0.23, 0), Vector3(0.11, 0.10, 0.07), "b82f41")
	# West railway lamp beside the tunnel.
	_cylinder(Vector3(-8.73, 1.61, TRACK_Z + 0.12), Vector3(0.12, 3.22, 0.12), "a8aaa5")
	_box(Vector3(-8.73, 3.15, TRACK_Z + 0.12), Vector3(0.43, 1.14, 0.35), "494751")
	for i in 2:
		var sig := Vector3(-8.73, 2.94 + i * 0.42, TRACK_Z + 0.32)
		_cylinder(sig, Vector3(0.25, 0.08, 0.25), ["ffdc50","6a6155"][i], Basis(Vector3.RIGHT, PI * 0.5))


func _signal(base: Vector3, pole_height: float, crossbuck: bool) -> void:
	_box(base + Vector3.UP * 0.17, Vector3(0.34, 0.34, 0.34), "a8aaa0")
	var bands := ceili(pole_height / 0.34)
	for i in bands:
		var band_h := pole_height / bands
		_cylinder(base + Vector3.UP * ((i + 0.5) * band_h), Vector3(0.175, band_h + 0.003, 0.175),
			["4a4851", "f4ca49"][i % 2])
	if crossbuck:
		for angle: float in [-0.68, 0.68]:
			var tilt := Basis(Vector3.BACK, angle)
			var top := base + Vector3(0, pole_height + 0.005, 0.032)
			_box(top, Vector3(1.06, 0.115, 0.075), "4a4650", tilt)
			_box(top + Vector3(0, 0, 0.045), Vector3(0.95, 0.072, 0.022), "f8cd4c", tilt)
	var level := pole_height - 0.54
	_box(base + Vector3(0, level, 0.07), Vector3(0.79, 0.24, 0.19), INK)
	for lamp in 2:
		var lamp_center := base + Vector3(-0.23 + 0.46 * lamp, level, 0.21)
		_cylinder(lamp_center, Vector3(0.32, 0.145, 0.32), INK, Basis(Vector3.RIGHT, PI * 0.5))
		_cylinder(lamp_center + Vector3(0,0,0.088), Vector3(0.208, 0.035, 0.208),
			"ff552c" if lamp == 0 else "925060", Basis(Vector3.RIGHT, PI * 0.5))
		_box(lamp_center + Vector3(0, 0.105, 0.055), Vector3(0.28, 0.052, 0.20), INK)
	_box(base + Vector3(-0.12, 1.87, 0), Vector3(0.38, 0.57, 0.32), "66656a")


func _wire_network() -> void:
	# Silhouette calibrated from the three distinct upright poles in the reference.
	var tops: Array[Vector3] = [
		Vector3(-6.97, 6.49, 0.58),
		Vector3(-1.50, 7.69, 2.43),
		Vector3(8.51, 8.28, 2.52),
	]
	for top in tops:
		var ground := Vector3(top.x, 0, top.z)
		_cylinder(ground + Vector3.UP * 0.13, Vector3(0.32, 0.26, 0.32), "a7a79b")
		_tube(ground + Vector3.UP * 0.08, top + Vector3.UP * 0.055, 0.173, "b8b5aa")
		for j in 3:
			var y := top.y - 0.11 - j * 0.415
			_box(Vector3(top.x, y, top.z), Vector3(0.115, 0.071, 0.64), "686a6a")
			_cylinder(Vector3(top.x, y+0.08, top.z+0.22), Vector3(0.095, 0.15, 0.095), "e6e4d8")
			_cylinder(Vector3(top.x, y+0.08, top.z-0.22), Vector3(0.095, 0.15, 0.095), "e6e4d8")
		_box(top + Vector3(0, -1.32, 0.08), Vector3(0.26, 0.21, 0.21), "858784")
	for span in range(tops.size() - 1):
		for cable in 6:
			var offset := Vector3(0, -0.025 - cable * 0.235, -0.23 if cable % 2 == 0 else 0.23)
			var a: Vector3 = tops[span] + offset
			var b: Vector3 = tops[span + 1] + offset
			_hanging_wire(a, b, a.distance_to(b) * (0.017 + 0.0028 * cable),
				0.048 if cable < 4 else 0.041)
	# Feeder towards the roof of the waiting room.
	_hanging_wire(tops[0] - Vector3.UP * 1.15, Vector3(-5.62, 3.11, -5.05), 0.20, 0.028)


func _hanging_wire(a: Vector3, b: Vector3, sag: float, diameter: float) -> void:
	var previous := a
	for i in range(1, 11):
		var t := i / 10.0
		var next := a.lerp(b, t) - Vector3.UP * (4.0 * sag * t * (1.0 - t))
		_tube(previous, next, diameter, "5a5563")
		previous = next


func _tube(a: Vector3, b: Vector3, diameter: float, color: String) -> void:
	var delta := b - a
	if delta.length_squared() < 0.000001:
		return
	var orientation := Basis(Quaternion(Vector3.UP, delta.normalized()))
	_cylinder((a+b)*0.5, Vector3(diameter, delta.length(), diameter), color, orientation)


func _box(center: Vector3, size: Vector3, color: String, rotation := Basis.IDENTITY) -> void:
	_collect("box", center, size, color, rotation)


func _cylinder(center: Vector3, size: Vector3, color: String, rotation := Basis.IDENTITY) -> void:
	_collect("cylinder", center, size, color, rotation)


func _collect(shape: String, center: Vector3, size: Vector3, color: String, rotation: Basis) -> void:
	var key := shape + ":" + color
	if not _batches.has(key):
		_batches[key] = []
	var transform_basis := Basis(rotation.x * size.x, rotation.y * size.y, rotation.z * size.z)
	_batches[key].append(_part_frame * Transform3D(transform_basis, center))


## Extrude a closed cross-section in Z/Y along X. The supplied perimeter runs
## clockwise in the Y/Z plane as viewed from the eastern end.
func _extruded_profile(profile: PackedVector2Array) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in profile.size():
		var end := (i + 1) % profile.size()
		var a := Vector3(-0.5, profile[i].y, profile[i].x)
		var b := Vector3(-0.5, profile[end].y, profile[end].x)
		var c := b + Vector3.RIGHT
		var d := a + Vector3.RIGHT
		_triangle(surface, a, c, b)
		_triangle(surface, a, d, c)
		if i > 0 and i < profile.size() - 1:
			var start := Vector3(-0.5, profile[0].y, profile[0].x)
			_triangle(surface, start, a, b)
			_triangle(surface, start + Vector3.RIGHT, c, d)
	return surface.commit()


func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := (b - a).cross(c - a).normalized()
	for point: Vector3 in [a, c, b]:
		surface.set_normal(normal)
		surface.add_vertex(point)


func _commit_meshes() -> void:
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.5
	cylinder.bottom_radius = 0.5
	cylinder.height = 1.0
	cylinder.radial_segments = 10
	cylinder.rings = 0
	var gable := _extruded_profile(PackedVector2Array([Vector2(-0.5,-0.5), Vector2(0.5,-0.5), Vector2(0,0.5)]))
	var car_roof := _extruded_profile(PackedVector2Array([
		Vector2(-0.5,0), Vector2(0.5,0), Vector2(0.49,0.26), Vector2(0.40,0.67),
		Vector2(0.25,0.94), Vector2(0.16,1.00), Vector2(-0.16,1.00),
		Vector2(-0.25,0.94), Vector2(-0.40,0.67), Vector2(-0.49,0.26)
	]))
	var portal := _extruded_profile(PackedVector2Array([
		Vector2(-0.5,0), Vector2(0.5,0), Vector2(0.5,0.77), Vector2(0.46,0.87),
		Vector2(0.35,0.94), Vector2(0.16,0.99), Vector2(0,1.0), Vector2(-0.16,0.99),
		Vector2(-0.35,0.94), Vector2(-0.46,0.87), Vector2(-0.5,0.77)
	]))
	var geometry := {"box": cube, "cylinder": cylinder, "gable": gable, "car_roof": car_roof, "portal": portal}
	for key: String in _batches:
		var parts := key.split(":")
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(parts[1])
		material.roughness = 1.0
		material.metallic_specular = 0.0
		if _emit_colors.has(parts[1]):
			material.emission_enabled = true
			material.emission = Color(parts[1])
			material.emission_energy_multiplier = _emit_colors[parts[1]]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = geometry[parts[0]]
		multi.instance_count = _batches[key].size()
		for i in multi.instance_count:
			multi.set_instance_transform(i, _batches[key][i])
		var instance := MultiMeshInstance3D.new()
		instance.name = ("Steelwork" if parts[0] == "cylinder" else "Station") + "_" + parts[1]
		if parts[1] == "5a5563":
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.multimesh = multi
		instance.material_override = material
		add_child(instance)
	_batches.clear()
