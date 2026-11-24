class_name Forest
extends StoryLevel
## Area 2, the Forgotten Forest (Act 2): through the army's quarantine cordon
## around Meridian. Kael finds a way through the outer wall, tunes the
## military radio tower to open the inner gate, and fights the Warden at the
## checkpoint that guards the service tunnel. West is the way in, east the
## way on.
##
##   x -130 .. -90   arrival clearing, aid post, outer wall (breach at the north end)
##   x  -90 .. -25   outpost, hunter's hide, watchtower
##   x  -25 .. -15   the river (shallow, loud)
##   x  -15 ..  60   radio tower hill, two Echo caves
##   x   60 .. 106   inner wall and the checkpoint arena (the Warden)
##   x  110          service tunnel into the Institute

enum Stage { WALL, TOWER, TUNE, TUNNEL, WARDEN, ENTER, DONE }

const L := CityBuilder.Look
const BOUNDS := Rect2(-134.0, -74.0, 268.0, 148.0)
const SPAWN := Vector3(-120.0, 0.1, 2.0)
const ARENA_CENTER := Vector3(86.0, 0.0, 0.0)
const WAYPOINTS: Dictionary = {
	0: Vector3(-90.0, 1.0, -42.0),
	1: Vector3(12.0, 1.0, 30.0),
	2: Vector3(12.0, 1.2, 33.0),
	3: Vector3(60.0, 1.0, 0.0),
	5: Vector3(110.0, 1.2, 0.0),
}
const ROCK := Color(0.2, 0.2, 0.19)
const DIRT := Color(0.2, 0.16, 0.11)
const GROUND := Color(0.1, 0.14, 0.07)

var dressing: ForestDressing
var stage: Stage = Stage.WALL
var warden: Enemy
var warden_controller: WardenController

var _builder: CityBuilder
var _environment: Environment
var _sun: DirectionalLight3D
var _tick: float = 0.0
## Open ground where no trees grow: [centre (x, z), radius].
var _clearings: Array = []
## Path segments kept clear of trees: [from (x, z), to (x, z)].
var _paths: Array = []
## Places the birds go quiet around.
var _quiet_spots: Array[Vector3] = [Vector3(-4.0, 0.0, -52.0), Vector3(40.0, 0.0, -48.0), ARENA_CENTER]


func _ready() -> void:
	screen_tint = Color(1.04, 1.0, 0.93)
	title = "THE FORGOTTEN FOREST"
	subtitle = "ACT 2"
	setup_story("ff", "the Forgotten Forest", "res://data/levels/forest.json", "res://data/story/forest.json", "res://data/documents/forest.json")
	default_surface = "grass"
	spawn_position = SPAWN
	spawn_yaw = -PI * 0.5
	GameState.current_area = "forest"

	_builder = CityBuilder.new()
	_builder.name = "Geometry"
	add_child(_builder)
	_build_terrain()
	_build_structures()
	_plant_trees()
	dressing = ForestDressing.new()
	dressing.build(_builder, self)
	_builder.commit()
	_builder.set_rain_ripples(0.0)
	_build_environment()
	dressing.build_effects(self)
	bake_navigation(AABB(Vector3(-132.0, -1.0, -72.0), Vector3(264.0, 5.0, 144.0)))
	_build_interactables()
	_build_triggers()
	_register_enemies()
	spawn_enemies()
	for patch: Array in [[Vector3(-100.0, 0.0, -30.0), Vector2(10, 8)], [Vector3(-60.0, 0.0, 10.0), Vector2(12, 8)], [Vector3(-30.0, 0.0, -20.0), Vector2(8, 10)],
			[Vector3(0.0, 0.0, 0.0), Vector2(12, 8)], [Vector3(30.0, 0.0, -30.0), Vector2(10, 10)], [Vector3(45.0, 0.0, 14.0), Vector2(8, 8)]]:
		_add_grass(patch[0], patch[1])

	AudioManager.set_ambience(&"birds", &"birds_loop", -12.0)
	AudioManager.set_ambience(&"wind", &"wind_loop", -22.0)
	SettingsManager.register_world(_environment, _sun)
	_update_objective()


func _exit_tree() -> void:
	SettingsManager.unregister_world(_environment)
	AudioManager.clear_ambience()
	super._exit_tree()


func _physics_process(delta: float) -> void:
	var player: Player = find_player()
	if player == null:
		return
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.5
	_update_enemy_sleep(player.global_position)
	# Birdsong thins out and stops near the Echo.
	var nearest: float = INF
	for spot: Vector3 in _quiet_spots:
		nearest = minf(nearest, spot.distance_to(player.global_position))
	AudioManager.set_ambience(&"birds", &"birds_loop", lerpf(AudioManager.SILENT_DB, -12.0, smoothstep(14.0, 40.0, nearest)))
	for enemy: Enemy in get_enemies():
		if not enemy.is_asleep() and not enemy.is_dead() and enemy.data.id == "wolf" and enemy.is_aware():
			_hint("wolves", 9.0)


func get_tour_stops() -> Array[Array]:
	return [
		[Vector3(-122.0, 3.0, 4.0), Vector3(-95.0, 2.0, -6.0)],
		[Vector3(-100.0, 16.0, -52.0), Vector3(-84.0, 1.5, -40.0)],
		[Vector3(-72.0, 3.0, -22.0), Vector3(-50.0, 2.0, 0.0)],
		[Vector3(-40.0, 13.0, 41.0), Vector3(0.0, 2.0, 10.0)],
		[Vector3(-26.0, 2.5, -4.0), Vector3(-2.0, 1.5, -40.0)],
		[Vector3(5.0, 3.0, -37.0), Vector3(-5.0, 1.2, -54.0)],
		[Vector3(8.0, 4.0, 18.0), Vector3(14.0, 6.0, 34.0)],
		[Vector3(36.0, 3.0, -24.0), Vector3(42.0, 1.2, -50.0)],
		[Vector3(52.0, 3.5, 2.0), Vector3(86.0, 2.0, 0.0)],
		[Vector3(72.0, 4.0, 14.0), Vector3(96.0, 1.5, -6.0)],
	]


# --- Story ----------------------------------------------------------------------

