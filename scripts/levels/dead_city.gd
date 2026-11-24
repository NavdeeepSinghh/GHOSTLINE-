class_name DeadCity
extends StoryLevel
## Area 1, the Dead City: Kael leaves his rooftop camp, crosses the district,
## restores power to the broadcast tower, survives what the noise brings and
## pins the signal's source to Meridian (Act 1).
##
## Geometry comes from DeadCityLayout; this script owns lighting and weather,
## everything Kael can use, the enemies, and the story flow.

enum Stage { PROLOGUE, REACH_MAIN, FIND_WAY, REACH_TOWER, RESTORE_POWER, JUNCTION, DEFEND, TRANSMIT, DONE }

const TUNING_PATH: String = "res://data/levels/dead_city.json"
const STORY_PATH: String = "res://data/story/dead_city.json"
const DOCUMENTS_PATH: String = "res://data/documents/dead_city.json"
const KILL_PLANE_Y: float = -20.0
## Stage -> where the objective marker points (stages without an entry have none).
## Where each fuse lies (marker targets).
const FUSE_SPOTS: Dictionary = {"fuse_metro": Vector3(-3.2, -4.0, -40.0), "fuse_school": Vector3(11.2, 0.0, -49.2)}
const WAYPOINTS: Dictionary = {
	0: Vector3(-29.0, 1.0, 55.5),
	1: Vector3(0.0, 1.0, -3.0),
	2: Vector3(-20.0, 1.0, 8.5),
	3: Vector3(-20.0, 1.0, -72.0),
	5: Vector3(-7.2, 1.3, -92.0),
	7: Vector3(-5.8, 1.3, -98.0),
	8: Vector3(40.0, 1.0, 54.0),
}
const JOURNAL_IDS: PackedStringArray = ["dc_mara_1", "dc_mara_2", "dc_mara_3"]

var stage: Stage = Stage.PROLOGUE
var dressing: DeadCityDressing
var weather: Weather
var layout: DeadCityLayout
var fuses_found: int = 0

var _builder: CityBuilder
var _environment: Environment
var _moon: DirectionalLight3D
var _wave: Array[Enemy] = []
var _tick: float = 0.0
var _powered_lights: Array[Light3D] = []
var _pharmacy_lights: Array[Light3D] = []
var _metro_ambience: bool = false
## The Echo showing itself at the top of the mast (cyan), during transmissions.
var _echo_flare: Node3D


func _ready() -> void:
	screen_tint = Color(0.96, 1.0, 1.05)
	title = "THE DEAD CITY"
	subtitle = "ACT 1"
	starting_weapons = ["rebar_pipe"]
	setup_story("dc", "the Dead City", TUNING_PATH, STORY_PATH, DOCUMENTS_PATH)
	default_surface = "wet"
	spawn_position = DeadCityLayout.SPAWN
	spawn_yaw = 0.0
	GameState.current_area = "dead_city"

	_builder = CityBuilder.new()
	_builder.name = "Geometry"
	add_child(_builder)
	layout = DeadCityLayout.new()
	layout.build(_builder)
	dressing = DeadCityDressing.new()
	dressing.build(_builder, layout)
	interiors = layout.interiors
	surfaces = layout.surfaces
	_build_lights_and_signs()
	_builder.commit()
	_build_environment()
	dressing.build_effects(self, layout)
	# The East Avenue gate is baked in as a wall, so enemies do not try to path
	# through it while it is shut; opening it rebuilds the navmesh.
	objects["gate"] = _make_door(Vector3(40.0, 1.6, -38.0), Vector3(3.2, 3.2, 0.25), Color(0.2, 0.22, 0.24))
	bake_navigation(AABB(Vector3(-60.0, -7.0, -106.0), Vector3(120.0, 11.0, 176.0)))
	_build_stealth_zones()
	_build_doors_and_ladders()
	_build_interactables()
	_build_triggers()
	_register_enemies()
	spawn_enemies()

	weather = Weather.new()
	weather.name = "Weather"
	weather.hearing_scale = float(tuning.get("rain_hearing_scale", 0.7))
	weather.particle_counts = tuning.get("rain_particles", weather.particle_counts)
	var interval: Array = tuning.get("lightning_interval", [18.0, 45.0])
	weather.lightning_interval = Vector2(float(interval[0]), float(interval[1]))
	weather.flash_light = _moon
	add_child(weather)
	AudioManager.set_ambience(&"city", &"city_drone_loop", -16.0)
	AudioManager.set_ambience(&"tunnel", &"tunnel_loop", AudioManager.SILENT_DB)

	SettingsManager.register_world(_environment, _moon)
	_update_objective()


func _exit_tree() -> void:
	SettingsManager.unregister_world(_environment)
	AudioManager.clear_ambience()
	super._exit_tree()


func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Player
		if _player == null:
			return
	var position_now: Vector3 = _player.global_position
	if position_now.y < KILL_PLANE_Y:
		_player.teleport(spawn_position, spawn_yaw)
	var camera: Camera3D = get_viewport().get_camera_3d()
	var indoors: bool = is_sheltered(camera.global_position if camera != null else position_now)
	weather.set_sheltered(indoors)
	var underground: bool = position_now.y < -1.5
	if underground != _metro_ambience:
		_metro_ambience = underground
		AudioManager.set_ambience(&"tunnel", &"tunnel_loop", -10.0 if underground else AudioManager.SILENT_DB)
		AudioManager.set_ambience(&"city", &"city_drone_loop", -26.0 if underground else -16.0)
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.5
		_update_enemy_sleep(position_now)
		_update_wave()
		_check_hints(position_now)


# --- Queries ---------------------------------------------------------------------

func journal_pages_found() -> int:
	var found: int = 0
	for page: String in JOURNAL_IDS:
		if GameState.collected_documents.has(page):
			found += 1
	return found


