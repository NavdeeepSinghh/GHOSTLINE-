class_name ForestDressing
extends RefCounted
## Set dressing for the Forgotten Forest: boulders, ferns along the trails,
## fallen logs and stumps, the debris of the quarantine (wire, barrels, crates,
## sandbags, warning signs), Echo mushrooms spreading east towards the
## facility, pollen drifting in the clearings, birds over the canopy and deer
## drinking at the river.
##
## Rocks, logs and stumps are solid but stay off the trails and clearings, so
## routes and the navmesh still connect (tests check the paths). Everything
## else is visual only.

const L := CityBuilder.Look
const FERN_GREENS: Array[Color] = [Color(0.12, 0.2, 0.08), Color(0.16, 0.22, 0.09), Color(0.1, 0.17, 0.1), Color(0.2, 0.2, 0.08)]
const ROCK := Color(0.22, 0.22, 0.2)
const WOOD := Color(0.2, 0.15, 0.1)
const OLIVE := Color(0.17, 0.2, 0.13)

var _b: CityBuilder
var _forest: Node
var _rng := RandomNumberGenerator.new()


func build(builder: CityBuilder, forest: Node) -> void:
	_b = builder
	_forest = forest
	_rng.seed = 2207
	var density: float = lerpf(0.6, 1.0, SettingsManager.get_float("graphics", "foliage_density"))
	_boulders(int(110 * density))
	_logs_and_stumps(int(40 * density), int(50 * density))
	_ferns(int(520 * density))
	_trail_edges()
	_quarantine_debris()
	_echo_growth()
	_flowers(int(260 * density))
	_fences()
	_camp(Vector3(-62.0, 0.0, 44.0))


func build_effects(parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "Wildlife"
	parent.add_child(root)
	for flock: Array in [[Vector3(-60.0, 0.0, -10.0), 22.0, 30.0], [Vector3(20.0, 0.0, 10.0), 18.0, 34.0], [Vector3(95.0, 0.0, -35.0), 14.0, 36.0]]:
		var birds := BirdFlock.new()
		birds.position = flock[0]
		birds.radius = flock[1]
		birds.height = flock[2]
		birds.count = 6 if CityFX.amount_scale() < 1.0 else 8
		root.add_child(birds)
	# Deer drinking at the river.
	for spot: Array in [[Vector3(-21.0, 0.0, 48.0), 30.0], [Vector3(-18.0, 0.0, -28.0), 200.0], [Vector3(-23.0, 0.0, 53.0), 80.0]]:
		var deer := Deer.new()
		deer.position = spot[0]
		deer.rotation_degrees.y = float(spot[1])
		root.add_child(deer)
	# Pollen and seeds drifting in the sunlit clearings.
	_atmosphere(root)
	for clearing: Vector3 in [Vector3(-118.0, 0.0, 0.0), Vector3(-70.0, 0.0, -30.0), Vector3(-45.0, 0.0, 30.0), Vector3(12.0, 0.0, 28.0),
			Vector3(-20.0, 0.0, 0.0), Vector3(52.0, 0.0, 4.0)]:
		root.add_child(_pollen(clearing))


func _open(x: float, z: float) -> bool:
	return bool(_forest.call(&"is_open_ground", Vector2(x, z)))


func _random_wooded_spot(margin: float = 0.0) -> Vector2:
	for attempt: int in 30:
		var at := Vector2(_rng.randf_range(-127.0, 127.0), _rng.randf_range(-67.0, 67.0))
		if _open(at.x, at.y):
			continue
		if margin > 0.0 and (_open(at.x + margin, at.y) or _open(at.x - margin, at.y) or _open(at.x, at.y + margin) or _open(at.x, at.y - margin)):
			continue
		return at
	return Vector2(INF, INF)


func _boulders(count: int) -> void:
	for i: int in count:
		var at: Vector2 = _random_wooded_spot(2.0)
		if at.x == INF:
			continue
		var size := Vector3(_rng.randf_range(0.9, 2.8), _rng.randf_range(0.6, 1.8), _rng.randf_range(0.9, 2.4))
		var tint: Color = ROCK * _rng.randf_range(0.75, 1.15)
		_b.box(Vector3(at.x, size.y * 0.4, at.y), size, L.RUBBLE, tint, true, false, _rng.randf_range(0.0, 90.0),
				Vector3(_rng.randf_range(-8.0, 8.0), 0.0, _rng.randf_range(-8.0, 8.0)))
		# Moss on top, and a smaller stone leaning on it.
		_b.box(Vector3(at.x, size.y * 0.85, at.y), Vector3(size.x * 0.7, 0.08, size.z * 0.7), L.EARTH, Color(0.14, 0.22, 0.08), false, false, _rng.randf_range(0.0, 90.0))
		if _rng.randf() < 0.5:
			var side := Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)).normalized() * (size.x * 0.6 + 0.3)
			var small := Vector3(_rng.randf_range(0.4, 0.8), _rng.randf_range(0.3, 0.6), _rng.randf_range(0.4, 0.8))
			_b.box(Vector3(at.x + side.x, small.y * 0.4, at.y + side.y), small, L.RUBBLE, tint * 0.9, false, false, _rng.randf_range(0.0, 90.0))


