class_name Facility
extends StoryLevel
## Area 3, the Meridian Resonance Institute (Act 3 and the finale). Four
## levels, each lower than the last, joined by stairwells running east:
##
##   Level 1 (y   0, x   0..40)   reception and security: restore power
##   Level 2 (y  -6, x  52..92)   living quarters: the research keycard, Lyra's wall
##   Level 3 (y -12, x 104..144)  research labs: laser grid, the resonance lock
##   Level 4 (y -18, x 156..192)  the Resonance Chamber: the Choir
##
## Clean white panels and failing lights at the top; emergency red in the
## middle; Echo growth and cyan light at the bottom.

enum Stage { POWER, DESCEND, KEYCARD, LABS, LOCK, CHAMBER, CHOIR, SEVER, DONE }

const L := CityBuilder.Look
const SPAWN := Vector3(3.0, 0.1, 0.0)
const LEVEL_Y: Array[float] = [0.0, -6.0, -12.0, -18.0]
const CHAMBER_CENTER := Vector3(176.0, -18.0, 0.0)
const WHITE := Color(0.62, 0.64, 0.66)
const GREY := Color(0.3, 0.32, 0.35)
const WAYPOINTS: Dictionary = {
	0: Vector3(33.0, 1.2, -10.0),
	1: Vector3(40.0, 1.0, 0.0),
	2: Vector3(63.0, -5.0, -8.0),
	3: Vector3(92.0, -5.0, 0.0),
	4: Vector3(143.0, -10.8, 0.0),
	5: Vector3(164.0, -17.0, 0.0),
	7: Vector3(176.0, -16.6, -11.5),
}

var stage: Stage = Stage.POWER
var dressing: FacilityDressing
var choir: Choir
var sentinels: Array[Sentinel] = []

var _builder: CityBuilder
var _environment: Environment
var _dummy_sun: DirectionalLight3D
var _power_lights: Array[Light3D] = []
var _laser_zone: Area3D
var _laser_visual: Node3D
var _laser_tick: float = 0.0
var _tick: float = 0.0
var _summoned: Array[Enemy] = []


func _ready() -> void:
	screen_tint = Color(0.95, 1.02, 1.05)
	title = "THE UNDERGROUND FACILITY"
	subtitle = "ACT 3"
	setup_story("uf", "the Underground Facility", "res://data/levels/facility.json", "res://data/story/facility.json", "res://data/documents/facility.json")
	spawn_position = SPAWN
	spawn_yaw = -PI * 0.5
	GameState.current_area = "facility"

	_builder = CityBuilder.new()
	_builder.name = "Geometry"
	add_child(_builder)
	_build_levels()
	dressing = FacilityDressing.new()
	dressing.build(_builder)
	_builder.commit()
	_builder.set_rain_ripples(0.0)
	_build_environment()
	dressing.build_effects(self)
	bake_navigation(AABB(Vector3(-2.0, -20.0, -30.0), Vector3(198.0, 24.0, 60.0)))
	_build_doors()
	_build_interactables()
	_build_sentinels_and_lasers()
	_build_triggers()
	_register_enemies()
	spawn_enemies()
	_spawn_choir()
	for light: Light3D in _power_lights:
		light.visible = false
	AudioManager.set_ambience(&"facility", &"facility_loop", -14.0)
	AudioManager.set_ambience(&"choir", &"choir_loop", AudioManager.SILENT_DB)
	SettingsManager.register_world(_environment, _dummy_sun)
	_update_objective()


func _exit_tree() -> void:
	SettingsManager.unregister_world(_environment)
	AudioManager.clear_ambience()
	super._exit_tree()


func is_sheltered(_point: Vector3) -> bool:
	return true


func _physics_process(delta: float) -> void:
	var player: Player = find_player()
	if player == null:
		return
	_update_lasers(delta, player)
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.5
	_update_enemy_sleep(player.global_position)
	# The deeper Kael goes, the more of the hum is the Choir.
	var depth: float = smoothstep(96.0, 160.0, player.global_position.x)
	AudioManager.set_ambience(&"choir", &"choir_loop", lerpf(AudioManager.SILENT_DB, -8.0, depth))
	AudioManager.set_ambience(&"facility", &"facility_loop", lerpf(-14.0, -24.0, depth))
	for sentinel: Sentinel in sentinels:
		if sentinel.enabled and sentinel.global_position.distance_to(player.global_position) < 14.0:
			_hint("sentinel", 9.0)


func get_tour_stops() -> Array[Array]:
	return [
		[Vector3(4.0, 2.2, 4.0), Vector3(24.0, 1.4, -2.0)],
		[Vector3(22.0, 2.4, -3.0), Vector3(38.0, 1.4, 0.0)],
		[Vector3(46.0, -1.0, 0.0), Vector3(56.0, -5.0, 0.0)],
		[Vector3(58.0, -3.8, 0.0), Vector3(84.0, -4.8, 0.5)],
		[Vector3(64.0, -3.8, 8.0), Vector3(58.0, -4.8, 13.0)],
		[Vector3(108.0, -9.8, 0.0), Vector3(128.0, -10.8, 0.0)],
		[Vector3(128.0, -9.6, 9.0), Vector3(114.0, -10.8, 8.0)],
		[Vector3(159.0, -15.6, 6.0), Vector3(176.0, -14.0, -10.0)],
		[Vector3(170.0, -15.0, 10.0), Vector3(176.0, -12.0, -14.0)],
	]


# --- Story ----------------------------------------------------------------------

func start_story(player: Player, skip_intro: bool) -> void:
	_player = player
	if not skip_intro:
		var shots: Array = [
			{"from": Vector3(14.0, 3.2, 9.0), "look": Vector3(4.0, 1.2, 0.0), "to": Vector3(11.0, 2.6, 6.0), "seconds": 9.5},
			{"from": Vector3(6.5, 1.7, -2.4), "look": Vector3(3.0, 1.4, 0.0), "to": Vector3(6.0, 1.6, -1.6), "seconds": 9.0, "fov": 45.0},
		]
		EventBus.fade_requested.emit(1.0, 0.0)
		EventBus.fade_requested.emit(0.0, 2.0)
		cinematic.play(shots, story.get("intro", []), player)
		await cinematic.finished
	EventBus.area_title_requested.emit(title, subtitle)
	_radio("arrive")
	set_checkpoint("uf_arrival", SPAWN, -PI * 0.5)
	_update_objective()


