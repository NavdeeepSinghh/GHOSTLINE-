class_name FacilityDressing
extends RefCounted
## Set dressing for the Underground Facility. Each room gets furniture along
## its walls by what it was (labs, offices, bunks, the school room...), the
## corridors get pipes, cable trays and hazard stripes, every level gets its
## sign, and the floors get what people dropped. Effects: monitors still
## glowing, server lights blinking, cables sparking, steam from a split pipe,
## rotating emergency beacons by the stairs, and Echo motes drifting in the
## lower levels and the Chamber.
##
## Furniture against walls is solid but keeps clear of doorways and of every
## pickup and panel; loose clutter is visual only. The Chamber platform where
## the Choir is fought is left empty.

const L := CityBuilder.Look
const Y: Array[float] = [0.0, -6.0, -12.0, -18.0]
const STEEL := Color(0.38, 0.4, 0.42)
const DARK := Color(0.12, 0.13, 0.14)
const DESK := Color(0.42, 0.4, 0.36)
const SCREEN_COLOR := Color(0.35, 0.95, 0.75)
const HAZARD := Color(0.75, 0.6, 0.08)

## Usables, doors and stairs nothing solid may cover: [x, z, level index, radius].
const KEEP_CLEAR: Array = [
	[3.0, 0.0, 0, 3.0], [9.5, 1.0, 0, 1.5], [34.0, 13.6, 0, 1.6], [33.0, -11.6, 0, 1.8], [32.0, 12.4, 0, 1.6], [20.0, 12.0, 0, 1.2],
	[40.0, 0.0, 0, 3.0], [27.0, 10.0, 0, 1.8], [27.0, -10.0, 0, 1.8], [5.0, 12.6, 0, 1.2], [37.0, -8.0, 0, 1.2],
	[52.0, 0.0, 1, 3.0], [92.0, 0.0, 1, 3.0], [63.0, 3.0, 1, 1.8], [81.0, 3.0, 1, 1.8], [63.0, -3.0, 1, 1.8], [81.0, -3.0, 1, 1.8],
	[65.5, -13.0, 1, 1.4], [79.5, -13.0, 1, 1.4], [63.0, 14.2, 1, 1.6], [80.0, 13.2, 1, 1.6], [85.7, -13.5, 1, 1.8], [90.6, 1.9, 1, 1.4],
	[58.0, -5.0, 1, 1.2], [86.0, 5.0, 1, 1.2], [76.0, -13.0, 1, 1.2], [72.0, 1.5, 1, 1.2],
	[104.0, 0.0, 2, 3.0], [144.0, 0.0, 2, 3.0], [114.0, 3.0, 2, 1.8], [120.0, 9.0, 2, 1.8], [131.0, 3.0, 2, 1.8], [124.0, 9.0, 2, 1.8],
	[114.0, -3.0, 2, 1.8], [131.0, -3.0, 2, 1.8], [113.0, 13.2, 2, 1.6], [131.0, 13.2, 2, 1.6], [113.0, -13.3, 2, 1.6], [117.0, -13.3, 2, 1.6],
	[135.0, -8.0, 2, 1.4], [131.0, 12.2, 2, 1.6], [142.6, 1.9, 2, 1.6], [115.6, -1.9, 2, 1.4], [118.0, 5.0, 2, 1.2], [136.0, -13.0, 2, 1.2],
	[122.0, 0.0, 2, 3.5],
	[156.0, 0.0, 3, 3.0], [161.1, 9.6, 3, 2.0], [157.5, -9.5, 3, 1.6], [158.5, 13.0, 3, 1.2], [158.0, 5.0, 3, 1.2],
]

## Rooms: [x0, z0, x1, z1, level, kind, doors as [side, position]].
const ROOMS: Array = [
	[27.0, 6.0, 39.7, 14.7, 0, "security", [["w", 10.0]]],
	[27.0, -14.7, 39.7, -6.0, 0, "generators", [["w", -10.0]]],
	[56.0, 3.0, 70.0, 14.7, 1, "school", [["n", 63.0]]],
	[74.0, 3.0, 88.0, 14.7, 1, "common", [["n", 81.0]]],
	[56.0, -14.7, 70.0, -3.0, 1, "bunks", [["s", 63.0]]],
	[74.0, -14.7, 88.0, -3.0, 1, "bunks", [["s", 81.0]]],
	[108.0, 3.0, 120.0, 14.7, 2, "lab", [["n", 114.0], ["e", 9.0]]],
	[124.0, 3.0, 138.0, 14.7, 2, "lab", [["n", 131.0], ["w", 9.0]]],
	[108.0, -14.7, 120.0, -3.0, 2, "office", [["s", 114.0]]],
	[124.0, -14.7, 138.0, -3.0, 2, "storage", [["s", 131.0]]],
]

var _b: CityBuilder
var _rng := RandomNumberGenerator.new()
var _screens: Array[Vector3] = []
var _server_lights: Array[Array] = []
var _sparks: Array[Vector3] = []
var _static_spots: Array[Array] = []
var _ghost_spots: Array[Array] = []
var _drip_spots: Array[Vector3] = []