func _logs_and_stumps(logs: int, stumps: int) -> void:
	for i: int in logs:
		var at: Vector2 = _random_wooded_spot(4.0)
		if at.x == INF:
			continue
		var length: float = _rng.randf_range(4.0, 9.0)
		var girth: float = _rng.randf_range(0.4, 0.7)
		var yaw: float = _rng.randf_range(0.0, 180.0)
		_b.box(Vector3(at.x, girth * 0.45, at.y), Vector3(girth, girth, length), L.RUBBLE, WOOD * _rng.randf_range(0.7, 1.1), true, false, yaw,
				Vector3(_rng.randf_range(-3.0, 3.0), 0.0, 0.0))
		# The root plate at one end, and moss along the top.
		var forward := Vector2(sin(deg_to_rad(yaw)), cos(deg_to_rad(yaw)))
		var root_at: Vector2 = at + forward * length * 0.5
		_b.box(Vector3(root_at.x, girth * 0.9, root_at.y), Vector3(girth * 3.2, girth * 2.6, 0.3), L.EARTH, Color(0.16, 0.12, 0.08), false, false, yaw)
		_b.box(Vector3(at.x, girth * 0.92, at.y), Vector3(girth * 0.6, 0.05, length * 0.8), L.EARTH, Color(0.13, 0.2, 0.07), false, false, yaw)
	for i: int in stumps:
		var at: Vector2 = _random_wooded_spot(1.0)
		if at.x == INF:
			continue
		var girth: float = _rng.randf_range(0.5, 0.9)
		var height: float = _rng.randf_range(0.3, 0.9)
		_b.box(Vector3(at.x, height * 0.5, at.y), Vector3(girth, height, girth), L.RUBBLE, WOOD * _rng.randf_range(0.8, 1.2), true, false, _rng.randf_range(0.0, 90.0))
		_b.box(Vector3(at.x, height + 0.01, at.y), Vector3(girth * 0.85, 0.02, girth * 0.85), L.INTERIOR, Color(0.42, 0.33, 0.22), false, false, _rng.randf_range(0.0, 90.0))


func _fern(at: Vector2, scale: float) -> void:
	var color: Color = FERN_GREENS[_rng.randi() % FERN_GREENS.size()] * _rng.randf_range(0.85, 1.2)
	var fronds: int = _rng.randi_range(4, 7)
	for f: int in fronds:
		var yaw: float = float(f) / float(fronds) * 360.0 + _rng.randf_range(-15.0, 15.0)
		var length: float = _rng.randf_range(0.6, 1.1) * scale
		var dir := Vector2(sin(deg_to_rad(yaw)), cos(deg_to_rad(yaw)))
		var centre: Vector2 = at + dir * length * 0.42
		_b.box(Vector3(centre.x, 0.28 * scale, centre.y), Vector3(0.22 * scale, 0.02, length), L.EARTH, color, false, false, yaw,
				Vector3(-_rng.randf_range(28.0, 45.0), 0.0, 0.0))


