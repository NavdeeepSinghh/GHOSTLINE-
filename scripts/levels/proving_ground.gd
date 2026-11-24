extends Level
## The Proving Ground: a graybox test level. Each station exercises one
## movement, camera, combat or stealth feature, laid out around the spawn point.
## Everything is built from the tables below so stations are quick to adjust.

const KILL_PLANE_Y: float = -15.0
const ARENA_HALF: float = 40.0
const ARENA_CENTER_Z: float = -10.0

var _builder: GrayboxBuilder
var _environment: Environment
var _sun: DirectionalLight3D


func _ready() -> void:
	spawn_position = Vector3(0.0, 0.1, 11.2)
	spawn_yaw = 0.0
	_builder = GrayboxBuilder.new()
	_builder.name = "Geometry"
	add_child(_builder)
	_build_lighting()
	_build_arena()
	_build_sprint_track()
	_build_jump_gaps()
	_build_vault_row()
	_build_shimmy_wall()
	_build_ladder_tower()
	_build_crouch_tunnel()
	_build_steps_and_slopes()
	_build_camera_corridor()
	_build_lock_on_range()
	_build_combat_yard()
	_build_bulwark_pen()
	_build_stealth_yard()
	_builder.commit()
	spawn_enemies()
	SettingsManager.register_world(_environment, _sun)


func _exit_tree() -> void:
	SettingsManager.unregister_world(_environment)


func _physics_process(_delta: float) -> void:
	for node: Node in get_tree().get_nodes_in_group(&"player"):
		var player: Player = node as Player
		if player != null and player.global_position.y < KILL_PLANE_Y:
			player.teleport(spawn_position, spawn_yaw)


## Camera stops for the benchmark fly-through and screenshot tour: [position, look-at].
func get_tour_stops() -> Array[Array]:
	return [
		[Vector3(0.0, 2.2, 15.0), Vector3(0.0, 1.0, 0.0)],
		[Vector3(-11.0, 3.0, 6.0), Vector3(-6.0, 1.0, -10.0)],
		[Vector3(-9.5, 2.0, -28.0), Vector3(0.0, 1.2, -33.0)],
		[Vector3(6.0, 6.5, -24.0), Vector3(14.0, 3.0, -17.0)],
		[Vector3(24.0, 4.0, -4.0), Vector3(14.0, 1.5, -8.0)],
		[Vector3(25.0, 3.0, 9.0), Vector3(14.0, 1.0, 2.0)],
		[Vector3(18.0, 5.0, 24.0), Vector3(12.0, 0.5, 16.0)],
		[Vector3(-20.0, 4.5, 22.0), Vector3(-12.0, 1.0, 12.0)],
		[Vector3(0.0, 9.0, 26.0), Vector3(0.0, 0.0, -10.0)],
	]


# --- Lighting ---------------------------------------------------------------

