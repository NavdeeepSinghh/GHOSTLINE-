class_name DeadCityDressing
extends RefCounted
## Set dressing for the Dead City: the clutter of a city left in a hurry.
## Wall details (air-conditioners, drainpipes, fire escapes, boarded windows,
## posters, awnings, graffiti), street litter, sagging power cables, traffic
## signals, rooftop tanks and billboards, and atmosphere (steam from grates,
## fires, emergency lights, a skyline with a few lit windows, smoke and sweeping
## searchlights).
##
## Nearly everything here is visual only (no collision), so the routes, the
## navmesh and the fights are the same as before. The few solid pieces stand
## flat against walls, away from doors, ladders and pickups.

const L := CityBuilder.Look

## Street-facing walls: [from (x, z), to (x, z), outward normal (x, z), roof height].
const FACADES: Array = [
	# South row, facing South Street.
	[Vector2(-58, 56), Vector2(-36, 56), Vector2(0, -1), 18.0],
	[Vector2(-4, 56), Vector2(30, 56), Vector2(0, -1), 16.0],
	[Vector2(30, 56), Vector2(58, 56), Vector2(0, -1), 20.0],
	# Middle blocks, facing South Street.
	[Vector2(-58, 44), Vector2(-43, 44), Vector2(0, 1), 20.0],
	[Vector2(-37, 44), Vector2(-18, 44), Vector2(0, 1), 13.0],
	[Vector2(-18, 44), Vector2(-6, 44), Vector2(0, 1), 14.0],
	[Vector2(6, 44), Vector2(35, 44), Vector2(0, 1), 18.0],
	[Vector2(45, 44), Vector2(58, 44), Vector2(0, 1), 15.0],
	# Middle blocks, facing Main Street.
	[Vector2(-58, -3), Vector2(-43, -3), Vector2(0, -1), 20.0],
	[Vector2(-37, -3), Vector2(-30, -3), Vector2(0, -1), 12.0],
	[Vector2(-12, -3), Vector2(-6, -3), Vector2(0, -1), 16.0],
	[Vector2(6, -3), Vector2(35, -3), Vector2(0, -1), 15.5],
	[Vector2(45, -3), Vector2(58, -3), Vector2(0, -1), 15.0],
	# North blocks, facing Main Street.
	[Vector2(-58, -17), Vector2(-43, -17), Vector2(0, 1), 22.0],
	[Vector2(-43, -17), Vector2(-6, -17), Vector2(0, 1), 16.0],
	[Vector2(6, -17), Vector2(35, -17), Vector2(0, 1), 7.0],
	[Vector2(45, -17), Vector2(58, -17), Vector2(0, 1), 18.0],
	# West Alley.
	[Vector2(-43, -3), Vector2(-43, 44), Vector2(1, 0), 20.0],
	[Vector2(-37, -3), Vector2(-37, 14), Vector2(-1, 0), 12.0],
	[Vector2(-37, 32), Vector2(-37, 44), Vector2(-1, 0), 13.0],
	# Central Avenue.
	[Vector2(-6, -3), Vector2(-6, 32), Vector2(1, 0), 16.0],
	[Vector2(-6, 32), Vector2(-6, 44), Vector2(1, 0), 14.0],
	[Vector2(6, -3), Vector2(6, 11), Vector2(-1, 0), 15.5],
	[Vector2(6, 11), Vector2(6, 44), Vector2(-1, 0), 18.0],
	# East Avenue.
	[Vector2(35, -3), Vector2(35, 11), Vector2(1, 0), 15.5],
	[Vector2(35, 11), Vector2(35, 44), Vector2(1, 0), 18.0],
	[Vector2(35, -60), Vector2(35, -17), Vector2(1, 0), 7.0],
	[Vector2(45, -3), Vector2(45, 44), Vector2(-1, 0), 15.0],
	[Vector2(45, -60), Vector2(45, -17), Vector2(-1, 0), 18.0],
	# Tower Plaza.
	[Vector2(-34, -104), Vector2(-34, -60), Vector2(1, 0), 14.0],
	[Vector2(46, -104), Vector2(46, -60), Vector2(-1, 0), 17.0],
	[Vector2(-34, -60), Vector2(-6, -60), Vector2(0, -1), 16.0],
	[Vector2(6, -60), Vector2(35, -60), Vector2(0, -1), 7.0],
	[Vector2(-34, -104), Vector2(46, -104), Vector2(0, 1), 20.0],
]

## Ground-level details stay away from these: doors, ladders, signs, the gate,
## the metro stairs, workbenches and pickups. [x, z, radius]
const KEEP_CLEAR: Array = [
	[-26.0, 44.0, 3.5], [-21.0, 32.0, 2.5], [19.0, -3.0, 3.5], [-12.0, 58.0, 3.0], [20.0, -60.0, 3.5],
	[0.0, -84.0, 4.0], [-29.0, 58.0, 3.0], [32.0, -60.0, 3.0], [12.0, -17.0, 3.0], [40.0, -38.0, 4.5],
	[37.4, -40.0, 2.0], [5.9, 43.0, 2.0], [24.0, 56.0, 4.0], [-20.0, -60.0, 5.0], [-20.0, -3.0, 5.0],
	[-27.5, 9.0, 3.0], [-28.5, -61.5, 3.0], [-33.0, 49.0, 1.5], [3.5, -21.5, 1.5], [38.0, -66.0, 1.5],
	[52.0, 49.5, 1.5], [-50.0, -9.0, 1.5], [40.0, -28.5, 1.5], [-29.0, -98.0, 1.5], [31.0, -13.4, 1.5],
	[20.0, 46.2, 2.0], [-5.75, 24.0, 2.0], [45.0, 26.0, 3.5],
]

## Street areas for litter.
const STREETS: Array[Rect2] = [
	Rect2(-58, 44, 116, 12), Rect2(-58, -17, 116, 14), Rect2(-6, -3, 12, 47), Rect2(-43, -3, 6, 47),
	Rect2(35, -60, 10, 104), Rect2(-34, -104, 80, 44),
]
const HOLES: Array[Rect2] = [Rect2(-24.5, -3.0, 9.0, 12.0), Rect2(-24.5, -71.0, 9.0, 12.0), Rect2(-9.5, -100.5, 19.0, 17.0)]

const WOOD := Color(0.27, 0.19, 0.12)
const POSTER_COLORS: Array[Color] = [Color(0.62, 0.58, 0.48), Color(0.5, 0.52, 0.55), Color(0.6, 0.36, 0.3),
		Color(0.42, 0.46, 0.4), Color(0.66, 0.6, 0.38)]
const AWNING_COLORS: Array[Color] = [Color(0.32, 0.12, 0.1), Color(0.16, 0.22, 0.2), Color(0.3, 0.26, 0.16)]
const PAINT_RED := Color(0.62, 0.13, 0.1)
const PAINT_WHITE := Color(0.62, 0.62, 0.6)

var _b: CityBuilder
var _rng := RandomNumberGenerator.new()
var _signal_heads: Array[Vector3] = []
var _vents: Array[Vector3] = []


## Geometry. Call before `CityBuilder.commit()`.
func build(builder: CityBuilder, layout: DeadCityLayout) -> void:
	_b = builder
	_rng.seed = 4242
	graffiti()
	for facade: Array in FACADES:
		_dress_facade(facade[0], facade[1], facade[2], float(facade[3]))
	for street: Rect2 in STREETS:
		_litter(street, int(street.get_area() / 9.0))
	_cables()
	_traffic_signals()
	_rooftops()
	_dumpsters_and_barrels()
	_grates()
	_plaza_checkpoint()
	_street_detail()


## Lights, particles and moving parts. Call after the level has its environment.
func build_effects(parent: Node3D, layout: DeadCityLayout) -> void:
	var root := Node3D.new()
	root.name = "Atmosphere"
	parent.add_child(root)
	var scale: float = CityFX.amount_scale()
	for at: Vector3 in _vents:
		root.add_child(CityFX.steam(at + Vector3(0.0, 0.1, 0.0), int(16 * scale)))
	# Fires: Kael's camp barrel, two street barrels, a burning wreck in the plaza.
	root.add_child(CityFX.fire(Vector3(-15.9, DeadCityLayout.ROOF_A_Y + 0.95, 74.6), 0.45, 1.6))
	root.add_child(CityFX.fire(Vector3(54.0, 0.95, 54.4), 0.5, 2.0))
	root.add_child(CityFX.fire(Vector3(-55.4, 0.95, -15.6), 0.5, 2.0))
	root.add_child(CityFX.fire(Vector3(-31.6, 0.95, -101.8), 0.5, 2.2))
	root.add_child(CityFX.fire(Vector3(34.0, 1.3, -90.0), 1.3, 3.2))
	root.add_child(CityFX.smoke_column(Vector3(34.0, 2.5, -90.0), 26.0, 3.0))
	# Emergency lights still running on two abandoned cars.
	for car: Array in [[Vector3(8.0, 0.0, -14.0), 100.0], [Vector3(14.0, 0.0, -66.0), 70.0]]:
		var yaw: float = float(car[1])
		var top: Vector3 = (car[0] as Vector3) + Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(0.0, 1.49, -0.2)
		root.add_child(CityFX.emergency_lights(top, yaw))
	# Traffic signals still blinking amber.
	for i: int in _signal_heads.size():
		var blinker := Blinker.new()
		blinker.position = _signal_heads[i]
		blinker.period = 1.4
		blinker.duty = 0.5
		blinker.phase = 0.7 * float(i % 2)
		blinker.add_child(CityFX.glow_bulb(Vector3.ZERO, Color(1.0, 0.6, 0.1), 0.12, 4.0))
		root.add_child(blinker)
	_skyline_effects(root, layout)
	_atmosphere(root, parent)