func _ferns(count: int) -> void:
	for i: int in count:
		var at: Vector2 = _random_wooded_spot()
		if at.x != INF:
			_fern(at, _rng.randf_range(0.7, 1.4))


## Ferns and the odd stone lining both sides of every trail.
func _trail_edges() -> void:
	var paths: Array = _forest.get(&"_paths")
	for path: Array in paths:
		var from: Vector2 = path[0]
		var to: Vector2 = path[1]
		var length: float = from.distance_to(to)
		if length < 1.0 or absf(from.x - to.x) < 0.1 and absf(from.y + 70.0) < 1.0:
			continue
		var along: Vector2 = (to - from) / length
		var side := Vector2(-along.y, along.x)
		var t: float = 2.0
		while t < length - 2.0:
			for s: float in [-1.0, 1.0]:
				var at: Vector2 = from + along * t + side * s * _rng.randf_range(4.4, 6.0)
				if _open(at.x, at.y):
					continue
				if _rng.randf() < 0.75:
					_fern(at, _rng.randf_range(0.6, 1.1))
				else:
					var size := Vector3(_rng.randf_range(0.3, 0.7), _rng.randf_range(0.2, 0.4), _rng.randf_range(0.3, 0.7))
					_b.box(Vector3(at.x, size.y * 0.4, at.y), size, L.RUBBLE, ROCK * _rng.randf_range(0.8, 1.1), false, false, _rng.randf_range(0.0, 90.0))
			t += _rng.randf_range(2.0, 3.5)


func _warning_sign(at: Vector3, yaw: float, text: String) -> void:
	_b.box(at + Vector3(0.0, 0.9, 0.0), Vector3(0.1, 1.8, 0.1), L.INTERIOR, WOOD, false, false, yaw)
	_b.box(at + Vector3(0.0, 1.7, 0.0), Vector3(1.4, 0.6, 0.04), L.METAL, Color(0.6, 0.5, 0.12), false, false, yaw, Vector3(0.0, 0.0, _rng.randf_range(-6.0, 6.0)))
	var label: Label3D = _b.sign_text(text, at + Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(0.0, 1.7, 0.03), yaw, 0.32, Color(0.08, 0.07, 0.05))
	label.modulate.a = 0.9


func _wire(from: Vector3, to: Vector3) -> void:
	var length: float = from.distance_to(to)
	var steps: int = int(length / 0.5)
	var previous: Vector3 = from
	for i: int in range(1, steps + 1):
		var t: float = float(i) / float(steps)
		var point: Vector3 = from.lerp(to, t) + Vector3(0.0, 0.35 + 0.3 * sin(t * length * 6.0), 0.3 * cos(t * length * 6.0))
		_b.segment(previous, point, 0.02, L.METAL, Color(0.25, 0.22, 0.2))
		previous = point