func _advance_to(next: Stage) -> void:
	if int(next) > int(stage):
		stage = next
		_update_objective()


func current_stage_key() -> String:
	var keys: PackedStringArray = ["power", "descend", "keycard", "labs", "lock", "chamber", "choir", "sever", "done"]
	return keys[int(stage)]


func _update_objective() -> void:
	var texts: Dictionary = story.get("objectives", {})
	var keys: PackedStringArray = ["power", "descend", "keycard", "labs", "lock", "chamber", "choir", "sever", "done"]
	var done: Array[String] = []
	for i: int in int(stage):
		done.append(str(texts.get(keys[i], "")))
	var sides: Dictionary = story.get("side_objectives", {})
	MissionManager.mission_title = "Act 3: The Song"
	MissionManager.set_completed(done)
	MissionManager.set_side("archive", str(sides.get("archive", "")), GameState.collected_documents.has("uf_security_archive"))
	if int(stage) >= int(Stage.LABS):
		MissionManager.set_side("office", str(sides.get("office", "")), GameState.collected_documents.has("uf_ilse_office"))
	var text: String = str(texts.get(keys[int(stage)], ""))
	MissionManager.set_objective(text, WAYPOINTS.get(int(stage)))
	EventBus.objective_changed.emit(text, MissionManager.active_side_text())


func _document_collected(document_id: String) -> void:
	if document_id == "uf_security_archive":
		_radio("archive")
	elif document_id == "uf_ilse_office":
		_radio("office")
	_update_objective()


func _story_ui() -> StoryUI:
	return get_tree().get_first_node_in_group(&"story_ui") as StoryUI


func _on_generators_used(_user: Player) -> void:
	if GameState.has_flag("uf_power"):
		return
	var ui: StoryUI = _story_ui()
	if ui == null:
		restore_power()
		return
	PuzzlePanels.load_balance(ui, Puzzles.LoadBalance.new(tuning.get("generator_loads", []), int(tuning.get("generator_capacity", 50))), restore_power)


func restore_power() -> void:
	if GameState.has_flag("uf_power"):
		return
	_apply_power()
	AudioManager.play_ui(&"power_up", -2.0, &"SFX")
	_advance_to(Stage.DESCEND)
	_radio("power")
	set_checkpoint("uf_power", Vector3(33.0, 0.1, -8.0), 0.0)


func _apply_power() -> void:
	GameState.set_flag("uf_power")
	for light: Light3D in _power_lights:
		light.visible = true
	_open_door("stair_1")
	(objects["generators"] as Usable).set_enabled(false)


func _on_keycard_door(_user: Player, key: String) -> void:
	if not GameState.has_flag("uf_keycard"):
		AudioManager.play_ui(&"ui_wrong", -6.0)
		EventBus.toast_requested.emit("Locked. It wants a research keycard.", 3.0)
		return
	_open_door(key)
	GameState.set_flag("uf_open_" + key)
	(objects["reader_" + key] as Usable).set_enabled(false)
	AudioManager.play_ui(&"switch", -2.0)


func _on_lock_used(_user: Player) -> void:
	if GameState.has_flag("uf_lock_open"):
		return
	_advance_to(Stage.LOCK)
	_hint("lock", 9.0)
	var ui: StoryUI = _story_ui()
	if ui == null:
		open_lock()
		return
	PuzzlePanels.tone_lock(ui, Puzzles.ToneLock.new(tuning.get("tone_sequence", [])), open_lock)


func open_lock() -> void:
	if GameState.has_flag("uf_lock_open"):
		return
	GameState.set_flag("uf_lock_open")
	_open_door("lock")
	(objects["lock_panel"] as Usable).set_enabled(false)
	AudioManager.play_sfx(&"gate_open", Vector3(144.0, -10.5, 0.0), 6.0)
	_advance_to(Stage.CHAMBER)
	_radio("lock_open")
	set_checkpoint("uf_lock", Vector3(141.0, LEVEL_Y[2] + 0.1, 0.0), -PI * 0.5)


func disable_sentinels(group: String) -> void:
	GameState.set_flag("uf_sentinels_" + group)
	for i: int in sentinels.size():
		if str(sentinels[i].get_meta(&"group")) == group:
			sentinels[i].disable()
			if objects.has("cable_%d" % i):
				(objects["cable_%d" % i] as Usable).set_enabled(false)


func power_down_lasers() -> void:
	GameState.set_flag("uf_lasers_off")
	if _laser_visual != null:
		_laser_visual.visible = false


func _update_lasers(delta: float, player: Player) -> void:
	if GameState.has_flag("uf_lasers_off") or _laser_zone == null:
		return
	_laser_tick -= delta
	if _laser_tick > 0.0 or not _laser_zone.overlaps_body(player):
		return
	_laser_tick = 0.4
	_hint("lasers", 8.0)
	var hit := HitInfo.new()
	hit.damage = float(tuning.get("laser_damage_per_tick", 9.0))
	hit.origin = _laser_zone.global_position
	hit.can_be_blocked = false
	hit.can_be_parried = false
	player.receive_hit(hit)


# --- The Choir --------------------------------------------------------------------

func _spawn_choir() -> void:
	if choir != null and is_instance_valid(choir):
		choir.queue_free()
	choir = Choir.new()
	choir.name = "Choir"
	choir.tuning = tuning.get("choir", {})
	choir.position = CHAMBER_CENTER
	add_child(choir)
	choir.summon_requested.connect(_on_summon)
	choir.phase_changed.connect(func(phase: int) -> void:
		EventBus.dialogue_requested.emit(story.get("phase_%d" % phase, []))
		_choir_phase_shot.call_deferred()
		if phase == 2:
			_hint("pillars", 9.0))
	choir.defeated.connect(_on_choir_defeated)