func _skyline_effects(root: Node3D, layout: DeadCityLayout) -> void:
	var fires: int = 0
	var beacons: int = 0
	for i: int in layout.skyline.size():
		var footprint: Rect2 = layout.skyline[i][0]
		var height: float = float(layout.skyline[i][1])
		var top := Vector3(footprint.get_center().x, height, footprint.get_center().y)
		if height > 58.0 and beacons < 8:
			root.add_child(CityFX.beacon(top + Vector3(0.0, 1.2, 0.0), 0.9, float(i) * 0.37))
			beacons += 1
		elif i % 7 == 2 and fires < 3:
			# Something still burning out there: only the smoke shows through the fog.
			root.add_child(CityFX.smoke_column(top + Vector3(0.0, 1.0, 0.0), 60.0, 10.0))
			fires += 1
	root.add_child(CityFX.searchlight(Vector3(-175.0, 0.0, -150.0), 170.0, 0.1))
	root.add_child(CityFX.searchlight(Vector3(185.0, 0.0, 70.0), 170.0, -0.08))


# --- Walls --------------------------------------------------------------------

func _clear(x: float, z: float, extra: float = 0.0) -> bool:
	for spot: Array in KEEP_CLEAR:
		if Vector2(x - float(spot[0]), z - float(spot[1])).length() < float(spot[2]) + extra:
			return false
	return true


func _dress_facade(a: Vector2, b: Vector2, normal: Vector2, height: float) -> void:
	var length: float = a.distance_to(b)
	var along: Vector2 = (b - a) / length
	var n3 := Vector3(normal.x, 0.0, normal.y)
	var along3 := Vector3(along.x, 0.0, along.y)
	var yaw: float = rad_to_deg(atan2(normal.x, normal.y))
	var floors: int = maxi(int((height - 1.5) / 3.5), 1)
	var t: float = _rng.randf_range(1.5, 3.0)
	var escape_done: bool = height < 12.0 or length < 12.0 or _rng.randf() > 0.6
	while t < length - 1.5:
		var p: Vector2 = a + along * t
		var base := Vector3(p.x, 0.0, p.y)
		var ground_ok: bool = _clear(p.x, p.y)
		# Upper floors: air-conditioners hanging under windows.
		for floor_index: int in range(1, floors):
			if _rng.randf() < 0.22:
				var y: float = floor_index * 3.5 + 1.1
				_b.box(base + n3 * 0.32 + Vector3(0.0, y, 0.0), _oriented(along3, Vector3(0.9, 0.55, 0.6)), L.METAL, Color(0.42, 0.42, 0.4) * _rng.randf_range(0.7, 1.0), false)
				_b.box(base + n3 * 0.63 + Vector3(0.0, y, 0.0), _oriented(along3, Vector3(0.7, 0.4, 0.04)), L.METAL, Color(0.12, 0.12, 0.13), false)
				if _rng.randf() < 0.4:
					# A rust streak running down from it.
					_b.box(base + n3 * 0.03 + Vector3(0.0, y - 1.2, 0.0), _oriented(along3, Vector3(0.25, 2.0, 0.02)), L.RUBBLE, CityBuilder.COLOR_RUST * 0.8, false)
		var roll: float = _rng.randf()
		if roll < 0.1:
			# Drainpipe, roof to street.
			_b.box(base + n3 * 0.14 + Vector3(0.0, height * 0.5, 0.0), Vector3(0.14, height, 0.14), L.METAL, Color(0.2, 0.21, 0.2), false)
			_b.box(base + n3 * 0.3 + Vector3(0.0, 0.2, 0.0), _oriented(along3, Vector3(0.14, 0.14, 0.4)), L.METAL, Color(0.2, 0.21, 0.2), false)
		elif ground_ok and roll < 0.32:
			_boarded_window(base, n3, along3)
		elif ground_ok and roll < 0.52:
			_posters(base, n3, along3)
		elif ground_ok and roll < 0.62 and height >= 7.0:
			_awning(base, n3, along3)
		if ground_ok and _rng.randf() < 0.25:
			_trash_pile(base + n3 * 0.6)
		if not escape_done and t > 4.0 and t < length - 5.0 and ground_ok and _clear(p.x, p.y, 2.0):
			_fire_escape(base, n3, along3, height)
			escape_done = true
			t += 4.0
		t += _rng.randf_range(2.6, 4.6)


## Size given as (along the wall, up, out from the wall) turned into world axes.
func _oriented(along3: Vector3, size: Vector3) -> Vector3:
	return Vector3(absf(along3.x) * size.x + absf(along3.z) * size.z, size.y, absf(along3.z) * size.x + absf(along3.x) * size.z)


func _boarded_window(base: Vector3, n3: Vector3, along3: Vector3) -> void:
	_b.box(base + n3 * 0.02 + Vector3(0.0, 1.7, 0.0), _oriented(along3, Vector3(1.5, 1.4, 0.02)), L.INTERIOR, Color(0.05, 0.05, 0.05), false)
	for i: int in 3:
		var y: float = 1.25 + i * 0.45
		var angle: float = _rng.randf_range(-12.0, 12.0)
		var tilt := Vector3(angle, 0.0, 0.0) if absf(along3.z) > 0.5 else Vector3(0.0, 0.0, angle)
		_b.box(base + n3 * 0.06 + Vector3(0.0, y, 0.0), _oriented(along3, Vector3(1.8, 0.2, 0.04)), L.INTERIOR, WOOD * _rng.randf_range(0.8, 1.2), false, false, 0.0, tilt)


func _posters(base: Vector3, n3: Vector3, along3: Vector3) -> void:
	for i: int in _rng.randi_range(1, 3):
		var offset: Vector3 = along3 * _rng.randf_range(-1.0, 1.0)
		var torn: float = 1.0 if _rng.randf() < 0.7 else _rng.randf_range(0.4, 0.7)
		var angle: float = _rng.randf_range(-5.0, 5.0)
		var tilt := Vector3(angle, 0.0, 0.0) if absf(along3.z) > 0.5 else Vector3(0.0, 0.0, angle)
		_b.box(base + offset + n3 * (0.03 + i * 0.005) + Vector3(0.0, 1.55 + _rng.randf_range(-0.1, 0.3) - (1.0 - torn) * 0.5, 0.0),
				_oriented(along3, Vector3(0.75, 1.05 * torn, 0.01)), L.INTERIOR, POSTER_COLORS[_rng.randi() % POSTER_COLORS.size()] * _rng.randf_range(0.6, 1.0), false, false, 0.0, tilt)


func _awning(base: Vector3, n3: Vector3, along3: Vector3) -> void:
	var color: Color = AWNING_COLORS[_rng.randi() % AWNING_COLORS.size()]
	var droop: float = 18.0 + _rng.randf_range(0.0, 10.0)
	# Tilted down and away from the wall; rotate about the wall's own axis.
	var tilt := Vector3(droop * signf(n3.z), 0.0, 0.0) if absf(n3.z) > 0.5 else Vector3(0.0, 0.0, -droop * signf(n3.x))
	_b.box(base + n3 * 0.7 + Vector3(0.0, 3.05, 0.0), _oriented(along3, Vector3(3.2, 0.05, 1.5)), L.RUBBLE, color, false, false, 0.0, tilt)
	_b.box(base + n3 * 1.38 + Vector3(0.0, 2.7, 0.0), _oriented(along3, Vector3(3.2, 0.28, 0.03)), L.RUBBLE, color * 0.8, false)


