class_name DeadCityLayout
extends RefCounted
## Geometry of the Dead City, built with CityBuilder. Coordinates are metres;
## -Z is north. Kael starts on a rooftop in the south and works north to the
## broadcast tower:
##
##   z  +92 .. +56   south row: camp rooftop (A), fire-escape roof (B), apartment
##   z  +56 .. +44   South Street
##   z  +44 ..  -3   middle blocks: store + courtyard + metro entrance (west), pharmacy (east)
##   z   -3 .. -17   Main Street (fire truck, gate to East Avenue)
##   z  -17 .. -60   north blocks: collapsed overpass on Central, Learning Centre (east)
##   z  -60 .. -104  Tower Plaza and the broadcast tower
##   y   -5          metro concourse running under the west blocks

const L := CityBuilder.Look

const BOUNDS := Rect2(-66.0, -112.0, 132.0, 204.0)
const SPAWN := Vector3(-10.0, 9.1, 70.0)
const ROOF_A_Y: float = 9.0
const ROOF_B_Y: float = 7.0
const ROOF_N2_Y: float = 7.0
const METRO_Y: float = -5.0
const METRO_HOLE_SOUTH := Rect2(-23.5, -2.0, 7.0, 10.0)
const METRO_HOLE_NORTH := Rect2(-23.5, -70.0, 7.0, 10.0)
const TOWER_TOP: float = 62.0
## Where Kael stands to use each workbench (the bench is 1 m further south / +Z).
const WORKBENCH_MAIN := Vector3(-27.5, 0.0, 8.0)
const WORKBENCH_PLAZA := Vector3(-28.5, 0.0, -62.4)

## Rooms and tunnels where the rain does not fall.
var interiors: Array[AABB] = []
## [AABB, surface name] for footsteps; anything else outdoors is wet concrete.
var surfaces: Array = []
## [centre, size] of tall-grass patches.
var grass: Array = []
## [centre, size] of deep-shadow volumes.
var shadows: Array = []
## [footprint Rect2, height] of the distant skyline blocks (for beacons and smoke).
var skyline: Array = []

var _b: CityBuilder


func build(builder: CityBuilder) -> void:
	_b = builder
	_ground()
	_perimeter()
	_south_row()
	_middle_west()
	_middle_east()
	_metro()
	_north_blocks()
	_plaza_and_tower()
	_streets()


func _interior(x0: float, z0: float, x1: float, z1: float, height: float = 3.4, base_y: float = 0.0, surface: String = "concrete") -> void:
	var box := AABB(Vector3(x0, base_y - 0.2, z0), Vector3(x1 - x0, height + 0.2, z1 - z0))
	interiors.append(box)
	surfaces.append([box, surface])


func _ground() -> void:
	_b.ground(BOUNDS, [METRO_HOLE_SOUTH, METRO_HOLE_NORTH])
	# Pavements: a lighter skin along the building lines (no step, so nothing trips on it).
	for strip: Rect2 in [Rect2(-58, 44, 116, 2.6), Rect2(-58, 53.4, 116, 2.6), Rect2(-58, -5.6, 116, 2.6),
			Rect2(-58, -17, 116, 2.6), Rect2(-34, -62.6, 80, 2.6)]:
		_b.block(strip.position.x, strip.position.y, strip.end.x, strip.end.y, 0.02, 0.0, L.CONCRETE, CityBuilder.COLOR_SIDEWALK, false, false)


func _perimeter() -> void:
	# The district is walled in by buildings; a ring of taller silhouettes stands behind them.
	_b.building(-66, -112, -58, 56, 24, 0.0, 3)
	_b.building(58, -112, 66, 56, 22, 0.0, 1)
	_b.building(-58, -112, 58, -104, 20, 0.0, 0)
	for i: int in 26:
		var angle: float = TAU * float(i) / 26.0 + _b.random_range(-0.08, 0.08)
		var distance: float = _b.random_range(125.0, 175.0)
		var at := Vector2(cos(angle) * distance * 0.8, sin(angle) * distance - 10.0)
		var half := Vector2(_b.random_range(8.0, 16.0), _b.random_range(8.0, 16.0))
		var height: float = _b.random_range(34.0, 78.0)
		_b.block(at.x - half.x, at.y - half.y, at.x + half.x, at.y + half.y, height, 0.0,
				L.FACADE, CityBuilder.FACADE_TINTS[i % CityBuilder.FACADE_TINTS.size()] * 0.7, false, false)
		skyline.append([Rect2(at - half, half * 2.0), height])