func get_tour_stops() -> Array[Array]:
	return [
		[Vector3(-11.0, 13.5, 76.0), Vector3(-8.0, 8.0, 40.0)],
		[Vector3(-30.0, 3.0, 52.0), Vector3(-6.0, 1.5, 49.0)],
		[Vector3(18.0, 2.4, 49.0), Vector3(40.0, 1.5, 51.0)],
		[Vector3(0.0, 3.0, 30.0), Vector3(0.0, 2.0, -8.0)],
		[Vector3(-20.0, 3.2, -6.0), Vector3(14.0, 2.0, -11.0)],
		[Vector3(34.0, 2.6, -8.0), Vector3(10.0, 2.5, -4.0)],
		[Vector3(-20.0, -3.0, -8.0), Vector3(-22.0, -4.0, -50.0)],
		[Vector3(-20.0, 2.5, -72.0), Vector3(0.0, 6.0, -90.0)],
		[Vector3(16.0, 2.2, -66.0), Vector3(-2.0, 1.2, -78.0)],
		[Vector3(-14.0, 3.0, -86.0), Vector3(6.0, 1.2, -74.0)],
		[Vector3(30.0, 9.5, -40.0), Vector3(0.0, 20.0, -92.0)],
		[Vector3(40.0, 4.0, -24.0), Vector3(30.0, 2.0, -10.0)],
	]


# --- Story ----------------------------------------------------------------------

func start_story(player: Player, skip_intro: bool) -> void:
	_player = player
	if skip_intro:
		_begin_play()
	else:
		play_prologue()


## The opening cinematic on the rooftop: the transmission, and Oren.
func play_prologue() -> void:
	var shots: Array = [
		{"from": Vector3(-12.0, 17.0, 77.0), "look": Vector3(-10.0, 10.0, 58.0), "to": Vector3(-12.0, 13.0, 76.0), "seconds": 7.0},
		{"from": Vector3(-11.4, 10.4, 67.8), "look": Vector3(-13.0, 9.9, 66.0), "to": Vector3(-11.8, 10.3, 67.4), "seconds": 5.0, "fov": 45.0},
		{"from": Vector3(-12.0, 21.0, 58.0), "look": Vector3(0.0, 56.0, -92.0), "to": Vector3(-11.0, 25.0, 46.0), "seconds": 11.5, "fov": 34.0},
		{"from": Vector3(-7.4, 10.7, 66.0), "look": Vector3(-10.0, 10.1, 70.0), "to": Vector3(-7.9, 10.6, 65.6), "seconds": 11.5, "fov": 45.0},
		{"from": Vector3(-14.0, 10.9, 73.2), "look": Vector3(-9.4, 10.2, 64.0), "to": Vector3(-13.2, 10.7, 72.6), "seconds": 13.0},
	]
	var events: Array = [
		{"at": 11.6, "call": weather.strike},
		{"at": 11.8, "call": set_echo_flare.bind(true)},
		{"at": 24.0, "call": set_echo_flare.bind(false)},
	]
	EventBus.fade_requested.emit(1.0, 0.0)
	EventBus.fade_requested.emit(0.0, 2.5)
	cinematic.play(shots, story.get("prologue", []), _player, events)
	await cinematic.finished
	_begin_play()


func _begin_play() -> void:
	_set_stage(Stage.PROLOGUE)
	EventBus.area_title_requested.emit(title, subtitle)
	_hint("move", 8.0)


## The Act 1 ending at the transmitter console.
func play_ending() -> void:
	_set_stage(Stage.DONE)
	var kael: Vector3 = _player.global_position + Vector3.UP * 1.4 if _player != null else Vector3(-5.0, 1.4, -97.0)
	var shots: Array = [
		{"from": Vector3(-1.5, 2.3, -92.5), "look": Vector3(-5.8, 1.2, -98.9), "to": Vector3(-2.5, 2.0, -94.0), "seconds": 6.5, "fov": 50.0},
		{"from": Vector3(10.0, 1.6, -74.0), "look": Vector3(0.0, 40.0, -92.0), "to": Vector3(9.0, 1.6, -76.0), "seconds": 5.0},
		{"from": Vector3(0.0, 20.0, -60.0), "look": Vector3(0.0, 30.0, -92.0), "to": Vector3(0.0, 36.0, -28.0), "seconds": 14.5},
		{"from": kael + Vector3(3.0, 0.4, 3.2), "look": kael, "to": kael + Vector3(2.2, 0.3, 2.6), "seconds": 11.5, "fov": 42.0},
		{"from": Vector3(0.0, 42.0, -20.0), "look": Vector3(60.0, 44.0, -260.0), "to": Vector3(4.0, 46.0, -30.0), "seconds": 5.0, "fov": 48.0},
	]
	var events: Array = [
		{"at": 6.5, "call": weather.strike},
		{"at": 6.4, "call": set_echo_flare.bind(true)},
		{"at": 30.0, "call": set_echo_flare.bind(false)},
		{"at": 38.5, "call": func() -> void: EventBus.fade_requested.emit(1.0, 3.0)},
	]
	cinematic.play(shots, story.get("ending", []), _player, events)
	await cinematic.finished
	EventBus.fade_requested.emit(0.0, 1.5)
	GameState.set_flag("act1_complete")
	(objects["exit_road"] as Usable).set_enabled(true)
	EventBus.act_completed.emit("Act 1: The Dead City", get_summary_rows())
	_update_objective()


func set_echo_flare(shown: bool) -> void:
	_echo_flare.visible = shown
	if shown:
		AudioManager.play_ui(&"echo_swell", -14.0, &"SFX")


func get_summary_rows() -> Array:
	var seconds: int = int(GameState.playtime_seconds)
	return [
		["Time", "%d:%02d" % [seconds / 60, seconds % 60]],
		["Documents found", "%d / %d" % [GameState.collected_documents.size(), documents.size()]],
		["Hollows silenced", str(enemies_defeated)],
		["Silent takedowns", str(takedowns)],
		["Side objectives", "%d / 2" % (int(GameState.has_flag("dc_pharmacy_power")) + int(GameState.has_flag("dc_journal_cache")))],
	]


func _set_stage(next: Stage) -> void:
	stage = next
	_update_objective()


func _advance_to(next: Stage) -> void:
	if int(next) > int(stage):
		_set_stage(next)


## Once a second: keep the fuse marker on the nearer fuse as Kael moves.
func tick_stuck(seconds: float) -> void:
	super.tick_stuck(seconds)
	if stage == Stage.RESTORE_POWER:
		MissionManager.waypoint = _waypoint()


func current_stage_key() -> String:
	var keys: PackedStringArray = ["prologue", "reach_main", "find_way", "reach_tower", "restore_power", "junction", "defend", "transmit", "done"]
	return keys[int(stage)]