func _fire_escape(base: Vector3, n3: Vector3, along3: Vector3, height: float) -> void:
	var rust := Color(0.22, 0.13, 0.09)
	var levels: int = int((height - 4.0) / 3.5)
	for i: int in levels:
		var y: float = 3.6 + i * 3.5
		var centre: Vector3 = base + n3 * 0.75 + Vector3(0.0, y, 0.0)
		_b.box(centre, _oriented(along3, Vector3(3.4, 0.07, 1.4)), L.METAL, rust, false)
		# Railing: top rail, mid rail and posts on the open sides.
		for rail_y: float in [1.0, 0.5]:
			_b.segment(centre + n3 * 0.68 - along3 * 1.7 + Vector3(0.0, rail_y, 0.0), centre + n3 * 0.68 + along3 * 1.7 + Vector3(0.0, rail_y, 0.0), 0.04, L.METAL, rust)
		for post: float in [-1.7, -0.6, 0.6, 1.7]:
			_b.segment(centre + n3 * 0.68 + along3 * post, centre + n3 * 0.68 + along3 * post + Vector3(0.0, 1.0, 0.0), 0.04, L.METAL, rust)
		for side: float in [-1.7, 1.7]:
			_b.segment(centre + along3 * side + Vector3(0.0, 1.0, 0.0), centre + n3 * 0.68 + along3 * side + Vector3(0.0, 1.0, 0.0), 0.04, L.METAL, rust)
		if i + 1 < levels:
			# A stair flight to the next platform, alternating direction.
			var dir: float = 1.0 if i % 2 == 0 else -1.0
			var low: Vector3 = centre + n3 * 0.15 - along3 * 1.2 * dir
			var high: Vector3 = centre + n3 * 0.15 + along3 * 1.3 * dir + Vector3(0.0, 3.5, 0.0)
			for edge: float in [-0.3, 0.3]:
				_b.segment(low + n3 * edge, high + n3 * edge, 0.06, L.METAL, rust)
			for s: int in 7:
				var step: Vector3 = low.lerp(high, (float(s) + 0.5) / 7.0)
				_b.box(step, _oriented(along3, Vector3(0.18, 0.04, 0.6)), L.METAL, rust, false)
	# The drop ladder, pulled up, under the first platform.
	var ladder_base: Vector3 = base + n3 * 1.3 + along3 * 1.2
	for side: float in [-0.25, 0.25]:
		_b.segment(ladder_base + along3 * side + Vector3(0.0, 1.6, 0.0), ladder_base + along3 * side + Vector3(0.0, 3.6, 0.0), 0.05, L.METAL, rust)
	for r: int in 6:
		_b.segment(ladder_base - along3 * 0.25 + Vector3(0.0, 1.8 + r * 0.32, 0.0), ladder_base + along3 * 0.25 + Vector3(0.0, 1.8 + r * 0.32, 0.0), 0.035, L.METAL, rust)


func _trash_pile(at: Vector3) -> void:
	for i: int in _rng.randi_range(2, 5):
		var size := Vector3(_rng.randf_range(0.35, 0.6), _rng.randf_range(0.25, 0.45), _rng.randf_range(0.35, 0.6))
		var offset := Vector3(_rng.randf_range(-0.7, 0.7), size.y * 0.5, _rng.randf_range(-0.7, 0.7))
		var color: Color = Color(0.05, 0.05, 0.055) if _rng.randf() < 0.7 else Color(0.14, 0.15, 0.12)
		_b.box(at + offset, size, L.RUBBLE, color, false, false, _rng.randf_range(0.0, 90.0), Vector3(_rng.randf_range(-12.0, 12.0), 0.0, _rng.randf_range(-12.0, 12.0)))


# --- Streets ------------------------------------------------------------------

func _near_keep_clear(x: float, z: float, margin: float) -> bool:
	for spot: Array in KEEP_CLEAR:
		if Vector2(x, z).distance_to(Vector2(float(spot[0]), float(spot[1]))) < float(spot[2]) + margin:
			return true
	return false


func _in_hole(x: float, z: float) -> bool:
	for hole: Rect2 in HOLES:
		if hole.has_point(Vector2(x, z)):
			return true
	return false


func _litter(area: Rect2, count: int) -> void:
	for i: int in count:
		var x: float
		var z: float
		if _rng.randf() < 0.6:
			# Most of it drifts against the kerbs.
			var edge: int = _rng.randi() % 2
			if area.size.x > area.size.y:
				x = _rng.randf_range(area.position.x, area.end.x)
				z = (area.position.y + _rng.randf_range(0.2, 2.2)) if edge == 0 else (area.end.y - _rng.randf_range(0.2, 2.2))
			else:
				z = _rng.randf_range(area.position.y, area.end.y)
				x = (area.position.x + _rng.randf_range(0.2, 2.2)) if edge == 0 else (area.end.x - _rng.randf_range(0.2, 2.2))
		else:
			x = _rng.randf_range(area.position.x, area.end.x)
			z = _rng.randf_range(area.position.y, area.end.y)
		if _in_hole(x, z):
			continue
		var kind: float = _rng.randf()
		var yaw: float = _rng.randf_range(0.0, 180.0)
		if kind < 0.4:
			# Sodden paper.
			_b.box(Vector3(x, 0.03, z), Vector3(_rng.randf_range(0.2, 0.45), 0.01, _rng.randf_range(0.25, 0.5)), L.INTERIOR,
					Color(0.5, 0.5, 0.47) * _rng.randf_range(0.5, 1.0), false, false, yaw)
		elif kind < 0.55:
			# A can or bottle on its side.
			_b.box(Vector3(x, 0.05, z), Vector3(0.08, 0.08, 0.2), L.METAL,
					[Color(0.5, 0.1, 0.08), Color(0.15, 0.3, 0.18), Color(0.55, 0.55, 0.55)][_rng.randi() % 3], false, false, yaw)
		elif kind < 0.8:
			# Broken concrete.
			var size := Vector3(_rng.randf_range(0.15, 0.55), _rng.randf_range(0.1, 0.35), _rng.randf_range(0.15, 0.55))
			_b.box(Vector3(x, size.y * 0.4, z), size, L.RUBBLE, CityBuilder.COLOR_CONCRETE * _rng.randf_range(0.5, 0.9), false, false, yaw,
					Vector3(_rng.randf_range(-15.0, 15.0), 0.0, _rng.randf_range(-15.0, 15.0)))
		elif kind < 0.9:
			# A plank.
			_b.box(Vector3(x, 0.04, z), Vector3(0.15, 0.05, _rng.randf_range(0.9, 1.8)), L.INTERIOR, WOOD * _rng.randf_range(0.7, 1.1), false, false, yaw)
		elif kind < 0.96:
			# Glass and metal glinting in puddles.
			_b.box(Vector3(x, 0.015, z), Vector3(0.12, 0.01, 0.1), L.METAL, Color(0.6, 0.65, 0.68), false, false, yaw)
		else:
			# A lost tyre.
			_b.box(Vector3(x, 0.12, z), Vector3(0.62, 0.22, 0.62), L.RUBBLE, Color(0.03, 0.03, 0.03), false, false, yaw)


## Roof height of the street wall at a point, or 0 where there is none.
func _height_at(x: float, z: float) -> float:
	for facade: Array in FACADES:
		var a: Vector2 = facade[0]
		var b: Vector2 = facade[1]
		var p := Vector2(x, z)
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(p, a, b)
		if closest.distance_to(p) < 0.6:
			return float(facade[3])
	return 0.0


func _cable(a: Vector3, b: Vector3, sag: float) -> void:
	var previous: Vector3 = a
	for i: int in range(1, 9):
		var t: float = float(i) / 8.0
		var point: Vector3 = a.lerp(b, t) - Vector3(0.0, sag * 4.0 * t * (1.0 - t), 0.0)
		_b.segment(previous, point, 0.035, L.METAL, Color(0.04, 0.04, 0.045))
		previous = point
	# Insulators at both ends.
	for end: Vector3 in [a, b]:
		_b.box(end, Vector3(0.12, 0.12, 0.12), L.METAL, Color(0.35, 0.3, 0.25), false)