func _south_row() -> void:
	_b.building(-66, 56, -36, 92, 18, 0.0, 2)
	_b.building(-38, 78, -2, 92, 22, 0.0, 4)
	_b.building(-4, 56, 30, 92, 16, 0.0, 5)
	_b.building(30, 56, 66, 92, 20, 0.0, 1)
	# Building B: Kael drops onto this roof and takes the fire-escape ladder to the street.
	_b.block(-36, 58, -22, 78, ROOF_B_Y, 0.0, L.FACADE, CityBuilder.FACADE_TINTS[0])
	_b.block(-36, 63.6, -22, 64.4, 1.2, ROOF_B_Y, L.CONCRETE, CityBuilder.COLOR_CONCRETE, true)
	_b.block(-35, 70, -32, 73, 1.6, ROOF_B_Y, L.METAL, CityBuilder.COLOR_DARK)
	_b.block(-36, 77.6, -22, 78, 1.0, ROOF_B_Y, L.CONCRETE, CityBuilder.COLOR_DARK)
	_b.block(-36, 58, -35.6, 78, 1.0, ROOF_B_Y, L.CONCRETE, CityBuilder.COLOR_DARK)
	# Building A: the camp roof, with a ground-floor apartment (a dinner table still set for four).
	var tint: Color = CityBuilder.FACADE_TINTS[2]
	_b.block(-20, 58, -4, 78, ROOF_A_Y - 3.5, 3.5, L.FACADE, tint)
	_b.block(-20, 68, -4, 78, 3.5, 0.0, L.FACADE, tint)
	_b.block(-20, 58, -18, 68, 3.5, 0.0, L.FACADE, tint)
	_b.block(-6, 58, -4, 68, 3.5, 0.0, L.FACADE, tint)
	_b.room(-18, 58, -6, 68, 3.2, [["n", -12.0, 2.2]], Color(0.33, 0.29, 0.24))
	_interior(-18, 58, -6, 68)
	_table(Vector3(-12.0, 0.0, 63.5), 4, false)
	_b.block(-17.6, 66.2, -16.6, 67.4, 1.9, 0.0, L.METAL, Color(0.5, 0.52, 0.5))  # refrigerator
	_b.block(-9.5, 66.6, -6.4, 67.6, 0.9, 0.0, L.INTERIOR, Color(0.22, 0.18, 0.14))
	# Camp on roof A: lean-to, crates, the radio on its crate, a parapet on three sides.
	_b.block(-20, 77.6, -4, 78, 1.0, ROOF_A_Y, L.CONCRETE, CityBuilder.COLOR_DARK)
	_b.block(-4.4, 58, -4, 78, 1.0, ROOF_A_Y, L.CONCRETE, CityBuilder.COLOR_DARK)
	_b.block(-20, 58, -6, 58.4, 1.0, ROOF_A_Y, L.CONCRETE, CityBuilder.COLOR_DARK)
	_b.box(Vector3(-8.0, ROOF_A_Y + 1.5, 74.5), Vector3(4.6, 0.08, 4.0), L.RUBBLE, Color(0.16, 0.2, 0.17), false, false, 0.0, Vector3(14.0, 0.0, 0.0))
	for post: Vector2 in [Vector2(-10.2, 72.7), Vector2(-5.8, 72.7)]:
		_b.box(Vector3(post.x, ROOF_A_Y + 1.0, post.y), Vector3(0.08, 2.0, 0.08), L.METAL, CityBuilder.COLOR_DARK, false)
	_b.block(-9.6, 75.0, -7.6, 75.8, 0.25, ROOF_A_Y, L.RUBBLE, Color(0.2, 0.17, 0.14), false, false)  # bedroll
	_b.block(-13.4, 65.6, -12.6, 66.4, 0.7, ROOF_A_Y, L.INTERIOR, Color(0.3, 0.22, 0.14))  # radio crate
	_b.block(-13.25, 65.8, -12.75, 66.2, 0.28, ROOF_A_Y + 0.7, L.METAL, Color(0.2, 0.22, 0.2), false, false)
	_b.box(Vector3(-12.8, ROOF_A_Y + 1.7, 66.0), Vector3(0.02, 1.5, 0.02), L.METAL, CityBuilder.COLOR_DARK, false)
	_b.strip(Vector3(-13.0, ROOF_A_Y + 0.9, 65.79), Vector3(0.12, 0.04, 0.02), CityBuilder.COLOR_SODIUM)
	_b.block(-16.5, 74.0, -15.3, 75.2, 0.9, ROOF_A_Y, L.METAL, CityBuilder.COLOR_RUST)  # fire barrel
	_b.strip(Vector3(-15.9, ROOF_A_Y + 0.92, 74.6), Vector3(0.9, 0.04, 0.9), CityBuilder.COLOR_SODIUM)
	_b.point_light(Vector3(-15.9, ROOF_A_Y + 1.5, 74.6), CityBuilder.COLOR_SODIUM, 2.2, 9.0, true)
	surfaces.append([AABB(Vector3(-36, 6.5, 58), Vector3(32, 4, 20)), "gravel"])