func _build_lighting() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.012, 0.02, 0.04)
	sky_material.sky_horizon_color = Color(0.07, 0.11, 0.16)
	sky_material.ground_bottom_color = Color(0.01, 0.014, 0.02)
	sky_material.ground_horizon_color = Color(0.07, 0.11, 0.16)
	sky_material.sun_angle_max = 8.0
	sky_material.sky_energy_multiplier = 1.0
	var sky := Sky.new()
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_128

	_environment = Environment.new()
	_environment.background_mode = Environment.BG_SKY
	_environment.sky = sky
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_environment.ambient_light_energy = 1.6
	_environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	_environment.tonemap_exposure = 1.15
	_environment.glow_enabled = true
	_environment.glow_intensity = 0.7
	_environment.glow_bloom = 0.08
	_environment.glow_hdr_threshold = 1.1
	_environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	_environment.ssao_enabled = true
	_environment.ssao_radius = 0.9
	_environment.ssao_intensity = 1.6
	_environment.ssr_enabled = true
	_environment.ssr_max_steps = 48
	_environment.ssr_fade_in = 0.2
	_environment.ssr_fade_out = 2.5
	_environment.fog_enabled = true
	_environment.fog_light_color = Color(0.1, 0.16, 0.22)
	_environment.fog_density = 0.008
	_environment.fog_sky_affect = 0.35
	_environment.volumetric_fog_enabled = true
	_environment.volumetric_fog_density = 0.022
	_environment.volumetric_fog_albedo = Color(0.62, 0.74, 0.86)
	_environment.volumetric_fog_emission = Color(0.02, 0.035, 0.05)
	_environment.volumetric_fog_emission_energy = 0.6
	_environment.volumetric_fog_anisotropy = 0.55
	_environment.volumetric_fog_length = 70.0
	_environment.volumetric_fog_ambient_inject = 0.35
	_environment.adjustment_enabled = true
	_environment.adjustment_contrast = 1.06
	_environment.adjustment_saturation = 1.08
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	world_environment.environment = _environment
	add_child(world_environment)

	_sun = DirectionalLight3D.new()
	_sun.name = "Moon"
	_sun.rotation_degrees = Vector3(-48.0, 38.0, 0.0)
	_sun.light_color = Color(0.56, 0.7, 1.0)
	_sun.light_energy = 1.25
	_sun.light_volumetric_fog_energy = 0.9
	_sun.shadow_enabled = true
	_sun.shadow_bias = 0.04
	_sun.shadow_normal_bias = 1.4
	_sun.shadow_blur = 1.2
	_sun.directional_shadow_blend_splits = true
	add_child(_sun)


# --- Stations ---------------------------------------------------------------

func _build_arena() -> void:
	var b: GrayboxBuilder = _builder
	var size: float = ARENA_HALF * 2.0
	b.add_block(0.0, ARENA_CENTER_Z, size, size, 1.0, -1.0, false, GrayboxBuilder.COLOR_FLOOR)
	# Perimeter walls with a thin light along the top.
	var wall_height: float = 6.0
	for side: float in [-1.0, 1.0]:
		b.add_block(side * (ARENA_HALF + 0.5), ARENA_CENTER_Z, 1.0, size + 2.0, wall_height, 0.0, false, GrayboxBuilder.COLOR_WALL)
		b.add_block(0.0, ARENA_CENTER_Z + side * (ARENA_HALF + 0.5), size, 1.0, wall_height, 0.0, false, GrayboxBuilder.COLOR_WALL)
		b.add_strip(Vector3(side * (ARENA_HALF - 0.02), wall_height - 0.4, ARENA_CENTER_Z), Vector3(0.05, 0.08, size), GrayboxBuilder.COLOR_ECHO)
		b.add_strip(Vector3(0.0, wall_height - 0.4, ARENA_CENTER_Z + side * (ARENA_HALF - 0.02)), Vector3(size, 0.08, 0.05), GrayboxBuilder.COLOR_ECHO)
	# Spawn pad.
	b.add_strip(Vector3(0.0, 0.012, 10.0), Vector3(2.4, 0.02, 0.08), GrayboxBuilder.COLOR_ECHO)
	b.add_strip(Vector3(0.0, 0.012, 12.4), Vector3(2.4, 0.02, 0.08), GrayboxBuilder.COLOR_ECHO)
	b.add_strip(Vector3(-1.2, 0.012, 11.2), Vector3(0.08, 0.02, 2.4), GrayboxBuilder.COLOR_ECHO)
	b.add_strip(Vector3(1.2, 0.012, 11.2), Vector3(0.08, 0.02, 2.4), GrayboxBuilder.COLOR_ECHO)
	b.add_sign("GHOSTLINE", Vector3(0.0, 0.02, 5.6), 0.0, 2.2, GrayboxBuilder.COLOR_TEXT, true)
	b.add_sign("PROVING GROUND  ·  MILESTONE 2", Vector3(0.0, 0.02, 6.9), 0.0, 0.9, GrayboxBuilder.COLOR_ECHO, true)
	b.add_lamp(-4.5, 13.5, GrayboxBuilder.COLOR_SODIUM, 4.2, 2.8, true)
	b.add_lamp(4.5, 13.5)