func _on_chamber_entered(player: Player) -> void:
	if stage >= Stage.CHOIR or GameState.has_flag("uf_choir_dead"):
		return
	stage = Stage.CHOIR
	_update_objective()
	set_checkpoint("uf_chamber", Vector3(159.0, LEVEL_Y[3] + 0.1, 0.0), -PI * 0.5)
	if not GameState.has_flag("uf_choir_seen"):
		GameState.set_flag("uf_choir_seen")
		var shots: Array = [
			{"from": Vector3(164.0, -16.4, 6.0), "look": Vector3(176.0, -9.0, -18.0), "to": Vector3(168.0, -16.8, 3.0), "seconds": 7.5},
			{"from": Vector3(176.0, -16.0, -4.0), "look": Vector3(176.0, -16.4, -12.8), "to": Vector3(176.0, -16.2, -7.0), "seconds": 5.0, "fov": 45.0},
		]
		cinematic.play(shots, story.get("choir_intro", []), player)
		await cinematic.finished
		EventBus.area_title_requested.emit("THE CHOIR", "What the Meridian team became")
	_hint("choir", 10.0)
	choir.begin(player)


## A beat on each phase change: the camera looks up at the heart as the Choir changes.
## Deferred, so any enemies it calls up hold still too.
func _choir_phase_shot() -> void:
	if choir == null or not is_instance_valid(choir):
		return
	var heart: Vector3 = CHAMBER_CENTER + Vector3(0.0, 1.6, -12.8)
	var shots: Array = [{"from": CHAMBER_CENTER + Vector3(3.5, 1.2, -3.0), "look": heart + Vector3(0.0, 1.5, 0.0),
			"to": CHAMBER_CENTER + Vector3(1.5, 1.0, -5.5), "seconds": 2.4, "fov": 50.0}]
	var frozen: Array = [choir]
	frozen.append_array(_summoned)
	AudioManager.play_sfx(&"choir_swell", heart, 4.0)
	boss_moment(shots, frozen)


func _on_summon(count: int) -> void:
	var spots: Array[Vector3] = [Vector3(166.0, -17.95, 10.0), Vector3(166.0, -17.95, -10.0), Vector3(186.0, -17.95, 10.0), Vector3(186.0, -17.95, -8.0)]
	var player: Player = find_player()
	for i: int in count:
		var enemy: Enemy = spawn_enemy("hollow" if i % 2 == 0 else "skitter", spots[i % spots.size()])
		_summoned.append(enemy)
		if player != null:
			enemy.alert.call_deferred(player.global_position)


func _on_choir_defeated() -> void:
	GameState.set_flag("uf_choir_dead")
	for enemy: Enemy in _summoned:
		if is_instance_valid(enemy) and not enemy.is_dead():
			enemy.finish_takedown()
	stage = Stage.SEVER
	(objects["anchor"] as Usable).set_enabled(true)
	_update_objective()
	EventBus.hint_requested.emit("The heart is still. Sever the anchor.", 8.0)


## The final blow: Kael cuts the anchor, the song ends, the credits roll.
func play_ending() -> void:
	if cinematic.is_playing:
		# A phase-change beat may still be on screen; the ending takes over.
		cinematic.skip()
	stage = Stage.DONE
	_update_objective()
	var player: Player = find_player()
	var shots: Array = [
		{"from": Vector3(173.0, -16.2, -6.0), "look": Vector3(176.0, -16.4, -12.8), "to": Vector3(174.0, -16.4, -8.0), "seconds": 13.0, "fov": 45.0},
		{"from": Vector3(176.0, -16.6, -9.0), "look": Vector3(176.0, -16.2, -4.0), "to": Vector3(176.4, -16.6, -9.6), "seconds": 12.5, "fov": 42.0},
		{"from": Vector3(168.0, -13.0, 10.0), "look": Vector3(176.0, -12.0, -16.0), "to": Vector3(164.0, -10.0, 13.0), "seconds": 11.5},
	]
	var events: Array = [
		{"at": 26.5, "call": func() -> void:
			AudioManager.play_ui(&"echo_swell", -2.0, &"SFX")
			if choir != null and is_instance_valid(choir):
				choir.collapse(VFX.value("collapse_seconds"))},
		{"at": 31.0, "call": func() -> void:
			AudioManager.clear_ambience()
			if choir != null and is_instance_valid(choir):
				choir.visible = false
			EventBus.fade_requested.emit(1.0, 4.0)},
	]
	cinematic.play(shots, story.get("ending", []), player, events)
	await cinematic.finished
	GameState.set_flag("game_complete")
	Chapters.mark_game_complete()
	NewGamePlus.record_finish()
	EventBus.act_completed.emit("Ghostline", get_summary_rows())
	var ui: StoryUI = _story_ui()
	if ui != null:
		await ui.summary_closed
	EventBus.credits_requested.emit(all_documents_found())


func all_documents_found() -> bool:
	return GameState.collected_documents.size() >= Documents.total()


func get_summary_rows() -> Array:
	var seconds: int = int(GameState.playtime_seconds)
	return [
		["Total time", "%d:%02d" % [seconds / 60, seconds % 60]],
		["Documents found", "%d / %d" % [GameState.collected_documents.size(), Documents.total()]],
		["Salvage left", str(GameState.salvage)],
		["Epilogue", "Unlocked" if all_documents_found() else "Find every document"],
	]


func reset_encounters() -> void:
	_summoned.clear()
	super.reset_encounters()
	if stage == Stage.CHOIR and not GameState.has_flag("uf_choir_dead"):
		EventBus.boss_ended.emit()
		_spawn_choir()
		stage = Stage.CHAMBER
		_update_objective()


func prepare_benchmark(player: Player) -> void:
	player.god_mode = true
	player.teleport(Vector3(170.0, LEVEL_Y[3] + 0.1, 4.0), -PI * 0.5)
	GameState.set_flag("uf_choir_seen")
	_on_chamber_entered(player)


# --- Saving ---------------------------------------------------------------------