func _cables() -> void:
	# Across the streets: [x or z along the street, from side, to side, axis].
	var spans: Array = []
	for x: float in [-51.0, -33.0, 0.0, 14.0, 39.0, 52.0]:
		spans.append([Vector2(x, 44.0), Vector2(x + _rng.randf_range(-5.0, 5.0), 56.0)])
	for x: float in [-52.0, -38.0, -9.0, 9.0, 27.0, 51.0]:
		spans.append([Vector2(x, -3.0), Vector2(x + _rng.randf_range(-5.0, 5.0), -17.0)])
	for z: float in [3.0, 9.0, 36.0, 41.0]:
		spans.append([Vector2(-43.0, z), Vector2(-37.0, z + _rng.randf_range(-2.0, 2.0))])
	for z: float in [2.0, 16.0, 28.0, 39.0]:
		spans.append([Vector2(-6.0, z), Vector2(6.0, z + _rng.randf_range(-4.0, 4.0))])
	for z: float in [16.0, 31.0, -24.0, -52.0]:
		spans.append([Vector2(35.0, z), Vector2(45.0, z + _rng.randf_range(-3.0, 3.0))])
	for span: Array in spans:
		var a: Vector2 = span[0]
		var b: Vector2 = span[1]
		var ha: float = _height_at(a.x, a.y)
		var hb: float = _height_at(b.x, b.y)
		if ha < 5.0 or hb < 5.0:
			continue
		var ya: float = minf(ha - 0.8, _rng.randf_range(6.0, 9.5))
		var yb: float = minf(hb - 0.8, _rng.randf_range(6.0, 9.5))
		var start := Vector3(a.x, ya, a.y)
		var finish := Vector3(b.x, yb, b.y)
		_cable(start, finish, start.distance_to(finish) * 0.07)
		if _rng.randf() < 0.45:
			_cable(start + Vector3(0.0, 0.5, 0.0), finish + Vector3(0.0, 0.45, 0.0), start.distance_to(finish) * 0.09)
	# A few snapped lines hanging down the walls.
	for drop: Array in [[Vector3(-47.0, 8.0, 44.1), Vector3(1, 0, 0.4)], [Vector3(22.0, 8.5, -2.9), Vector3(0.5, 0, -0.6)],
			[Vector3(-42.9, 9.0, 18.0), Vector3(0.6, 0, 0.3)], [Vector3(44.9, 7.5, -30.0), Vector3(-0.6, 0, 0.4)],
			[Vector3(-30.0, 7.5, -59.9), Vector3(0.3, 0, -0.7)]]:
		var top: Vector3 = drop[0]
		var lean: Vector3 = drop[1]
		var previous: Vector3 = top
		for i: int in range(1, 7):
			var t: float = float(i) / 6.0
			var point: Vector3 = top + lean * (t * t * 1.6) - Vector3(0.0, (top.y - 0.6) * t, 0.0)
			_b.segment(previous, point, 0.035, L.METAL, Color(0.04, 0.04, 0.045))
			previous = point
	# Guy wires from the broadcast mast down to anchor blocks in the plaza.
	for anchor: Vector3 in [Vector3(-22.0, 0.0, -76.0), Vector3(22.0, 0.0, -74.0), Vector3(-26.0, 0.0, -100.0), Vector3(28.0, 0.0, -101.0)]:
		var on_mast := Vector3(signf(anchor.x) * 3.0, 32.0, -92.0 + (3.0 if anchor.z > -92.0 else -3.0))
		_b.segment(anchor + Vector3(0.0, 0.5, 0.0), on_mast, 0.05, L.METAL, Color(0.08, 0.08, 0.09))
		_b.box(anchor + Vector3(0.0, 0.25, 0.0), Vector3(0.9, 0.5, 0.9), L.CONCRETE, CityBuilder.COLOR_CONCRETE * 0.7, true)


func _traffic_signals() -> void:
	for corner: Array in [[Vector3(6.7, 0.0, 44.7), Vector3(0, 0, 1)], [Vector3(-6.7, 0.0, 55.3), Vector3(0, 0, -1)],
			[Vector3(-6.7, 0.0, -3.7), Vector3(0, 0, -1)], [Vector3(6.7, 0.0, -16.3), Vector3(0, 0, 1)]]:
		var at: Vector3 = corner[0]
		var arm: Vector3 = corner[1]
		var dark := Color(0.09, 0.1, 0.1)
		_b.box(at + Vector3(0.0, 2.8, 0.0), Vector3(0.16, 5.6, 0.16), L.METAL, dark, true)
		_b.segment(at + Vector3(0.0, 5.4, 0.0), at + arm * 4.0 + Vector3(0.0, 5.4, 0.0), 0.11, L.METAL, dark)
		var head: Vector3 = at + arm * 3.6 + Vector3(0.0, 4.75, 0.0)
		_b.box(head, Vector3(0.36, 1.1, 0.36), L.METAL, Color(0.06, 0.06, 0.05), false)
		# Dead red and green lenses; the amber one blinks (an effect added later).
		_b.box(head + Vector3(0.0, 0.33, 0.0) - arm * 0.19, Vector3(0.2, 0.2, 0.2) - arm.abs() * 0.18, L.METAL, Color(0.18, 0.03, 0.02), false)
		_b.box(head + Vector3(0.0, -0.33, 0.0) - arm * 0.19, Vector3(0.2, 0.2, 0.2) - arm.abs() * 0.18, L.METAL, Color(0.02, 0.1, 0.04), false)
		_signal_heads.append(head - arm * 0.2)
		_signal_heads.append(head + arm * 0.2)
		# A pedestrian button box and a bent sign on the pole.
		_b.box(at + Vector3(0.0, 1.1, 0.0) - arm * 0.12, Vector3(0.14, 0.22, 0.14), L.METAL, Color(0.5, 0.42, 0.1), false)
		_b.box(at + Vector3(0.0, 2.6, 0.0) + arm.cross(Vector3.UP) * 0.3, Vector3(0.6, 0.6, 0.6) - arm.cross(Vector3.UP).abs() * 0.58,
				L.METAL, Color(0.5, 0.5, 0.5), false, false, 0.0, Vector3(0.0, 0.0, 8.0))


func _grates() -> void:
	for at: Vector3 in [Vector3(0.0, 0.0, 50.0), Vector3(-44.0, 0.0, -11.0), Vector3(22.0, 0.0, -7.0), Vector3(40.0, 0.0, 20.0),
			Vector3(-40.0, 0.0, 30.0), Vector3(12.0, 0.0, -78.0), Vector3(-6.0, 0.0, -66.0)]:
		_b.box(at + Vector3(0.0, 0.012, 0.0), Vector3(1.1, 0.02, 1.1), L.METAL, Color(0.05, 0.05, 0.05), false)
		for bar: int in 5:
			_b.box(at + Vector3(-0.44 + bar * 0.22, 0.025, 0.0), Vector3(0.05, 0.02, 1.0), L.METAL, Color(0.16, 0.15, 0.14), false)
		_vents.append(at)


func _dumpsters_and_barrels() -> void:
	for dumpster: Array in [[Vector3(-55.0, 0.0, 44.75), 0.0], [Vector3(54.5, 0.0, -3.75), 0.0], [Vector3(40.0, 0.0, -103.25), 0.0],
			[Vector3(44.25, 0.0, 5.0), 90.0]]:
		var at: Vector3 = dumpster[0]
		var yaw: float = float(dumpster[1])
		var green := Color(0.1, 0.17, 0.13)
		_b.box(at + Vector3(0.0, 0.65, 0.0), Vector3(2.2, 1.3, 1.4) if yaw == 0.0 else Vector3(1.4, 1.3, 2.2), L.METAL, green, true)
		_b.box(at + Vector3(0.0, 1.38, 0.0), Vector3(2.25, 0.08, 1.45) if yaw == 0.0 else Vector3(1.45, 0.08, 2.25), L.METAL, green * 0.7, false, false, 0.0,
				Vector3(-14.0, 0.0, 0.0) if yaw == 0.0 else Vector3(0.0, 0.0, 14.0))
		_trash_pile(at + Vector3(1.6, 0.0, 0.4) if yaw == 0.0 else at + Vector3(-0.4, 0.0, 1.8))
	# Fire barrels (the fires themselves are effects).
	for at: Vector3 in [Vector3(54.0, 0.0, 54.4), Vector3(-55.4, 0.0, -15.6), Vector3(-31.6, 0.0, -101.8)]:
		_b.box(at + Vector3(0.0, 0.45, 0.0), Vector3(0.6, 0.9, 0.6), L.METAL, CityBuilder.COLOR_RUST, true)
		_b.box(at + Vector3(0.0, 0.88, 0.0), Vector3(0.5, 0.04, 0.5), L.RUBBLE, Color(0.9, 0.35, 0.08) * 1.5, false)
	# The wreck burning in the plaza: scorched shell.
	_b.box(Vector3(34.0, 1.42, -90.0), Vector3(1.5, 0.04, 2.0), L.RUBBLE, Color(0.02, 0.02, 0.02), false, false, -35.0)