func start_story(player: Player, skip_intro: bool) -> void:
	_player = player
	if not skip_intro:
		var shots: Array = [
			{"from": Vector3(-126.0, 9.0, 14.0), "look": Vector3(-96.0, 4.0, -8.0), "to": Vector3(-122.0, 5.0, 10.0), "seconds": 9.0},
			{"from": Vector3(-116.0, 1.8, -1.5), "look": Vector3(-120.0, 1.4, 2.0), "to": Vector3(-115.0, 1.7, -0.5), "seconds": 8.5, "fov": 45.0},
		]
		EventBus.fade_requested.emit(1.0, 0.0)
		EventBus.fade_requested.emit(0.0, 2.0)
		cinematic.play(shots, story.get("intro", []), player)
		await cinematic.finished
	EventBus.area_title_requested.emit(title, subtitle)
	_radio("arrive")
	set_checkpoint("ff_arrival", SPAWN, -PI * 0.5)
	_update_objective()


func _advance_to(next: Stage) -> void:
	if int(next) > int(stage):
		stage = next
		_update_objective()


func current_stage_key() -> String:
	var keys: PackedStringArray = ["wall", "tower", "tune", "tunnel", "warden", "enter", "done"]
	return keys[int(stage)]


func _update_objective() -> void:
	var texts: Dictionary = story.get("objectives", {})
	var keys: PackedStringArray = ["wall", "tower", "tune", "tunnel", "warden", "enter", "done"]
	var done: Array[String] = []
	for i: int in int(stage):
		done.append(str(texts.get(keys[i], "")))
	var text: String = str(texts.get(keys[int(stage)], ""))
	var sides: Dictionary = story.get("side_objectives", {})
	MissionManager.mission_title = "Act 2: The Cordon"
	MissionManager.set_completed(done)
	var side: String = ""
	if GameState.collected_documents.has("ff_hunter_note") or GameState.has_flag("ff_cache"):
		MissionManager.set_side("cache", str(sides.get("cache", "")), GameState.has_flag("ff_cache"))
	var patrol: int = int(GameState.collected_documents.has("ff_patrol_log")) + int(GameState.collected_documents.has("ff_patrol_final"))
	if patrol > 0:
		MissionManager.set_side("patrol", str(sides.get("patrol", "")) % patrol, patrol >= 2)
	side = MissionManager.active_side_text()
	MissionManager.set_objective(text, WAYPOINTS.get(int(stage)))
	EventBus.objective_changed.emit(text, side)


func _document_collected(document_id: String) -> void:
	if document_id == "ff_patrol_final" and GameState.collected_documents.has("ff_patrol_log"):
		_radio("patrol")
	_update_objective()


func _on_radio_used(_user: Player) -> void:
	if GameState.has_flag("ff_gate_open"):
		return
	_advance_to(Stage.TUNE)
	var ui: StoryUI = get_tree().get_first_node_in_group(&"story_ui") as StoryUI
	if ui == null:
		open_inner_gate()
		return
	var puzzle := Puzzles.Waveform.new(int(tuning.get("carrier_frequency", 4)), int(tuning.get("carrier_strength", 2)))
	PuzzlePanels.waveform(ui, puzzle, open_inner_gate)


## The tower is tuned: the inner gate opens and the road to the checkpoint is clear.
func open_inner_gate() -> void:
	if GameState.has_flag("ff_gate_open"):
		return
	GameState.set_flag("ff_gate_open")
	_open_door("inner_gate")
	(objects["radio"] as Usable).set_enabled(false)
	AudioManager.play_sfx(&"gate_open", Vector3(60.0, 1.5, 0.0), 6.0)
	_advance_to(Stage.TUNNEL)
	_radio("tuned")
	set_checkpoint("ff_tuned", Vector3(12.0, 0.1, 28.0), 0.0)


func _on_arena_entered(player: Player) -> void:
	if GameState.has_flag("ff_warden_dead") or stage >= Stage.WARDEN:
		return
	_advance_to(Stage.WARDEN)
	set_checkpoint("ff_checkpoint", Vector3(63.0, 0.1, 0.0), -PI * 0.5)
	if not GameState.has_flag("ff_warden_seen"):
		# First time only: the Warden rises from its post and turns to face Kael.
		GameState.set_flag("ff_warden_seen")
		if warden == null or not is_instance_valid(warden):
			_spawn_warden()
		var at: Vector3 = warden.global_position
		var shots: Array = [
			{"from": at + Vector3(-9.0, 1.4, 6.0), "look": at + Vector3(0.0, 1.6, 0.0), "to": at + Vector3(-6.5, 1.2, 4.0), "seconds": 3.2},
			{"from": at + Vector3(-3.2, 1.0, 1.2), "look": at + Vector3(0.0, 2.2, 0.0), "to": at + Vector3(-2.6, 0.8, 0.9), "seconds": 2.6, "fov": 42.0},
		]
		AudioManager.play_sfx(&"boss_roar", at, 6.0)
		await boss_moment(shots, [warden], [], "THE WARDEN", "Meridian's last guard")
	_radio("arena")
	_hint("warden", 9.0)
	_wake_warden(player)


func _spawn_warden() -> void:
	if warden != null and is_instance_valid(warden):
		warden.queue_free()
	warden = Enemy.new()
	warden.data = WardenController.make_data(tuning.get("warden", {}))
	warden.name = "Warden"
	warden.position = ARENA_CENTER + Vector3(10.0, 0.05, 0.0)
	warden.rotation.y = PI * 0.5
	add_child(warden)
	warden.set_asleep(true)
	warden_controller = null


func _wake_warden(player: Player) -> void:
	if warden == null or not is_instance_valid(warden) or warden.is_dead():
		_spawn_warden()
	warden.set_asleep(false)
	warden_controller = WardenController.new()
	warden_controller.tuning = tuning.get("warden", {})
	warden.add_child(warden_controller)
	warden_controller.phase_changed.connect(func(phase: int) -> void:
		_hint("warden_%d" % phase, 9.0)
		_warden_phase_shot())
	warden_controller.defeated.connect(_on_warden_defeated)
	warden.alert.call_deferred(player.global_position)