func _quarantine_debris() -> void:
	# Coiled wire along the inside of the outer wall, broken where the wall fell.
	_wire(Vector3(-87.6, 0.0, -68.0), Vector3(-87.6, 0.0, -48.0))
	_wire(Vector3(-87.6, 0.0, -34.0), Vector3(-87.6, 0.0, -6.0))
	_wire(Vector3(-87.6, 0.0, 6.0), Vector3(-87.6, 0.0, 40.0))
	# Barrels and crates by the gatehouse, the outpost and the inner gate.
	for group: Vector3 in [Vector3(-95.5, 0.0, 6.0), Vector3(-80.0, 0.0, -42.0), Vector3(-62.0, 0.0, -40.0), Vector3(53.5, 0.0, -12.5), Vector3(53.5, 0.0, 13.0)]:
		for i: int in _rng.randi_range(3, 5):
			var at: Vector3 = group + Vector3(_rng.randf_range(-1.5, 1.5), 0.0, _rng.randf_range(-1.5, 1.5))
			if _rng.randf() < 0.6:
				_b.box(at + Vector3(0.0, 0.45, 0.0), Vector3(0.6, 0.9, 0.6), L.METAL, [OLIVE, CityBuilder.COLOR_RUST, Color(0.25, 0.22, 0.18)][_rng.randi() % 3], false)
			else:
				_b.box(at + Vector3(0.0, 0.35, 0.0), Vector3(0.9, 0.7, 0.7), L.INTERIOR, Color(0.28, 0.24, 0.15), false, false, _rng.randf_range(0.0, 90.0))
		_b.collider(group + Vector3(0.0, 0.5, 0.0), Vector3(2.4, 1.0, 2.4))
	# A tipped barrel leaking into the grass.
	_b.box(Vector3(-79.0, 0.3, -45.0), Vector3(0.6, 0.6, 0.9), L.METAL, CityBuilder.COLOR_RUST, false, false, 30.0)
	_b.box(Vector3(-78.6, 0.012, -46.0), Vector3(1.4, 0.01, 1.8), L.ASPHALT, Color(0.04, 0.04, 0.03), false, false, 20.0)
	# Sandbags either side of the inner gate.
	for z: float in [-7.5, 7.5]:
		for i: int in 5:
			for row: int in 2:
				_b.box(Vector3(55.5 + row * 0.25, 0.17 + row * 0.32, z - 1.6 + i * 0.75), Vector3(0.85, 0.32, 0.7), L.RUBBLE, Color(0.3, 0.27, 0.19) * _rng.randf_range(0.85, 1.1), false, false, 90.0 + _rng.randf_range(-6.0, 6.0))
		_b.collider(Vector3(55.6, 0.35, z + 0.0), Vector3(1.0, 0.7, 3.8))
	# Warning signs along the way in.
	_warning_sign(Vector3(-100.0, 0.0, 5.0), 90.0, "DANGER\nRESTRICTED AREA")
	_warning_sign(Vector3(-86.0, 0.0, -40.0), -90.0, "QUARANTINE\nDO NOT ENTER")
	_warning_sign(Vector3(-30.0, 0.0, -2.0), -90.0, "MERIDIAN PROPERTY\nNO TRESPASSING")
	_warning_sign(Vector3(36.0, 0.0, 9.0), -45.0, "SERVICE ROAD\nAUTHORISED ONLY")
	_warning_sign(Vector3(56.0, 0.0, -4.5), -90.0, "STOP\nCHECKPOINT AHEAD")
	# A second wreck, rolled into the trees off the radio-hut trail.
	_b.car(28.0, 24.0, 140.0, OLIVE)
	_b.box(Vector3(28.0, 1.5, 24.0), Vector3(2.0, 0.05, 3.0), L.RUBBLE, Color(0.12, 0.2, 0.08), false, false, 140.0)