func _update_objective() -> void:
	var texts: Dictionary = story.get("objectives", {})
	var keys: PackedStringArray = ["prologue", "reach_main", "find_way", "reach_tower", "restore_power",
			"junction", "defend", "transmit", "done"]
	var text: String = str(texts.get(keys[int(stage)], ""))
	if stage == Stage.RESTORE_POWER:
		text = text % fuses_found
	var sides: Dictionary = story.get("side_objectives", {})
	var side: String = ""
	var pages: int = journal_pages_found()
	if pages > 0 and not GameState.has_flag("dc_journal_cache"):
		side = str(sides.get("journal", "")) % pages
	elif GameState.has_flag("dc_pharmacy_seen") and not GameState.has_flag("dc_pharmacy_power"):
		side = str(sides.get("pharmacy", ""))
	var done: Array[String] = []
	for i: int in int(stage):
		done.append(str(texts.get(keys[i], "")).replace(": find fuses (%d / 2)", ""))
	MissionManager.mission_title = "Act 1: Static"
	MissionManager.set_completed(done)
	if pages > 0:
		MissionManager.set_side("journal", str(sides.get("journal", "")) % pages, GameState.has_flag("dc_journal_cache"))
	if GameState.has_flag("dc_pharmacy_seen") or GameState.has_flag("dc_pharmacy_power"):
		MissionManager.set_side("pharmacy", str(sides.get("pharmacy", "")), GameState.has_flag("dc_pharmacy_power"))
	MissionManager.set_objective(text, _waypoint())
	EventBus.objective_changed.emit(text, side)


## Where the objective marker points. While Kael is looking for fuses it points
## at the nearest one he has not taken yet.
func _waypoint() -> Variant:
	if stage == Stage.RESTORE_POWER:
		var player: Player = find_player()
		var best: Variant = null
		var best_distance: float = INF
		for key: String in FUSE_SPOTS:
			if _taken.get(key, false):
				continue
			var spot: Vector3 = FUSE_SPOTS[key]
			var distance: float = player.global_position.distance_to(spot) if player != null else 0.0
			if best == null or distance < best_distance:
				best = spot
				best_distance = distance
		return best if best != null else WAYPOINTS.get(int(Stage.JUNCTION))
	return WAYPOINTS.get(int(stage))


func _check_hints(position_now: Vector3) -> void:
	for enemy: Enemy in get_enemies():
		if enemy.is_asleep() or enemy.is_dead():
			continue
		if enemy.is_aware():
			_hint("combat", 9.0)
		if enemy.has_armor() and enemy.global_position.distance_to(position_now) < 16.0:
			_hint("bulwark", 8.0)


# --- Checkpoints, enemies, the climax ---------------------------------------------

func reset_encounters() -> void:
	_wave.clear()
	super.reset_encounters()
	if stage == Stage.DEFEND:
		_spawn_wave.call_deferred()


func prepare_benchmark(player: Player) -> void:
	# A fixed fight in the plaza so the route includes AI, animation and combat effects.
	player.god_mode = true
	player.teleport(Vector3(4.0, 0.1, -80.0), PI)
	_spawn_wave()
	for enemy: Enemy in get_enemies():
		if enemy.global_position.z < -58.0:
			enemy.alert(player.global_position)


func _spawn_wave() -> void:
	_wave.clear()
	var target: Vector3 = _player.global_position if _player != null else Vector3(0.0, 0.0, -80.0)
	for entry: Dictionary in tuning.get("climax_wave", []):
		var at: Array = entry["position"]
		var enemy: Enemy = spawn_enemy(str(entry["type"]), Vector3(float(at[0]), float(at[1]), float(at[2])))
		_wave.append(enemy)
		enemy.alert.call_deferred(target)


func _update_wave() -> void:
	if stage != Stage.DEFEND or _wave.is_empty():
		return
	for enemy: Enemy in _wave:
		if is_instance_valid(enemy) and not enemy.is_dead():
			# Keep stragglers coming rather than leaving the fight unfinished.
			if not enemy.is_aware() and _player != null:
				enemy.alert(_player.global_position)
			return
	_wave.clear()
	_set_stage(Stage.TRANSMIT)
	_radio("wave_clear")
	(objects["console"] as Usable).set_enabled(true)
	set_checkpoint("dc_tower_clear", Vector3(0.0, 0.1, -86.5), 0.0)


# --- Lighting, weather and atmosphere ------------------------------------------------

func _build_environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.008, 0.013, 0.022)
	sky_material.sky_horizon_color = Color(0.07, 0.1, 0.11)
	sky_material.ground_bottom_color = Color(0.008, 0.012, 0.018)
	sky_material.ground_horizon_color = Color(0.07, 0.1, 0.11)
	sky_material.sky_curve = 0.09
	sky_material.sun_angle_max = 6.0
	var sky := Sky.new()
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_128

	_environment = Environment.new()
	_environment.background_mode = Environment.BG_SKY
	_environment.sky = sky
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_environment.ambient_light_energy = 1.35
	_environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	_environment.tonemap_exposure = 1.2
	_environment.glow_enabled = true
	_environment.glow_intensity = 0.85
	_environment.glow_bloom = 0.1
	_environment.glow_hdr_threshold = 1.0
	_environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	_environment.ssao_enabled = true
	_environment.ssao_radius = 1.1
	_environment.ssao_intensity = 1.8
	_environment.ssr_enabled = true
	_environment.ssr_max_steps = 48
	_environment.ssr_fade_in = 0.2
	_environment.ssr_fade_out = 2.5
	_environment.fog_enabled = true
	_environment.fog_light_color = Color(0.075, 0.11, 0.125)
	_environment.fog_density = 0.007
	_environment.fog_sky_affect = 0.5
	_environment.fog_height = 30.0
	_environment.fog_height_density = 0.02
	_environment.volumetric_fog_enabled = true
	_environment.volumetric_fog_density = 0.028
	_environment.volumetric_fog_albedo = Color(0.66, 0.74, 0.78)
	_environment.volumetric_fog_emission = Color(0.02, 0.032, 0.036)
	_environment.volumetric_fog_emission_energy = 0.7
	_environment.volumetric_fog_anisotropy = 0.6
	_environment.volumetric_fog_length = 80.0
	_environment.volumetric_fog_ambient_inject = 0.3
	_environment.adjustment_enabled = true
	_environment.adjustment_contrast = 1.12
	_environment.adjustment_saturation = 0.92
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	world_environment.environment = _environment
	add_child(world_environment)

	_moon = DirectionalLight3D.new()
	_moon.name = "Moon"
	_moon.rotation_degrees = Vector3(-52.0, 148.0, 0.0)
	_moon.light_color = Color(0.56, 0.72, 0.92)
	_moon.light_energy = 0.75
	_moon.light_volumetric_fog_energy = 0.8
	_moon.shadow_enabled = true
	_moon.shadow_bias = 0.04
	_moon.shadow_normal_bias = 1.4
	_moon.shadow_blur = 1.2
	_moon.directional_shadow_blend_splits = true
	add_child(_moon)