func _build_sprint_track() -> void:
	var b: GrayboxBuilder = _builder
	var x: float = -16.0
	for edge: float in [-2.0, 2.0]:
		b.add_strip(Vector3(x + edge, 0.012, -11.0), Vector3(0.07, 0.02, 40.0), GrayboxBuilder.COLOR_SODIUM)
	for i: int in 5:
		var z: float = 9.0 - i * 10.0
		b.add_strip(Vector3(x, 0.012, z), Vector3(4.0, 0.02, 0.07), GrayboxBuilder.COLOR_SODIUM)
		b.add_sign("%d M" % (i * 10), Vector3(x - 2.9, 0.02, z), 0.0, 1.0, GrayboxBuilder.COLOR_SODIUM, true)
	b.add_sign("SPRINT TRACK", Vector3(x, 0.02, 10.4), 0.0, 1.2, GrayboxBuilder.COLOR_TEXT, true)
	b.add_sign("HOLD SHIFT  ·  WATCH STAMINA", Vector3(x, 0.02, 11.3), 0.0, 0.55, GrayboxBuilder.COLOR_SODIUM, true)
	b.add_lamp(x - 3.2, 0.0)
	b.add_lamp(x - 3.2, -22.0)


func _build_jump_gaps() -> void:
	var b: GrayboxBuilder = _builder
	var x: float = -6.0
	var top: float = 1.0
	b.add_ramp(Vector3(x, 0.0, 4.0), Vector3(x, top, 0.5), 3.0)
	# [z centre, depth] of each platform; the gaps between them widen: 2 m, 3 m, 4 m.
	var platforms: Array[Vector2] = [Vector2(-1.25, 3.5), Vector2(-6.5, 3.0), Vector2(-12.5, 3.0), Vector2(-20.0, 4.0)]
	for platform: Vector2 in platforms:
		b.add_block(x, platform.x, 3.0, platform.y, top, 0.0, true)
	b.add_sign("2 M", Vector3(x + 1.9, 0.02, -4.0), 0.0, 1.0, GrayboxBuilder.COLOR_PAINT, true)
	b.add_sign("3 M", Vector3(x + 1.9, 0.02, -9.5), 0.0, 1.0, GrayboxBuilder.COLOR_PAINT, true)
	b.add_sign("4 M", Vector3(x + 1.9, 0.02, -16.0), 0.0, 1.0, GrayboxBuilder.COLOR_PAINT, true)
	b.add_sign("JUMP GAPS", Vector3(x, 0.02, 5.4), 0.0, 1.2, GrayboxBuilder.COLOR_TEXT, true)
	b.add_sign("SPACE  ·  SPRINT FOR THE LONG ONE", Vector3(x, 0.02, 6.3), 0.0, 0.55, GrayboxBuilder.COLOR_PAINT, true)
	b.add_ramp(Vector3(x, 0.0, -25.5), Vector3(x, top, -22.0), 3.0)
	b.add_lamp(x - 2.6, -9.5, GrayboxBuilder.COLOR_ECHO, 3.6, 1.6)


func _build_vault_row() -> void:
	var b: GrayboxBuilder = _builder
	var heights: PackedFloat32Array = [0.6, 1.0, 1.25, 1.7, 2.3, 2.6, 3.2]
	var notes: PackedStringArray = ["VAULT", "VAULT", "VAULT", "JUMP + PULL UP", "JUMP + GRAB", "JUMP + GRAB", "TOO HIGH"]
	for i: int in heights.size():
		var x: float = 7.0 + i * 2.6
		b.add_block(x, 1.0, 2.0, 2.4, heights[i], 0.0, true)
		b.add_sign("%.1f M" % heights[i], Vector3(x, minf(heights[i], 2.4) * 0.5 + 0.12, 2.215), 0.0, 0.72, GrayboxBuilder.COLOR_PAINT)
		b.add_sign(notes[i], Vector3(x, 0.02, 3.0), 0.0, 0.4, GrayboxBuilder.COLOR_TEXT, true)
	b.add_sign("VAULT AND CLIMB", Vector3(14.8, 0.02, 4.6), 0.0, 1.2, GrayboxBuilder.COLOR_TEXT, true)
	b.add_sign("FACE A YELLOW EDGE  ·  SPACE", Vector3(14.8, 0.02, 5.5), 0.0, 0.55, GrayboxBuilder.COLOR_PAINT, true)
	b.add_lamp(5.0, 3.6)
	b.add_lamp(25.0, 3.6, GrayboxBuilder.COLOR_SODIUM, 4.2, 2.6, true)