func capture_state() -> void:
	var state: Dictionary = capture_common()
	state["stage"] = int(Stage.CHAMBER) if stage == Stage.CHOIR else int(stage)
	GameState.set_level_state(flag_prefix, state)


func restore_state(player: Player) -> void:
	_player = player
	var state: Dictionary = saved_state()
	stage = int(state.get("stage", 0)) as Stage
	restore_common(state)
	if GameState.has_flag("uf_power"):
		_apply_power()
	for key: String in ["stair_2", "office"]:
		if GameState.has_flag("uf_open_" + key):
			_open_door(key)
			(objects["reader_" + key] as Usable).set_enabled(false)
	if GameState.has_flag("uf_lock_open"):
		_open_door("lock")
		(objects["lock_panel"] as Usable).set_enabled(false)
	for group: String in ["upper", "labs"]:
		if GameState.has_flag("uf_sentinels_" + group):
			disable_sentinels(group)
	for i: int in sentinels.size():
		if _taken.has("cable_%d" % i):
			sentinels[i].disable()
	if GameState.has_flag("uf_lasers_off"):
		power_down_lasers()
	if GameState.has_flag("uf_choir_dead"):
		if choir != null and is_instance_valid(choir):
			choir.queue_free()
		(objects["anchor"] as Usable).set_enabled(stage == Stage.SEVER)
	_update_objective()


# --- Geometry -------------------------------------------------------------------

## One level: floor slab and a walled, roofed shell with the given doorways.
func _shell(x0: float, x1: float, y: float, doors: Array, color: Color, height: float = 4.0, z0: float = -15.0, z1: float = 15.0) -> void:
	_builder.block(x0, z0, x1, z1, 0.5, y - 0.5, L.PANEL, color * 0.8)
	_builder.room(x0, z0, x1, z1, height, doors, color, y, true, L.PANEL)


## A stairwell running east from (x, y_top) down to (x + 12, y_top - 6).
func _stairs(x: float, y_top: float) -> void:
	_builder.ramp(Vector3(x + 12.0, y_top - 6.0, 0.0), Vector3(x, y_top, 0.0), 3.4, L.METAL, GREY)
	_builder.block(x, -2.0, x + 12.0, -1.7, 10.5, y_top - 6.5, L.PANEL, GREY)
	_builder.block(x, 1.7, x + 12.0, 2.0, 10.5, y_top - 6.5, L.PANEL, GREY)
	_builder.block(x, -2.0, x + 12.0, 2.0, 0.3, y_top + 4.0, L.PANEL, GREY)
	_builder.point_light(Vector3(x + 6.0, y_top - 0.5, 0.0), CityBuilder.COLOR_RED, 1.4, 9.0)
	surfaces.append([AABB(Vector3(x, y_top - 7.0, -2.0), Vector3(12.0, 8.0, 4.0)), "metal"])


func _light(at: Vector3, color: Color, energy: float, needs_power: bool, flicker: bool = false) -> void:
	_builder.strip(at + Vector3(0.0, 0.14, 0.0), Vector3(1.6, 0.05, 0.3), color)
	var light: OmniLight3D = _builder.point_light(at, color, energy, 10.0, false, flicker)
	if needs_power:
		_power_lights.append(light)


func _echo_growth(from: Vector3, along: Vector3, length: float, count: int) -> void:
	for i: int in count:
		var at: Vector3 = from + along * _builder.random_range(0.0, length) + Vector3(0.0, _builder.random_range(0.2, 3.2), 0.0)
		_builder.strip(at, Vector3(absf(along.x) * 0.4 + 0.1, _builder.random_range(0.15, 0.9), absf(along.z) * 0.4 + 0.1), CityBuilder.COLOR_ECHO)