func _middle_west() -> void:
	_b.building(-58, -3, -43, 44, 20, 0.0, 0)
	# Convenience store on South Street, with a back door into the courtyard.
	_b.room(-34, 32, -18, 44, 3.2, [["s", -26.0, 2.0], ["n", -21.0, 1.6]], Color(0.3, 0.31, 0.3))
	_interior(-34, 32, -18, 44)
	_b.block(-37, 32, -34, 44, 3.5, 0.0, L.FACADE, CityBuilder.FACADE_TINTS[1])
	_b.block(-37, 32, -18, 44, 9.5, 3.5, L.FACADE, CityBuilder.FACADE_TINTS[1])
	_b.building(-18, 32, -6, 44, 14, 0.0, 5)
	for shelf_x: float in [-31.0, -28.0, -25.0]:
		_b.block(shelf_x - 0.25, 34.5, shelf_x + 0.25, 40.0, 1.7, 0.0, L.METAL, Color(0.25, 0.26, 0.28))
	_b.block(-22.5, 39.0, -19.0, 39.8, 1.05, 0.0, L.INTERIOR, Color(0.2, 0.2, 0.22))  # counter
	# Courtyard: overgrown, dark, a quiet way round South Street.
	_b.block(-37, 24, -34, 32, 6, 0.0, L.CONCRETE, CityBuilder.COLOR_DARK)
	_b.block(-37, 14, -34, 20, 6, 0.0, L.CONCRETE, CityBuilder.COLOR_DARK)
	_b.building(-12, -3, -6, 32, 16, 0.0, 3)
	_b.block(-34, 10, -12, 14, 8, 0.0, L.FACADE, CityBuilder.FACADE_TINTS[4])
	_b.block(-34, 14, -33.6, 20, 6, 0.0, L.CONCRETE, CityBuilder.COLOR_DARK)
	_b.block(-30, 24, -27.5, 26, 1.3, 0.0, L.METAL, Color(0.1, 0.16, 0.12))  # dumpster
	_b.block(-17, 16, -14, 18.5, 1.1, 0.0, L.INTERIOR, Color(0.3, 0.22, 0.14), true)
	grass.append([Vector3(-24.0, 0.0, 21.0), Vector2(9.0, 7.0)])
	shadows.append([Vector3(-23.0, 0.0, 23.0), Vector3(22.0, 4.0, 18.0)])
	surfaces.append([AABB(Vector3(-34, -0.2, 14), Vector3(22, 3, 18)), "grass"])
	# Metro entrance square on Main Street.
	_b.building(-37, -3, -30, 14, 12, 0.0, 2)


func _middle_east() -> void:
	# The East Avenue block, with Lucky's Diner on the ground floor (z 20..32).
	var east_tint: Color = CityBuilder.FACADE_TINTS[4]
	_b.building(45, -3, 58, 20, 15, 0.0, 4)
	_b.building(45, 32, 58, 44, 15, 0.0, 4)
	_b.block(57, 20, 58, 32, 3.5, 0.0, L.FACADE, east_tint)
	_b.block(45, 20, 58, 32, 11.5, 3.5, L.FACADE, east_tint)
	_diner()
	_b.building(6, 11, 35, 44, 18, 0.0, 0)
	# Pharmacy on Main Street: shop floor, generator room, shuttered dispensary.
	var wall := Color(0.36, 0.38, 0.37)
	_b.room(10, -3, 28, 5, 3.2, [["n", 19.0, 2.2], ["s", 13.5, 2.0], ["s", 24.0, 1.8]], wall)
	_b.room(10, 5, 19, 11, 3.2, [["n", 13.5, 2.0]], wall)
	_b.room(19, 5, 28, 11, 3.2, [["n", 24.0, 1.8]], wall)
	_interior(10, -3, 28, 11)
	_b.block(6, -3, 10, 11, 3.5, 0.0, L.FACADE, CityBuilder.FACADE_TINTS[3])
	_b.block(28, -3, 35, 11, 3.5, 0.0, L.FACADE, CityBuilder.FACADE_TINTS[3])
	_b.block(6, -3, 35, 11, 12.0, 3.5, L.FACADE, CityBuilder.FACADE_TINTS[3])
	_b.block(11.0, 1.2, 16.5, 1.9, 1.05, 0.0, L.INTERIOR, Color(0.5, 0.52, 0.5))  # counter
	for shelf_x: float in [21.0, 23.5, 26.0]:
		_b.block(shelf_x - 0.2, -1.5, shelf_x + 0.2, 3.0, 1.6, 0.0, L.METAL, Color(0.42, 0.44, 0.44))
	_b.block(11.0, 8.5, 13.2, 10.2, 1.2, 0.0, L.METAL, Color(0.32, 0.3, 0.12))  # generator
	_b.block(20.0, 9.6, 27.2, 10.4, 1.8, 0.0, L.METAL, Color(0.42, 0.44, 0.44))