func _build_shimmy_wall() -> void:
	var b: GrayboxBuilder = _builder
	# A long ledge. The crates on top leave room to hang but not to climb up,
	# so the only way along the middle is to shimmy.
	b.add_block(14.0, -8.0, 13.0, 1.5, 2.3, 0.0, true)
	b.add_block(14.0, -8.25, 8.0, 1.0, 1.4, 2.3, false, GrayboxBuilder.COLOR_WALL)
	b.add_sign("SHIMMY LEDGE", Vector3(14.0, 0.02, -5.4), 0.0, 1.2, GrayboxBuilder.COLOR_TEXT, true)
	b.add_sign("A / D  SHIMMY   ·   W  CLIMB   ·   C  DROP", Vector3(14.0, 0.02, -4.5), 0.0, 0.55, GrayboxBuilder.COLOR_PAINT, true)
	b.add_strip(Vector3(14.0, 3.74, -7.74), Vector3(8.0, 0.05, 0.05), GrayboxBuilder.COLOR_MAGENTA)


func _build_ladder_tower() -> void:
	var b: GrayboxBuilder = _builder
	var top: float = 5.0
	b.add_block(14.0, -19.0, 5.0, 5.0, top, 0.0, false, GrayboxBuilder.COLOR_BLOCK)
	# Railings on three sides of the roof.
	b.add_block(16.4, -19.0, 0.2, 5.0, 1.0, top, false, GrayboxBuilder.COLOR_WALL)
	b.add_block(14.0, -21.4, 5.0, 0.2, 1.0, top, false, GrayboxBuilder.COLOR_WALL)
	# Stepped descent on the west side: drop down, or climb back up ledge by ledge.
	b.add_block(9.5, -19.0, 4.0, 5.0, 3.6, 0.0, true)
	b.add_block(6.0, -19.0, 3.0, 5.0, 2.3, 0.0, true)
	b.add_block(3.6, -19.0, 1.8, 5.0, 1.1, 0.0, true)

	var ladder := Ladder.new()
	ladder.name = "TowerLadder"
	ladder.height = top
	ladder.position = Vector3(14.0, 0.0, -16.5)
	add_child(ladder)
	_add_ladder_visual(ladder)
	b.add_sign("LADDER", Vector3(14.0, 0.02, -14.2), 0.0, 1.2, GrayboxBuilder.COLOR_TEXT, true)
	b.add_sign("E  CLIMB   ·   W / S   ·   SPACE  JUMP OFF", Vector3(14.0, 0.02, -13.3), 0.0, 0.55, GrayboxBuilder.COLOR_ECHO, true)
	b.add_lamp(17.4, -15.4, GrayboxBuilder.COLOR_ECHO, 3.8, 2.0)


func _add_ladder_visual(ladder: Ladder) -> void:
	var b: GrayboxBuilder = _builder
	var base: Vector3 = ladder.position
	for side: float in [-0.26, 0.26]:
		b.add_strip(base + Vector3(side, ladder.height * 0.5, 0.05), Vector3(0.05, ladder.height, 0.05), GrayboxBuilder.COLOR_ECHO)
	var rungs: int = int(ladder.height / 0.3)
	for i: int in range(1, rungs + 1):
		b.add_strip(base + Vector3(0.0, i * 0.3, 0.05), Vector3(0.5, 0.035, 0.035), GrayboxBuilder.COLOR_ECHO)