## A beat on each phase change: the camera swings in on the Warden as it changes.
func _warden_phase_shot() -> void:
	if warden == null or not is_instance_valid(warden):
		return
	var player: Player = find_player()
	var at: Vector3 = warden.global_position
	var side: Vector3 = (player.global_position - at) if player != null else Vector3(-1.0, 0.0, 0.0)
	side.y = 0.0
	side = side.normalized() if side.length() > 0.1 else Vector3(-1.0, 0.0, 0.0)
	var across: Vector3 = side.cross(Vector3.UP)
	var shots: Array = [{"from": at + side * 6.0 + across * 2.5 + Vector3(0.0, 1.0, 0.0), "look": at + Vector3(0.0, 1.8, 0.0),
			"to": at + side * 4.5 + across * 1.5 + Vector3(0.0, 0.8, 0.0), "seconds": 2.2, "fov": 48.0}]
	AudioManager.play_sfx(&"boss_roar", at, 4.0)
	boss_moment(shots, [warden])


func _on_warden_defeated() -> void:
	GameState.set_flag("ff_warden_dead")
	set_checkpoint("ff_warden_down", ARENA_CENTER + Vector3(0.0, 0.1, 0.0), -PI * 0.5)
	var player: Player = find_player()
	var shots: Array = [
		{"from": ARENA_CENTER + Vector3(-6.0, 2.2, 6.0), "look": ARENA_CENTER + Vector3(10.0, 1.0, 0.0), "to": ARENA_CENTER + Vector3(-3.0, 1.8, 4.0), "seconds": 14.5},
		{"from": Vector3(104.0, 1.8, -2.5), "look": Vector3(110.0, 2.0, 0.0), "to": Vector3(106.0, 1.8, -1.5), "seconds": 13.5, "fov": 45.0},
		{"from": Vector3(96.0, 6.0, 8.0), "look": Vector3(110.0, 2.0, 0.0), "to": Vector3(99.0, 4.0, 5.0), "seconds": 14.0},
	]
	await get_tree().create_timer(1.6, false).timeout
	if cinematic.is_playing:
		cinematic.skip()
	cinematic.play(shots, story.get("confession", []), player)
	await cinematic.finished
	stage = Stage.ENTER
	(objects["tunnel"] as Usable).set_enabled(true)
	_update_objective()
	EventBus.act_completed.emit("Act 2: The Forgotten Forest", get_summary_rows())


func get_summary_rows() -> Array:
	var seconds: int = int(GameState.playtime_seconds)
	var found: int = 0
	for entry: Dictionary in documents:
		if GameState.collected_documents.has(str(entry["id"])):
			found += 1
	return [
		["Time so far", "%d:%02d" % [seconds / 60, seconds % 60]],
		["Documents found here", "%d / %d" % [found, documents.size()]],
		["Enemies defeated here", str(enemies_defeated)],
		["Silent takedowns", str(takedowns)],
		["Side objectives", "%d / 2" % (int(GameState.has_flag("ff_cache")) + int(MissionManager.is_side_done("patrol")))],
	]


func reset_encounters() -> void:
	super.reset_encounters()
	if stage == Stage.WARDEN and not GameState.has_flag("ff_warden_dead"):
		# Retry: the Warden is back at full strength and waits for Kael to step in again.
		EventBus.boss_ended.emit()
		_spawn_warden()
		stage = Stage.TUNNEL
		_update_objective()


func prepare_benchmark(player: Player) -> void:
	player.god_mode = true
	player.teleport(ARENA_CENTER + Vector3(-4.0, 0.1, 0.0), -PI * 0.5)
	_wake_warden(player)


# --- Saving ---------------------------------------------------------------------

func capture_state() -> void:
	var state: Dictionary = capture_common()
	# A fight in progress is not saved: Kael comes back to the gate before it.
	state["stage"] = int(Stage.TUNNEL) if stage == Stage.WARDEN else int(stage)
	GameState.set_level_state(flag_prefix, state)


func restore_state(player: Player) -> void:
	_player = player
	var state: Dictionary = saved_state()
	stage = int(state.get("stage", 0)) as Stage
	restore_common(state)
	if GameState.has_flag("ff_gate_open"):
		_open_door("inner_gate")
		(objects["radio"] as Usable).set_enabled(false)
	if GameState.has_flag("ff_warden_dead"):
		if warden != null and is_instance_valid(warden):
			warden.queue_free()
		(objects["tunnel"] as Usable).set_enabled(true)
	_update_objective()


# --- Geometry -------------------------------------------------------------------

func _path(from: Vector2, to: Vector2) -> void:
	_paths.append([from, to])
	var along: Vector2 = to - from
	var middle: Vector2 = (from + to) * 0.5
	_builder.box(Vector3(middle.x, 0.012, middle.y), Vector3(along.length() + 2.0, 0.02, 3.4), L.EARTH, DIRT, false, false, rad_to_deg(-along.angle()))


func _clearing(x: float, z: float, radius: float) -> void:
	_clearings.append([Vector2(x, z), radius])


func _build_terrain() -> void:
	var b: CityBuilder = _builder
	b.ground(BOUNDS, [], L.EARTH, GROUND)
	# Cliffs ring the valley.
	b.block(-134, -74, 134, -70, 9, 0.0, L.RUBBLE, ROCK)
	b.block(-134, 70, 134, 74, 9, 0.0, L.RUBBLE, ROCK)
	b.block(-134, -74, -130, 74, 9, 0.0, L.RUBBLE, ROCK)
	b.block(130, -74, 134, 74, 9, 0.0, L.RUBBLE, ROCK)
	for i: int in 40:
		var along: float = b.random_range(-128.0, 128.0)
		var north: bool = i % 2 == 0
		b.box(Vector3(along, b.random_range(2.0, 6.0), -69.0 if north else 69.0), Vector3(b.random_range(5.0, 12.0), b.random_range(6.0, 13.0), b.random_range(3.0, 6.0)),
				L.RUBBLE, ROCK * b.random_range(0.7, 1.1), false, false, b.random_range(-20.0, 20.0))
	# Trails.
	_path(Vector2(-126, 2), Vector2(-94, 0))
	_path(Vector2(-96, -2), Vector2(-92, -40))
	_path(Vector2(-88, -40), Vector2(-70, -30))
	_path(Vector2(-70, -30), Vector2(-48, -4))
	_path(Vector2(-48, -4), Vector2(-20, -8))
	_path(Vector2(-48, -4), Vector2(-45, 30))
	_path(Vector2(-20, -8), Vector2(12, 26))
	_path(Vector2(-20, -8), Vector2(-4, -44))
	_path(Vector2(12, 26), Vector2(40, 4))
	_path(Vector2(40, 4), Vector2(60, 0))
	_path(Vector2(40, 4), Vector2(40, -40))
	_path(Vector2(60, 0), Vector2(108, 0))
	for clearing: Array in [[-118, 0, 14], [-70, -30, 12], [-45, 34, 7], [12, 30, 10], [-4, -52, 9], [40, -48, 9], [52, 4, 8], [86, 0, 24], [-56, -6, 5], [-62, 44, 6]]:
		_clearing(clearing[0], clearing[1], clearing[2])
	# The river: shallow, wide, loud to wade.
	b.block(-25, -70, -15, 70, 0.03, 0.0, L.ASPHALT, Color(0.05, 0.1, 0.13), false, false)
	surfaces.append([AABB(Vector3(-25, -0.5, -70), Vector3(10, 3, 140)), "wet"])
	_paths.append([Vector2(-20, -70), Vector2(-20, 70)])
	for i: int in 14:
		var at := Vector3(b.random_range(-24.0, -16.0), 0.15, b.random_range(-66.0, 66.0))
		b.box(at, Vector3(b.random_range(0.6, 1.6), 0.5, b.random_range(0.6, 1.4)), L.RUBBLE, ROCK, false, false, b.random_range(0.0, 90.0))