func _build_lights_and_signs() -> void:
	var b: CityBuilder = _builder
	# Street lamps: most are dead. The lit ones mark the way north.
	b.lamp(-24.0, 56.4, true, CityBuilder.COLOR_SODIUM, 5.6, 3.4, true)
	b.lamp(12.0, 43.6, false)
	b.lamp(36.0, 56.4, true, CityBuilder.COLOR_SODIUM, 5.6, 3.0, false, 0.0, true)
	b.lamp(-52.0, 43.6, false)
	b.lamp(5.6, 22.0, true)
	b.lamp(-36.6, 28.0, false)
	b.lamp(-36.0, -2.6, true, CityBuilder.COLOR_SODIUM, 5.6, 3.2, false, 0.0, true)
	b.lamp(0.0, -17.4, true, CityBuilder.COLOR_SODIUM, 5.6, 3.4, true)
	b.lamp(24.0, -2.6, true, CityBuilder.COLOR_SODIUM, 5.6, 2.8)
	b.lamp(-14.0, -17.4, true, CityBuilder.COLOR_SODIUM, 5.6, 3.0)
	b.lamp(-5.6, 40.0, true, CityBuilder.COLOR_SODIUM, 5.6, 2.8)
	b.lamp(52.0, -17.4, true)
	b.lamp(-52.0, -17.4, false)
	b.lamp(40.0, -44.0, true, CityBuilder.COLOR_SODIUM, 5.6, 2.6)
	b.lamp(-30.0, -64.0, true, CityBuilder.COLOR_SODIUM, 5.6, 3.2, true)
	b.lamp(30.0, -62.0, false)
	b.lamp(18.0, -98.0, true, CityBuilder.COLOR_SODIUM, 5.6, 3.0, false, 0.0, true)
	b.lamp(-20.0, -100.0, false)
	# Neon that somehow still runs.
	b.neon("24H MART", Vector3(-26.0, 4.3, 44.2), 0.0, CityBuilder.COLOR_MAGENTA, 1.7)
	b.neon("PHARMACY +", Vector3(19.0, 4.4, -3.25), 180.0, CityBuilder.COLOR_RED, 1.5, true, 2.0)
	b.neon("HOTEL", Vector3(-5.75, 9.0, 24.0), 90.0, CityBuilder.COLOR_MAGENTA, 2.2, true, 2.6)
	b.neon("M  METRO", Vector3(-20.0, 4.6, 9.9), 180.0, CityBuilder.COLOR_SODIUM, 1.4, false, 1.8)
	b.neon("ON AIR", Vector3(0.0, 5.2, -83.6), 0.0, CityBuilder.COLOR_MAGENTA, 1.6, true, 1.8)
	b.sign_text("KESTREL ST", Vector3(5.9, 3.2, 43.0), -90.0, 0.7, Color(0.55, 0.6, 0.6))
	b.sign_text("HALLORAN ST AID STATION", Vector3(24.0, 2.3, 55.9), 180.0, 0.55, Color(0.6, 0.62, 0.55))
	b.sign_text("MERIDIAN BROADCAST", Vector3(0.0, 6.4, -83.6), 0.0, 1.1, Color(0.5, 0.52, 0.55))
	b.sign_text("LEARNING CENTRE", Vector3(20.0, 3.0, -60.25), 180.0, 0.8, Color(0.6, 0.55, 0.45))
	# Interiors.
	b.point_light(Vector3(-12.0, 1.3, 63.5), CityBuilder.COLOR_WARM, 0.9, 6.0)
	b.strip(Vector3(-12.0, 0.84, 63.5), Vector3(0.05, 0.12, 0.05), CityBuilder.COLOR_WARM)
	b.point_light(Vector3(-26.0, 2.6, 38.0), Color(0.6, 0.75, 0.9), 0.7, 9.0)
	b.point_light(Vector3(20.0, 2.6, -54.0), CityBuilder.COLOR_WARM, 0.6, 9.0)
	# Metro: emergency lamps and the glow of the growth.
	for lamp_z: float in [-8.0, -22.0, -36.0, -50.0]:
		b.strip(Vector3(-20.0, DeadCityLayout.METRO_Y + 3.9, lamp_z), Vector3(1.2, 0.06, 0.2), CityBuilder.COLOR_SODIUM)
		b.point_light(Vector3(-20.0, DeadCityLayout.METRO_Y + 3.4, lamp_z), Color(1.0, 0.74, 0.5), 1.9, 14.0, false, lamp_z < -20.0)
	b.point_light(Vector3(-30.5, DeadCityLayout.METRO_Y + 1.8, -54.5), CityBuilder.COLOR_ECHO, 1.6, 9.0)
	b.point_light(Vector3(-3.5, DeadCityLayout.METRO_Y + 3.0, -35.0), CityBuilder.COLOR_RED, 0.8, 7.0)
	# Lights that come on with restored power.
	for at: Vector3 in [Vector3(-4.0, 3.4, -92.0), Vector3(4.0, 3.4, -92.0)]:
		_powered_lights.append(b.point_light(at, Color(0.85, 0.92, 1.0), 2.2, 11.0))
	for level_y: float in [22.0, 42.0, DeadCityLayout.TOWER_TOP + 10.0]:
		var beacon: OmniLight3D = b.point_light(Vector3(0.0, level_y, -92.0), CityBuilder.COLOR_RED, 5.0, 26.0)
		beacon.distance_fade_enabled = false
		_powered_lights.append(beacon)
		var bulb := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.35
		sphere.height = 0.7
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.albedo_color = CityBuilder.COLOR_RED * 2.5
		sphere.material = glow
		bulb.mesh = sphere
		beacon.add_child(bulb)
	for at: Vector3 in [Vector3(14.0, 2.8, 1.0), Vector3(24.0, 2.8, 1.0), Vector3(23.5, 2.8, 8.0)]:
		_pharmacy_lights.append(b.point_light(at, Color(0.8, 0.95, 0.9), 1.8, 9.0))
	for light: Light3D in _powered_lights + _pharmacy_lights:
		light.visible = false
	var flare: OmniLight3D = b.point_light(Vector3(0.0, DeadCityLayout.TOWER_TOP + 10.5, -92.0), CityBuilder.COLOR_ECHO, 9.0, 40.0, false, true)
	flare.distance_fade_enabled = false
	flare.light_volumetric_fog_energy = 4.0
	var orb := MeshInstance3D.new()
	var orb_mesh := SphereMesh.new()
	orb_mesh.radius = 1.3
	orb_mesh.height = 2.6
	var orb_glow := StandardMaterial3D.new()
	orb_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	orb_glow.albedo_color = CityBuilder.COLOR_ECHO * 6.0
	orb_glow.disable_fog = true
	orb_mesh.material = orb_glow
	orb.mesh = orb_mesh
	flare.add_child(orb)
	flare.visible = false
	_echo_flare = flare