func _build_crouch_tunnel() -> void:
	var b: GrayboxBuilder = _builder
	var x: float = 2.0
	var clearance: float = 1.55
	for side: float in [-1.3, 1.3]:
		b.add_block(x + side, -18.0, 0.6, 9.0, clearance + 0.5, 0.0, false, GrayboxBuilder.COLOR_WALL)
	b.add_block(x, -18.0, 3.2, 9.0, 0.5, clearance, false, GrayboxBuilder.COLOR_WALL)
	b.add_strip(Vector3(x, clearance - 0.02, -18.0), Vector3(0.06, 0.03, 8.6), GrayboxBuilder.COLOR_MAGENTA)
	for light_z: float in [-15.5, -18.0, -20.5]:
		var tunnel_light := OmniLight3D.new()
		tunnel_light.position = Vector3(x, clearance - 0.25, light_z)
		tunnel_light.light_color = GrayboxBuilder.COLOR_MAGENTA
		tunnel_light.light_energy = 0.7
		tunnel_light.omni_range = 3.2
		add_child(tunnel_light)
	b.add_sign("CROUCH TUNNEL", Vector3(x, 0.02, -12.2), 0.0, 1.0, GrayboxBuilder.COLOR_TEXT, true)
	b.add_sign("C  TOGGLE CROUCH", Vector3(x, 0.02, -11.5), 0.0, 0.5, GrayboxBuilder.COLOR_MAGENTA, true)
	# Waist-high cover to practise sneaking behind.
	b.add_block(-1.5, -27.0, 3.0, 0.4, 1.0, 0.0, false, GrayboxBuilder.COLOR_BLOCK)
	b.add_block(4.5, -27.0, 3.0, 0.4, 1.0, 0.0, false, GrayboxBuilder.COLOR_BLOCK)


func _build_steps_and_slopes() -> void:
	var b: GrayboxBuilder = _builder
	# Stairs with real 0.18 m steps (exercises step-up), then a platform.
	var step_count: int = 10
	for i: int in step_count:
		b.add_block(8.0 + i * 0.32, 18.0, 0.32, 3.0, 0.18 * (i + 1), 0.0, false, GrayboxBuilder.COLOR_BLOCK)
	b.add_block(13.04, 18.0, 4.0, 3.0, 1.8, 0.0, false, GrayboxBuilder.COLOR_BLOCK)
	b.add_ramp(Vector3(19.4, 0.0, 18.0), Vector3(15.04, 1.8, 18.0), 3.0)
	b.add_sign("STAIRS", Vector3(9.4, 0.02, 20.4), 0.0, 0.7, GrayboxBuilder.COLOR_TEXT, true)
	b.add_sign("RAMP 22°", Vector3(17.4, 0.02, 20.4), 0.0, 0.7, GrayboxBuilder.COLOR_TEXT, true)
	# Slopes: walkable 40°, and 55° which is too steep to stand on.
	b.add_ramp(Vector3(22.0, 0.0, 24.0), Vector3(22.0, 2.5, 21.02), 2.6)
	b.add_block(22.0, 19.5, 2.6, 3.0, 2.5, 0.0, false, GrayboxBuilder.COLOR_BLOCK)
	b.add_sign("40° OK", Vector3(22.0, 0.02, 25.0), 0.0, 0.7, GrayboxBuilder.COLOR_TEXT, true)
	b.add_ramp(Vector3(26.0, 0.0, 24.0), Vector3(26.0, 3.0, 21.9), 2.6)
	b.add_block(26.0, 20.4, 2.6, 3.0, 3.0, 0.0, false, GrayboxBuilder.COLOR_BLOCK)
	b.add_sign("55° TOO STEEP", Vector3(26.0, 0.02, 25.0), 0.0, 0.7, GrayboxBuilder.COLOR_MAGENTA, true)
	# Curbs: the first three step up automatically; the last needs a vault.
	var curbs: PackedFloat32Array = [0.15, 0.25, 0.35, 0.6]
	for i: int in curbs.size():
		var x: float = 8.5 + i * 3.0
		b.add_block(x, 25.0, 2.4, 1.6, curbs[i], 0.0, i == curbs.size() - 1)
		b.add_sign("%.2f M" % curbs[i], Vector3(x, 0.02, 26.5), 0.0, 0.55, GrayboxBuilder.COLOR_TEXT, true)
	b.add_sign("STEPS AND SLOPES", Vector3(14.0, 0.02, 14.8), 0.0, 1.2, GrayboxBuilder.COLOR_TEXT, true)
	b.add_lamp(6.4, 21.5)
	b.add_lamp(20.0, 26.5)