func _build_structures() -> void:
	var b: CityBuilder = _builder
	var concrete := Color(0.3, 0.3, 0.29)
	var olive := Color(0.17, 0.2, 0.13)
	# Arrival: a wrecked truck, the aid post tent, a workbench under a tarp.
	b.car(-112.0, -5.0, 70.0, olive)
	b.box(Vector3(-106.0, 1.0, -9.0), Vector3(0.06, 2.8, 4.4), L.RUBBLE, olive, false, false, 0.0, Vector3(0.0, 0.0, 42.0))
	b.box(Vector3(-107.9, 1.0, -9.0), Vector3(0.06, 2.8, 4.4), L.RUBBLE, olive, false, false, 0.0, Vector3(0.0, 0.0, -42.0))
	b.collider(Vector3(-107.0, 0.8, -9.0), Vector3(2.4, 1.6, 4.2))
	_workbench(Vector3(-112.0, 0.0, 7.0))
	# Outer quarantine wall along x = -90, shut gate at z = 0, collapsed at the north end.
	b.block(-91, -70, -89, -46, 5, 0.0, L.CONCRETE, concrete)
	b.block(-91, -36, -89, -3, 5, 0.0, L.CONCRETE, concrete)
	b.block(-91, 3, -89, 70, 5, 0.0, L.CONCRETE, concrete)
	b.block(-90.4, -3, -89.6, 3, 4.4, 0.0, L.METAL, CityBuilder.COLOR_DARK)
	b.rubble(-92, -46, -88, -44, 2.0, 5)
	b.rubble(-92, -38, -88, -36, 2.0, 5)
	b.sign_text("QUARANTINE  ·  NO EXIT", Vector3(-89.0, 3.4, 0.0), 90.0, 0.9, Color(0.75, 0.7, 0.4))
	# Firing positions and wire on the inside of the wall, pointing inward (east).
	for z: float in [-28.0, -14.0, 14.0, 28.0, 44.0]:
		b.barrier(-84.0, z, 4.0, 90.0)
		b.box(Vector3(-83.2, 1.15, z), Vector3(1.6, 0.12, 0.12), L.METAL, CityBuilder.COLOR_DARK, false, false, 0.0)
	b.block(-93.5, -4.5, -91.2, -1.5, 2.6, 0.0, L.CONCRETE, concrete)  # gatehouse
	# Outpost: tents, crates, a workbench.
	for tent: Vector2 in [Vector2(-74, -36), Vector2(-66, -36)]:
		for side: float in [-1.0, 1.0]:
			b.box(Vector3(tent.x + side * 0.95, 1.05, tent.y), Vector3(0.06, 2.9, 4.4), L.RUBBLE, olive, false, false, 0.0, Vector3(0.0, 0.0, side * 42.0))
		b.collider(Vector3(tent.x, 0.8, tent.y), Vector3(2.6, 1.6, 4.2))
	b.block(-78, -27, -76, -25, 1.1, 0.0, L.INTERIOR, Color(0.3, 0.24, 0.16), true)
	b.block(-63.2, -28.4, -62.0, -27.2, 0.9, 0.0, L.METAL, CityBuilder.COLOR_RUST)
	b.strip(Vector3(-62.6, 0.92, -27.8), Vector3(0.9, 0.04, 0.9), CityBuilder.COLOR_SODIUM)
	b.point_light(Vector3(-62.6, 1.5, -27.8), CityBuilder.COLOR_SODIUM, 1.8, 8.0)
	_workbench(Vector3(-70.0, 0.0, -23.0))
	# Hunter's hide: a lean-to against a boulder.
	b.block(-58.5, -8.5, -55.5, -6.0, 2.4, 0.0, L.RUBBLE, ROCK)
	b.box(Vector3(-57.0, 1.3, -4.6), Vector3(3.2, 0.08, 2.6), L.RUBBLE, Color(0.2, 0.17, 0.1), false, false, 0.0, Vector3(-24.0, 0.0, 0.0))
	# Watchtower with a ladder.
	for leg: Vector2 in [Vector2(-46.5, 32.5), Vector2(-43.5, 32.5), Vector2(-46.5, 35.5), Vector2(-43.5, 35.5)]:
		b.box(Vector3(leg.x, 4.0, leg.y), Vector3(0.25, 8.0, 0.25), L.METAL, CityBuilder.COLOR_RUST, false)
	b.block(-47, 32, -43, 36, 0.3, 8.0, L.METAL, CityBuilder.COLOR_RUST)
	b.block(-47, 32, -43, 32.15, 1.0, 8.3, L.METAL, CityBuilder.COLOR_DARK)
	b.block(-47, 32, -46.85, 36, 1.0, 8.3, L.METAL, CityBuilder.COLOR_DARK)
	b.block(-43.15, 32, -43, 36, 1.0, 8.3, L.METAL, CityBuilder.COLOR_DARK)
	b.block(-47, 32, -43, 36, 0.2, 10.6, L.METAL, CityBuilder.COLOR_DARK, false, false)
	surfaces.append([AABB(Vector3(-47, 8.0, 32), Vector3(4, 3, 4)), "metal"])
	# Radio tower: hut with the set inside, lattice mast behind it.
	b.room(8, 30, 16, 36, 2.8, [["n", 12.0, 2.0]], Color(0.26, 0.27, 0.23))
	interiors.append(AABB(Vector3(8, -0.2, 30), Vector3(8, 3, 6)))
	surfaces.append([AABB(Vector3(8, -0.2, 30), Vector3(8, 3, 6)), "concrete"])
	b.block(10.2, 34.6, 13.8, 35.4, 0.9, 0.0, L.METAL, Color(0.2, 0.22, 0.2))
	b.strip(Vector3(12.0, 1.2, 34.6), Vector3(0.5, 0.2, 0.04), CityBuilder.COLOR_SODIUM)
	b.point_light(Vector3(12.0, 2.2, 33.0), CityBuilder.COLOR_WARM, 1.2, 7.0)
	for corner: Vector2 in [Vector2(18, 38), Vector2(21, 38), Vector2(18, 41), Vector2(21, 41)]:
		b.box(Vector3(corner.x, 14.0, corner.y), Vector3(0.3, 28.0, 0.3), L.METAL, CityBuilder.COLOR_RUST, false)
	for level: float in [5.0, 10.0, 15.0, 20.0, 25.0]:
		b.box(Vector3(19.5, level, 38.0), Vector3(3.3, 0.18, 0.18), L.METAL, CityBuilder.COLOR_RUST, false)
		b.box(Vector3(19.5, level, 41.0), Vector3(3.3, 0.18, 0.18), L.METAL, CityBuilder.COLOR_RUST, false)
		b.box(Vector3(18.0, level, 39.5), Vector3(0.18, 0.18, 3.3), L.METAL, CityBuilder.COLOR_RUST, false)
		b.box(Vector3(21.0, level, 39.5), Vector3(0.18, 0.18, 3.3), L.METAL, CityBuilder.COLOR_RUST, false)
	b.collider(Vector3(19.5, 3.0, 39.5), Vector3(3.4, 6.0, 3.4))
	# The two caves, glowing with Echo growth.
	for cave: Array in [[-10.0, -60.0, 2.0, -48.0, "s"], [34.0, -56.0, 46.0, -44.0, "s"]]:
		b.room(cave[0], cave[1], cave[2], cave[3], 3.6, [[cave[4], (float(cave[0]) + float(cave[2])) * 0.5, 3.0]], ROCK, 0.0, true, L.RUBBLE)
		var box := AABB(Vector3(cave[0], -0.2, cave[1]), Vector3(float(cave[2]) - float(cave[0]), 4.0, float(cave[3]) - float(cave[1])))
		interiors.append(box)
		surfaces.append([box, "gravel"])
		b.block(float(cave[0]) - 2.5, float(cave[1]) - 2.5, float(cave[2]) + 2.5, float(cave[3]) - 0.4, 6.5, 0.0, L.RUBBLE, ROCK * 0.9, false, false)
		for i: int in 12:
			var at := Vector3(b.random_range(float(cave[0]) + 0.5, float(cave[2]) - 0.5), b.random_range(0.3, 3.0), float(cave[1]) + 0.2)
			b.strip(at, Vector3(b.random_range(0.1, 0.6), b.random_range(0.15, 0.8), 0.1), CityBuilder.COLOR_ECHO)
		b.point_light(Vector3((float(cave[0]) + float(cave[2])) * 0.5, 1.8, float(cave[1]) + 2.0), CityBuilder.COLOR_ECHO, 2.2, 10.0)
	# Inner wall along x = 60 (the gate itself is a door the level owns), second workbench.
	b.block(59, -70, 61, -3, 5.5, 0.0, L.CONCRETE, concrete)
	b.block(59, 3, 61, 70, 5.5, 0.0, L.CONCRETE, concrete)
	b.sign_text("MERIDIAN  ·  SERVICE ACCESS", Vector3(58.9, 4.0, 0.0), -90.0, 0.9, Color(0.75, 0.7, 0.4))
	_workbench(Vector3(52.0, 0.0, 8.0))
	# The checkpoint arena: walled yard, pillars for cover, the gate booth, the tunnel mouth.
	b.block(61, -24, 108, -22, 5.5, 0.0, L.CONCRETE, concrete)
	b.block(61, 22, 108, 24, 5.5, 0.0, L.CONCRETE, concrete)
	b.block(106, -22, 108, -3.5, 7.0, 0.0, L.CONCRETE, concrete)
	b.block(106, 3.5, 108, 22, 7.0, 0.0, L.CONCRETE, concrete)
	b.block(106, -3.5, 114, 3.5, 1.0, 5.0, L.CONCRETE, concrete)
	b.block(108, -4.5, 114, -3.5, 5.0, 0.0, L.CONCRETE, concrete)
	b.block(108, 3.5, 114, 4.5, 5.0, 0.0, L.CONCRETE, concrete)
	b.block(113, -3.5, 114, 3.5, 5.0, 0.0, L.METAL, CityBuilder.COLOR_DARK)
	b.ground(Rect2(62, -21.9, 44, 43.8), [], L.ASPHALT, CityBuilder.COLOR_ASPHALT, 0.02, 0.02)
	surfaces.append([AABB(Vector3(61, -0.5, -22), Vector3(53, 4, 44)), "concrete"])
	for pillar: Vector2 in [Vector2(74, -9), Vector2(74, 9), Vector2(86, -13), Vector2(86, 13), Vector2(97, -8), Vector2(97, 8)]:
		b.block(pillar.x - 0.9, pillar.y - 0.9, pillar.x + 0.9, pillar.y + 0.9, 4.5, 0.0, L.CONCRETE, concrete)
	b.block(66, -20, 70, -16, 2.8, 0.0, L.CONCRETE, concrete * 0.9)
	b.car(80.0, 17.0, 20.0, olive)
	b.lamp(64.0, -20.0, true, CityBuilder.COLOR_SODIUM, 5.6, 3.0, true)
	b.lamp(104.0, 20.0, true, CityBuilder.COLOR_SODIUM, 5.6, 3.0, false, 0.0, true)
	b.point_light(Vector3(110.0, 3.5, 0.0), CityBuilder.COLOR_ECHO, 1.5, 9.0)