func build(builder: CityBuilder) -> void:
	_b = builder
	_rng.seed = 3109
	for room: Array in ROOMS:
		_dress_room(room)
	_reception()
	_corridors()
	_signs()
	_chamber_edges()
	for level: int in 3:
		_floor_clutter(level)
	_fixtures()


func build_effects(parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "Atmosphere"
	parent.add_child(root)
	var scale: float = CityFX.amount_scale()
	for at: Vector3 in _screens:
		var light := OmniLight3D.new()
		light.position = at
		light.light_color = SCREEN_COLOR
		light.light_energy = 0.35
		light.omni_range = 2.2
		light.distance_fade_enabled = true
		light.distance_fade_begin = 30.0
		light.distance_fade_length = 8.0
		root.add_child(light)
	for entry: Array in _server_lights:
		var blinker := Blinker.new()
		blinker.position = entry[0]
		blinker.period = _rng.randf_range(0.4, 1.6)
		blinker.duty = _rng.randf_range(0.3, 0.8)
		blinker.phase = _rng.randf() * 2.0
		blinker.add_child(CityFX.glow_bulb(Vector3.ZERO, entry[1], 0.025, 5.0))
		root.add_child(blinker)
	for at: Vector3 in _sparks:
		root.add_child(SparkEmitter.make(at))
	root.add_child(CityFX.steam(Vector3(70.0, Y[1] + 3.4, -2.4), int(12 * scale)))
	root.add_child(CityFX.steam(Vector3(128.0, Y[2] + 3.4, 2.4), int(12 * scale)))
	# On the stairwell ceilings, just past each top step.
	for at: Vector3 in [Vector3(41.5, Y[0] + 3.7, 1.4), Vector3(93.5, Y[1] + 3.7, 1.4), Vector3(145.5, Y[2] + 3.7, 1.4)]:
		root.add_child(_rotating_beacon(at))
	root.add_child(_motes(Vector3(124.0, Y[2] + 2.0, 0.0), Vector3(20.0, 2.0, 14.0), 40))
	for spot: Array in _static_spots:
		root.add_child(CityFX.static_screen(spot[0], float(spot[1])))
	for ghost: EchoGhost in EchoGhost.from_data("facility", _ghost_spots):
		root.add_child(ghost)
	# Leaks: through the missing ceiling tiles, and a few along the corridors.
	for level: int in [1, 2]:
		for k: int in 2:
			_drip_spots.append(Vector3((54.0 if level == 1 else 106.0) + 8.0 + k * 16.0 + _rng.randf_range(-1.0, 1.0), Y[level], -0.9))
	for spot: Vector3 in _drip_spots:
		var drip := Drip.new()
		drip.position = spot
		drip.drop_height = 3.9
		root.add_child(drip)
	for entry: Array in [["WELCOME  ·  THE FUTURE IS LISTENING", Vector3(0.12, 2.4, 0.0), 90.0, Vector2(5.0, 2.2)],
			["RESONANCE TRIAL 7  ·  COHERENCE 98%", Vector3(114.0, Y[2] + 2.5, 14.55), 180.0, Vector2(3.2, 1.6)]]:
		var screen := HologramScreen.new()
		screen.text = str(entry[0])
		screen.position = entry[1]
		screen.rotation_degrees.y = float(entry[2])
		screen.size = entry[3]
		root.add_child(screen)
	root.add_child(CityFX.mist(Vector3(176.0, Y[3] + 0.9, 0.0), Vector3(36.0, 2.4, 30.0), 0.3, Color(0.6, 0.9, 1.0), Color(0.03, 0.14, 0.18)))
	root.add_child(_motes(Vector3(174.0, Y[3] + 5.0, -4.0), Vector3(18.0, 6.0, 20.0), 90))


func _clear(x: float, z: float, level: int, extra: float = 0.0) -> bool:
	for spot: Array in KEEP_CLEAR:
		if int(spot[2]) == level and Vector2(x - float(spot[0]), z - float(spot[1])).length() < float(spot[3]) + extra:
			return false
	return true


# --- Rooms ----------------------------------------------------------------------

func _dress_room(room: Array) -> void:
	var x0: float = room[0]
	var z0: float = room[1]
	var x1: float = room[2]
	var z1: float = room[3]
	var level: int = room[4]
	var kind: String = room[5]
	var y: float = Y[level]
	var doors: Array = room[6]
	# Walk each wall: [start, end, inward normal, side name].
	var walls: Array = [
		[Vector2(x0 + 0.6, z0 + 0.25), Vector2(x1 - 0.6, z0 + 0.25), Vector2(0, 1), "n"],
		[Vector2(x0 + 0.6, z1 - 0.25), Vector2(x1 - 0.6, z1 - 0.25), Vector2(0, -1), "s"],
		[Vector2(x0 + 0.25, z0 + 0.6), Vector2(x0 + 0.25, z1 - 0.6), Vector2(1, 0), "w"],
		[Vector2(x1 - 0.25, z0 + 0.6), Vector2(x1 - 0.25, z1 - 0.6), Vector2(-1, 0), "e"],
	]
	for wall: Array in walls:
		var a: Vector2 = wall[0]
		var b: Vector2 = wall[1]
		var inward: Vector2 = wall[2]
		var length: float = a.distance_to(b)
		var along: Vector2 = (b - a) / length
		var t: float = 0.6
		while t < length - 0.6:
			var p: Vector2 = a + along * t
			var blocked: bool = false
			for door: Array in doors:
				if str(door[0]) == str(wall[3]):
					var door_at: float = float(door[1])
					var coord: float = p.x if str(wall[3]) in ["n", "s"] else p.y
					if absf(coord - door_at) < 2.0:
						blocked = true
			if blocked or not _clear(p.x, p.y, level, 0.6):
				t += 0.8
				continue
			t += _wall_piece(kind, Vector3(p.x, y, p.y), inward, along, level)
		# Clutter in the middle of the room.
	for i: int in _rng.randi_range(3, 7):
		var at := Vector3(_rng.randf_range(x0 + 1.5, x1 - 1.5), y, _rng.randf_range(z0 + 1.5, z1 - 1.5))
		_loose(at, kind)


## Places one piece of wall furniture and returns how far along the wall it took.
func _wall_piece(kind: String, base: Vector3, inward: Vector2, along: Vector2, level: int) -> float:
	var n3 := Vector3(inward.x, 0.0, inward.y)
	var a3 := Vector3(along.x, 0.0, along.y)
	var roll: float = _rng.randf()
	match kind:
		"lab":
			if roll < 0.55:
				_bench(base, n3, a3, 1.8, true)
				return 1.9
			elif roll < 0.8:
				_rack(base, n3, a3)
				return 0.9
			return 1.2
		"storage":
			if roll < 0.7:
				_rack(base, n3, a3)
				return 0.85
			_shelf(base, n3, a3)
			return 1.3
		"security", "office":
			if roll < 0.5:
				_bench(base, n3, a3, 1.6, roll < 0.35)
				return 1.8
			elif roll < 0.75:
				_cabinet(base, n3, a3)
				return 0.8
			return 1.0
		"bunks":
			if roll < 0.6:
				_locker(base, n3, a3)
				return 0.7
			return 1.4
		"school":
			if roll < 0.45:
				_drawing(base, n3, a3)
				return 1.2
			elif roll < 0.6:
				_shelf(base, n3, a3)
				return 1.4
			return 1.0
		"common":
			if roll < 0.35:
				_shelf(base, n3, a3)
				return 1.4
			elif roll < 0.55:
				_cabinet(base, n3, a3)
				return 0.9
			return 1.2
		"generators":
			if roll < 0.5:
				_cabinet(base, n3, a3, Color(0.3, 0.3, 0.2))
				return 0.9
			return 1.2
	return 1.2


func _oriented(along3: Vector3, size: Vector3) -> Vector3:
	return Vector3(absf(along3.x) * size.x + absf(along3.z) * size.z, size.y, absf(along3.z) * size.x + absf(along3.x) * size.z)


func _bench(base: Vector3, n3: Vector3, a3: Vector3, width: float, monitor: bool) -> void:
	var top: Vector3 = base + n3 * 0.38 + Vector3(0.0, 0.88, 0.0)
	_b.box(top, _oriented(a3, Vector3(width, 0.06, 0.75)), L.METAL, DESK, true)
	_b.box(top + Vector3(0.0, -0.45, 0.0) - n3 * 0.2, _oriented(a3, Vector3(width * 0.95, 0.85, 0.3)), L.METAL, DESK * 0.7, false)
	if monitor:
		var screen_at: Vector3 = top + Vector3(0.0, 0.3, 0.0) - n3 * 0.15
		_b.box(screen_at, _oriented(a3, Vector3(0.6, 0.4, 0.05)), L.METAL, DARK, false)
		if _rng.randf() < 0.6:
			_b.strip(screen_at + n3 * 0.03, _oriented(a3, Vector3(0.52, 0.32, 0.01)), SCREEN_COLOR)
			_screens.append(screen_at + n3 * 0.5)
		elif _static_spots.size() < 14 and _rng.randf() < 0.6:
			_static_spots.append([screen_at + n3 * 0.035, rad_to_deg(atan2(n3.x, n3.z))])
			if _ghost_spots.size() < 3 and _rng.randf() < 0.5:
				_ghost_spots.append([base + n3 * 1.15, rad_to_deg(atan2(-n3.x, -n3.z))])
		else:
			_b.box(screen_at + n3 * 0.03, _oriented(a3, Vector3(0.52, 0.32, 0.01)), L.METAL, Color(0.02, 0.03, 0.03), false)
	for i: int in _rng.randi_range(1, 4):
		var item: Vector3 = top + a3 * _rng.randf_range(-width * 0.4, width * 0.4) + n3 * _rng.randf_range(0.0, 0.2) + Vector3(0.0, 0.08, 0.0)
		if _rng.randf() < 0.5:
			_b.box(item, Vector3(0.22, 0.01, 0.3), L.INTERIOR, Color(0.75, 0.74, 0.7), false, false, _rng.randf_range(0.0, 90.0))
		else:
			_b.box(item + Vector3(0.0, 0.05, 0.0), Vector3(0.08, 0.16, 0.08), L.PANEL, Color(0.5, 0.65, 0.68), false)


func _rack(base: Vector3, n3: Vector3, a3: Vector3) -> void:
	var centre: Vector3 = base + n3 * 0.42 + Vector3(0.0, 1.0, 0.0)
	_b.box(centre, _oriented(a3, Vector3(0.7, 2.0, 0.8)), L.METAL, DARK, true)
	var face: Vector3 = centre + n3 * 0.41
	for row: int in 8:
		_b.box(face + Vector3(0.0, -0.8 + row * 0.22, 0.0), _oriented(a3, Vector3(0.6, 0.12, 0.02)), L.METAL, Color(0.2, 0.21, 0.22), false)
		if _rng.randf() < 0.55:
			var color: Color = [Color(0.2, 1.0, 0.4), Color(0.2, 1.0, 0.4), Color(1.0, 0.6, 0.1), Color(1.0, 0.15, 0.1)][_rng.randi() % 4]
			_server_lights.append([face + n3 * 0.02 + a3 * _rng.randf_range(-0.22, 0.22) + Vector3(0.0, -0.8 + row * 0.22, 0.0), color])
	if _rng.randf() < 0.4:
		# Cables spilling out of the back and across the floor.
		var from: Vector3 = centre + Vector3(0.0, 0.9, 0.0)
		_b.segment(from, from + n3 * 1.2 + Vector3(0.0, -1.85, 0.0), 0.03, L.METAL, Color(0.05, 0.05, 0.05))
		_b.segment(from + n3 * 1.2 + Vector3(0.0, -1.85, 0.0), from + n3 * 1.9 + a3 * 0.8 + Vector3(0.0, -1.87, 0.0), 0.03, L.METAL, Color(0.05, 0.05, 0.05))


func _cabinet(base: Vector3, n3: Vector3, a3: Vector3, color: Color = Color(0.32, 0.34, 0.36)) -> void:
	var height: float = _rng.randf_range(1.1, 1.5)
	_b.box(base + n3 * 0.3 + Vector3(0.0, height * 0.5, 0.0), _oriented(a3, Vector3(0.7, height, 0.55)), L.METAL, color, true)
	for d: int in 3:
		_b.box(base + n3 * 0.58 + Vector3(0.0, 0.25 + d * height / 3.0, 0.0), _oriented(a3, Vector3(0.12, 0.03, 0.03)), L.METAL, DARK, false)
	if _rng.randf() < 0.3:
		# A drawer hanging open, papers spilling.
		_b.box(base + n3 * 0.8 + Vector3(0.0, 0.6, 0.0), _oriented(a3, Vector3(0.6, 0.25, 0.5)), L.METAL, color * 0.9, false)
		_b.box(base + n3 * 1.3 + Vector3(0.0, 0.01, 0.0), Vector3(0.6, 0.01, 0.5), L.INTERIOR, Color(0.75, 0.74, 0.7), false, false, _rng.randf_range(0.0, 90.0))


func _locker(base: Vector3, n3: Vector3, a3: Vector3) -> void:
	_b.box(base + n3 * 0.28 + Vector3(0.0, 0.95, 0.0), _oriented(a3, Vector3(0.6, 1.9, 0.5)), L.METAL, Color(0.24, 0.3, 0.34) * _rng.randf_range(0.85, 1.1), true)
	_b.box(base + n3 * 0.54 + Vector3(0.0, 1.6, 0.0), _oriented(a3, Vector3(0.4, 0.08, 0.02)), L.METAL, DARK, false)
	if _rng.randf() < 0.3:
		# Door hanging open.
		_b.box(base + n3 * 0.8 + a3 * 0.3 + Vector3(0.0, 0.95, 0.0), _oriented(a3, Vector3(0.03, 1.8, 0.55)), L.METAL, Color(0.24, 0.3, 0.34), false)


func _shelf(base: Vector3, n3: Vector3, a3: Vector3) -> void:
	_b.box(base + n3 * 0.22 + Vector3(0.0, 0.9, 0.0), _oriented(a3, Vector3(1.2, 1.8, 0.4)), L.INTERIOR, Color(0.3, 0.26, 0.2), true)
	for s: int in 4:
		for item: int in _rng.randi_range(1, 4):
			var at: Vector3 = base + n3 * 0.25 + a3 * _rng.randf_range(-0.5, 0.5) + Vector3(0.0, 0.2 + s * 0.45 + 0.12, 0.0)
			_b.box(at + n3 * 0.2, Vector3(0.12, 0.22, 0.1) * _rng.randf_range(0.7, 1.3), L.INTERIOR,
					[Color(0.5, 0.2, 0.15), Color(0.2, 0.3, 0.45), Color(0.6, 0.55, 0.4), Color(0.25, 0.4, 0.25)][_rng.randi() % 4], false)


func _drawing(base: Vector3, n3: Vector3, a3: Vector3) -> void:
	# Children's drawings pinned to the wall.
	for i: int in _rng.randi_range(1, 3):
		var at: Vector3 = base + n3 * 0.03 + a3 * _rng.randf_range(-0.5, 0.5) + Vector3(0.0, _rng.randf_range(1.0, 1.7), 0.0)
		_b.box(at, _oriented(a3, Vector3(0.42, 0.3, 0.01)), L.INTERIOR, Color(0.85, 0.83, 0.78), false)
		var mark: Color = [Color(0.8, 0.3, 0.2), Color(0.25, 0.45, 0.8), Color(0.9, 0.75, 0.2), Color(0.3, 0.7, 0.35)][_rng.randi() % 4]
		_b.box(at + n3 * 0.01 + Vector3(0.0, _rng.randf_range(-0.08, 0.08), 0.0), _oriented(a3, Vector3(_rng.randf_range(0.1, 0.3), 0.08, 0.005)), L.INTERIOR, mark, false)


func _loose(at: Vector3, kind: String) -> void:
	var roll: float = _rng.randf()
	if roll < 0.35:
		# A chair on its side.
		_b.box(at + Vector3(0.0, 0.25, 0.0), Vector3(0.45, 0.06, 0.45), L.METAL, DARK, false, false, _rng.randf_range(0.0, 90.0), Vector3(85.0, 0.0, 0.0))
		_b.box(at + Vector3(0.2, 0.22, 0.0), Vector3(0.05, 0.45, 0.4), L.METAL, DARK, false, false, _rng.randf_range(0.0, 90.0))
	elif roll < 0.7:
		for p: int in _rng.randi_range(2, 6):
			_b.box(at + Vector3(_rng.randf_range(-0.8, 0.8), 0.006, _rng.randf_range(-0.8, 0.8)), Vector3(0.22, 0.004, 0.3), L.INTERIOR,
					Color(0.78, 0.77, 0.72) * _rng.randf_range(0.8, 1.0), false, false, _rng.randf_range(0.0, 180.0))
	elif kind in ["lab", "storage", "office"]:
		# Broken glass.
		for g: int in 6:
			_b.box(at + Vector3(_rng.randf_range(-0.5, 0.5), 0.005, _rng.randf_range(-0.5, 0.5)), Vector3(0.1, 0.004, 0.07), L.PANEL,
					Color(0.7, 0.8, 0.82), false, false, _rng.randf_range(0.0, 180.0))
	elif kind in ["school", "common", "bunks"]:
		# A blanket or a child's thing left behind.
		_b.box(at + Vector3(0.0, 0.03, 0.0), Vector3(1.0, 0.05, 0.7), L.INTERIOR, [Color(0.45, 0.2, 0.2), Color(0.2, 0.3, 0.4), Color(0.4, 0.38, 0.25)][_rng.randi() % 3],
				false, false, _rng.randf_range(0.0, 180.0))


# --- Shared spaces ----------------------------------------------------------------

func _reception() -> void:
	# Waiting chairs in rows, a dead plant, a fallen ceiling panel.
	for row: float in [-7.0, 7.0]:
		for i: int in 5:
			var at := Vector3(14.0 + i * 0.7, 0.0, row)
			_b.box(at + Vector3(0.0, 0.45, 0.0), Vector3(0.55, 0.06, 0.5), L.PANEL, Color(0.3, 0.42, 0.48), false)
			_b.box(at + Vector3(0.0, 0.75, -0.24 * signf(row)), Vector3(0.55, 0.55, 0.06), L.PANEL, Color(0.3, 0.42, 0.48), false)
		_b.collider(Vector3(15.4, 0.4, row), Vector3(3.6, 0.8, 0.6))
	for plant: Vector3 in [Vector3(1.0, 0.0, -14.0), Vector3(1.0, 0.0, 14.0), Vector3(25.5, 0.0, 14.0)]:
		_b.box(plant + Vector3(0.0, 0.3, 0.0), Vector3(0.5, 0.6, 0.5), L.PANEL, Color(0.5, 0.5, 0.48), true)
		for leaf: int in 5:
			_b.box(plant + Vector3(0.0, 0.85, 0.0), Vector3(0.05, 0.6, 0.18), L.EARTH, Color(0.28, 0.24, 0.12), false, false, leaf * 36.0,
					Vector3(_rng.randf_range(-35.0, 35.0), 0.0, _rng.randf_range(-35.0, 35.0)))
	_b.box(Vector3(18.0, 0.15, 3.5), Vector3(2.0, 0.05, 1.2), L.PANEL, Color(0.55, 0.56, 0.56), false, false, 20.0, Vector3(14.0, 0.0, 0.0))
	_b.box(Vector3(18.0, 3.9, 4.0), Vector3(2.0, 0.02, 1.2), L.PANEL, Color(0.02, 0.02, 0.02), false)
	_sparks.append(Vector3(18.0, 3.85, 4.0))


func _corridors() -> void:
	# Pipes and cable trays along the ceilings of Levels 2 and 3, and the edges of the hall.
	for level: int in [1, 2]:
		var y: float = Y[level]
		var x0: float = 52.0 if level == 1 else 104.0
		var x1: float = 92.0 if level == 1 else 144.0
		for side: float in [-1.0, 1.0]:
			var z: float = 2.55 * side
			_b.box(Vector3((x0 + x1) * 0.5, y + 3.6, z), Vector3(x1 - x0, 0.22, 0.22), L.METAL, Color(0.3, 0.32, 0.3), false)
			_b.box(Vector3((x0 + x1) * 0.5, y + 3.3, z - 0.15 * side), Vector3(x1 - x0, 0.12, 0.12), L.METAL, Color(0.45, 0.2, 0.12), false)
			_b.box(Vector3((x0 + x1) * 0.5, y + 3.85, z * 0.6), Vector3(x1 - x0, 0.05, 0.5), L.METAL, Color(0.25, 0.26, 0.27), false)
		# Hazard stripes either side of each stairwell door.
		for door_x: float in [x0, x1]:
			for s: int in 5:
				_b.box(Vector3(door_x + (1.0 if door_x == x0 else -1.0) * 0.6, y + 0.006, -1.2 + s * 0.6), Vector3(0.4, 0.008, 0.25), L.METAL,
						HAZARD if s % 2 == 0 else DARK, false, false, 0.0)
		# A section of cable tray has come down and is sparking.
		var fallen_x: float = x0 + (x1 - x0) * 0.62
		_b.segment(Vector3(fallen_x, y + 3.6, 2.4), Vector3(fallen_x + 1.5, y + 0.3, 1.4), 0.08, L.METAL, Color(0.25, 0.26, 0.27))
		_sparks.append(Vector3(fallen_x, y + 3.5, 2.3))
	for side: float in [-1.0, 1.0]:
		_b.box(Vector3(20.0, 3.6, 14.4 * side), Vector3(40.0, 0.22, 0.22), L.METAL, Color(0.3, 0.32, 0.3), false)
	# Stairwells: handrails and stripes on the top step.
	for x: float in [40.0, 92.0, 144.0]:
		var top_y: float = Y[[40.0, 92.0, 144.0].find(x)]
		for side: float in [-1.0, 1.0]:
			_b.segment(Vector3(x, top_y + 1.0, 1.55 * side), Vector3(x + 12.0, top_y - 5.0, 1.55 * side), 0.05, L.METAL, HAZARD * 0.8)
		for s: int in 6:
			_b.box(Vector3(x + 0.3, top_y + 0.01, -1.4 + s * 0.56), Vector3(0.3, 0.01, 0.28), L.METAL, HAZARD if s % 2 == 0 else DARK, false)


func _signs() -> void:
	var paint := Color(0.2, 0.22, 0.24)
	_b.sign_text("LEVEL 1  ·  RECEPTION AND SECURITY", Vector3(39.9, 3.0, -4.0), -90.0, 0.55, paint)
	_b.sign_text("STAIRS DOWN  ·  LEVEL 2", Vector3(39.9, 2.6, 3.4), -90.0, 0.45, Color(0.6, 0.45, 0.05))
	_b.sign_text("LEVEL 2  ·  RESIDENTIAL", Vector3(52.1, Y[1] + 3.0, -2.2), 90.0, 0.55, paint)
	_b.sign_text("CLASSROOM", Vector3(63.0, Y[1] + 2.7, 2.9), 180.0, 0.4, paint)
	_b.sign_text("COMMON ROOM", Vector3(81.0, Y[1] + 2.7, 2.9), 180.0, 0.4, paint)
	_b.sign_text("DORMITORY A", Vector3(63.0, Y[1] + 2.7, -2.9), 0.0, 0.4, paint)
	_b.sign_text("DORMITORY B", Vector3(81.0, Y[1] + 2.7, -2.9), 0.0, 0.4, paint)
	_b.sign_text("LEVEL 3  ·  RESEARCH", Vector3(104.1, Y[2] + 3.0, -2.2), 90.0, 0.55, Color(0.35, 0.1, 0.08))
	_b.sign_text("RESONANCE LAB A", Vector3(114.0, Y[2] + 2.7, 2.9), 180.0, 0.4, paint)
	_b.sign_text("RESONANCE LAB B", Vector3(131.0, Y[2] + 2.7, 2.9), 180.0, 0.4, paint)
	_b.sign_text("DR. I. VANCE", Vector3(114.0, Y[2] + 2.7, -2.9), 0.0, 0.4, paint)
	_b.sign_text("RESONANCE CHAMBER\nAUTHORISED PERSONNEL ONLY", Vector3(143.9, Y[2] + 3.0, -2.6), -90.0, 0.4, Color(0.35, 0.1, 0.08))


func _chamber_edges() -> void:
	# Only the margins: the platform itself is the arena.
	var y: float = Y[3]
	for z: float in [-13.6, -12.8, -6.5, -5.7, -4.9]:
		_rack(Vector3(156.25, y, z), Vector3(1, 0, 0), Vector3(0, 0, 1))
	# Thick cables running from the wall to the heart's pit.
	for z: float in [-6.0, 6.0]:
		_b.segment(Vector3(156.3, y + 0.15, z), Vector3(162.0, y + 0.12, z * 0.6), 0.18, L.METAL, Color(0.06, 0.06, 0.07))
		_b.segment(Vector3(162.0, y + 0.12, z * 0.6), Vector3(176.0, y + 0.1, -13.0 + absf(z) * 0.1), 0.18, L.METAL, Color(0.06, 0.06, 0.07))
	# Observation window frame high on the west wall.
	_b.box(Vector3(156.2, y + 7.0, 0.0), Vector3(0.1, 2.0, 8.0), L.METAL, DARK, false)
	_b.strip(Vector3(156.25, y + 7.0, 0.0), Vector3(0.02, 1.7, 7.6), Color(0.1, 0.25, 0.28))


func _floor_clutter(level: int) -> void:
	var y: float = Y[level]
	var x0: float = [0.0, 52.0, 104.0][level]
	for i: int in 24:
		var at := Vector3(_rng.randf_range(x0 + 2.0, x0 + 38.0), y, _rng.randf_range(-2.6, 2.6) if level > 0 else _rng.randf_range(-13.0, 13.0))
		if not _clear(at.x, at.z, level):
			continue
		_b.box(at + Vector3(0.0, 0.006, 0.0), Vector3(0.22, 0.004, 0.3), L.INTERIOR, Color(0.78, 0.77, 0.72) * _rng.randf_range(0.7, 1.0),
				false, false, _rng.randf_range(0.0, 180.0))


func _rotating_beacon(at: Vector3) -> Node3D:
	var root := Node3D.new()
	root.position = at
	root.add_child(CityFX.glow_bulb(Vector3.ZERO, Color(1.0, 0.15, 0.05), 0.12, 3.0))
	var spot := SpotLight3D.new()
	spot.light_color = Color(1.0, 0.15, 0.05)
	spot.light_energy = 4.0
	spot.spot_range = 9.0
	spot.spot_angle = 22.0
	spot.rotation_degrees = Vector3(-35.0, 0.0, 0.0)
	root.add_child(spot)
	var spinner := Spinner.new()
	spinner.target = root
	root.add_child(spinner)
	return root


func _motes(at: Vector3, extents: Vector3, amount: int) -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = extents
	process.direction = Vector3.UP
	process.spread = 180.0
	process.initial_velocity_min = 0.05
	process.initial_velocity_max = 0.25
	process.gravity = Vector3(0.0, 0.08, 0.0)
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 0.6
	process.color_ramp = CityFX._ramp([[0.0, Color(0.27, 0.92, 1.0, 0.0)], [0.3, Color(0.27, 0.92, 1.0, 0.9)], [1.0, Color(0.27, 0.92, 1.0, 0.0)]])
	var particles: GPUParticles3D = CityFX._particles(int(amount * CityFX.amount_scale()), 7.0, process, 0.06, true,
			AABB(-extents * 1.4, extents * 2.8))
	particles.position = at
	return particles


# --- Close-range detail (M8) ------------------------------------------------------

## Walls and ceilings of the shared spaces: EXIT signs, extinguishers, stopped
## clocks, notice boards, ceiling light frames, missing ceiling tiles with
## wires hanging through, a water cooler, carts.
func _fixtures() -> void:
	var green := Color(0.2, 0.9, 0.45)
	# Over every stairwell door on both sides.
	for door: Array in [[Vector3(39.9, Y[0] + 2.75, 0.0), -90.0], [Vector3(52.1, Y[1] + 2.75, 0.0), 90.0], [Vector3(91.9, Y[1] + 2.75, 0.0), -90.0],
			[Vector3(104.1, Y[2] + 2.75, 0.0), 90.0], [Vector3(143.9, Y[2] + 2.75, 0.0), -90.0]]:
		var at: Vector3 = door[0]
		var facing: float = float(door[1])
		var out := Vector3(sin(deg_to_rad(facing)), 0.0, cos(deg_to_rad(facing)))
		_b.box(at, Vector3(0.6, 0.25, 0.6) - Vector3(absf(out.x), 0.0, absf(out.z)) * 0.55, L.METAL, DARK, false)
		_b.strip(at + out * 0.03, Vector3(0.5, 0.17, 0.5) - Vector3(absf(out.x), 0.0, absf(out.z)) * 0.48, green)
		_b.sign_text("EXIT", at + out * 0.05, facing, 0.32, Color(0.02, 0.15, 0.05))
	# Fire extinguishers and stopped clocks along the corridors and in reception.
	var walls: Array = [
		[Vector3(8.0, Y[0], -14.85), 0.0], [Vector3(30.0, Y[0], 14.85), 180.0], [Vector3(2.0, Y[0], -6.0), 90.0],
		[Vector3(58.0, Y[1], 2.85), 180.0], [Vector3(76.0, Y[1], -2.85), 0.0], [Vector3(88.0, Y[1], 2.85), 180.0],
		[Vector3(110.0, Y[2], -2.85), 0.0], [Vector3(126.0, Y[2], -2.85), 0.0], [Vector3(140.0, Y[2], 2.85), 180.0],
	]
	for i: int in walls.size():
		var base: Vector3 = walls[i][0]
		var yaw: float = float(walls[i][1])
		var out := Vector3(sin(deg_to_rad(yaw)), 0.0, cos(deg_to_rad(yaw)))
		if i % 2 == 0:
			_b.box(base + out * 0.12 + Vector3(0.0, 0.95, 0.0), Vector3(0.16, 0.5, 0.16), L.METAL, Color(0.6, 0.08, 0.06), false)
			_b.box(base + out * 0.12 + Vector3(0.0, 1.25, 0.0), Vector3(0.06, 0.1, 0.06), L.METAL, DARK, false)
			_b.box(base + out * 0.02 + Vector3(0.0, 1.55, 0.0), Vector3(0.3, 0.3, 0.3) - out.abs() * 0.29, L.PANEL, Color(0.6, 0.1, 0.08), false)
		else:
			var clock: Vector3 = base + out * 0.04 + Vector3(0.0, 2.6, 0.0)
			_b.box(clock, Vector3(0.45, 0.45, 0.45) - out.abs() * 0.41, L.PANEL, Color(0.8, 0.8, 0.76), false)
			_b.box(clock + out * 0.03, Vector3(0.03, 0.17, 0.03) - out.abs() * 0.02, L.METAL, DARK, false, false, 0.0, Vector3(0.0, 0.0, 0.0))
			_b.box(clock + out * 0.03 + Vector3(0.0, 0.0, 0.0), Vector3(0.12, 0.03, 0.12) - out.abs() * 0.11, L.METAL, DARK, false)
		# A notice board next to some of them.
		if i % 3 == 1:
			var board: Vector3 = base + out * 0.03 + Vector3(0.0, 1.6, 0.0) + out.cross(Vector3.UP) * 1.4
			_b.box(board, Vector3(1.2, 0.8, 1.2) - out.abs() * 1.17, L.INTERIOR, Color(0.42, 0.3, 0.18), false)
			for note: int in _rng.randi_range(3, 6):
				var shift: Vector3 = out.cross(Vector3.UP) * _rng.randf_range(-0.45, 0.45) + Vector3(0.0, _rng.randf_range(-0.28, 0.28), 0.0)
				_b.box(board + shift + out * 0.015, Vector3(0.18, 0.22, 0.18) - out.abs() * 0.175, L.INTERIOR,
						[Color(0.85, 0.84, 0.78), Color(0.85, 0.78, 0.45), Color(0.6, 0.75, 0.85)][_rng.randi() % 3], false)
	# Ceiling light frames along the corridors; some tiles gone, wires hanging.
	for level: int in [1, 2]:
		var x0: float = 52.0 if level == 1 else 104.0
		for k: int in 9:
			var x: float = x0 + 3.0 + k * 4.2
			var ceiling: float = Y[level] + 3.96
			if _rng.randf() < 0.22:
				_b.box(Vector3(x, ceiling - 0.01, 0.6), Vector3(1.2, 0.02, 1.2), L.INTERIOR, Color(0.01, 0.01, 0.01), false)
				_drip_spots.append(Vector3(x - 0.35, Y[level], 0.95))
				for w: int in _rng.randi_range(1, 3):
					var top := Vector3(x + _rng.randf_range(-0.4, 0.4), ceiling, 0.6 + _rng.randf_range(-0.4, 0.4))
					var low: Vector3 = top - Vector3(_rng.randf_range(-0.3, 0.3), _rng.randf_range(0.8, 1.6), _rng.randf_range(-0.3, 0.3))
					_b.segment(top, low, 0.02, L.METAL, [Color(0.05, 0.05, 0.05), Color(0.5, 0.1, 0.08), Color(0.6, 0.55, 0.1)][w % 3])
				_b.box(Vector3(x + 0.3, Y[level] + 0.02, 0.2), Vector3(0.6, 0.03, 0.6), L.INTERIOR, Color(0.6, 0.6, 0.58), false, false, _rng.randf_range(0.0, 45.0))
			else:
				_b.box(Vector3(x, ceiling - 0.03, 0.0), Vector3(1.4, 0.05, 0.35), L.METAL, Color(0.7, 0.7, 0.68), false)
				_b.box(Vector3(x, ceiling - 0.06, 0.0), Vector3(1.3, 0.01, 0.26), L.PANEL, Color(0.85, 0.88, 0.9) * (0.55 if _rng.randf() < 0.5 else 0.3), false)
	# Reception: a water cooler; a trolley in each corridor.
	_b.box(Vector3(1.0, 0.55, 9.0), Vector3(0.4, 1.1, 0.4), L.PANEL, Color(0.75, 0.75, 0.72), true)
	_b.box(Vector3(1.0, 1.3, 9.0), Vector3(0.3, 0.4, 0.3), L.PANEL, Color(0.35, 0.55, 0.65), false)
	for cart: Vector3 in [Vector3(84.0, Y[1], -1.8), Vector3(138.0, Y[2], -1.6)]:
		_b.box(cart + Vector3(0.0, 0.85, 0.0), Vector3(1.0, 0.04, 0.55), L.METAL, STEEL, false)
		_b.box(cart + Vector3(0.0, 0.35, 0.0), Vector3(1.0, 0.04, 0.55), L.METAL, STEEL, false)
		for leg: Vector2 in [Vector2(-0.45, -0.24), Vector2(0.45, -0.24), Vector2(-0.45, 0.24), Vector2(0.45, 0.24)]:
			_b.box(cart + Vector3(leg.x, 0.45, leg.y), Vector3(0.03, 0.9, 0.03), L.METAL, STEEL, false)
		for item: int in 3:
			_b.box(cart + Vector3(_rng.randf_range(-0.35, 0.35), 0.95, _rng.randf_range(-0.15, 0.15)), Vector3(0.12, 0.18, 0.12), L.PANEL,
					Color(0.55, 0.7, 0.72), false)
		_b.collider(cart + Vector3(0.0, 0.45, 0.0), Vector3(1.0, 0.9, 0.55))