func _echo_growth() -> void:
	# Glowing caps among the trees, thicker the nearer they are to the facility.
	for i: int in 220:
		var at := Vector2(_rng.randf_range(-40.0, 128.0), _rng.randf_range(-67.0, 67.0))
		var bias: float = inverse_lerp(-40.0, 128.0, at.x)
		if _rng.randf() > bias * bias or _open(at.x, at.y):
			continue
		for c: int in _rng.randi_range(2, 5):
			var p: Vector2 = at + Vector2(_rng.randf_range(-0.5, 0.5), _rng.randf_range(-0.5, 0.5))
			var stem: float = _rng.randf_range(0.06, 0.2)
			_b.box(Vector3(p.x, stem * 0.5, p.y), Vector3(0.03, stem, 0.03), L.INTERIOR, Color(0.5, 0.55, 0.55), false)
			_b.strip(Vector3(p.x, stem + 0.02, p.y), Vector3(0.12, 0.04, 0.12) * _rng.randf_range(0.7, 1.4), CityBuilder.COLOR_ECHO)
	# Veins of growth crossing the ground near the caves and the yard wall.
	for vein: Array in [[Vector2(-4.0, -46.0), Vector2(6.0, -38.0)], [Vector2(40.0, -42.0), Vector2(30.0, -32.0)], [Vector2(62.0, -30.0), Vector2(62.0, -60.0)],
			[Vector2(62.0, 30.0), Vector2(62.0, 62.0)], [Vector2(109.0, 6.0), Vector2(118.0, 20.0)]]:
		var from: Vector2 = vein[0]
		var to: Vector2 = vein[1]
		var steps: int = int(from.distance_to(to) / 0.8)
		for s: int in steps:
			var p: Vector2 = from.lerp(to, float(s) / float(steps)) + Vector2(_rng.randf_range(-0.6, 0.6), _rng.randf_range(-0.6, 0.6))
			_b.strip(Vector3(p.x, 0.03, p.y), Vector3(_rng.randf_range(0.1, 0.25), 0.03, _rng.randf_range(0.5, 1.0)), CityBuilder.COLOR_ECHO, _rng.randf_range(0.0, 180.0))


func _pollen(at: Vector3) -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(12.0, 3.5, 12.0)
	process.direction = Vector3(1.0, 0.2, 0.3)
	process.spread = 60.0
	process.initial_velocity_min = 0.1
	process.initial_velocity_max = 0.35
	process.gravity = Vector3(0.05, -0.02, 0.0)
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 0.4
	process.turbulence_noise_scale = 6.0
	process.color_ramp = CityFX._ramp([[0.0, Color(1.0, 0.95, 0.75, 0.0)], [0.2, Color(1.0, 0.92, 0.7, 0.8)], [0.8, Color(1.0, 0.9, 0.65, 0.6)], [1.0, Color(1.0, 0.9, 0.6, 0.0)]])
	var particles: GPUParticles3D = CityFX._particles(int(45 * CityFX.amount_scale()), 9.0, process, 0.05, true,
			AABB(Vector3(-16, -2, -16), Vector3(32, 12, 32)))
	particles.position = at + Vector3(0.0, 3.5, 0.0)
	return particles


# --- Close-range detail (M8) ------------------------------------------------------

const PETALS: Array[Color] = [Color(0.85, 0.8, 0.3), Color(0.8, 0.82, 0.85), Color(0.6, 0.35, 0.7), Color(0.85, 0.45, 0.2), Color(0.4, 0.5, 0.85)]


## Small wildflowers in drifts at the edges of clearings and trails.
func _flowers(count: int) -> void:
	for i: int in count:
		var at := Vector2(_rng.randf_range(-127.0, 127.0), _rng.randf_range(-67.0, 67.0))
		# Edges: open ground with wooded ground a few metres away.
		if not _open(at.x, at.y) or (_open(at.x + 3.0, at.y) and _open(at.x - 3.0, at.y) and _open(at.x, at.y + 3.0) and _open(at.x, at.y - 3.0)):
			continue
		if at.x > -26.0 and at.x < -14.0:
			continue
		var color: Color = PETALS[_rng.randi() % PETALS.size()]
		for f: int in _rng.randi_range(3, 7):
			var p: Vector2 = at + Vector2(_rng.randf_range(-0.7, 0.7), _rng.randf_range(-0.7, 0.7))
			var stem: float = _rng.randf_range(0.15, 0.4)
			_b.box(Vector3(p.x, stem * 0.5, p.y), Vector3(0.02, stem, 0.02), L.EARTH, Color(0.15, 0.25, 0.08), false)
			_b.box(Vector3(p.x, stem + 0.02, p.y), Vector3(0.09, 0.03, 0.09), L.INTERIOR, color * _rng.randf_range(0.85, 1.1), false, false, _rng.randf_range(0.0, 90.0))