func _rooftops() -> void:
	# [footprint x0, z0, x1, z1, roof height]
	var roofs: Array = [
		[-58.0, -3.0, -43.0, 44.0, 20.0], [6.0, 11.0, 35.0, 44.0, 18.0], [-4.0, 56.0, 30.0, 92.0, 16.0], [30.0, 56.0, 66.0, 92.0, 20.0],
		[45.0, -3.0, 58.0, 44.0, 15.0], [45.0, -60.0, 58.0, -17.0, 18.0], [-58.0, -104.0, -34.0, -60.0, 14.0],
		[46.0, -104.0, 58.0, -60.0, 17.0], [-58.0, -60.0, -43.0, -17.0, 22.0], [-43.0, -60.0, -6.0, -17.0, 16.0],
		[-12.0, -3.0, -6.0, 32.0, 16.0], [-58.0, 56.0, -36.0, 92.0, 18.0],
	]
	for roof: Array in roofs:
		var x0: float = roof[0]
		var z0: float = roof[1]
		var x1: float = roof[2]
		var z1: float = roof[3]
		var y: float = roof[4]
		for i: int in _rng.randi_range(3, 6):
			var at := Vector3(_rng.randf_range(x0 + 2.0, x1 - 2.0), y, _rng.randf_range(z0 + 2.0, z1 - 2.0))
			var size := Vector3(_rng.randf_range(1.2, 2.6), _rng.randf_range(0.8, 1.6), _rng.randf_range(1.2, 2.6))
			_b.box(at + Vector3(0.0, size.y * 0.5, 0.0), size, L.METAL, Color(0.3, 0.31, 0.3) * _rng.randf_range(0.6, 1.0), false)
		for i: int in _rng.randi_range(1, 2):
			var at := Vector3(_rng.randf_range(x0 + 1.0, x1 - 1.0), y, _rng.randf_range(z0 + 1.0, z1 - 1.0))
			var tall: float = _rng.randf_range(4.0, 9.0)
			_b.box(at + Vector3(0.0, tall * 0.5, 0.0), Vector3(0.1, tall, 0.1), L.METAL, Color(0.12, 0.12, 0.12), false)
			for c: int in 3:
				_b.box(at + Vector3(0.0, tall * (0.5 + c * 0.17), 0.0), Vector3(1.2 - c * 0.3, 0.05, 0.05), L.METAL, Color(0.12, 0.12, 0.12), false, false, _rng.randf_range(0.0, 90.0))
		if _rng.randf() < 0.5:
			# A satellite dish turned to the sky.
			var dish := Vector3(_rng.randf_range(x0 + 1.5, x1 - 1.5), y, _rng.randf_range(z0 + 1.5, z1 - 1.5))
			_b.box(dish + Vector3(0.0, 0.6, 0.0), Vector3(0.12, 1.2, 0.12), L.METAL, Color(0.3, 0.3, 0.3), false)
			_b.box(dish + Vector3(0.0, 1.3, 0.0), Vector3(1.4, 0.06, 1.4), L.METAL, Color(0.6, 0.6, 0.58), false, false, _rng.randf_range(0.0, 90.0), Vector3(35.0, 0.0, 0.0))
	# Water tanks on stilts.
	for tank: Vector3 in [Vector3(-51.0, 20.0, 30.0), Vector3(52.0, 15.0, 20.0), Vector3(-50.0, 22.0, -40.0), Vector3(20.0, 16.0, 75.0)]:
		for leg: Vector2 in [Vector2(-1.2, -1.2), Vector2(1.2, -1.2), Vector2(-1.2, 1.2), Vector2(1.2, 1.2)]:
			_b.box(tank + Vector3(leg.x, 1.5, leg.y), Vector3(0.18, 3.0, 0.18), L.METAL, Color(0.15, 0.13, 0.12), false)
		_b.box(tank + Vector3(0.0, 4.6, 0.0), Vector3(3.0, 3.2, 3.0), L.INTERIOR, Color(0.28, 0.2, 0.14), false, false, 45.0)
		_b.box(tank + Vector3(0.0, 6.5, 0.0), Vector3(2.4, 0.6, 2.4), L.INTERIOR, Color(0.2, 0.15, 0.1), false, false, 45.0)
		_b.box(tank + Vector3(0.0, 7.0, 0.0), Vector3(1.0, 0.5, 1.0), L.INTERIOR, Color(0.2, 0.15, 0.1), false, false, 45.0)
	# Billboards: one over South Street, one over the plaza.
	_billboard(Vector3(20.0, 18.0, 42.5), 0.0, "MERIDIAN BROADCAST", "THE VOICE OF THE CITY")
	_billboard(Vector3(-24.0, 16.0, -58.5), 180.0, "STAY TUNED", "KEEP YOUR RADIO ON")


func _billboard(at: Vector3, yaw: float, title: String, line: String) -> void:
	var basis := Basis(Vector3.UP, deg_to_rad(yaw))
	var frame := Color(0.14, 0.13, 0.12)
	for leg: float in [-4.5, -1.5, 1.5, 4.5]:
		_b.box(at + basis * Vector3(leg, 2.0, -0.6), Vector3(0.2, 4.0, 0.2), L.METAL, frame, false, false, yaw)
		_b.segment(at + basis * Vector3(leg, 0.0, -2.0), at + basis * Vector3(leg, 3.5, -0.6), 0.1, L.METAL, frame)
	_b.box(at + basis * Vector3(0.0, 5.6, 0.0), Vector3(12.0, 4.4, 0.2), L.PANEL, Color(0.42, 0.42, 0.4), false, false, yaw)
	# A torn corner.
	_b.box(at + basis * Vector3(4.6, 7.0, 0.12), Vector3(2.6, 1.4, 0.03), L.RUBBLE, Color(0.12, 0.12, 0.13), false, false, yaw)
	_b.box(at + basis * Vector3(0.0, 3.3, 0.6), Vector3(12.0, 0.08, 1.2), L.METAL, frame, false, false, yaw)
	var forward: Vector3 = basis * Vector3(0.0, 0.0, 1.0)
	_b.sign_text(title, at + basis * Vector3(-0.6, 6.4, 0.12), yaw, 3.6, Color(0.55, 0.25, 0.2))
	_b.sign_text(line, at + basis * Vector3(-0.6, 4.6, 0.12), yaw, 1.6, Color(0.2, 0.2, 0.22))
	# One working lamp on the catwalk, sputtering.
	_b.strip(at + basis * Vector3(-3.0, 3.45, 1.0), Vector3(0.5, 0.1, 0.2), CityBuilder.COLOR_WARM, yaw)
	_b.point_light(at + forward * 2.2 + Vector3(0.0, 4.4, 0.0) + basis * Vector3(-3.0, 0.0, 0.0), CityBuilder.COLOR_WARM, 2.4, 9.0, false, true)


## Painted words on the walls. Call in `build` (labels are added to the builder).
func graffiti() -> void:
	var lines: Array = [
		["THEY HEAR YOU", Vector3(-50.5, 2.3, 44.04), 0.0, 1.5, PAINT_RED],
		["STAY QUIET", Vector3(44.0, 2.0, 55.96), 180.0, 1.3, PAINT_WHITE],
		["EVAC NORTH. FOLLOW THE TOWER LIGHTS", Vector3(-42.96, 2.4, 22.0), 90.0, 0.7, PAINT_WHITE],
		["DON'T FOLLOW THE SONG", Vector3(51.0, 2.2, -3.04), 180.0, 1.0, PAINT_RED],
		["QUARANTINE ZONE 4", Vector3(-28.0, 2.6, -16.96), 0.0, 1.1, Color(0.6, 0.48, 0.1)],
		["WE WERE HERE", Vector3(44.96, 2.4, 14.0), -90.0, 1.2, PAINT_WHITE],
		["IIII IIII IIII IIII IIII II", Vector3(44.96, 1.5, 14.0), -90.0, 0.8, PAINT_WHITE],
		["NOBODY IS COMING", Vector3(-33.96, 2.5, -80.0), 90.0, 1.3, PAINT_RED],
		["LISTEN", Vector3(26.0, 3.2, -103.96), 0.0, 3.0, PAINT_RED],
	]
	_b.neon("LUCKY'S", Vector3(44.9, 3.6, 26.0), -90.0, CityBuilder.COLOR_WARM, 1.6, true, 1.8)
	_b.neon("OPEN", Vector3(44.9, 2.9, 23.8), -90.0, Color(1.0, 0.25, 0.2), 0.7, true, 0.8)
	for entry: Array in lines:
		var label: Label3D = _b.sign_text(str(entry[0]), entry[1], float(entry[2]), float(entry[3]), entry[4])
		label.rotation_degrees.z = _rng.randf_range(-3.0, 3.0)
		label.modulate.a = 0.85