func _workbench(at: Vector3) -> void:
	_builder.block(at.x - 1.1, at.z + 0.8, at.x + 1.1, at.z + 1.5, 0.9, 0.0, L.METAL, Color(0.24, 0.2, 0.15))
	_builder.strip(Vector3(at.x, 1.3, at.z + 1.38), Vector3(1.6, 0.05, 0.05), CityBuilder.COLOR_WARM)
	_builder.point_light(Vector3(at.x, 1.5, at.z + 0.6), CityBuilder.COLOR_WARM, 1.2, 5.0)
	_clearing(at.x, at.z, 4.0)


func is_open_ground(at: Vector2) -> bool:
	return _is_open_ground(at)


func _is_open_ground(at: Vector2) -> bool:
	for clearing: Array in _clearings:
		if at.distance_to(clearing[0]) < float(clearing[1]):
			return true
	for path: Array in _paths:
		var from: Vector2 = path[0]
		var to: Vector2 = path[1]
		var t: float = clampf((at - from).dot(to - from) / maxf((to - from).length_squared(), 0.001), 0.0, 1.0)
		if at.distance_to(from.lerp(to, t)) < 4.2:
			return true
	if absf(at.x + 90.0) < 3.0 or absf(at.x - 60.0) < 3.0 or (at.x > -27.0 and at.x < -13.0):
		return true
	return false