func _build_stealth_zones() -> void:
	for entry: Array in layout.shadows:
		var zone := StealthZone.new()
		zone.kind = StealthZone.Kind.SHADOW
		zone.size = entry[1]
		zone.position = entry[0]
		add_child(zone)
	for entry: Array in layout.grass:
		_add_grass(entry[0], entry[1])


# --- Doors, ladders, things to use ----------------------------------------------------

func _build_doors_and_ladders() -> void:
	# Created after the navigation bake so paths run through them once open.
	# (The East Avenue gate is made before the bake; see _ready.)
	objects["shutter"] = _make_door(Vector3(24.0, 1.2, 5.0), Vector3(1.8, 2.4, 0.2), Color(0.45, 0.47, 0.48))
	objects["ladder_escape"] = _make_ladder(Vector3(-29.0, 0.0, 57.95), DeadCityLayout.ROOF_B_Y, true, true)
	objects["ladder_roof"] = _make_ladder(Vector3(32.0, 0.0, -60.05), DeadCityLayout.ROOF_N2_Y, true, true)
	objects["ladder_shortcut"] = _make_ladder(Vector3(12.0, 0.0, -16.95), DeadCityLayout.ROOF_N2_Y, false, false)


func _build_interactables() -> void:
	var metro_y: float = DeadCityLayout.METRO_Y
	# The eight documents.
	_add_document("dc_fridge_note", Vector3(-16.4, 1.3, 66.3))
	_add_document("dc_mara_1", Vector3(-20.5, 1.1, 39.2))
	_add_document("dc_evac_order", Vector3(20.0, 1.0, 46.2))
	_add_document("dc_pharmacy_log", Vector3(13.5, 1.1, 1.3))
	_add_document("dc_mara_2", Vector3(-31.2, metro_y + 0.6, -36.0))
	_add_document("dc_classroom", Vector3(28.0, 1.3, -48.6))
	_add_document("dc_mara_3", Vector3(22.0, DeadCityLayout.ROOF_N2_Y + 0.3, -38.2))
	_add_document("dc_engineer_voicemail", Vector3(6.0, 0.9, -98.6))
	# Supplies.
	for at: Vector3 in [Vector3(-33.0, 0.0, 49.0), Vector3(3.5, 0.0, -21.5), Vector3(-25.0, metro_y, -6.0), Vector3(38.0, 0.0, -66.0), Vector3(51.8, 0.0, 31.0)]:
		var crate := ThrowablePickup.new()
		crate.position = at
		add_child(crate)
	var salvage: int = int(tuning.get("salvage_pickup", 25))
	var scrap_spots: Array[Vector3] = [Vector3(-8.0, 0.0, 66.0), Vector3(-32.0, 0.0, 34.0), Vector3(-15.5, 0.0, 30.0), Vector3(52.0, 0.0, 49.5),
			Vector3(-2.0, metro_y, -39.0), Vector3(-50.0, 0.0, -9.0), Vector3(40.0, 0.0, -28.5), Vector3(-29.0, 0.0, -98.0),
			Vector3(56.2, 0.0, 28.0), Vector3(54.4, 0.0, 21.4)]
	for i: int in scrap_spots.size():
		var scrap: Usable = _make_pickup("Take salvage", scrap_spots[i], Vector3(0.3, 0.16, 0.22), Color(0.4, 0.42, 0.45), Color(0.9, 0.85, 0.7))
		_track("salvage_%d" % i, scrap)
		scrap.used.connect(func(_player: Player) -> void:
			GameState.salvage += salvage
			AudioManager.play_ui(&"pickup", -8.0)
			EventBus.toast_requested.emit("Salvage +%d" % salvage, 1.8))
	# Fire Axe, clipped to the side of the fire truck.
	var axe: Usable = _make_pickup("Take the Fire Axe", Vector3(31.0, 0.0, -13.4), Vector3(0.1, 0.9, 0.28), Color(0.55, 0.08, 0.06), CityBuilder.COLOR_WARM)
	_track("axe", axe)
	axe.used.connect(func(player: Player) -> void:
		player.grant_weapon("fire_axe")
		AudioManager.play_ui(&"pickup", -6.0)
		EventBus.toast_requested.emit("Fire Axe", 2.5)
		_hint("axe", 8.0))
	# Fuses.
	# The school fuse sits on a crate in the Learning Centre's back corner, not on the floor.
	_builder_crate(Vector3(11.2, 0.0, -49.2))
	for entry: Array in [["fuse_metro", Vector3(-3.2, metro_y + 1.0, -40.0)], ["fuse_school", Vector3(11.2, 0.62, -49.2)]]:
		var fuse: Usable = _make_pickup("Take the fuse", entry[1], Vector3(0.16, 0.38, 0.16), Color(0.85, 0.62, 0.2), CityBuilder.COLOR_SODIUM)
		var fuse_mesh: MeshInstance3D = fuse.get_meta(&"mesh")
		((fuse_mesh.mesh as BoxMesh).material as StandardMaterial3D).emission_energy_multiplier = 2.5
		_track(str(entry[0]), fuse)
		_highlight(fuse, Color(1.0, 0.6, 0.15))
		fuse.used.connect(_on_fuse_taken.bind(str(entry[0])))
	# Pharmacy side objective.
	var generator: Usable = _make_usable("Start the generator", Vector3(12.1, 0.0, 8.0), true)
	_track("generator", generator)
	generator.used.connect(_on_generator_started)
	var core: Usable = _make_pickup("Take the cardiac stimulant", Vector3(23.6, 1.0, 9.3), Vector3(0.14, 0.3, 0.14), Color(0.9, 0.3, 0.25), CityBuilder.COLOR_RED)
	_track("vital_core", core)
	# A Lung Core on top of the courtyard crate: reward for climbing somewhere optional.
	var lung: Usable = _make_pickup("Take the Lung Core", Vector3(-15.5, 1.1, 17.2), Vector3(0.16, 0.26, 0.16), Color(0.75, 0.85, 0.95), Color(0.75, 0.88, 1.0))
	_track("lung_core", lung)
	lung.used.connect(func(player: Player) -> void:
		var bonus: float = Upgrades.core_bonus("lung_core_stamina_bonus")
		player.add_max_stamina(bonus)
		GameState.set_flag("dc_lung_core")
		AudioManager.play_ui(&"core_pickup", -4.0)
		EventBus.toast_requested.emit("Lung Core: maximum stamina +%d" % int(bonus), 3.5))
	# Workbenches: rest, save, upgrade.
	for entry: Array in [["workbench_main", DeadCityLayout.WORKBENCH_MAIN], ["workbench_plaza", DeadCityLayout.WORKBENCH_PLAZA]]:
		var bench: Usable = _make_usable("Rest at the workbench", entry[1], false, 1.0)
		objects[entry[0]] = bench
		bench.used.connect(_on_workbench_used.bind(str(entry[0]), entry[1] as Vector3))
	core.used.connect(_on_vital_core_taken)
	# Shortcuts.
	var lever: Usable = _make_usable("Unlatch the gate", Vector3(37.4, 0.0, -40.0), true, 0.8)
	_track("gate_lever", lever)
	lever.used.connect(func(_player: Player) -> void:
		_apply_gate_open()
		AudioManager.play_sfx(&"gate_open", Vector3(40.0, 1.5, -38.0), 2.0)
		EventBus.toast_requested.emit("Shortcut opened: East Avenue gate", 3.0))
	var kick: Usable = _make_usable("Kick the ladder down", Vector3(12.0, DeadCityLayout.ROOF_N2_Y, -18.0), true)
	_track("ladder_kick", kick)
	kick.used.connect(func(_player: Player) -> void:
		_apply_ladder_down()
		var ladder: Ladder = objects["ladder_shortcut"]
		AudioManager.play_sfx(&"ladder_drop", ladder.global_position + Vector3.UP * 3.0, 2.0)
		EventBus.noise_emitted.emit(ladder.global_position, 14.0, self)
		EventBus.toast_requested.emit("Shortcut opened: ladder to Main Street", 3.0))
	# Mara's locker: opens once all three journal pages are read.
	var locker: Usable = _make_usable("Open Mara's locker", Vector3(24.9, DeadCityLayout.ROOF_N2_Y, -38.3), true)
	_track("locker", locker)
	locker.set_enabled(false)
	locker.used.connect(_on_locker_opened)
	# The tower.
	var panel: Usable = _make_usable("Junction panel", Vector3(-7.2, 0.0, -92.0), false, 0.9)
	_track("panel", panel)
	panel.used.connect(_on_panel_used)
	var console: Usable = _make_usable("Triangulate the signal", Vector3(-5.8, 0.0, -98.0), true)
	_track("console", console)
	console.set_enabled(false)
	console.used.connect(func(_player: Player) -> void: play_ending())
	# The way out: East Avenue's far end, open once the signal is triangulated.
	var road: Usable = _make_usable("Leave the city for Meridian", Vector3(40.0, 0.0, 54.0), false, 1.6)
	objects["exit_road"] = road
	road.set_enabled(false)
	road.used.connect(func(_player: Player) -> void: EventBus.travel_requested.emit("forest"))