func _build_levels() -> void:
	var b: CityBuilder = _builder
	var white_light := Color(0.9, 0.95, 1.0)
	# Level 1: reception and security.
	var y: float = LEVEL_Y[0]
	_shell(0.0, 40.0, y, [["e", 0.0, 3.0]], WHITE)
	b.room(27, 6, 39.7, 14.7, 4.0, [["w", 10.0, 2.0]], WHITE, y, false, L.PANEL)       # security office
	b.room(27, -14.7, 39.7, -6, 4.0, [["w", -10.0, 2.0]], WHITE, y, false, L.PANEL)    # generator room
	b.block(9.0, -3.5, 10.0, 3.5, 1.1, y, L.PANEL, GREY)                                 # reception desk
	b.block(0.3, -1.6, 0.6, 1.6, 3.0, y, L.METAL, CityBuilder.COLOR_DARK, false, false)  # sealed tunnel door
	for bench_z: float in [-12.0, 12.0]:
		b.block(4.0, bench_z - 0.4, 9.0, bench_z + 0.4, 0.5, y, L.METAL, GREY)
	b.block(30.0, 13.4, 36.0, 14.2, 0.9, y, L.METAL, GREY)                               # security desk
	b.block(30.0, -14.2, 37.0, -12.6, 1.6, y, L.METAL, Color(0.32, 0.3, 0.12))            # generators
	b.sign_text("MERIDIAN RESONANCE INSTITUTE", Vector3(10.05, y + 2.6, 0.0), -90.0, 0.8, Color(0.25, 0.3, 0.35))
	for at: Vector3 in [Vector3(6.0, y + 3.7, 0.0), Vector3(18.0, y + 3.7, -8.0), Vector3(18.0, y + 3.7, 8.0), Vector3(33.0, y + 3.7, 10.0), Vector3(33.0, y + 3.7, -10.0)]:
		_light(at, white_light, 1.7, true, at.x > 15.0 and at.z < 0.0)
	b.point_light(Vector3(14.0, y + 3.4, 0.0), CityBuilder.COLOR_RED, 1.2, 12.0)
	b.point_light(Vector3(33.0, y + 3.2, -10.0), CityBuilder.COLOR_RED, 0.9, 8.0)
	_stairs(40.0, y)
	# Level 2: living quarters.
	y = LEVEL_Y[1]
	_shell(52.0, 92.0, y, [["w", 0.0, 3.0], ["e", 0.0, 3.0]], WHITE * 0.92)
	b.room(56, 3, 70, 14.7, 4.0, [["n", 63.0, 2.0]], WHITE, y, false, L.PANEL)       # school room
	b.room(74, 3, 88, 14.7, 4.0, [["n", 81.0, 2.0]], WHITE, y, false, L.PANEL)       # common room
	b.room(56, -14.7, 70, -3, 4.0, [["s", 63.0, 2.0]], WHITE, y, false, L.PANEL)     # bunks A
	b.room(74, -14.7, 88, -3, 4.0, [["s", 81.0, 2.0]], WHITE, y, false, L.PANEL)     # bunks B
	for row: int in 2:
		for column: int in 3:
			var desk := Vector3(59.0 + column * 3.6, y, 7.0 + row * 3.0)
			b.block(desk.x - 0.55, desk.z - 0.3, desk.x + 0.55, desk.z + 0.3, 0.7, y, L.INTERIOR, Color(0.5, 0.42, 0.3))
	for bunk_x: float in [57.5, 61.5, 65.5, 75.5, 79.5]:
		b.block(bunk_x - 0.5, -14.2, bunk_x + 0.5, -12.0, 0.5, y, L.METAL, GREY)
		b.block(bunk_x - 0.5, -14.2, bunk_x + 0.5, -12.0, 0.1, y + 1.5, L.METAL, GREY, false, false)
	b.block(76.0, 12.6, 84.0, 14.0, 0.8, y, L.INTERIOR, Color(0.4, 0.33, 0.24))      # common room table
	b.block(84.6, -13.8, 86.8, -13.1, 0.9, y, L.METAL, Color(0.24, 0.2, 0.15))         # workbench
	b.strip(Vector3(85.7, y + 1.3, -13.2), Vector3(1.6, 0.05, 0.05), CityBuilder.COLOR_WARM)
	for at: Vector3 in [Vector3(58.0, y + 3.7, 0.0), Vector3(72.0, y + 3.7, 0.0), Vector3(86.0, y + 3.7, 0.0), Vector3(63.0, y + 3.7, 9.0), Vector3(81.0, y + 3.7, 9.0)]:
		_light(at, white_light, 1.5, true, at.x > 70.0 and at.z == 0.0)
	b.point_light(Vector3(63.0, y + 3.2, -9.0), CityBuilder.COLOR_RED, 1.0, 9.0)
	b.point_light(Vector3(81.0, y + 3.2, -9.0), CityBuilder.COLOR_WARM, 1.0, 8.0)
	_stairs(92.0, y)
	# Level 3: research labs. Emergency red, and the growth has reached this far.
	y = LEVEL_Y[2]
	_shell(104.0, 144.0, y, [["w", 0.0, 3.0], ["e", 0.0, 3.0]], WHITE * 0.8)
	b.room(108, 3, 120, 14.7, 4.0, [["n", 114.0, 2.0], ["e", 9.0, 2.0]], WHITE * 0.85, y, false, L.PANEL)    # lab A
	b.room(124, 3, 138, 14.7, 4.0, [["n", 131.0, 2.0], ["w", 9.0, 2.0]], WHITE * 0.85, y, false, L.PANEL)    # lab B
	b.block(120, 2.85, 124, 3.15, 4.0, y, L.PANEL, WHITE * 0.85)                                              # closes the passage between them
	b.room(108, -14.7, 120, -3, 4.0, [["s", 114.0, 2.0]], WHITE * 0.85, y, false, L.PANEL)                    # Dr. Vance's office
	b.room(124, -14.7, 138, -3, 4.0, [["s", 131.0, 2.0]], WHITE * 0.85, y, false, L.PANEL)                    # storage
	b.block(109.0, 12.8, 118.0, 14.0, 0.9, y, L.METAL, GREY)
	b.block(126.0, 12.8, 136.0, 14.0, 0.9, y, L.METAL, GREY)
	b.block(110.0, -14.0, 116.0, -12.8, 0.8, y, L.INTERIOR, Color(0.36, 0.26, 0.18))
	for at: Vector3 in [Vector3(110.0, y + 3.4, 0.0), Vector3(134.0, y + 3.4, 0.0), Vector3(131.0, y + 3.2, -9.0)]:
		b.point_light(at, CityBuilder.COLOR_RED, 1.5, 12.0, false, true)
	_light(Vector3(114.0, y + 3.7, 9.0), white_light, 1.4, true, true)
	_light(Vector3(131.0, y + 3.7, 9.0), white_light, 1.4, true)
	b.point_light(Vector3(114.0, y + 2.6, -9.0), CityBuilder.COLOR_WARM, 1.1, 8.0)
	_echo_growth(Vector3(126.0, y, -2.85), Vector3(1, 0, 0), 17.0, 14)
	_echo_growth(Vector3(143.7, y, -14.0), Vector3(0, 0, 1), 28.0, 22)
	b.point_light(Vector3(141.0, y + 2.0, 0.0), CityBuilder.COLOR_ECHO, 1.8, 10.0)
	_stairs(144.0, y)
	# Level 4: the Resonance Chamber. A platform; beyond its north edge, the Choir.
	y = LEVEL_Y[3]
	b.room(156, -28, 192, 16, 13.0, [["w", 0.0, 3.0]], Color(0.1, 0.12, 0.14), y, true, L.PANEL)
	b.block(156, -14, 192, 16, 0.6, y - 0.6, L.METAL, Color(0.16, 0.18, 0.2))
	b.block(162, -14.4, 192, -14.0, 0.5, y, L.METAL, CityBuilder.COLOR_DARK)
	b.block(160.0, 9.2, 162.2, 9.9, 0.9, y, L.METAL, Color(0.24, 0.2, 0.15))           # last workbench
	b.strip(Vector3(161.1, y + 1.3, 9.8), Vector3(1.6, 0.05, 0.05), CityBuilder.COLOR_WARM)
	b.block(157.0, -11.0, 158.0, -8.0, 1.1, y, L.METAL, GREY)
	_echo_growth(Vector3(156.3, y, -13.0), Vector3(0, 0, 1), 28.0, 30)
	_echo_growth(Vector3(162.0, y, 15.7), Vector3(1, 0, 0), 28.0, 30)
	b.point_light(Vector3(176.0, y - 0.2, -20.0), CityBuilder.COLOR_ECHO, 4.0, 22.0)
	b.point_light(Vector3(160.0, y + 3.0, 0.0), CityBuilder.COLOR_WARM, 1.2, 9.0)
	surfaces.append([AABB(Vector3(156, y - 1.0, -28), Vector3(36, 14, 44)), "metal"])