## Lucky's Diner: booths along the street window, a counter with stools, a
## kitchen through the pass, a jukebox still lit. Breakfast was being served.
func _diner() -> void:
	var red := Color(0.42, 0.12, 0.1)
	var chrome := Color(0.55, 0.56, 0.56)
	var tile := Color(0.5, 0.48, 0.44)
	_b.room(45, 20, 57, 32, 3.2, [["w", 26.0, 2.4]], Color(0.46, 0.42, 0.36))
	_interior(45, 20, 57, 32)
	# Chequered floor.
	for i: int in 12:
		for j: int in 12:
			if (i + j) % 2 == 0:
				_b.box(Vector3(45.5 + i, 0.012, 20.5 + j), Vector3(1.0, 0.01, 1.0), L.INTERIOR, Color(0.12, 0.12, 0.12), false)
	# Booths along the west (street) wall, either side of the door.
	for z: float in [21.6, 30.4]:
		for side: float in [-0.9, 0.9]:
			_b.block(45.3, z + side - 0.3, 47.6, z + side + 0.3, 0.5, 0.0, L.INTERIOR, red, true)
			_b.block(45.3, z + side + (0.25 if side > 0 else -0.25) - 0.08, 47.6, z + side + (0.25 if side > 0 else -0.25) + 0.08, 0.6, 0.5, L.INTERIOR, red, false)
		_b.block(45.5, z - 0.45, 47.4, z + 0.45, 0.05, 0.72, L.INTERIOR, Color(0.7, 0.68, 0.62))
		_b.box(Vector3(46.4, 0.36, z), Vector3(0.1, 0.72, 0.1), L.METAL, chrome, false)
		# Breakfast still on the table.
		for plate: float in [-0.25, 0.25]:
			_b.box(Vector3(46.4, 0.78, z + plate), Vector3(0.26, 0.02, 0.26), L.INTERIOR, Color(0.85, 0.84, 0.8), false)
		_b.box(Vector3(46.9, 0.84, z), Vector3(0.08, 0.14, 0.08), L.INTERIOR, Color(0.75, 0.5, 0.2), false)
	# The counter, stools and the pass to the kitchen.
	_b.block(50.0, 22.0, 51.0, 30.0, 1.05, 0.0, L.INTERIOR, red)
	_b.block(49.9, 21.9, 51.1, 30.1, 0.06, 1.05, L.INTERIOR, Color(0.75, 0.73, 0.68))
	for z: float in [22.8, 24.4, 26.0, 27.6, 29.2]:
		_b.box(Vector3(49.2, 0.35, z), Vector3(0.06, 0.7, 0.06), L.METAL, chrome, false)
		_b.box(Vector3(49.2, 0.72, z), Vector3(0.42, 0.08, 0.42), L.INTERIOR, red, false)
	_b.collider(Vector3(49.2, 0.4, 26.0), Vector3(0.5, 0.8, 7.0))
	for item: Vector3 in [Vector3(50.5, 1.16, 23.0), Vector3(50.4, 1.16, 25.5), Vector3(50.6, 1.16, 28.4)]:
		_b.box(item, Vector3(0.18, 0.16, 0.18), L.INTERIOR, Color(0.6, 0.55, 0.45), false)
	_b.box(Vector3(50.5, 1.2, 27.0), Vector3(0.4, 0.25, 0.3), L.METAL, Color(0.2, 0.2, 0.2), false)  # till
	# Kitchen behind: grill, fridge, shelves, the pass window in a half wall.
	# Half wall with the pass above it; the way into the kitchen is at the north end.
	_b.block(53.0, 20.0, 53.3, 29.8, 1.1, 0.0, L.INTERIOR, tile, true)
	_b.block(53.0, 20.0, 53.3, 29.8, 0.6, 2.6, L.INTERIOR, tile, false)
	_b.block(55.6, 21.0, 56.8, 25.0, 0.95, 0.0, L.METAL, chrome, true)  # grill
	_b.box(Vector3(56.2, 1.0, 23.0), Vector3(1.0, 0.04, 3.6), L.METAL, Color(0.08, 0.08, 0.08), false)
	_b.block(55.8, 29.6, 56.8, 31.6, 2.0, 0.0, L.METAL, Color(0.6, 0.6, 0.58), true)  # fridge
	for shelf_y: float in [1.2, 1.8, 2.4]:
		_b.block(56.4, 26.0, 56.9, 28.8, 0.04, shelf_y, L.METAL, chrome)
	# The jukebox in the corner, still glowing.
	_b.block(55.8, 31.0, 56.9, 31.9, 1.5, 0.0, L.INTERIOR, Color(0.3, 0.12, 0.08), true)
	_b.strip(Vector3(55.78, 1.0, 31.45), Vector3(0.02, 0.8, 0.6), CityBuilder.COLOR_WARM)
	# A menu board and the specials, chalk on black.
	_b.box(Vector3(52.95, 2.3, 26.0), Vector3(0.04, 0.9, 2.6), L.INTERIOR, Color(0.05, 0.05, 0.05), false)
	_b.sign_text("TODAY: EGGS ANY WAY  ·  COFFEE 2", Vector3(52.92, 2.45, 26.0), -90.0, 0.28, Color(0.8, 0.8, 0.75))
	_b.sign_text("WE STAY OPEN AS LONG AS THE LIGHTS DO", Vector3(52.92, 2.15, 26.0), -90.0, 0.22, Color(0.8, 0.8, 0.75))
	_b.point_light(Vector3(51.0, 2.9, 26.0), CityBuilder.COLOR_WARM, 1.4, 9.0, false, true)
	_b.point_light(Vector3(55.0, 2.6, 23.0), Color(0.75, 0.85, 1.0), 0.6, 5.0)