## A crate for an item to sit on, visual only (added after the level geometry is committed).
func _builder_crate(at: Vector3) -> void:
	var crate := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.7, 0.6, 0.6)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.24, 0.16)
	box.material = material
	crate.mesh = box
	crate.position = at + Vector3(0.0, 0.3, 0.0)
	add_child(crate)


func _on_fuse_taken(_player: Player, key: String) -> void:
	GameState.set_flag("dc_" + key)
	fuses_found += 1
	AudioManager.play_ui(&"pickup", -6.0)
	EventBus.toast_requested.emit("Fuse %d / 2" % fuses_found, 2.5)
	_radio("first_fuse" if fuses_found == 1 else "fuses_done")
	if fuses_found >= 2:
		_advance_to(Stage.JUNCTION)
	else:
		_advance_to(Stage.RESTORE_POWER)
	_update_objective()


func _on_generator_started(_player: Player) -> void:
	_apply_pharmacy_power()
	var at := Vector3(12.1, 1.0, 9.3)
	AudioManager.play_sfx(&"power_up", at, 4.0)
	# The noise carries: the street comes to look.
	EventBus.noise_emitted.emit(at, float(tuning.get("generator_noise_radius", 40.0)), self)
	for spot: Vector3 in [Vector3(2.0, 0.05, -10.0), Vector3(-6.0, 0.05, -12.0)]:
		var hollow: Enemy = spawn_enemy("hollow", spot)
		hollow.alert.call_deferred(Vector3(19.0, 0.0, -1.0))
	_radio("pharmacy_power")
	_update_objective()


func _on_vital_core_taken(player: Player) -> void:
	var bonus: float = float(tuning.get("vital_core_health_bonus", 25.0))
	player.health.max_health += bonus
	player.health.heal(player.health.max_health)
	GameState.max_health = player.health.max_health
	GameState.set_flag("dc_vital_core")
	player.emit_combat_status()
	AudioManager.play_ui(&"core_pickup", -4.0)
	EventBus.toast_requested.emit("Vital Core: maximum health +%d" % int(bonus), 3.5)