## Tower Plaza was the evacuation point: sandbags either side of the tower door,
## an ambulance against the west wall, and what people dropped when they ran.
func _plaza_checkpoint() -> void:
	var khaki := Color(0.3, 0.27, 0.19)
	for side: float in [-1.0, 1.0]:
		var x0: float = 4.5 * side
		var x1: float = 10.0 * side
		_b.collider(Vector3((x0 + x1) * 0.5, 0.35, -81.6), Vector3(absf(x1 - x0), 0.7, 0.9))
		var x: float = minf(x0, x1)
		while x < maxf(x0, x1) - 0.2:
			for row: int in 2:
				_b.box(Vector3(x + 0.35 + row * 0.3, 0.17 + row * 0.33, -81.6 + _rng.randf_range(-0.05, 0.05)), Vector3(0.68, 0.32, 0.85),
						L.RUBBLE, khaki * _rng.randf_range(0.8, 1.15), false, false, _rng.randf_range(-6.0, 6.0))
			x += 0.7
	# A folding table and crates at the checkpoint.
	_b.box(Vector3(-7.0, 0.74, -79.5), Vector3(1.8, 0.05, 0.8), L.METAL, Color(0.35, 0.35, 0.33), false)
	for leg: Vector2 in [Vector2(-0.8, -0.35), Vector2(0.8, -0.35), Vector2(-0.8, 0.35), Vector2(0.8, 0.35)]:
		_b.box(Vector3(-7.0 + leg.x, 0.37, -79.5 + leg.y), Vector3(0.04, 0.74, 0.04), L.METAL, Color(0.2, 0.2, 0.2), false)
	_b.collider(Vector3(-7.0, 0.4, -79.5), Vector3(1.8, 0.8, 0.8))
	_b.box(Vector3(-6.8, 0.8, -79.5), Vector3(0.5, 0.06, 0.35), L.INTERIOR, Color(0.6, 0.6, 0.56), false, false, 12.0)
	for crate: Vector3 in [Vector3(7.5, 0.0, -79.0), Vector3(8.4, 0.0, -79.4), Vector3(7.9, 0.6, -79.2)]:
		_b.box(crate + Vector3(0.0, 0.3, 0.0), Vector3(0.8, 0.6, 0.6), L.INTERIOR, Color(0.25, 0.28, 0.18), crate.y < 0.1)
	# The ambulance, nosed into the west wall, doors open.
	var white := Color(0.55, 0.55, 0.52)
	_b.box(Vector3(-31.6, 1.25, -91.0), Vector3(2.3, 2.2, 5.6), L.METAL, white, true)
	_b.box(Vector3(-31.6, 0.85, -87.6), Vector3(2.2, 1.3, 1.4), L.METAL, white * 0.9, true)
	_b.box(Vector3(-30.43, 1.3, -91.0), Vector3(0.02, 0.3, 5.0), L.METAL, Color(0.5, 0.08, 0.06), false)
	_b.box(Vector3(-32.77, 1.3, -91.0), Vector3(0.02, 0.3, 5.0), L.METAL, Color(0.5, 0.08, 0.06), false)
	for side: float in [-1.0, 1.0]:
		_b.box(Vector3(-31.6 + side * 1.4, 1.2, -94.3), Vector3(0.05, 1.9, 1.1), L.METAL, white * 0.85, false, false, side * 70.0)
	for wheel: Vector2 in [Vector2(-1.1, -89.0), Vector2(1.1, -89.0), Vector2(-1.1, -93.0), Vector2(1.1, -93.0)]:
		_b.box(Vector3(-31.6 + wheel.x, 0.35, wheel.y), Vector3(0.3, 0.7, 0.7), L.RUBBLE, Color(0.03, 0.03, 0.03), false)
	_b.box(Vector3(-31.6, 2.42, -88.8), Vector3(1.0, 0.12, 0.3), L.METAL, Color(0.1, 0.1, 0.1), false)
	# A stretcher half out of the back.
	_b.box(Vector3(-31.6, 0.75, -95.2), Vector3(0.6, 0.06, 2.0), L.INTERIOR, Color(0.45, 0.42, 0.38), false, false, 0.0, Vector3(-14.0, 0.0, 0.0))
	# Dropped luggage across the square.
	for i: int in 26:
		var at := Vector3(_rng.randf_range(-24.0, 30.0), 0.0, _rng.randf_range(-98.0, -64.0))
		if _in_hole(at.x, at.z) or Vector2(at.x, at.z + 72.0).length() < 6.0:
			continue
		var size := Vector3(_rng.randf_range(0.4, 0.75), _rng.randf_range(0.18, 0.3), _rng.randf_range(0.5, 0.85))
		var colour: Color = [Color(0.12, 0.13, 0.16), Color(0.32, 0.16, 0.12), Color(0.2, 0.24, 0.2), Color(0.38, 0.33, 0.26)][_rng.randi() % 4]
		_b.box(at + Vector3(0.0, size.y * 0.5, 0.0), size, L.INTERIOR, colour, false, false, _rng.randf_range(0.0, 180.0))


# --- Close-range detail (M8) ------------------------------------------------------

const SHOP_NAMES: PackedStringArray = ["PAWN & LOAN", "NOODLE BAR", "TAILOR", "PHONE REPAIR", "BAKERY", "LAUNDRY", "HARDWARE",
		"BOOKS", "BARBER", "PRINT SHOP", "CORNER MART", "DENTIST", "KEYS CUT", "TEA HOUSE"]
const SIGN_PAINTS: Array[Color] = [Color(0.6, 0.55, 0.45), Color(0.55, 0.25, 0.2), Color(0.3, 0.42, 0.45), Color(0.62, 0.5, 0.2)]
const CLOTH: Array[Color] = [Color(0.55, 0.2, 0.18), Color(0.2, 0.3, 0.45), Color(0.6, 0.58, 0.5), Color(0.25, 0.35, 0.25), Color(0.5, 0.42, 0.2)]


## Streets wider than an alley get shopfronts, balconies and street furniture.
func _street_detail() -> void:
	var shop: int = 0
	for facade: Array in FACADES:
		var a: Vector2 = facade[0]
		var b: Vector2 = facade[1]
		var normal: Vector2 = facade[2]
		var height: float = float(facade[3])
		var alley: bool = absf(a.x + 43.0) < 0.1 or absf(a.x + 37.0) < 0.1
		var length: float = a.distance_to(b)
		var along: Vector2 = (b - a) / length
		var n3 := Vector3(normal.x, 0.0, normal.y)
		var a3 := Vector3(along.x, 0.0, along.y)
		var yaw: float = rad_to_deg(atan2(normal.x, normal.y))
		var t: float = _rng.randf_range(2.5, 5.0)
		while t < length - 2.5:
			var p: Vector2 = a + along * t
			var base := Vector3(p.x, 0.0, p.y)
			if _clear(p.x, p.y, 1.0):
				if height >= 7.0 and _rng.randf() < 0.32:
					_shopfront(base, n3, a3, yaw, SHOP_NAMES[shop % SHOP_NAMES.size()])
					shop += 1
				if not alley and _rng.randf() < 0.45:
					_street_furniture(base + n3 * _rng.randf_range(1.6, 2.3) + a3 * _rng.randf_range(-1.0, 1.0), n3, a3)
			if height >= 12.0 and _rng.randf() < 0.18:
				_balcony(base, n3, a3, float(_rng.randi_range(1, int((height - 4.0) / 3.5))) * 3.5 + 0.2)
			t += _rng.randf_range(4.5, 7.5)
	# Washing strung across the West Alley.
	for z: float in [6.0, 12.0, 27.0, 38.0]:
		var y: float = _rng.randf_range(5.0, 7.5)
		_laundry(Vector3(-42.9, y, z), Vector3(-37.1, y + _rng.randf_range(-0.4, 0.4), z + _rng.randf_range(-1.5, 1.5)))
	# Street trees, long dead, along the wide pavements.
	for at: Vector2 in [Vector2(-50.0, 46.2), Vector2(-14.0, 46.2), Vector2(12.0, 46.2), Vector2(50.0, 46.2), Vector2(-48.0, -4.6),
			Vector2(30.0, -4.6), Vector2(-24.0, -15.4), Vector2(28.0, -15.4), Vector2(43.4, 34.0), Vector2(36.6, 2.0)]:
		if _clear(at.x, at.y, 1.0):
			_dead_tree(Vector3(at.x, 0.0, at.y))
	# Potholes and cracks in the asphalt.
	for street: Rect2 in STREETS:
		for i: int in int(street.get_area() / 60.0):
			var x: float = _rng.randf_range(street.position.x + 3.0, street.end.x - 3.0)
			var z: float = _rng.randf_range(street.position.y + 3.0, street.end.y - 3.0)
			if _in_hole(x, z):
				continue
			if _rng.randf() < 0.4:
				_b.box(Vector3(x, 0.006, z), Vector3(_rng.randf_range(0.6, 1.4), 0.008, _rng.randf_range(0.5, 1.2)), L.ASPHALT, Color(0.03, 0.03, 0.035),
						false, false, _rng.randf_range(0.0, 180.0))
			else:
				var yaw: float = _rng.randf_range(0.0, 180.0)
				for c: int in _rng.randi_range(2, 4):
					_b.box(Vector3(x + c * 0.5 * sin(deg_to_rad(yaw)), 0.005, z + c * 0.5 * cos(deg_to_rad(yaw))), Vector3(0.05, 0.006, _rng.randf_range(0.6, 1.2)),
							L.ASPHALT, Color(0.04, 0.04, 0.045), false, false, yaw + _rng.randf_range(-25.0, 25.0))