## Old fence lines beside some of the trails: leaning posts and sagging wire.
func _fences() -> void:
	for line: Array in [[Vector2(-112.0, -9.0), Vector2(-96.0, -9.0)], [Vector2(-80.0, -50.0), Vector2(-60.0, -50.0)], [Vector2(-6.0, 32.0), Vector2(8.0, 40.0)],
			[Vector2(46.0, 10.0), Vector2(46.0, 28.0)], [Vector2(20.0, -12.0), Vector2(32.0, -24.0)]]:
		var from: Vector2 = line[0]
		var to: Vector2 = line[1]
		var posts: int = int(from.distance_to(to) / 2.5) + 1
		var previous_top: Vector3 = Vector3.INF
		for i: int in posts:
			var p: Vector2 = from.lerp(to, float(i) / float(posts - 1))
			if _open(p.x, p.y) and _rng.randf() < 0.5:
				previous_top = Vector3.INF
				continue
			var lean := Vector3(_rng.randf_range(-12.0, 12.0), 0.0, _rng.randf_range(-12.0, 12.0))
			_b.box(Vector3(p.x, 0.6, p.y), Vector3(0.12, 1.2, 0.12), L.RUBBLE, WOOD * _rng.randf_range(0.8, 1.2), false, false, _rng.randf_range(0.0, 90.0), lean)
			var top := Vector3(p.x, 1.1, p.y)
			if previous_top != Vector3.INF and _rng.randf() < 0.8:
				for wire_y: float in [0.0, -0.45]:
					var a: Vector3 = previous_top + Vector3(0.0, wire_y, 0.0)
					var b: Vector3 = top + Vector3(0.0, wire_y, 0.0)
					var middle: Vector3 = a.lerp(b, 0.5) - Vector3(0.0, 0.15, 0.0)
					_b.segment(a, middle, 0.015, L.METAL, Color(0.3, 0.26, 0.22))
					_b.segment(middle, b, 0.015, L.METAL, Color(0.3, 0.26, 0.22))
			previous_top = top


## Someone camped here after the quarantine: a collapsed tent, a fire ring, a pack.
func _camp(at: Vector3) -> void:
	var canvas := Color(0.3, 0.32, 0.22)
	_b.box(at + Vector3(-1.5, 0.75, -0.5), Vector3(2.6, 0.05, 2.0), L.RUBBLE, canvas, false, false, 15.0, Vector3(0.0, 0.0, 38.0))
	_b.box(at + Vector3(-2.6, 0.35, -0.5), Vector3(0.6, 0.05, 2.0), L.RUBBLE, canvas * 0.8, false, false, 15.0, Vector3(0.0, 0.0, -60.0))
	_b.box(at + Vector3(-0.4, 0.75, -0.2), Vector3(0.05, 1.5, 0.05), L.INTERIOR, WOOD, false)
	for i: int in 8:
		var angle: float = float(i) / 8.0 * TAU
		_b.box(at + Vector3(1.5 + cos(angle) * 0.6, 0.1, 0.8 + sin(angle) * 0.6), Vector3(0.25, 0.2, 0.22), L.RUBBLE, ROCK * 0.8, false, false, rad_to_deg(angle))
	_b.box(at + Vector3(1.5, 0.03, 0.8), Vector3(0.8, 0.04, 0.8), L.ASPHALT, Color(0.04, 0.04, 0.04), false)
	for i: int in 3:
		_b.box(at + Vector3(1.5, 0.1, 0.8), Vector3(0.08, 0.08, 0.7), L.RUBBLE, Color(0.1, 0.08, 0.06), false, false, i * 60.0)
	for seat: Vector3 in [Vector3(3.0, 0.2, 0.6), Vector3(1.2, 0.2, 2.4)]:
		_b.box(at + seat, Vector3(0.4, 0.4, 1.4), L.RUBBLE, WOOD, true, false, 90.0 if seat.x > 2.0 else 0.0)
	_b.box(at + Vector3(-0.2, 0.25, 1.6), Vector3(0.5, 0.5, 0.3), L.RUBBLE, OLIVE, false, false, 25.0)
	_b.box(at + Vector3(0.4, 0.05, 1.9), Vector3(0.12, 0.1, 0.08), L.METAL, Color(0.5, 0.5, 0.5), false)
	_warning_sign(at + Vector3(4.0, 0.0, -2.5), 200.0, "KEEP OUT\nTHE WOODS SING")