func _on_locker_opened(player: Player) -> void:
	var amount: int = int(tuning.get("journal_cache_salvage", 150))
	GameState.salvage += amount
	GameState.set_flag("dc_journal_cache")
	player.add_throwables(3)
	AudioManager.play_ui(&"core_pickup", -6.0)
	EventBus.toast_requested.emit("Mara's cache: salvage +%d, bottles restocked" % amount, 3.5)
	_update_objective()


func _on_panel_used(_player: Player) -> void:
	if GameState.has_flag("dc_power_on"):
		return
	if fuses_found < 2:
		AudioManager.play_ui(&"ui_wrong", -6.0)
		EventBus.toast_requested.emit("The panel is dead. Fuse slots filled: %d / 2" % fuses_found, 3.0)
		_advance_to(Stage.RESTORE_POWER)
		return
	var ui: StoryUI = get_tree().get_first_node_in_group(&"story_ui") as StoryUI
	if ui == null:
		restore_power()
		return
	var relays: int = int(tuning.get("junction_relays", 5))
	var puzzle := JunctionPuzzle.new(relays, tuning.get("junction_scramble", [0, 2, 3]))
	var clue: String = "Scrawled inside the panel door: \"1, 3, 4. Any order. — Arlo\"" if GameState.collected_documents.has("dc_engineer_voicemail") else ""
	if not ui.puzzle_solved.is_connected(restore_power):
		ui.puzzle_solved.connect(restore_power, CONNECT_ONE_SHOT)
	ui.show_puzzle(puzzle, clue)


## The junction is rerouted: the tower wakes, and the city hears it.
func restore_power() -> void:
	if GameState.has_flag("dc_power_on"):
		return
	_apply_power_on()
	AudioManager.play_ui(&"power_up", -2.0, &"SFX")
	AudioManager.play_ui(&"echo_swell", -8.0, &"SFX")
	CombatFX.shake(0.35)
	set_checkpoint("dc_tower_power", Vector3(0.0, 0.1, -86.5), 0.0)
	_set_stage(Stage.DEFEND)
	_radio("power_on")
	_spawn_wave()


# --- World changes shared by play and by loading a save ----------------------------------

func _apply_gate_open() -> void:
	_open_door("gate", true)
	GameState.set_flag("dc_gate_open")


func _apply_ladder_down() -> void:
	var ladder: Ladder = objects["ladder_shortcut"]
	ladder.enabled = true
	(ladder.get_node(^"Visual") as Node3D).visible = true
	GameState.set_flag("dc_ladder_down")


func _apply_pharmacy_power() -> void:
	GameState.set_flag("dc_pharmacy_power")
	_open_door("shutter")
	for light: Light3D in _pharmacy_lights:
		light.visible = true
	var hum := AudioStreamPlayer3D.new()
	hum.stream = AudioManager.load_loop(&"generator_loop")
	hum.bus = &"Ambience"
	hum.unit_size = 5.0
	hum.max_distance = 40.0
	hum.position = Vector3(12.1, 1.0, 9.3)
	add_child(hum)
	hum.play()


func _apply_power_on() -> void:
	GameState.set_flag("dc_power_on")
	(objects["panel"] as Usable).set_enabled(false)
	for light: Light3D in _powered_lights:
		light.visible = true


func _on_workbench_used(player: Player, key: String, at: Vector3) -> void:
	# Resting: full health and supplies, the district's ordinary enemies return, progress is saved.
	player.health.heal(player.health.max_health)
	player.injectors = player.combat.max_injectors
	player.emit_combat_status()
	reset_encounters()
	set_checkpoint("dc_" + key, at + Vector3(0.0, 0.1, -0.6), PI, true)
	EventBus.workbench_used.emit(player)


# --- Saving and loading ---------------------------------------------------------------

func capture_state() -> void:
	var state: Dictionary = capture_common()
	state["stage"] = int(stage)
	state["fuses"] = fuses_found
	GameState.set_level_state(flag_prefix, state)


func restore_state(player: Player) -> void:
	_player = player
	var state: Dictionary = saved_state()
	stage = int(state.get("stage", 0)) as Stage
	fuses_found = int(state.get("fuses", 0))
	restore_common(state)
	if GameState.has_flag("dc_gate_open"):
		_apply_gate_open()
	if GameState.has_flag("dc_ladder_down"):
		_apply_ladder_down()
	if GameState.has_flag("dc_pharmacy_power"):
		_apply_pharmacy_power()
	if GameState.has_flag("dc_power_on"):
		_apply_power_on()
	var locker: Usable = objects["locker"]
	locker.set_enabled(journal_pages_found() == JOURNAL_IDS.size() and not GameState.has_flag("dc_journal_cache"))
	(objects["console"] as Usable).set_enabled(stage == Stage.TRANSMIT)
	(objects["exit_road"] as Usable).set_enabled(stage == Stage.DONE)
	if stage == Stage.DEFEND:
		_spawn_wave.call_deferred()
	_update_objective()


func _document_collected(document_id: String) -> void:
	if JOURNAL_IDS.has(document_id) and journal_pages_found() == JOURNAL_IDS.size() and not GameState.has_flag("dc_journal_cache"):
		(objects["locker"] as Usable).set_enabled(true)
		_radio("journal_done")
	_update_objective()


# --- Triggers -----------------------------------------------------------------------