func _metro() -> void:
	var y: float = METRO_Y
	var dark := Color(0.17, 0.18, 0.19)
	# Floor, perimeter walls (the street slab is the ceiling), maintenance room to the east.
	_b.block(-33, -61, 1, -1, 1.0, y - 1.0, L.INTERIOR, Color(0.2, 0.2, 0.2))
	_b.block(-33, -61, -32, -1, 4.0, y, L.INTERIOR, dark)
	_b.block(-8, -61, -7, -42, 4.0, y, L.INTERIOR, dark)
	_b.block(-8, -28, -7, -1, 4.0, y, L.INTERIOR, dark)
	_b.block(-8, -42, -7, -36.2, 4.0, y, L.INTERIOR, dark)
	_b.block(-8, -33.8, -7, -28, 4.0, y, L.INTERIOR, dark)
	_b.block(-8, -36.2, -7, -33.8, 1.6, y + 2.4, L.INTERIOR, dark)
	_b.block(-7, -42, 1, -41, 4.0, y, L.INTERIOR, dark)
	_b.block(-7, -29, 1, -28, 4.0, y, L.INTERIOR, dark)
	_b.block(0, -41, 1, -29, 4.0, y, L.INTERIOR, dark)
	for end_z: Array in [[-2.0, -1.0], [-61.0, -60.0]]:
		_b.block(-33, end_z[0], -23.5, end_z[1], 4.0, y, L.INTERIOR, dark)
		_b.block(-16.5, end_z[0], -7, end_z[1], 4.0, y, L.INTERIOR, dark)
	# Ramps up to the street at both ends, with retaining walls and street-level railings.
	_b.ramp(Vector3(-20.0, y, -2.0), Vector3(-20.0, 0.0, 8.0), 7.0, L.CONCRETE, CityBuilder.COLOR_SIDEWALK)
	_b.ramp(Vector3(-20.0, y, -60.0), Vector3(-20.0, 0.0, -70.0), 7.0, L.CONCRETE, CityBuilder.COLOR_SIDEWALK)
	for hole: Rect2 in [METRO_HOLE_SOUTH, METRO_HOLE_NORTH]:
		for side_x: float in [hole.position.x - 0.5, hole.end.x]:
			_b.block(side_x, hole.position.y, side_x + 0.5, hole.end.y, 6.0, y - 1.0, L.CONCRETE, CityBuilder.COLOR_CONCRETE)
			_b.block(side_x, hole.position.y, side_x + 0.5, hole.end.y, 1.1, 0.0, L.METAL, CityBuilder.COLOR_DARK)
	# Close the deep end of each stairwell at street level (south one faces Main Street).
	_b.block(-24, -2.5, -16, -2.0, 1.1, 0.0, L.METAL, CityBuilder.COLOR_DARK)
	# Under the ramps: fill so nobody walks behind them.
	_b.block(-23.5, 2.0, -16.5, 8.0, 3.0, y - 1.0, L.CONCRETE, CityBuilder.COLOR_CONCRETE)
	_b.block(-23.5, -70.0, -16.5, -64.0, 3.0, y - 1.0, L.CONCRETE, CityBuilder.COLOR_CONCRETE)
	for pillar_z: float in [-10.0, -20.0, -30.0, -40.0, -50.0]:
		for pillar_x: float in [-27.5, -12.5]:
			_b.block(pillar_x - 0.45, pillar_z - 0.45, pillar_x + 0.45, pillar_z + 0.45, 4.0, y, L.CONCRETE, CityBuilder.COLOR_CONCRETE)
	# Ticket barriers, a dead kiosk, benches.
	for gate_x: float in [-30.5, -27.0, -13.0, -9.5]:
		_b.block(gate_x - 1.0, -15.3, gate_x + 1.0, -14.7, 1.0, y, L.METAL, Color(0.3, 0.32, 0.34))
	_b.block(-31.5, -49, -29.0, -45, 2.6, y, L.METAL, Color(0.16, 0.2, 0.24))
	for bench_z: float in [-24.0, -36.0]:
		_b.block(-31.6, bench_z - 1.2, -30.9, bench_z + 1.2, 0.5, y, L.METAL, Color(0.25, 0.2, 0.15))
	_b.block(-5.5, -40.4, -1.0, -39.6, 1.0, y, L.METAL, Color(0.3, 0.3, 0.32))  # workbench
	_b.block(-0.9, -34, -0.2, -31, 2.0, y, L.METAL, Color(0.25, 0.3, 0.28))  # lockers
	# Echo growth on the far wall: the first cyan in the game.
	for i: int in 14:
		var at := Vector3(-31.92, y + _b.random_range(0.4, 3.2), _b.random_range(-58.0, -51.0))
		_b.strip(at, Vector3(0.1, _b.random_range(0.15, 0.7), _b.random_range(0.1, 0.5)), CityBuilder.COLOR_ECHO)
	_interior(-33, -61, 1, 8, 4.5, y, "concrete")
	_interior(-23.5, -70, -16.5, -60, 4.5, y, "concrete")
	shadows.append([Vector3(-16.0, y, -31.0), Vector3(34.0, 4.0, 60.0)])