func _shopfront(base: Vector3, n3: Vector3, a3: Vector3, yaw: float, name: String) -> void:
	var width: float = 3.0
	# A roll-down shutter, some jammed half open.
	var drop: float = 2.6 if _rng.randf() < 0.7 else _rng.randf_range(1.2, 2.0)
	var steel := Color(0.36, 0.37, 0.36) * _rng.randf_range(0.7, 1.05)
	for i: int in int(drop / 0.16):
		_b.box(base + n3 * 0.05 + Vector3(0.0, 2.75 - i * 0.16, 0.0), _oriented(a3, Vector3(width, 0.13, 0.04)), L.METAL, steel * (0.9 if i % 2 else 1.0), false)
	_b.box(base + n3 * 0.12 + Vector3(0.0, 2.9, 0.0), _oriented(a3, Vector3(width + 0.2, 0.3, 0.2)), L.METAL, steel * 0.7, false)
	if drop < 2.5:
		_b.box(base + n3 * 0.02 + Vector3(0.0, (2.75 - drop) * 0.5, 0.0), _oriented(a3, Vector3(width, 2.75 - drop, 0.01)), L.INTERIOR, Color(0.02, 0.02, 0.02), false)
	# Graffiti tags on the shutter and the shop's sign above.
	if _rng.randf() < 0.5:
		_b.box(base + n3 * 0.08 + a3 * _rng.randf_range(-0.8, 0.8) + Vector3(0.0, 1.6, 0.0), _oriented(a3, Vector3(_rng.randf_range(0.6, 1.4), 0.4, 0.01)), L.INTERIOR,
				[PAINT_RED, PAINT_WHITE, Color(0.2, 0.35, 0.6)][_rng.randi() % 3] * 0.8, false)
	var paint: Color = SIGN_PAINTS[_rng.randi() % SIGN_PAINTS.size()]
	_b.box(base + n3 * 0.1 + Vector3(0.0, 3.35, 0.0), _oriented(a3, Vector3(width, 0.55, 0.08)), L.PANEL, paint * 0.5, false)
	var label: Label3D = _b.sign_text(name, base + n3 * 0.15 + Vector3(0.0, 3.35, 0.0), yaw, 0.55, paint * 1.3)
	label.rotation_degrees.z = _rng.randf_range(-2.0, 2.0) if _rng.randf() < 0.3 else 0.0


func _balcony(base: Vector3, n3: Vector3, a3: Vector3, y: float) -> void:
	var rail := Color(0.12, 0.12, 0.12)
	var slab: Vector3 = base + n3 * 0.5 + Vector3(0.0, y, 0.0)
	_b.box(slab, _oriented(a3, Vector3(2.4, 0.12, 1.0)), L.CONCRETE, CityBuilder.COLOR_CONCRETE * 0.8, false)
	_b.segment(slab + n3 * 0.48 - a3 * 1.2 + Vector3(0.0, 0.9, 0.0), slab + n3 * 0.48 + a3 * 1.2 + Vector3(0.0, 0.9, 0.0), 0.04, L.METAL, rail)
	for k: int in 7:
		var post: Vector3 = slab + n3 * 0.48 + a3 * (-1.2 + k * 0.4)
		_b.segment(post, post + Vector3(0.0, 0.9, 0.0), 0.03, L.METAL, rail)
	for side: float in [-1.2, 1.2]:
		_b.segment(slab + a3 * side + Vector3(0.0, 0.9, 0.0), slab + a3 * side + n3 * 0.48 + Vector3(0.0, 0.9, 0.0), 0.04, L.METAL, rail)
	# Plant pots, a chair, a blanket over the rail.
	if _rng.randf() < 0.6:
		_b.box(slab + a3 * _rng.randf_range(-0.9, 0.9) + Vector3(0.0, 0.25, 0.0), Vector3(0.35, 0.35, 0.35), L.RUBBLE, Color(0.4, 0.22, 0.14), false)
		_b.box(slab + a3 * _rng.randf_range(-0.9, 0.9) + Vector3(0.0, 0.55, 0.0), Vector3(0.3, 0.5, 0.3), L.EARTH, Color(0.2, 0.18, 0.1), false)
	if _rng.randf() < 0.4:
		_b.box(slab + n3 * 0.5 + Vector3(0.0, 0.6, 0.0), _oriented(a3, Vector3(1.0, 0.7, 0.03)), L.RUBBLE, CLOTH[_rng.randi() % CLOTH.size()], false)


func _laundry(from: Vector3, to: Vector3) -> void:
	var previous: Vector3 = from
	var points: Array[Vector3] = []
	for i: int in range(1, 9):
		var t: float = float(i) / 8.0
		var point: Vector3 = from.lerp(to, t) - Vector3(0.0, 0.5 * 4.0 * t * (1.0 - t), 0.0)
		_b.segment(previous, point, 0.02, L.METAL, Color(0.4, 0.4, 0.38))
		points.append(point)
		previous = point
	for i: int in range(0, 7):
		if _rng.randf() < 0.75:
			var at: Vector3 = points[i]
			var size := Vector3(_rng.randf_range(0.35, 0.8), _rng.randf_range(0.4, 0.9), 0.02)
			_b.box(at - Vector3(0.0, size.y * 0.5, 0.0), size, L.RUBBLE, CLOTH[_rng.randi() % CLOTH.size()] * _rng.randf_range(0.7, 1.1), false, false,
					rad_to_deg(atan2(to.x - from.x, to.z - from.z)) + 90.0, Vector3(_rng.randf_range(-8.0, 8.0), 0.0, 0.0))


func _street_furniture(at: Vector3, n3: Vector3, a3: Vector3) -> void:
	var roll: float = _rng.randf()
	var dark := Color(0.12, 0.13, 0.13)
	if roll < 0.18:
		# Fire hydrant.
		_b.box(at + Vector3(0.0, 0.35, 0.0), Vector3(0.28, 0.7, 0.28), L.METAL, Color(0.55, 0.12, 0.08), true)
		_b.box(at + Vector3(0.0, 0.72, 0.0), Vector3(0.2, 0.1, 0.2), L.METAL, Color(0.45, 0.1, 0.06), false)
		_b.box(at + Vector3(0.0, 0.45, 0.0), Vector3(0.45, 0.1, 0.1), L.METAL, Color(0.45, 0.1, 0.06), false)
	elif roll < 0.34:
		# A bench, bolted down.
		_b.box(at + Vector3(0.0, 0.45, 0.0), _oriented(a3, Vector3(1.8, 0.06, 0.45)), L.INTERIOR, Color(0.28, 0.2, 0.13), true)
		_b.box(at + n3 * 0.2 + Vector3(0.0, 0.75, 0.0), _oriented(a3, Vector3(1.8, 0.35, 0.05)), L.INTERIOR, Color(0.28, 0.2, 0.13), false)
		for side: float in [-0.75, 0.75]:
			_b.box(at + a3 * side + Vector3(0.0, 0.22, 0.0), _oriented(a3, Vector3(0.06, 0.45, 0.45)), L.METAL, dark, false)
	elif roll < 0.46:
		# Mailbox or newspaper box.
		var blue: bool = _rng.randf() < 0.5
		_b.box(at + Vector3(0.0, 0.6, 0.0), Vector3(0.5, 1.2, 0.45), L.METAL, Color(0.15, 0.22, 0.4) if blue else Color(0.5, 0.45, 0.15), true, false,
				_rng.randf_range(-10.0, 10.0))
	elif roll < 0.58:
		# Bollards.
		for k: int in 3:
			_b.box(at + a3 * (k - 1) * 1.1 + Vector3(0.0, 0.45, 0.0), Vector3(0.18, 0.9, 0.18), L.METAL, dark, true)
	elif roll < 0.7:
		# A bike chained to a rack, wheels gone.
		_b.box(at + Vector3(0.0, 0.4, 0.0), _oriented(a3, Vector3(1.3, 0.05, 0.05)), L.METAL, dark, false)
		_b.segment(at + a3 * -0.5 + Vector3(0.0, 0.4, 0.0), at + a3 * 0.1 + Vector3(0.0, 0.85, 0.0), 0.04, L.METAL, Color(0.5, 0.15, 0.1))
		_b.segment(at + a3 * 0.1 + Vector3(0.0, 0.85, 0.0), at + a3 * 0.5 + Vector3(0.0, 0.4, 0.0), 0.04, L.METAL, Color(0.5, 0.15, 0.1))
		_b.box(at + a3 * -0.55 + Vector3(0.0, 0.33, 0.0), _oriented(a3, Vector3(0.65, 0.65, 0.03)), L.RUBBLE, Color(0.03, 0.03, 0.03), false)
	elif roll < 0.8:
		# Traffic cones and a plastic barrier.
		for k: int in _rng.randi_range(1, 3):
			var cone_at: Vector3 = at + a3 * _rng.randf_range(-1.2, 1.2) + n3 * _rng.randf_range(-0.4, 0.4)
			var fallen: bool = _rng.randf() < 0.3
			_b.box(cone_at + Vector3(0.0, 0.12 if fallen else 0.35, 0.0), Vector3(0.22, 0.7, 0.22), L.RUBBLE, Color(0.75, 0.3, 0.06), false, false,
					_rng.randf_range(0.0, 90.0), Vector3(90.0 if fallen else 0.0, 0.0, 0.0))
			_b.box(cone_at + Vector3(0.0, 0.02, 0.0), Vector3(0.38, 0.04, 0.38), L.RUBBLE, Color(0.7, 0.28, 0.05), false)
	elif roll < 0.9:
		# An abandoned shopping cart.
		_b.box(at + Vector3(0.0, 0.65, 0.0), _oriented(a3, Vector3(0.9, 0.5, 0.55)), L.METAL, Color(0.5, 0.52, 0.52), false, false, _rng.randf_range(-20.0, 20.0))
		_b.box(at + Vector3(0.0, 0.2, 0.0), _oriented(a3, Vector3(0.8, 0.05, 0.5)), L.METAL, Color(0.4, 0.42, 0.42), false)
		_b.box(at + Vector3(0.0, 0.7, 0.0), Vector3(0.4, 0.3, 0.35), L.RUBBLE, Color(0.06, 0.06, 0.06), false)
	else:
		# A concrete planter with something long dead in it.
		_b.box(at + Vector3(0.0, 0.35, 0.0), Vector3(1.0, 0.7, 1.0), L.CONCRETE, CityBuilder.COLOR_CONCRETE * 0.75, true)
		_b.box(at + Vector3(0.0, 0.72, 0.0), Vector3(0.85, 0.04, 0.85), L.EARTH, Color(0.12, 0.1, 0.07), false)
		for k: int in 4:
			_b.box(at + Vector3(0.0, 0.95, 0.0), Vector3(0.04, 0.5, 0.15), L.EARTH, Color(0.25, 0.2, 0.1), false, false, k * 45.0,
					Vector3(_rng.randf_range(-40.0, 40.0), 0.0, _rng.randf_range(-40.0, 40.0)))