## Scatters the trees: two MultiMeshes (trunks, canopies) and one small collider per trunk.
func _plant_trees() -> void:
	var trunks: Array[Transform3D] = []
	var trunk_colors: Array[Color] = []
	var canopies: Array[Transform3D] = []
	var canopy_colors: Array[Color] = []
	var leaves: Array[Transform3D] = []
	var leaf_colors: Array[Color] = []
	var random := RandomNumberGenerator.new()
	random.seed = 4077
	var density: float = lerpf(0.6, 1.0, SettingsManager.get_float("graphics", "foliage_density"))
	for i: int in int(1500.0 * density):
		var at := Vector2(random.randf_range(-128.0, 128.0), random.randf_range(-68.0, 68.0))
		if _is_open_ground(at):
			continue
		var height: float = random.randf_range(9.0, 16.0)
		var girth: float = random.randf_range(0.22, 0.42)
		var dead: bool = random.randf() < 0.05
		var bark: Color = Color(0.13, 0.1, 0.075) * random.randf_range(0.8, 1.25)
		if dead:
			bark = Color(0.22, 0.21, 0.19) * random.randf_range(0.8, 1.1)
		trunks.append(Transform3D(Basis.from_scale(Vector3(girth, height * (0.9 if dead else 0.62), girth)), Vector3(at.x, height * (0.45 if dead else 0.31), at.y)))
		trunk_colors.append(bark)
		_builder.collider(Vector3(at.x, 1.5, at.y), Vector3(girth * 1.6, 3.0, girth * 1.6))
		if dead:
			continue
		if random.randf() < 0.18:
			# A broadleaf (some of them birches): a rounded crown of a few clumps.
			if random.randf() < 0.5:
				trunk_colors[trunk_colors.size() - 1] = Color(0.68, 0.66, 0.6) * random.randf_range(0.85, 1.05)
			var crown: Color = Color(0.16, 0.24, 0.08).lerp(Color(0.3, 0.32, 0.1), random.randf()) * random.randf_range(0.85, 1.15)
			for clump: int in random.randi_range(3, 5):
				var size: float = random.randf_range(1.6, 2.6)
				var offset := Vector3(random.randf_range(-1.4, 1.4), random.randf_range(-0.8, 1.2), random.randf_range(-1.4, 1.4))
				leaves.append(Transform3D(Basis.from_scale(Vector3(size, size * 0.8, size)), Vector3(at.x, height * 0.62 + 1.2, at.y) + offset))
				leaf_colors.append(crown * random.randf_range(0.9, 1.1))
			continue
		# A fir: three stacked tiers, widest at the bottom, each turned a little.
		var spread: float = random.randf_range(2.4, 3.8)
		var needles: Color = Color(0.06, 0.13, 0.07).lerp(Color(0.1, 0.15, 0.06), random.randf()) * random.randf_range(0.8, 1.2)
		var tiers: Array = [[0.3, 0.42, 1.0], [0.52, 0.34, 0.74], [0.72, 0.3, 0.46]]
		for tier: Array in tiers:
			var tier_height: float = height * float(tier[1])
			var tier_spread: float = spread * float(tier[2])
			canopies.append(Transform3D(Basis(Vector3.UP, random.randf() * TAU) * Basis.from_scale(Vector3(tier_spread, tier_height, tier_spread)),
					Vector3(at.x, height * float(tier[0]) + tier_height * 0.5, at.y)))
			canopy_colors.append(needles * random.randf_range(0.9, 1.1))
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.7
	trunk_mesh.bottom_radius = 1.0
	trunk_mesh.height = 1.0
	trunk_mesh.radial_segments = 7
	trunk_mesh.rings = 1
	var bark_material := StandardMaterial3D.new()
	bark_material.albedo_color = Color.WHITE
	bark_material.vertex_color_use_as_albedo = true
	# Instance colours are written as sRGB, like albedo colours.
	bark_material.vertex_color_is_srgb = true
	bark_material.roughness = 0.95
	trunk_mesh.material = bark_material
	var canopy_mesh := CylinderMesh.new()
	canopy_mesh.top_radius = 0.0
	canopy_mesh.bottom_radius = 1.0
	canopy_mesh.height = 1.0
	canopy_mesh.radial_segments = 8
	canopy_mesh.rings = 1
	var needle_material := StandardMaterial3D.new()
	needle_material.albedo_color = Color.WHITE
	needle_material.vertex_color_use_as_albedo = true
	needle_material.vertex_color_is_srgb = true
	needle_material.roughness = 0.9
	canopy_mesh.material = needle_material
	var leaf_mesh := SphereMesh.new()
	leaf_mesh.radius = 1.0
	leaf_mesh.height = 2.0
	leaf_mesh.radial_segments = 8
	leaf_mesh.rings = 4
	leaf_mesh.material = needle_material
	for entry: Array in [[trunk_mesh, trunks, trunk_colors, "Trunks"], [canopy_mesh, canopies, canopy_colors, "Canopies"], [leaf_mesh, leaves, leaf_colors, "Leaves"]]:
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = true
		multimesh.mesh = entry[0]
		var transforms: Array[Transform3D] = entry[1]
		var colors: Array[Color] = entry[2]
		multimesh.instance_count = transforms.size()
		for i: int in transforms.size():
			multimesh.set_instance_transform(i, transforms[i])
			multimesh.set_instance_color(i, colors[i])
		var instance := MultiMeshInstance3D.new()
		instance.name = str(entry[3])
		instance.multimesh = multimesh
		add_child(instance)