func _north_blocks() -> void:
	_b.building(-58, -60, -43, -17, 22, 0.0, 1)
	_b.building(-43, -60, -6, -17, 16, 0.0, 5)
	_b.building(45, -60, 58, -17, 18, 0.0, 2)
	# The overpass that came down across Central Avenue.
	_b.rubble(-6, -47, 6, -31, 5.0, 16)
	_b.box(Vector3(0.0, 4.2, -36.0), Vector3(12.0, 0.9, 13.0), L.CONCRETE, CityBuilder.COLOR_CONCRETE, true, false, 0.0, Vector3(-52.0, 0.0, 6.0))
	_b.box(Vector3(-1.0, 5.0, -44.0), Vector3(12.0, 0.9, 10.0), L.CONCRETE, CityBuilder.COLOR_CONCRETE, true, false, 0.0, Vector3(50.0, 0.0, -9.0))
	for pillar_x: float in [-4.6, 4.6]:
		_b.block(pillar_x - 0.8, -29.5, pillar_x + 0.8, -28.0, 8.5, 0.0, L.CONCRETE, CityBuilder.COLOR_CONCRETE)
	_b.block(-6, -29.6, 6, -27.8, 1.2, 8.5, L.CONCRETE, CityBuilder.COLOR_CONCRETE, false, false)
	# Learning Centre block: one long low roof (Mara's camp), classroom on the plaza side.
	var tint: Color = CityBuilder.FACADE_TINTS[2]
	_b.block(6, -48, 35, -17, ROOF_N2_Y, 0.0, L.FACADE, tint)
	_b.block(6, -60, 35, -48, ROOF_N2_Y - 3.7, 3.7, L.FACADE, tint)
	_b.block(6, -60, 10, -48, 3.7, 0.0, L.FACADE, tint)
	_b.block(30, -60, 35, -48, 3.7, 0.0, L.FACADE, tint)
	_b.room(10, -60, 30, -48, 3.4, [["n", 20.0, 2.0]], Color(0.4, 0.38, 0.3))
	_interior(10, -60, 30, -48)
	_b.block(12.0, -48.5, 20.0, -48.3, 1.4, 1.0, L.INTERIOR, Color(0.05, 0.09, 0.07), false, false)  # blackboard
	for row: int in 3:
		for column: int in 4:
			var desk := Vector3(13.0 + column * 3.6, 0.0, -57.0 + row * 2.6)
			_b.block(desk.x - 0.55, desk.z - 0.3, desk.x + 0.55, desk.z + 0.3, 0.7, 0.0, L.INTERIOR, Color(0.42, 0.33, 0.2))
			# Every chair pushed back at the same angle.
			_b.box(desk + Vector3(0.35, 0.3, -1.0), Vector3(0.4, 0.6, 0.4), L.METAL, Color(0.3, 0.2, 0.15), false, false, 24.0)
	# Roof camp: tarp, bedroll, locker, a low wall to hide behind.
	_b.block(6, -60, 31, -59.6, 0.9, ROOF_N2_Y, L.CONCRETE, CityBuilder.COLOR_DARK)
	_b.block(33, -60, 35, -59.6, 0.9, ROOF_N2_Y, L.CONCRETE, CityBuilder.COLOR_DARK)
	_b.block(34.6, -60, 35, -17, 0.9, ROOF_N2_Y, L.CONCRETE, CityBuilder.COLOR_DARK)
	_b.block(6, -60, 6.4, -17, 0.9, ROOF_N2_Y, L.CONCRETE, CityBuilder.COLOR_DARK)
	_b.box(Vector3(22.0, ROOF_N2_Y + 1.5, -38.0), Vector3(5.0, 0.08, 4.0), L.RUBBLE, Color(0.2, 0.17, 0.12), false, false, 0.0, Vector3(0.0, 0.0, 12.0))
	for post: Vector2 in [Vector2(19.6, -39.8), Vector2(19.6, -36.2), Vector2(24.4, -39.8), Vector2(24.4, -36.2)]:
		_b.box(Vector3(post.x, ROOF_N2_Y + 0.9, post.y), Vector3(0.08, 1.8, 0.08), L.METAL, CityBuilder.COLOR_DARK, false)
	_b.block(21.0, -38.6, 23.0, -37.8, 0.22, ROOF_N2_Y, L.RUBBLE, Color(0.22, 0.18, 0.16), false, false)
	_b.block(25.2, -39.0, 25.9, -37.6, 1.8, ROOF_N2_Y, L.METAL, Color(0.24, 0.3, 0.3))  # Mara's locker
	_b.block(12, -30, 16, -27, 2.2, ROOF_N2_Y, L.METAL, CityBuilder.COLOR_DARK)
	_b.block(27, -25, 31, -22, 1.4, ROOF_N2_Y, L.CONCRETE, CityBuilder.COLOR_CONCRETE)
	surfaces.append([AABB(Vector3(6, 6.5, -60), Vector3(29, 4, 43)), "gravel"])
	# East Avenue: fence posts either side of the gate (the gate leaf itself is a door the level owns).
	_b.block(35, -38.3, 38.4, -37.7, 3.2, 0.0, L.METAL, CityBuilder.COLOR_DARK)
	_b.block(41.6, -38.3, 45, -37.7, 3.2, 0.0, L.METAL, CityBuilder.COLOR_DARK)