func _dead_tree(at: Vector3) -> void:
	var bark := Color(0.14, 0.12, 0.1)
	var height: float = _rng.randf_range(4.0, 6.0)
	_b.box(at + Vector3(0.0, height * 0.5, 0.0), Vector3(0.22, height, 0.22), L.RUBBLE, bark, true)
	# Iron grate around the root.
	_b.box(at + Vector3(0.0, 0.015, 0.0), Vector3(1.3, 0.02, 1.3), L.METAL, Color(0.08, 0.08, 0.08), false)
	for i: int in _rng.randi_range(4, 7):
		var start: Vector3 = at + Vector3(0.0, _rng.randf_range(height * 0.45, height * 0.95), 0.0)
		var dir := Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(0.4, 1.0), _rng.randf_range(-1.0, 1.0)).normalized()
		var tip: Vector3 = start + dir * _rng.randf_range(1.0, 2.2)
		_b.segment(start, tip, 0.08, L.RUBBLE, bark)
		for twig: int in 2:
			var twig_dir: Vector3 = (dir + Vector3(_rng.randf_range(-0.7, 0.7), _rng.randf_range(0.0, 0.6), _rng.randf_range(-0.7, 0.7))).normalized()
			_b.segment(tip, tip + twig_dir * _rng.randf_range(0.4, 0.9), 0.04, L.RUBBLE, bark)


# --- Atmosphere (M9) ---------------------------------------------------------------

func _atmosphere(root: Node3D, level: Node3D) -> void:
	var splashes := RainSplashes.new()
	splashes.level = level
	root.add_child(splashes)
	for entry: Array in [["MERIDIAN  ·  LISTEN TO THE FUTURE", Vector3(30.0, 6.8, -3.08), 180.0, Color(0.25, 0.85, 1.0), Vector2(4.6, 2.4)],
			["RESONANCE IS PEACE", Vector3(10.0, 7.2, 55.92), 180.0, Color(1.0, 0.35, 0.75), Vector2(4.0, 2.2)],
			["EVACUATION CANCELLED  ·  STAY INDOORS", Vector3(45.92, 8.0, -80.0), -90.0, Color(1.0, 0.45, 0.2), Vector2(5.0, 2.6)]]:
		var screen := HologramScreen.new()
		screen.text = str(entry[0])
		screen.position = entry[1]
		screen.rotation_degrees.y = float(entry[2])
		screen.colour = entry[3]
		screen.size = entry[4]
		root.add_child(screen)
	# The Echo creeping out from the foot of the tower, across the plaza and up its walls.
	var veins: Array[Transform3D] = []
	var tower := Vector2(0.0, -92.0)
	for strand: int in 34:
		var angle: float = _rng.randf() * TAU
		var p: Vector2 = tower + Vector2(cos(angle), sin(angle)) * 12.6
		var heading: float = angle
		for step: int in _rng.randi_range(6, 18):
			heading += _rng.randf_range(-0.5, 0.5)
			var length: float = _rng.randf_range(0.5, 1.1)
			var next: Vector2 = p + Vector2(cos(heading), sin(heading)) * length
			if (absf(next.x) < 9.5 and next.y > -100.5 and next.y < -83.5) or _in_hole(next.x, next.y) or next.y < -103.0 or next.y > -61.0 or next.x < -33.0 or next.x > 45.0:
				break
			var mid: Vector2 = (p + next) * 0.5
			var basis := Basis(Vector3.UP, -heading + PI * 0.5) * Basis.from_scale(Vector3(_rng.randf_range(0.06, 0.16), 0.02, length))
			veins.append(Transform3D(basis, Vector3(mid.x, 0.025, mid.y)))
			p = next
	for face: Array in [[Vector3(-9.17, 0.0, -92.0), Vector3(0, 0, 1)], [Vector3(9.17, 0.0, -92.0), Vector3(0, 0, 1)], [Vector3(0.0, 0.0, -83.83), Vector3(1, 0, 0)]]:
		for strand: int in 9:
			var x: float = _rng.randf_range(-7.0, 7.0)
			if absf(x) < 2.0 and (face[1] as Vector3).x > 0.5:
				x += 4.0 * signf(x + 0.01)  # keep clear of the door
			var y: float = 0.0
			for step: int in _rng.randi_range(3, 9):
				var rise: float = _rng.randf_range(0.4, 0.9)
				var at: Vector3 = (face[0] as Vector3) + (face[1] as Vector3) * x + Vector3(0.0, y + rise * 0.5, 0.0)
				veins.append(Transform3D(Basis.from_scale(Vector3(0.05, rise + 0.04, 0.05)), at))
				y += rise
				x += _rng.randf_range(-0.12, 0.12)
	root.add_child(GlowVeins.make(veins))
	root.add_child(CityFX.motes(Vector3(0.0, 3.0, -88.0), Vector3(16.0, 3.0, 14.0), 70))
	for ghost: EchoGhost in EchoGhost.from_data("dead_city"):
		root.add_child(ghost)
	_details(root, level)


# --- More life (M10) ------------------------------------------------------------------

func _details(root: Node3D, level: Node3D) -> void:
	var papers := BlowingPaper.new()
	papers.level = level
	root.add_child(papers)
	# Crows: some on the roof edges, some picking at the street.
	for i: int in 4:
		var facade: Array = FACADES[_rng.randi() % FACADES.size()]
		var along: float = _rng.randf_range(0.2, 0.8)
		var at2: Vector2 = (facade[0] as Vector2).lerp(facade[1], along) - (facade[2] as Vector2) * 0.15
		var roof := Crows.new()
		roof.on_ground = false
		roof.count = _rng.randi_range(3, 5)
		roof.spread = 1.8
		roof.position = Vector3(at2.x, float(facade[3]) + 0.02, at2.y)
		var edge: Vector2 = (facade[1] as Vector2) - (facade[0] as Vector2)
		roof.rotation.y = atan2(-edge.y, edge.x)
		root.add_child(roof)
	var placed: int = 0
	var tries: int = 0
	while placed < 6 and tries < 200:
		tries += 1
		var street: Rect2 = STREETS[_rng.randi() % STREETS.size()]
		var x: float = _rng.randf_range(street.position.x + 2.0, street.end.x - 2.0)
		var z: float = _rng.randf_range(street.position.y + 2.0, street.end.y - 2.0)
		if _in_hole(x, z) or _near_keep_clear(x, z, 2.0):
			continue
		var ground := Crows.new()
		ground.count = _rng.randi_range(2, 4)
		ground.spread = 1.2
		ground.position = Vector3(x, 0.0, z)
		root.add_child(ground)
		placed += 1
	# Abandoned cars with their hazard lights still going.
	for car: Array in [[14.0, -66.0, 70.0], [-6.0, 52.5, -96.0], [2.5, 30.0, 8.0], [-39.0, 8.0, 4.0]]:
		var basis := Basis(Vector3.UP, deg_to_rad(float(car[2])))
		var at := Vector3(float(car[0]), 0.0, float(car[1]))
		var blinker := Blinker.new()
		blinker.period = 1.1
		blinker.duty = 0.5
		blinker.phase = _rng.randf()
		for corner: Vector3 in [Vector3(-0.78, 0.68, 2.16), Vector3(0.78, 0.68, 2.16), Vector3(-0.78, 0.7, -2.16), Vector3(0.78, 0.7, -2.16)]:
			blinker.add_child(CityFX.glow_bulb(at + basis * corner, Color(1.0, 0.55, 0.1), 0.06))
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.55, 0.15)
		light.light_energy = 0.6
		light.omni_range = 4.5
		light.position = at + Vector3(0.0, 0.9, 0.0)
		blinker.add_child(light)
		root.add_child(blinker)