func _build_environment() -> void:
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.background_color = Color(0.0, 0.0, 0.0)
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color(0.42, 0.46, 0.52)
	_environment.ambient_light_energy = 0.22
	_environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	_environment.tonemap_exposure = 1.15
	_environment.adjustment_enabled = true
	_environment.adjustment_contrast = 1.1
	_environment.adjustment_saturation = 0.9
	_environment.glow_enabled = true
	_environment.glow_intensity = 0.9
	_environment.glow_bloom = 0.1
	_environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	_environment.ssao_enabled = true
	_environment.ssao_radius = 1.0
	_environment.ssao_intensity = 2.0
	_environment.ssr_enabled = true
	_environment.volumetric_fog_enabled = true
	_environment.volumetric_fog_density = 0.012
	_environment.volumetric_fog_albedo = Color(0.8, 0.85, 0.9)
	_environment.volumetric_fog_length = 40.0
	var world_environment := WorldEnvironment.new()
	world_environment.environment = _environment
	add_child(world_environment)
	# Underground: no sun. The settings code expects a directional light to exist.
	_dummy_sun = DirectionalLight3D.new()
	_dummy_sun.light_energy = 0.0
	_dummy_sun.shadow_enabled = false
	add_child(_dummy_sun)


# --- Doors, things to use, security -------------------------------------------------

func _build_doors() -> void:
	var metal := Color(0.22, 0.24, 0.27)
	objects["stair_1"] = _make_door(Vector3(40.0, LEVEL_Y[0] + 1.2, 0.0), Vector3(0.3, 2.4, 3.0), metal)
	objects["stair_2"] = _make_door(Vector3(92.0, LEVEL_Y[1] + 1.2, 0.0), Vector3(0.3, 2.4, 3.0), metal)
	objects["office"] = _make_door(Vector3(114.0, LEVEL_Y[2] + 1.2, -3.0), Vector3(2.0, 2.4, 0.3), metal)
	objects["lock"] = _make_door(Vector3(144.0, LEVEL_Y[2] + 1.2, 0.0), Vector3(0.3, 2.4, 3.0), Color(0.1, 0.4, 0.45))