func _plaza_and_tower() -> void:
	_b.building(-58, -104, -34, -60, 14, 0.0, 4)
	_b.building(46, -104, 58, -60, 17, 0.0, 3)
	# Tower base: junction panel and transmitter console inside; mast above.
	var tint := Color(0.3, 0.31, 0.33)
	_b.room(-9, -100, 9, -84, 4.0, [["s", 0.0, 2.6]], tint)
	_interior(-9, -100, 9, -84, 4.2)
	_b.block(-9.3, -100.3, 9.3, -83.7, 3.0, 4.3, L.FACADE, CityBuilder.FACADE_TINTS[1])
	_b.block(-8.6, -99.4, -3.0, -98.4, 1.0, 0.0, L.METAL, Color(0.2, 0.22, 0.24))  # console desk
	_b.block(3.5, -99.4, 8.4, -98.4, 0.8, 0.0, L.INTERIOR, Color(0.3, 0.24, 0.18))  # engineer's desk
	_b.block(-8.75, -93.5, -8.45, -90.5, 2.0, 0.6, L.METAL, Color(0.3, 0.32, 0.3), false, false)  # junction cabinet
	var base_y: float = 7.3
	for corner: Vector2 in [Vector2(-3, -95), Vector2(3, -95), Vector2(-3, -89), Vector2(3, -89)]:
		_b.box(Vector3(corner.x, base_y + (TOWER_TOP - base_y) * 0.5, corner.y), Vector3(0.4, TOWER_TOP - base_y, 0.4), L.METAL, Color(0.34, 0.2, 0.16), false)
	var level: float = base_y + 5.0
	while level < TOWER_TOP:
		for side: float in [-3.0, 3.0]:
			_b.box(Vector3(0.0, level, -92.0 + side), Vector3(6.4, 0.22, 0.22), L.METAL, Color(0.34, 0.2, 0.16), false)
			_b.box(Vector3(side, level, -92.0), Vector3(0.22, 0.22, 6.4), L.METAL, Color(0.34, 0.2, 0.16), false)
			_b.box(Vector3(0.0, level - 2.5, -92.0 + side), Vector3(8.0, 0.14, 0.14), L.METAL, Color(0.3, 0.18, 0.14), false, false, 0.0, Vector3(0.0, 0.0, 38.0))
			_b.box(Vector3(side, level - 2.5, -92.0), Vector3(0.14, 0.14, 8.0), L.METAL, Color(0.3, 0.18, 0.14), false, false, 0.0, Vector3(38.0, 0.0, 0.0))
		level += 5.0
	_b.box(Vector3(0.0, TOWER_TOP + 5.0, -92.0), Vector3(0.25, 10.0, 0.25), L.METAL, Color(0.34, 0.2, 0.16), false)
	# Plaza furniture: a dry fountain, kiosks, barriers and wrecks to fight around.
	_b.block(-4, -76, 4, -68, 0.6, 0.0, L.CONCRETE, CityBuilder.COLOR_CONCRETE, true)
	_b.block(-1, -73, 1, -71, 2.6, 0.6, L.CONCRETE, CityBuilder.COLOR_DARK)
	_b.block(22, -80, 26, -76, 2.8, 0.0, L.METAL, Color(0.16, 0.2, 0.24))
	_b.block(-30, -84, -26, -80, 2.8, 0.0, L.METAL, Color(0.22, 0.2, 0.16))
	_b.barrier(-13.0, -80.0, 4.0, 20.0)
	_b.barrier(13.0, -82.0, 4.0, -15.0)
	_b.barrier(-10.0, -66.0, 3.0, 90.0)
	_b.car(14.0, -66.0, 70.0, Color(0.16, 0.2, 0.26))
	_b.car(-28.0, -72.0, 12.0)
	_b.car(34.0, -90.0, -35.0, Color(0.24, 0.24, 0.22))
	grass.append([Vector3(30.0, 0.0, -68.0), Vector2(8.0, 6.0)])
	grass.append([Vector3(-18.0, 0.0, -96.0), Vector2(10.0, 6.0)])