func _build_environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.24, 0.38, 0.55)
	sky_material.sky_horizon_color = Color(0.86, 0.78, 0.62)
	sky_material.ground_bottom_color = Color(0.08, 0.09, 0.07)
	sky_material.ground_horizon_color = Color(0.82, 0.7, 0.52)
	sky_material.sky_curve = 0.12
	var sky := Sky.new()
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_SKY
	_environment.sky = sky
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_environment.ambient_light_energy = 1.0
	_environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	_environment.tonemap_exposure = 1.0
	_environment.glow_enabled = true
	_environment.glow_intensity = 0.7
	_environment.glow_bloom = 0.08
	_environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	_environment.ssao_enabled = true
	_environment.ssao_radius = 1.2
	_environment.ssao_intensity = 2.0
	_environment.fog_enabled = true
	_environment.fog_light_color = Color(0.66, 0.66, 0.58)
	_environment.fog_density = 0.005
	_environment.fog_sky_affect = 0.4
	_environment.volumetric_fog_enabled = true
	_environment.volumetric_fog_density = 0.013
	_environment.volumetric_fog_albedo = Color(0.9, 0.86, 0.76)
	_environment.volumetric_fog_anisotropy = 0.75
	_environment.volumetric_fog_length = 90.0
	_environment.volumetric_fog_ambient_inject = 0.2
	_environment.adjustment_enabled = true
	_environment.adjustment_contrast = 1.09
	_environment.adjustment_saturation = 1.08
	var world_environment := WorldEnvironment.new()
	world_environment.environment = _environment
	add_child(world_environment)
	# A low morning sun through the trees: long shadows and visible shafts in the mist.
	_sun = DirectionalLight3D.new()
	_sun.name = "Sun"
	_sun.rotation_degrees = Vector3(-24.0, -112.0, 0.0)
	_sun.light_color = Color(1.0, 0.82, 0.58)
	_sun.light_energy = 1.9
	_sun.light_volumetric_fog_energy = 2.2
	_sun.shadow_enabled = true
	_sun.shadow_bias = 0.05
	_sun.shadow_normal_bias = 1.5
	_sun.directional_shadow_blend_splits = true
	add_child(_sun)


# --- Things to use ----------------------------------------------------------------

func _build_interactables() -> void:
	objects["inner_gate"] = _make_door(Vector3(60.0, 2.5, 0.0), Vector3(0.5, 5.0, 6.0), Color(0.2, 0.22, 0.2))
	objects["ladder_tower"] = _make_ladder(Vector3(-45.0, 0.0, 31.95), 8.3, true, true)
	_add_document("ff_child_drawing", Vector3(-107.0, 0.05, -5.6))
	_add_document("ff_quarantine_order", Vector3(-88.4, 1.0, -3.0))
	_add_document("ff_soldier_letter", Vector3(-77.0, 1.1, -26.0))
	_add_document("ff_hunter_note", Vector3(-57.0, 0.3, -4.8))
	_add_document("ff_patrol_log", Vector3(-45.0, 8.35, 34.5))
	_add_document("ff_radio_log", Vector3(11.0, 0.95, 34.4))
	_add_document("ff_patrol_final", Vector3(40.0, 0.2, -54.0))
	_add_document("ff_guard_report", Vector3(71.0, 0.2, -16.0))
	for entry: Array in [["workbench_arrival", Vector3(-112.0, 0.0, 7.0)], ["workbench_outpost", Vector3(-70.0, 0.0, -23.0)], ["workbench_gate", Vector3(52.0, 0.0, 8.0)]]:
		var bench: Usable = _make_usable("Rest at the workbench", entry[1], false, 1.0)
		objects[entry[0]] = bench
		bench.used.connect(_on_workbench_used.bind(str(entry[0]), entry[1] as Vector3))
	var salvage: int = int(tuning.get("salvage_pickup", 30))
	var scrap_spots: Array[Vector3] = [Vector3(-110.0, 0.0, -3.0), Vector3(-86.0, 0.0, 14.0), Vector3(-66.0, 0.0, -38.0), Vector3(-44.0, 8.3, 33.0),
			Vector3(-2.0, 0.0, 6.0), Vector3(14.5, 0.0, 31.5), Vector3(36.0, 0.0, -46.0), Vector3(68.0, 0.0, -18.0)]
	for i: int in scrap_spots.size():
		var scrap: Usable = _make_pickup("Take salvage", scrap_spots[i], Vector3(0.3, 0.16, 0.22), Color(0.4, 0.42, 0.45), Color(0.9, 0.85, 0.7))
		_track("salvage_%d" % i, scrap)
		scrap.used.connect(func(_user: Player) -> void:
			GameState.salvage += salvage
			AudioManager.play_ui(&"pickup", -8.0)
			EventBus.toast_requested.emit("Salvage +%d" % salvage, 1.8))
	for at: Vector3 in [Vector3(-75.0, 0.0, -32.0), Vector3(-20.0, 0.0, 12.0), Vector3(50.0, 0.0, 2.0)]:
		var crate := ThrowablePickup.new()
		crate.position = at
		add_child(crate)
	# The hunter's cache (side objective): a free tier on the weapon in hand, plus a Lung Core.
	var cache: Usable = _make_pickup("Open the hunter's cache", Vector3(-4.0, 0.0, -57.5), Vector3(0.6, 0.35, 0.4), Color(0.3, 0.22, 0.14), CityBuilder.COLOR_WARM)
	_track("cache", cache)
	cache.used.connect(_on_cache_opened)
	var lung: Usable = _make_pickup("Take the Lung Core", Vector3(-8.0, 0.0, -56.0), Vector3(0.16, 0.26, 0.16), Color(0.75, 0.85, 0.95), Color(0.75, 0.88, 1.0))
	_track("lung_core", lung)
	lung.used.connect(func(player: Player) -> void:
		player.add_max_stamina(Upgrades.core_bonus("lung_core_stamina_bonus"))
		GameState.set_flag("ff_lung_core")
		AudioManager.play_ui(&"core_pickup", -4.0)
		EventBus.toast_requested.emit("Lung Core: maximum stamina +%d" % int(Upgrades.core_bonus("lung_core_stamina_bonus")), 3.5))
	var vital: Usable = _make_pickup("Take the Vital Core", Vector3(44.0, 0.0, -54.5), Vector3(0.14, 0.3, 0.14), Color(0.9, 0.3, 0.25), CityBuilder.COLOR_RED)
	_track("vital_core", vital)
	vital.used.connect(func(player: Player) -> void:
		var bonus: float = Upgrades.core_bonus("vital_core_health_bonus")
		player.health.max_health += bonus
		player.health.heal(player.health.max_health)
		GameState.max_health = player.health.max_health
		GameState.set_flag("ff_vital_core")
		player.emit_combat_status()
		AudioManager.play_ui(&"core_pickup", -4.0)
		EventBus.toast_requested.emit("Vital Core: maximum health +%d" % int(bonus), 3.5))
	var radio: Usable = _make_usable("Tune the radio set", Vector3(12.0, 0.0, 33.6), false, 1.0)
	objects["radio"] = radio
	radio.used.connect(_on_radio_used)
	var tunnel: Usable = _make_usable("Enter the service tunnel", Vector3(111.0, 0.0, 0.0), false, 1.6)
	objects["tunnel"] = tunnel
	tunnel.set_enabled(false)
	tunnel.used.connect(func(_user: Player) -> void: EventBus.travel_requested.emit("facility"))
	_spawn_warden()