func _build_interactables() -> void:
	var y1: float = LEVEL_Y[0]
	var y2: float = LEVEL_Y[1]
	var y3: float = LEVEL_Y[2]
	var y4: float = LEVEL_Y[3]
	_add_document("uf_reception_memo", Vector3(9.5, y1 + 1.12, 1.0))
	_add_document("uf_security_archive", Vector3(34.0, y1 + 0.92, 13.6))
	_add_document("uf_technician_voicemail", Vector3(80.0, y2 + 0.82, 13.2))
	_add_document("uf_lyra_wall", Vector3(63.0, y2 + 1.2, 14.2))
	_add_document("uf_ilse_notes", Vector3(113.0, y3 + 0.92, 13.2))
	_add_document("uf_medical_chart", Vector3(131.0, y3 + 0.92, 13.2))
	_add_document("uf_ilse_office", Vector3(113.0, y3 + 0.82, -13.3))
	_add_document("uf_anchor_log", Vector3(157.5, y4 + 1.12, -9.5))
	var generators: Usable = _make_usable("Generator control", Vector3(33.0, y1, -11.6), false, 1.0)
	objects["generators"] = generators
	generators.used.connect(_on_generators_used)
	var security: Usable = _make_usable("Security desk: switch off the cameras", Vector3(32.0, y1, 12.4), true, 1.0)
	_track("security_upper", security)
	security.used.connect(func(_user: Player) -> void:
		disable_sentinels("upper")
		AudioManager.play_ui(&"switch", -2.0)
		EventBus.toast_requested.emit("Sentinels offline on Levels 1 and 2", 3.0))
	var keycard: Usable = _make_pickup("Take the research keycard", Vector3(65.5, y2 + 0.52, -13.0), Vector3(0.18, 0.02, 0.12), Color(0.2, 0.6, 0.8), Color(0.6, 0.8, 1.0))
	_track("keycard", keycard)
	_highlight(keycard, Color(0.4, 0.8, 1.0))
	keycard.used.connect(func(_user: Player) -> void:
		GameState.set_flag("uf_keycard")
		AudioManager.play_ui(&"pickup", -6.0)
		EventBus.toast_requested.emit("Research keycard", 2.5)
		_advance_to(Stage.LABS))
	for entry: Array in [["stair_2", Vector3(90.6, y2, 1.9)], ["office", Vector3(115.6, y3, -1.9)]]:
		var reader: Usable = _make_usable("Card reader", entry[1], false, 0.9)
		objects["reader_" + str(entry[0])] = reader
		reader.used.connect(_on_keycard_door.bind(str(entry[0])))
	var lab_panel: Usable = _make_usable("Lab control: cameras and laser grid off", Vector3(131.0, y3, 12.2), true, 1.0)
	_track("security_labs", lab_panel)
	lab_panel.used.connect(func(_user: Player) -> void:
		disable_sentinels("labs")
		power_down_lasers()
		AudioManager.play_ui(&"switch", -2.0)
		EventBus.toast_requested.emit("Laser grid and lab Sentinels offline", 3.0))
	var lock_panel: Usable = _make_usable("Resonance lock", Vector3(142.6, y3, 1.9), false, 0.9)
	objects["lock_panel"] = lock_panel
	lock_panel.used.connect(_on_lock_used)
	var anchor: Usable = _make_usable("Sever the anchor", Vector3(176.0, y4, -12.0), true, 1.6)
	_track("anchor", anchor)
	anchor.set_enabled(false)
	anchor.used.connect(func(_user: Player) -> void: play_ending())
	for entry: Array in [["workbench_quarters", Vector3(85.7, y2, -12.2)], ["workbench_chamber", Vector3(161.1, y4, 8.3)]]:
		var bench: Usable = _make_usable("Rest at the workbench", entry[1], false, 1.0)
		objects[entry[0]] = bench
		bench.used.connect(_on_workbench_used.bind(str(entry[0]), entry[1] as Vector3))
	var salvage: int = int(tuning.get("salvage_pickup", 35))
	var scrap_spots: Array[Vector3] = [Vector3(5.0, y1, 12.6), Vector3(37.0, y1, -8.0), Vector3(58.0, y2, -5.0), Vector3(86.0, y2, 5.0),
			Vector3(76.0, y2, -13.0), Vector3(118.0, y3, 5.0), Vector3(136.0, y3, -13.0), Vector3(158.5, y4, 13.0)]
	for i: int in scrap_spots.size():
		var scrap: Usable = _make_pickup("Take salvage", scrap_spots[i], Vector3(0.3, 0.16, 0.22), Color(0.4, 0.42, 0.45), Color(0.9, 0.85, 0.7))
		_track("salvage_%d" % i, scrap)
		scrap.used.connect(func(_user: Player) -> void:
			GameState.salvage += salvage
			AudioManager.play_ui(&"pickup", -8.0)
			EventBus.toast_requested.emit("Salvage +%d" % salvage, 1.8))
	var lung: Usable = _make_pickup("Take the Lung Core", Vector3(79.5, y2 + 0.52, -13.0), Vector3(0.16, 0.26, 0.16), Color(0.75, 0.85, 0.95), Color(0.75, 0.88, 1.0))
	_track("lung_core", lung)
	lung.used.connect(func(player: Player) -> void:
		player.add_max_stamina(Upgrades.core_bonus("lung_core_stamina_bonus"))
		GameState.set_flag("uf_lung_core")
		AudioManager.play_ui(&"core_pickup", -4.0)
		EventBus.toast_requested.emit("Lung Core: maximum stamina +%d" % int(Upgrades.core_bonus("lung_core_stamina_bonus")), 3.5))
	var vital: Usable = _make_pickup("Take the Vital Core", Vector3(135.0, y3, -8.0), Vector3(0.14, 0.3, 0.14), Color(0.9, 0.3, 0.25), CityBuilder.COLOR_RED)
	_track("vital_core", vital)
	vital.used.connect(func(player: Player) -> void:
		var bonus: float = Upgrades.core_bonus("vital_core_health_bonus")
		player.health.max_health += bonus
		player.health.heal(player.health.max_health)
		GameState.max_health = player.health.max_health
		GameState.set_flag("uf_vital_core")
		player.emit_combat_status()
		AudioManager.play_ui(&"core_pickup", -4.0)
		EventBus.toast_requested.emit("Vital Core: maximum health +%d" % int(bonus), 3.5))
	# The Resonance Blade, in Dr. Vance's office.
	var blade: Usable = _make_pickup("Take the Resonance Blade", Vector3(117.0, y3 + 0.82, -13.3), Vector3(0.08, 0.06, 0.9), Color(0.2, 0.7, 0.8), CityBuilder.COLOR_ECHO)
	_track("blade", blade)
	blade.used.connect(func(player: Player) -> void:
		player.grant_weapon("resonance_blade")
		AudioManager.play_ui(&"core_pickup", -4.0)
		EventBus.toast_requested.emit("Resonance Blade: cuts Echo-touched things deeper. Press 3", 4.0))
	for at: Vector3 in [Vector3(20.0, y1, 12.0), Vector3(72.0, y2, 1.5), Vector3(158.0, y4, 5.0)]:
		var crate := ThrowablePickup.new()
		crate.position = at
		add_child(crate)


func _on_workbench_used(player: Player, key: String, at: Vector3) -> void:
	player.health.heal(player.health.max_health)
	player.injectors = player.combat.max_injectors
	player.emit_combat_status()
	reset_encounters()
	set_checkpoint("uf_" + key, at + Vector3(0.0, 0.1, 1.0), 0.0, true)
	EventBus.workbench_used.emit(player)


func _build_sentinels_and_lasers() -> void:
	# Each camera looks out into its room (yaw 0 faces -Z). The two in reception
	# and the one in Lab B used to face the wall they hang on.
	for entry: Array in [[Vector3(20.0, LEVEL_Y[0] + 3.5, -14.0), 180.0, "upper", Vector3(0, 0, -0.85)], [Vector3(24.0, LEVEL_Y[0] + 3.5, 14.0), 0.0, "upper", Vector3(0, 0, 0.85)],
			[Vector3(72.0, LEVEL_Y[1] + 3.5, 1.6), -90.0, "upper", Vector3(0, 0, 1.3)], [Vector3(106.0, LEVEL_Y[2] + 3.5, 0.0), -90.0, "labs", Vector3(0, 0, 2.85)],
			[Vector3(137.0, LEVEL_Y[2] + 3.5, 14.0), 40.0, "labs", Vector3(0, 0, 0.62)]]:
		var sentinel := Sentinel.new()
		sentinel.position = entry[0]
		sentinel.rotation_degrees.y = entry[1]
		sentinel.set_meta(&"group", entry[2])
		add_child(sentinel)
		_add_cable_box(sentinels.size(), sentinel, entry[3])
		sentinels.append(sentinel)
	# Laser grid across the Level 3 corridor.
	_laser_zone = Area3D.new()
	_laser_zone.collision_layer = 0
	_laser_zone.collision_mask = Player.LAYER_PLAYER
	_laser_zone.position = Vector3(122.0, LEVEL_Y[2] + 1.2, 0.0)
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.8, 2.4, 5.6)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	_laser_zone.add_child(collision)
	add_child(_laser_zone)
	_laser_visual = Node3D.new()
	_laser_visual.position = _laser_zone.position
	add_child(_laser_visual)
	var beam_material := StandardMaterial3D.new()
	beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_material.albedo_color = Color(1.0, 0.1, 0.08) * 2.5
	for i: int in 7:
		var beam := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.03, 0.03, 5.6)
		mesh.material = beam_material
		beam.mesh = mesh
		beam.position.y = -1.0 + i * 0.33
		_laser_visual.add_child(beam)
	var glow := OmniLight3D.new()
	glow.light_color = CityBuilder.COLOR_RED
	glow.light_energy = 1.2
	glow.omni_range = 5.0
	_laser_visual.add_child(glow)