func _build_triggers() -> void:
	# Tutorial hints on the way down from the camp.
	_trigger(Vector3(-18.5, 9.0, 68.0), Vector3(3.0, 3.0, 20.0), func(_p: Player) -> void: _hint("jump"))
	_trigger(Vector3(-29.0, 7.0, 67.5), Vector3(14.0, 3.0, 6.0), func(_p: Player) -> void: _hint("mantle"))
	_trigger(Vector3(-29.0, 7.0, 60.0), Vector3(14.0, 3.0, 4.0), func(_p: Player) -> void: _hint("ladder"))
	_trigger(Vector3(-27.0, 0.0, 53.0), Vector3(22.0, 4.0, 9.0), func(_p: Player) -> void:
		_advance_to(Stage.REACH_MAIN)
		set_checkpoint("dc_south_street", Vector3(-29.0, 0.1, 55.0), 0.0)
		_radio("street")
		_hint("crouch", 9.0))
	_trigger(Vector3(-40.0, 0.0, 50.0), Vector3(8.0, 4.0, 12.0), func(_p: Player) -> void: _hint("takedown", 9.0))
	_trigger(Vector3(-26.0, 0.0, 45.5), Vector3(5.0, 4.0, 3.0), func(_p: Player) -> void: _hint("takedown", 9.0))
	_trigger(Vector3(-33.0, 0.0, 49.0), Vector3(5.0, 4.0, 5.0), func(_p: Player) -> void: _hint("bottle", 9.0))
	_trigger(Vector3(0.0, 0.0, 49.0), Vector3(40.0, 4.0, 10.0), func(_p: Player) -> void: _hint("rain", 8.0))
	# Main Street: the overpass is down; Oren points at the metro.
	for center: Vector3 in [Vector3(0.0, 0.0, -1.0), Vector3(-40.0, 0.0, -1.0), Vector3(40.0, 0.0, -1.0)]:
		_trigger(center, Vector3(12.0, 4.0, 4.0), _on_reached_main_street)
	_trigger(Vector3(19.0, 0.0, -1.0), Vector3(6.0, 3.0, 4.0), func(_p: Player) -> void:
		GameState.set_flag("dc_pharmacy_seen")
		_update_objective())
	_trigger(Vector3(-20.0, DeadCityLayout.METRO_Y, -8.0), Vector3(20.0, 4.0, 8.0), func(_p: Player) -> void:
		_advance_to(Stage.REACH_TOWER)
		set_checkpoint("dc_metro", Vector3(-20.0, DeadCityLayout.METRO_Y + 0.1, -5.0), 0.0)
		_radio("metro"))
	# Tower Plaza, from the metro exit or through the gate.
	for center: Vector3 in [Vector3(-20.0, 0.0, -73.0), Vector3(40.0, 0.0, -57.0)]:
		_trigger(center, Vector3(10.0, 4.0, 5.0), func(_p: Player) -> void:
			_advance_to(Stage.RESTORE_POWER)
			set_checkpoint("dc_plaza", Vector3(-20.0, 0.1, -72.5), 0.0)
			_radio("plaza"))


func _on_reached_main_street(_player: Player) -> void:
	if GameState.has_flag("dc_radio_main_street"):
		return
	_advance_to(Stage.FIND_WAY)
	set_checkpoint("dc_main_street", Vector3(0.0, 0.1, 2.0), 0.0)
	_radio("main_street")


# --- Enemies ------------------------------------------------------------------------

func _register_enemies() -> void:
	var metro: float = DeadCityLayout.METRO_Y + 0.05
	# South Street: two walkers and one with its back turned (the first takedown).
	add_enemy_spawn("hollow", Vector3(10.0, 0.05, 50.0), -90.0, [Vector3(6.0, 0.0, 50.0), Vector3(26.0, 0.0, 50.0)])
	add_enemy_spawn("hollow", Vector3(46.0, 0.05, 50.0), 90.0, [Vector3(40.0, 0.0, 48.0), Vector3(52.0, 0.0, 52.0)])
	add_enemy_spawn("hollow", Vector3(-46.0, 0.05, 51.0), 90.0)
	add_enemy_spawn("hollow", Vector3(-23.0, 0.05, 36.5), 0.0)
	add_enemy_spawn("skitter", Vector3(-28.0, 0.05, 28.0), 180.0, [Vector3(-28.0, 0.0, 28.0), Vector3(-16.0, 0.0, 22.0), Vector3(-26.0, 0.0, 17.0)])
	add_enemy_spawn("hollow", Vector3(-40.0, 0.05, 30.0), 0.0, [Vector3(-40.0, 0.0, 36.0), Vector3(-40.0, 0.0, 4.0)])
	add_enemy_spawn("hollow", Vector3(0.0, 0.05, 20.0), 180.0, [Vector3(0.0, 0.0, 38.0), Vector3(0.0, 0.0, 6.0)])
	# Main Street and the pharmacy.
	add_enemy_spawn("hollow", Vector3(20.0, 0.05, -9.0), 90.0)
	add_enemy_spawn("hollow", Vector3(24.0, 0.05, -15.0), -90.0, [Vector3(18.0, 0.0, -15.0), Vector3(44.0, 0.0, -15.0)])
	add_enemy_spawn("spitter", Vector3(50.0, 0.05, -12.0), 90.0)
	add_enemy_spawn("hollow", Vector3(-44.0, 0.05, -10.0), -90.0, [Vector3(-52.0, 0.0, -10.0), Vector3(-28.0, 0.0, -9.0)])
	add_enemy_spawn("hollow", Vector3(22.0, 0.05, 1.0), 180.0)
	# Metro.
	add_enemy_spawn("hollow", Vector3(-20.0, metro, -18.0), 0.0, [Vector3(-20.0, metro, -11.0), Vector3(-20.0, metro, -28.0)])
	add_enemy_spawn("skitter", Vector3(-28.0, metro, -38.0), 180.0, [Vector3(-28.0, metro, -38.0), Vector3(-12.0, metro, -44.0)])
	add_enemy_spawn("skitter", Vector3(-12.0, metro, -54.0), 0.0)
	# Skitters waiting on the walls, head down.
	add_wall_spawn("skitter", Vector3(-32.0, 4.2, -16.6), Vector3(0, 0, 1), Vector3(-32.0, 0.05, -13.0))
	add_wall_spawn("skitter", Vector3(26.0, 4.6, 44.4), Vector3(0, 0, 1), Vector3(26.0, 0.05, 48.0))
	add_wall_spawn("skitter", Vector3(44.95, 4.4, -26.0), Vector3(-1, 0, 0), Vector3(41.0, 0.05, -26.0))
	# Tower Plaza and the Learning Centre.
	add_enemy_spawn("bulwark", Vector3(0.0, 0.05, -80.0), 180.0, [Vector3(-6.0, 0.0, -80.0), Vector3(8.0, 0.0, -79.0)])
	add_enemy_spawn("hollow", Vector3(-22.0, 0.05, -88.0), 0.0, [Vector3(-22.0, 0.0, -88.0), Vector3(-30.0, 0.0, -96.0)])
	add_enemy_spawn("hollow", Vector3(24.0, 0.05, -90.0), 0.0)
	add_enemy_spawn("spitter", Vector3(38.0, 0.05, -98.0), 180.0)
	add_enemy_spawn("hollow", Vector3(26.0, 0.05, -52.0), 180.0)