func _on_workbench_used(player: Player, key: String, at: Vector3) -> void:
	player.health.heal(player.health.max_health)
	player.injectors = player.combat.max_injectors
	player.emit_combat_status()
	reset_encounters()
	set_checkpoint("ff_" + key, at + Vector3(0.0, 0.1, -0.6), PI, true)
	EventBus.workbench_used.emit(player)


func _on_cache_opened(player: Player) -> void:
	GameState.set_flag("ff_cache")
	var weapon_id: String = player.weapon.id
	var before: int = Upgrades.tier(weapon_id)
	GameState.weapons[weapon_id] = mini(before + 1, Upgrades.MAX_TIER)
	GameState.salvage += 60
	AudioManager.play_ui(&"core_pickup", -6.0)
	EventBus.toast_requested.emit(("Hunter's cache: %s honed to tier %d, salvage +60" % [player.weapon.display_name, before + 1])
			if before < Upgrades.MAX_TIER else "Hunter's cache: salvage +60", 4.0)
	_radio("cache")
	_update_objective()


func _build_triggers() -> void:
	_trigger(Vector3(-84.0, 0.0, -40.0), Vector3(6.0, 4.0, 14.0), func(_p: Player) -> void:
		_advance_to(Stage.TOWER)
		set_checkpoint("ff_inside_wall", Vector3(-84.0, 0.1, -40.0), -PI * 0.5))
	_trigger(Vector3(-20.0, 0.0, -8.0), Vector3(12.0, 4.0, 30.0), func(_p: Player) -> void: _hint("ford", 8.0))
	_trigger(Vector3(12.0, 0.0, 24.0), Vector3(16.0, 4.0, 8.0), func(_p: Player) -> void:
		_advance_to(Stage.TUNE)
		set_checkpoint("ff_tower", Vector3(12.0, 0.1, 26.0), PI)
		_radio("tower"))
	var arena := TriggerZone.new()
	arena.size = Vector3(6.0, 4.0, 40.0)
	arena.position = Vector3(69.0, 0.0, 0.0)
	arena.one_shot = false
	add_child(arena)
	arena.triggered.connect(_on_arena_entered)


func _register_enemies() -> void:
	# The breach in the outer wall.
	add_enemy_spawn("hollow", Vector3(-86.0, 0.05, -44.0), 90.0)
	add_enemy_spawn("hollow", Vector3(-80.0, 0.05, -36.0), 180.0, [Vector3(-80.0, 0.0, -36.0), Vector3(-82.0, 0.0, -20.0)])
	add_enemy_spawn("hollow", Vector3(-98.0, 0.05, -24.0), 0.0, [Vector3(-98.0, 0.0, -24.0), Vector3(-97.0, 0.0, -6.0)])
	# The outpost.
	add_enemy_spawn("hollow", Vector3(-70.0, 0.05, -32.0), 0.0)
	add_enemy_spawn("spitter", Vector3(-60.0, 0.05, -36.0), 90.0)
	add_enemy_spawn("hollow", Vector3(-58.0, 0.05, -18.0), 180.0, [Vector3(-58.0, 0.0, -18.0), Vector3(-50.0, 0.0, -6.0)])
	# Wolves: by the watchtower, at the ford, around the lower cave.
	add_enemy_spawn("wolf", Vector3(-40.0, 0.05, 26.0), 180.0, [Vector3(-40.0, 0.0, 26.0), Vector3(-50.0, 0.0, 22.0)])
	add_enemy_spawn("wolf", Vector3(-38.0, 0.05, 30.0), 90.0)
	add_enemy_spawn("wolf", Vector3(-10.0, 0.05, -10.0), 90.0, [Vector3(-10.0, 0.0, -10.0), Vector3(-6.0, 0.0, -30.0)])
	add_enemy_spawn("wolf", Vector3(-8.0, 0.05, -4.0), 90.0)
	add_enemy_spawn("wolf", Vector3(-4.0, 0.05, -12.0), 180.0)
	add_enemy_spawn("wolf", Vector3(36.0, 0.05, -38.0), 0.0, [Vector3(36.0, 0.0, -38.0), Vector3(44.0, 0.0, -34.0)])
	add_enemy_spawn("wolf", Vector3(42.0, 0.05, -40.0), 0.0)
	add_enemy_spawn("hollow", Vector3(40.0, 0.05, -50.0), 0.0)
	# The radio tower and the road to the inner gate.
	add_enemy_spawn("hollow", Vector3(6.0, 0.05, 26.0), 90.0, [Vector3(6.0, 0.0, 26.0), Vector3(18.0, 0.0, 24.0)])
	add_enemy_spawn("hollow", Vector3(20.0, 0.05, 30.0), -90.0)
	add_enemy_spawn("spitter", Vector3(30.0, 0.05, 10.0), 90.0)
	add_enemy_spawn("bulwark", Vector3(46.0, 0.05, 0.0), 90.0, [Vector3(46.0, 0.0, -4.0), Vector3(44.0, 0.0, 6.0)])