func _build_camera_corridor() -> void:
	var b: GrayboxBuilder = _builder
	# Tight corridor with a turn, then a low-ceilinged room: the camera must
	# pull in without clipping and ease back out afterwards.
	b.add_block(-13.9, 22.0, 0.4, 12.0, 3.5, 0.0, false, GrayboxBuilder.COLOR_WALL)
	b.add_block(-15.9, 20.8, 0.4, 9.6, 3.5, 0.0, false, GrayboxBuilder.COLOR_WALL)
	b.add_block(-20.85, 25.8, 10.3, 0.4, 3.5, 0.0, false, GrayboxBuilder.COLOR_WALL)
	b.add_block(-19.85, 27.8, 12.3, 0.4, 3.5, 0.0, false, GrayboxBuilder.COLOR_WALL)
	# Low room at the end of the corridor.
	b.add_block(-29.0, 22.0, 6.0, 12.0, 0.4, 2.2, false, GrayboxBuilder.COLOR_WALL)
	for pillar_z: float in [18.5, 22.0, 25.5]:
		b.add_block(-27.0, pillar_z, 0.6, 0.6, 2.2, 0.0, false, GrayboxBuilder.COLOR_BLOCK)
		b.add_block(-31.0, pillar_z, 0.6, 0.6, 2.2, 0.0, false, GrayboxBuilder.COLOR_BLOCK)
	b.add_strip(Vector3(-29.0, 2.17, 22.0), Vector3(0.06, 0.03, 11.0), GrayboxBuilder.COLOR_SODIUM)
	b.add_sign("CAMERA CORRIDOR", Vector3(-14.9, 0.02, 14.8), 0.0, 0.9, GrayboxBuilder.COLOR_TEXT, true)
	b.add_lamp(-11.8, 17.0)
	var room_light := OmniLight3D.new()
	room_light.position = Vector3(-29.0, 1.8, 22.0)
	room_light.light_color = GrayboxBuilder.COLOR_SODIUM
	room_light.light_energy = 1.6
	room_light.omni_range = 9.0
	add_child(room_light)


func _build_lock_on_range() -> void:
	var b: GrayboxBuilder = _builder
	var positions: Array[Vector3] = [Vector3(-12.0, 0.0, -36.0), Vector3(-8.5, 0.0, -40.0), Vector3(-5.0, 0.0, -36.0)]
	for i: int in positions.size():
		var dummy := TargetDummy.new()
		dummy.name = "TargetDummy%d" % (i + 1)
		dummy.position = positions[i]
		add_child(dummy)
	b.add_sign("LOCK-ON RANGE", Vector3(-8.5, 0.02, -31.2), 0.0, 1.2, GrayboxBuilder.COLOR_TEXT, true)
	b.add_sign("TAB  LOCK   ·   FLICK MOUSE TO SWITCH", Vector3(-8.5, 0.02, -30.3), 0.0, 0.55, GrayboxBuilder.COLOR_ECHO, true)


# --- Milestone 2: combat and stealth ------------------------------------------