# --- Atmosphere (M9) ---------------------------------------------------------------

func _atmosphere(root: Node3D) -> void:
	# Low mist along the river, in the hollows and over the Warden's yard.
	root.add_child(CityFX.mist(Vector3(-20.0, 0.8, 0.0), Vector3(12.0, 2.2, 140.0), 0.22))
	for hollow: Array in [[Vector3(-70.0, 0.6, -30.0), 26.0], [Vector3(-4.0, 0.6, -52.0), 18.0], [Vector3(40.0, 0.6, -48.0), 18.0], [Vector3(-62.0, 0.6, 44.0), 14.0]]:
		root.add_child(CityFX.mist(hollow[0], Vector3(float(hollow[1]), 1.6, float(hollow[1])), 0.18))
	root.add_child(CityFX.mist(Vector3(86.0, 0.8, 0.0), Vector3(46.0, 2.0, 46.0), 0.2, Color(0.75, 0.9, 0.95), Color(0.02, 0.08, 0.1)))
	# Leaves drifting down around Kael, and Echo spores thick near the facility.
	var leaves := ParticleProcessMaterial.new()
	leaves.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	leaves.emission_box_extents = Vector3(14.0, 1.0, 14.0)
	leaves.direction = Vector3(0.3, -1.0, 0.2)
	leaves.spread = 25.0
	leaves.initial_velocity_min = 0.4
	leaves.initial_velocity_max = 0.9
	leaves.gravity = Vector3(0.2, -0.35, 0.1)
	leaves.turbulence_enabled = true
	leaves.turbulence_noise_strength = 1.4
	leaves.angle_min = -180.0
	leaves.angle_max = 180.0
	leaves.angular_velocity_min = -90.0
	leaves.angular_velocity_max = 90.0
	leaves.color_ramp = CityFX._ramp([[0.0, Color(0.55, 0.45, 0.15, 0.0)], [0.15, Color(0.5, 0.4, 0.12, 0.9)], [0.85, Color(0.45, 0.32, 0.1, 0.9)], [1.0, Color(0.4, 0.3, 0.1, 0.0)]])
	var falling: GPUParticles3D = CityFX._particles(int(40 * CityFX.amount_scale()), 9.0, leaves, 0.12, false, AABB(Vector3(-16, -12, -16), Vector3(32, 16, 32)))
	(falling.draw_pass_1.surface_get_material(0) as StandardMaterial3D).shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	var follow := FollowPlayer.new()
	follow.offset = Vector3(0.0, 9.0, 0.0)
	falling.add_child(follow)
	root.add_child(falling)
	root.add_child(CityFX.motes(Vector3(90.0, 2.5, 0.0), Vector3(22.0, 2.5, 22.0), 70))
	for ghost: EchoGhost in EchoGhost.from_data("forest"):
		root.add_child(ghost)
	# Ravens picking about the clearings and along the old fence.
	for spot: Vector3 in [Vector3(-112.0, 0.0, 4.0), Vector3(-66.0, 0.0, -26.0), Vector3(-2.0, 0.0, -48.0), Vector3(30.0, 0.0, 20.0), Vector3(-58.0, 0.0, 40.0)]:
		var ravens := Crows.new()
		ravens.count = 3
		ravens.spread = 1.5
		ravens.position = spot
		root.add_child(ravens)