## A junction box on the wall right under each camera. Sneak beneath the cone
## and cut the cable to put that one camera out (it cannot be done while it is
## watching you).
## `to_wall`: from the camera's floor spot to the wall the box hangs on.
func _add_cable_box(index: int, sentinel: Sentinel, to_wall: Vector3) -> void:
	var wall_side: Vector3 = to_wall.normalized()
	var floor_at: Vector3 = sentinel.position - Vector3(0.0, 3.5, 0.0)
	var box_at: Vector3 = floor_at + to_wall + Vector3(0.0, 1.3, 0.0)
	var box := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.35, 0.45, 0.35) - wall_side.abs() * 0.22
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.45, 0.4, 0.15)
	mesh.material = material
	box.mesh = mesh
	box.position = box_at
	add_child(box)
	var conduit := MeshInstance3D.new()
	var conduit_mesh := BoxMesh.new()
	conduit_mesh.size = Vector3(0.05, 1.95, 0.05)
	conduit_mesh.material = material
	conduit.mesh = conduit_mesh
	conduit.position = box_at + Vector3(0.0, 1.25, 0.0)
	add_child(conduit)
	var key: String = "cable_%d" % index
	var usable: Usable = _make_usable("Cut the camera's cable", floor_at + to_wall - wall_side * 0.5, false, 1.1)
	usable.set_meta(&"mesh", box)
	objects[key] = usable
	usable.used.connect(func(_user: Player) -> void: cut_cable(index))


func cut_cable(index: int) -> bool:
	var sentinel: Sentinel = sentinels[index]
	if not sentinel.enabled:
		return false
	if sentinel.suspicion > 0.35:
		AudioManager.play_ui(&"ui_wrong", -6.0)
		EventBus.toast_requested.emit("It's watching you. Get out of the light first.", 2.5)
		return false
	sentinel.disable()
	var key: String = "cable_%d" % index
	_taken[key] = true
	(objects[key] as Usable).set_enabled(false)
	AudioManager.play_sfx(&"switch", sentinel.global_position, 0.0)
	EventBus.toast_requested.emit("Camera out", 2.0)
	_hint("cable", 8.0)
	return true


func _build_triggers() -> void:
	_trigger(Vector3(56.0, LEVEL_Y[1], 0.0), Vector3(6.0, 3.0, 4.0), func(_p: Player) -> void:
		_advance_to(Stage.KEYCARD)
		set_checkpoint("uf_quarters", Vector3(55.0, LEVEL_Y[1] + 0.1, 0.0), -PI * 0.5)
		_radio("quarters"))
	_trigger(Vector3(108.0, LEVEL_Y[2], 0.0), Vector3(6.0, 3.0, 4.0), func(_p: Player) -> void:
		_advance_to(Stage.LOCK)
		set_checkpoint("uf_labs", Vector3(107.0, LEVEL_Y[2] + 0.1, 0.0), -PI * 0.5)
		_radio("labs"))
	var chamber := TriggerZone.new()
	chamber.size = Vector3(4.0, 4.0, 28.0)
	chamber.position = Vector3(165.0, LEVEL_Y[3], 0.0)
	chamber.one_shot = false
	add_child(chamber)
	chamber.triggered.connect(_on_chamber_entered)


func _register_enemies() -> void:
	var y1: float = LEVEL_Y[0] + 0.05
	var y2: float = LEVEL_Y[1] + 0.05
	var y3: float = LEVEL_Y[2] + 0.05
	add_enemy_spawn("hollow", Vector3(16.0, y1, -6.0), 90.0, [Vector3(16.0, y1, -6.0), Vector3(16.0, y1, 8.0)])
	add_enemy_spawn("hollow", Vector3(22.0, y1, 4.0), 180.0)
	add_enemy_spawn("hollow", Vector3(33.0, y1, 9.0), 0.0)
	add_enemy_spawn("spitter", Vector3(36.0, y1, 0.0), 90.0)
	add_enemy_spawn("hollow", Vector3(62.0, y2, 0.0), 90.0, [Vector3(60.0, y2, 0.0), Vector3(86.0, y2, 0.0)])
	add_enemy_spawn("hollow", Vector3(60.0, y2, 8.0), 0.0)
	add_enemy_spawn("hollow", Vector3(66.0, y2, 10.0), 180.0)
	add_enemy_spawn("skitter", Vector3(62.0, y2, -9.0), 0.0)
	add_enemy_spawn("skitter", Vector3(80.0, y2, 8.0), 180.0)
	add_enemy_spawn("hollow", Vector3(84.0, y2, -8.0), 90.0)
	add_enemy_spawn("bulwark", Vector3(128.0, y3, 0.0), 90.0, [Vector3(126.0, y3, 0.0), Vector3(140.0, y3, 0.0)])
	add_enemy_spawn("spitter", Vector3(116.0, y3, 10.0), 180.0)
	add_enemy_spawn("spitter", Vector3(134.0, y3, 6.0), 90.0)
	add_enemy_spawn("skitter", Vector3(130.0, y3, -9.0), 0.0)
	add_enemy_spawn("skitter", Vector3(112.0, y3, -1.0), 90.0)
	# Skitters waiting on the corridor walls.
	add_wall_spawn("skitter", Vector3(68.0, y2 + 2.6, -2.6), Vector3(0, 0, 1), Vector3(68.0, y2 + 0.05, -0.5))
	add_wall_spawn("skitter", Vector3(127.0, y3 + 2.6, 2.6), Vector3(0, 0, -1), Vector3(127.0, y3 + 0.05, 0.5))
	add_enemy_spawn("hollow", Vector3(140.0, y3, -1.0), 90.0)