func _build_combat_yard() -> void:
	var b: GrayboxBuilder = _builder
	var cx: float = 30.0
	var cz: float = -36.0
	# Low cover blocks to break line of sight with the Spitter.
	b.add_block(cx - 4.0, cz + 1.0, 2.4, 0.6, 1.3, 0.0, false, GrayboxBuilder.COLOR_BLOCK)
	b.add_block(cx + 3.5, cz - 3.0, 0.6, 2.4, 1.3, 0.0, false, GrayboxBuilder.COLOR_BLOCK)
	for corner: Vector2 in [Vector2(-8, -9), Vector2(8, -9), Vector2(-8, 9), Vector2(8, 9)]:
		b.add_strip(Vector3(cx + corner.x, 0.012, cz + corner.y), Vector3(1.6, 0.02, 0.08), GrayboxBuilder.COLOR_MAGENTA)
		b.add_strip(Vector3(cx + corner.x, 0.012, cz + corner.y), Vector3(0.08, 0.02, 1.6), GrayboxBuilder.COLOR_MAGENTA)
	b.add_sign("COMBAT YARD", Vector3(cx, 0.02, cz + 11.5), 0.0, 1.3, GrayboxBuilder.COLOR_TEXT, true)
	b.add_sign("LMB LIGHT  ·  RMB HEAVY  ·  Q BLOCK / PARRY  ·  F DODGE", Vector3(cx, 0.02, cz + 12.6), 0.0, 0.5, GrayboxBuilder.COLOR_ECHO, true)
	b.add_lamp(cx - 9.0, cz + 9.5, GrayboxBuilder.COLOR_SODIUM, 4.6, 3.0, true)
	b.add_lamp(cx + 9.0, cz - 9.5, GrayboxBuilder.COLOR_MAGENTA, 4.6, 2.4)
	add_enemy_spawn("hollow", Vector3(cx - 3.0, 0.05, cz + 4.0), 180.0,
			[Vector3(cx - 5.0, 0.0, cz + 5.0), Vector3(cx + 5.0, 0.0, cz + 5.0)])
	add_enemy_spawn("hollow", Vector3(cx + 4.0, 0.05, cz - 1.0), 180.0)
	add_enemy_spawn("skitter", Vector3(cx - 5.0, 0.05, cz - 5.0), 180.0,
			[Vector3(cx - 6.0, 0.0, cz - 6.0), Vector3(cx - 1.0, 0.0, cz - 7.0)])
	add_enemy_spawn("spitter", Vector3(cx + 5.5, 0.05, cz - 7.0), 180.0)


func _build_bulwark_pen() -> void:
	var b: GrayboxBuilder = _builder
	var cx: float = 31.0
	var cz: float = -8.0
	for side: float in [-1.0, 1.0]:
		b.add_block(cx + side * 6.5, cz, 0.5, 13.0, 1.6, 0.0, false, GrayboxBuilder.COLOR_WALL)
	b.add_block(cx, cz - 6.5, 13.5, 0.5, 1.6, 0.0, false, GrayboxBuilder.COLOR_WALL)
	b.add_sign("BULWARK", Vector3(cx, 0.02, cz + 8.2), 0.0, 1.2, GrayboxBuilder.COLOR_TEXT, true)
	b.add_sign("ARMOURED  ·  BREAK IT WITH HEAVY ATTACKS OR THE AXE (2)", Vector3(cx, 0.02, cz + 9.2), 0.0, 0.5, GrayboxBuilder.COLOR_ECHO, true)
	b.add_lamp(cx - 5.5, cz + 6.0, GrayboxBuilder.COLOR_SODIUM, 4.6, 2.8, true)
	add_enemy_spawn("bulwark", Vector3(cx, 0.05, cz - 3.0), 180.0)