func _streets() -> void:
	# South Street: wrecks, the evacuation tents, weeds through the tarmac.
	_b.car(-48.0, 47.5, 82.0)
	_b.car(-6.0, 52.5, -96.0, Color(0.2, 0.22, 0.2))
	_b.car(4.0, 47.0, 78.0, Color(0.14, 0.16, 0.22))
	_b.car(44.0, 52.0, -80.0)
	_b.car(52.0, 47.0, 14.0, Color(0.26, 0.24, 0.2))
	for tent_x: float in [16.0, 24.0, 32.0]:
		_tent(Vector3(tent_x, 0.0, 53.0))
	_b.barrier(20.0, 46.2, 5.0)
	_b.barrier(29.0, 46.2, 5.0)
	grass.append([Vector3(-30.0, 0.0, 50.5), Vector2(10.0, 6.0)])
	grass.append([Vector3(10.0, 0.0, 49.0), Vector2(7.0, 5.0)])
	surfaces.append([AABB(Vector3(-35, -0.2, 47.5), Vector3(10, 3, 6)), "grass"])
	# West Alley and Central Avenue (south half).
	_b.block(-42.6, 26, -40.6, 29, 1.3, 0.0, L.METAL, Color(0.1, 0.16, 0.12))
	_b.car(-39.0, 8.0, 4.0, Color(0.18, 0.18, 0.2))
	_b.car(2.5, 30.0, 8.0)
	_b.car(-2.6, 14.0, 172.0, Color(0.2, 0.2, 0.24))
	shadows.append([Vector3(-40.0, 0.0, 20.0), Vector3(6.0, 4.0, 46.0)])
	# Main Street: the fire truck, more wrecks, a toppled billboard.
	_b.block(27.0, -12.6, 35.5, -10.0, 2.9, 0.0, L.METAL, Color(0.42, 0.06, 0.05))
	_b.block(35.5, -12.5, 38.0, -10.1, 2.3, 0.0, L.METAL, Color(0.36, 0.05, 0.05))
	_b.block(27.5, -12.9, 35.0, -12.6, 0.5, 1.2, L.METAL, Color(0.6, 0.6, 0.58), false, false)
	_b.car(-46.0, -7.0, 96.0, Color(0.22, 0.22, 0.2))
	_b.car(-30.0, -13.0, -82.0)
	_b.car(8.0, -14.0, 100.0, Color(0.15, 0.2, 0.18))
	_b.car(50.0, -8.0, 60.0)
	_b.box(Vector3(-50.0, 1.6, -13.0), Vector3(9.0, 0.3, 4.5), L.METAL, CityBuilder.COLOR_DARK, true, false, 20.0, Vector3(0.0, 0.0, 24.0))
	_b.barrier(14.0, -8.0, 4.0, 90.0)
	_b.barrier(-3.0, -19.5, 5.0, 0.0)
	grass.append([Vector3(-52.0, 0.0, -8.0), Vector2(6.0, 6.0)])
	# Pocket north of Main Street under the standing overpass piers.
	_b.car(2.0, -23.0, 30.0, Color(0.2, 0.18, 0.16))
	# East Avenue.
	_b.car(38.5, 20.0, 2.0, Color(0.18, 0.2, 0.24))
	_b.car(42.0, 34.0, 184.0)
	_b.car(41.5, -50.0, 6.0, Color(0.22, 0.2, 0.2))
	_b.block(36.0, -30.0, 38.0, -27.0, 1.2, 0.0, L.INTERIOR, Color(0.3, 0.22, 0.14), true)
	# Workbenches: one by the metro on Main Street, one in Tower Plaza.
	for bench: Vector3 in [WORKBENCH_MAIN, WORKBENCH_PLAZA]:
		_b.block(bench.x - 1.1, bench.z + 0.8, bench.x + 1.1, bench.z + 1.5, 0.9, 0.0, L.METAL, Color(0.24, 0.2, 0.15))
		_b.block(bench.x - 1.1, bench.z + 1.4, bench.x + 1.1, bench.z + 1.5, 0.9, 0.9, L.METAL, Color(0.16, 0.17, 0.18), false, false)
		_b.block(bench.x - 0.9, bench.z + 0.95, bench.x - 0.5, bench.z + 1.25, 0.22, 0.9, L.METAL, Color(0.5, 0.12, 0.1), false, false)
		_b.strip(Vector3(bench.x, 1.65, bench.z + 1.38), Vector3(1.6, 0.05, 0.05), CityBuilder.COLOR_WARM)
		_b.point_light(Vector3(bench.x, 1.5, bench.z + 0.6), CityBuilder.COLOR_WARM, 1.2, 5.0)
	# Vines down the taller facades.
	_b.vines(Vector3(-36.0, 13.0, 31.94), Vector3(1, 0, 0), 30.0, 16, 7.0)
	_b.vines(Vector3(6.0, 15.5, -3.06), Vector3(1, 0, 0), 28.0, 14, 8.0)
	_b.vines(Vector3(-43.0, 16.0, -16.94), Vector3(1, 0, 0), 36.0, 18, 9.0)
	_b.vines(Vector3(-57.94, 20.0, -3.0), Vector3(0, 0, 1), 46.0, 16, 10.0)
	_b.vines(Vector3(45.94, 17.0, -104.0), Vector3(0, 0, 1), 44.0, 14, 9.0)
	_b.vines(Vector3(-4.0, 16.0, 55.94), Vector3(1, 0, 0), 34.0, 14, 8.0)


func _table(at: Vector3, chairs: int, pushed_back: bool) -> void:
	_b.block(at.x - 0.9, at.z - 0.5, at.x + 0.9, at.z + 0.5, 0.06, 0.72, L.INTERIOR, Color(0.34, 0.24, 0.15))
	for leg: Vector2 in [Vector2(-0.8, -0.4), Vector2(0.8, -0.4), Vector2(-0.8, 0.4), Vector2(0.8, 0.4)]:
		_b.box(at + Vector3(leg.x, 0.36, leg.y), Vector3(0.07, 0.72, 0.07), L.INTERIOR, Color(0.3, 0.2, 0.12), false)
	_b.collider(at + Vector3(0.0, 0.4, 0.0), Vector3(1.8, 0.8, 1.0))
	var seats: Array[Vector2] = [Vector2(-0.45, -0.85), Vector2(0.45, -0.85), Vector2(-0.45, 0.85), Vector2(0.45, 0.85)]
	for i: int in mini(chairs, seats.size()):
		var seat: Vector2 = seats[i] * (1.5 if pushed_back else 1.0)
		_b.box(at + Vector3(seat.x, 0.25, seat.y), Vector3(0.42, 0.5, 0.42), L.INTERIOR, Color(0.3, 0.2, 0.12), false)
		# A plate and a cup at each place.
		_b.box(at + Vector3(seats[i].x, 0.795, seats[i].y * 0.42), Vector3(0.24, 0.02, 0.24), L.INTERIOR, Color(0.8, 0.8, 0.76), false)
		_b.box(at + Vector3(seats[i].x + 0.2, 0.83, seats[i].y * 0.42), Vector3(0.07, 0.1, 0.07), L.INTERIOR, Color(0.7, 0.72, 0.74), false)


## An A-frame evacuation tent (canvas drawn tilted; one solid box inside).
func _tent(at: Vector3) -> void:
	var canvas := Color(0.23, 0.26, 0.2)
	for side: float in [-1.0, 1.0]:
		_b.box(at + Vector3(side * 0.95, 1.05, 0.0), Vector3(0.06, 2.9, 4.4), L.RUBBLE, canvas, false, false, 0.0, Vector3(0.0, 0.0, side * 42.0))
	_b.collider(at + Vector3(0.0, 0.8, 0.0), Vector3(2.6, 1.6, 4.2))