func _build_stealth_yard() -> void:
	var b: GrayboxBuilder = _builder
	var cx: float = -30.0
	var cz: float = -36.0
	# Walls to sneak along, a roofed dark corner and two patches of tall grass.
	b.add_block(cx + 2.0, cz + 4.0, 6.0, 0.5, 2.2, 0.0, false, GrayboxBuilder.COLOR_WALL)
	b.add_block(cx - 4.0, cz - 2.0, 0.5, 6.0, 2.2, 0.0, false, GrayboxBuilder.COLOR_WALL)
	b.add_block(cx + 5.0, cz - 5.0, 0.5, 5.0, 2.2, 0.0, false, GrayboxBuilder.COLOR_WALL)
	b.add_block(cx - 5.5, cz + 7.0, 5.0, 5.0, 0.3, 2.6, false, GrayboxBuilder.COLOR_WALL)
	for post: Vector2 in [Vector2(-7.8, 4.7), Vector2(-3.2, 4.7), Vector2(-7.8, 9.3), Vector2(-3.2, 9.3)]:
		b.add_block(cx + post.x, cz + post.y, 0.3, 0.3, 2.6, 0.0, false, GrayboxBuilder.COLOR_BLOCK)
	_add_stealth_zone(StealthZone.Kind.SHADOW, Vector3(cx - 5.5, 0.0, cz + 7.0), Vector3(5.0, 2.6, 5.0))
	_add_grass(Vector3(cx + 1.0, 0.0, cz - 1.0), Vector2(5.0, 4.0))
	_add_grass(Vector3(cx + 6.5, 0.0, cz + 7.5), Vector2(4.0, 4.0))
	b.add_sign("STEALTH YARD", Vector3(cx, 0.02, cz + 12.5), 0.0, 1.3, GrayboxBuilder.COLOR_TEXT, true)
	b.add_sign("CROUCH (C)  ·  TAKEDOWN FROM BEHIND (E)  ·  THROW BOTTLE (G)", Vector3(cx, 0.02, cz + 13.6), 0.0, 0.5, GrayboxBuilder.COLOR_ECHO, true)
	b.add_sign("TALL GRASS  ·  CROUCH TO HIDE", Vector3(cx + 1.0, 0.02, cz + 1.9), 0.0, 0.4, GrayboxBuilder.COLOR_TEXT, true)
	b.add_sign("SHADOW  ·  HARDER TO SEE", Vector3(cx - 5.5, 0.02, cz + 10.4), 0.0, 0.4, GrayboxBuilder.COLOR_TEXT, true)
	b.add_lamp(cx + 8.5, cz - 8.5, GrayboxBuilder.COLOR_SODIUM, 4.6, 2.6, true)
	var crate := ThrowablePickup.new()
	crate.position = Vector3(cx + 9.0, 0.0, cz + 11.0)
	add_child(crate)
	add_enemy_spawn("hollow", Vector3(cx - 1.0, 0.05, cz + 1.5), 0.0,
			[Vector3(cx - 1.5, 0.0, cz + 2.0), Vector3(cx - 1.5, 0.0, cz - 7.0)])
	add_enemy_spawn("hollow", Vector3(cx + 7.5, 0.05, cz - 2.0), 0.0,
			[Vector3(cx + 7.5, 0.0, cz + 2.0), Vector3(cx + 7.5, 0.0, cz - 8.0), Vector3(cx + 2.5, 0.0, cz - 8.0)])
	add_enemy_spawn("hollow", Vector3(cx - 7.0, 0.05, cz - 7.0), 0.0)


func _add_stealth_zone(kind: StealthZone.Kind, at: Vector3, size: Vector3) -> void:
	var zone := StealthZone.new()
	zone.kind = kind
	zone.size = size
	zone.position = at
	add_child(zone)


## A patch of tall grass: one MultiMesh of blades plus a hiding volume.
func _add_grass(at: Vector3, area: Vector2) -> void:
	_add_stealth_zone(StealthZone.Kind.HIDING, at, Vector3(area.x, 1.6, area.y))
	var blade := BoxMesh.new()
	blade.size = Vector3(0.05, 1.0, 0.012)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.1, 0.2, 0.13)
	material.roughness = 1.0
	blade.material = material
	var count: int = int(area.x * area.y * 55.0)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = blade
	multimesh.instance_count = count
	var random := RandomNumberGenerator.new()
	random.seed = int(at.x * 31.0 + at.z * 17.0)
	for i: int in count:
		var height: float = random.randf_range(0.7, 1.25)
		var basis := Basis(Vector3.UP, random.randf() * TAU) * Basis(Vector3.RIGHT, random.randf_range(-0.22, 0.22))
		basis = basis.scaled(Vector3(1.0, height, 1.0))
		var offset := Vector3(random.randf_range(-0.5, 0.5) * area.x, height * 0.5, random.randf_range(-0.5, 0.5) * area.y)
		multimesh.set_instance_transform(i, Transform3D(basis, offset))
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.position = at
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
