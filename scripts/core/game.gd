extends Node
## Boots the game: shows the main menu over the live level, starts or loads a
## run, spawns Kael and his camera, owns pausing, saving and the benchmark.
##
## Starting a new game, loading a save and returning to the menu all reload
## this scene with a request in `boot_request`, so every run begins from a
## freshly built level.
##
## Command line (after "--"):
##   --level=dead_city|proving_ground      --skip-intro      --skip-menu
##   --benchmark [--benchmark-seconds=N] [--benchmark-preset=NAME] [--benchmark-quit]
##   --preset=low|medium|high     --windowed

const LEVELS: Dictionary = {
	"dead_city": "res://scenes/levels/dead_city/dead_city.tscn",
	"forest": "res://scenes/levels/forest/forest.tscn",
	"facility": "res://scenes/levels/facility/facility.tscn",
	"proving_ground": "res://scenes/levels/proving_ground/proving_ground.tscn",
}
const DEFAULT_LEVEL: String = "dead_city"
const PLAYER_PATH: String = "res://scenes/player/player.tscn"
const DEV_TOUR_PATH: String = "res://tools/dev/visual_tour.gd"
const RESPAWN_DELAY: float = 2.6
const AUTO_DETECT_SECONDS: float = 10.0

enum Mode { MENU, PLAY }

## What the next boot of this scene should do: {} shows the menu,
## {"mode": "new"} starts a new game, {"mode": "load", "slot": name} loads a save,
## {"mode": "travel"} arrives in GameState.current_area keeping the run in memory.
static var boot_request: Dictionary = {}

var world: Node
var level: Level
var player: Player
var camera_rig: CameraRig
var hud: HUD
var story_ui: StoryUI
## Set before the game enters the tree to pick the level (tests, tools).
var level_name: String = ""
var pause_menu: PauseMenu
var debug_overlay: DebugOverlay
var benchmark: Benchmark
var benchmark_results: BenchmarkResults

var main_menu: MainMenu
var mode: Mode = Mode.PLAY
## Autosave at checkpoints. Off in automated runs unless a test turns it on.
var autosave_enabled: bool = true
## Tests set this to see the main menu even when running headless.
var force_menu: bool = false

var _options: Dictionary = {}
var _automated: bool = false
var _menu_camera: Camera3D
var _menu_time: float = 0.0
var _auto_detecting: bool = false
## Covers the screen while an area loads (New Game, Load, travel); null otherwise.
var loading_screen: LoadingScreen
## A chapter or mission run: autosaves and manual saves are off, so the player's
## own progress is never overwritten.
var practice_run: bool = false
var screen_fx: ScreenFX
var photo_mode: PhotoMode


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_options = _parse_options()
	_automated = _options.has("benchmark-quit") or _options.has("visual-tour")
	if level_name.is_empty():
		level_name = str(_options.get("level", DEFAULT_LEVEL))
	if not LEVELS.has(level_name):
		push_warning("Unknown level '%s', loading %s" % [level_name, DEFAULT_LEVEL])
		level_name = DEFAULT_LEVEL
	var headless: bool = DisplayServer.get_name() == "headless"
	var request: Dictionary = boot_request
	boot_request = {}
	var direct: bool = (_automated or headless or _options.has("skip-menu") or _options.has("benchmark")
			or _options.has("level") or level_name != DEFAULT_LEVEL)
	force_menu = force_menu or _options.has("show-menu")
	mode = Mode.PLAY if (not request.is_empty() or (direct and not force_menu)) else Mode.MENU
	autosave_enabled = not (_automated or headless)
	var travelling: bool = str(request.get("mode", "")) == "travel"
	if str(request.get("mode", "")) == "chapter" and Chapters.ORDER.has(str(request.get("area", ""))):
		# A chapter starts like arriving in the area, with a prepared Kael.
		Chapters.apply(str(request.get("area", "")))
		travelling = true
	if not travelling:
		GameState.reset()
	var new_game_plus: bool = str(request.get("mode", "")) == "new_plus" and NewGamePlus.is_available()
	if new_game_plus:
		NewGamePlus.apply()
	MissionManager.reset()
	CombatDirector.clear()
	var loading: bool = str(request.get("mode", "")) == "load"
	if loading and SaveManager.load_game(str(request.get("slot", SaveManager.AUTOSAVE_SLOT))) != OK:
		loading = false
	# Missions start like a loaded game built from data; chapters and missions are
	# practice runs that never write to the player's saves (carried across travel).
	var mission_title: String = ""
	if str(request.get("mode", "")) == "mission" and Missions.apply(str(request.get("id", ""))):
		loading = true
		mission_title = str((Missions.find(str(request.get("id", "")))[1] as Dictionary).get("title", ""))
	practice_run = str(request.get("mode", "")) in ["chapter", "mission"] or bool(request.get("practice", false))
	if (loading or travelling) and LEVELS.has(GameState.current_area):
		level_name = GameState.current_area
	if _options.has("windowed"):
		SettingsManager.set_value("graphics", "fullscreen", false, false)
	if _options.has("preset"):
		SettingsManager.apply_graphics_preset(str(_options["preset"]), false)

	if not request.is_empty():
		loading_screen = LoadingScreen.for_area(level_name)
		add_child(loading_screen)
		_finish_loading.call_deferred()

	world = Node.new()
	world.name = "World"
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)

	level = (load(LEVELS[level_name]) as PackedScene).instantiate() as Level
	world.add_child(level)
	Player.starting_weapons = level.starting_weapons

	player = (load(PLAYER_PATH) as PackedScene).instantiate() as Player
	player.position = level.spawn_position
	player.rotation.y = level.spawn_yaw
	world.add_child(player)

	camera_rig = CameraRig.new()
	camera_rig.name = "CameraRig"
	world.add_child(camera_rig)
	camera_rig.follow(player)
	screen_fx = ScreenFX.new()
	screen_fx.name = "ScreenFX"
	add_child(screen_fx)
	if level is StoryLevel:
		screen_fx.set_tint((level as StoryLevel).screen_tint)
	var effects := VFX.new()
	effects.name = "VFX"
	effects.world = world
	add_child(effects)

	hud = HUD.new()
	add_child(hud)
	story_ui = StoryUI.new()
	add_child(story_ui)
	player.emit_combat_status()
	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	pause_menu.resume_requested.connect(set_paused.bind(false))
	pause_menu.respawn_requested.connect(_on_respawn_requested)
	pause_menu.benchmark_requested.connect(start_benchmark)
	pause_menu.quit_requested.connect(quit_game)
	pause_menu.quit_to_menu_requested.connect(quit_to_menu)
	pause_menu.save_requested.connect(save_to_slot)
	pause_menu.load_requested.connect(load_slot)
	pause_menu.photo_mode_requested.connect(open_photo_mode)
	photo_mode = PhotoMode.new()
	photo_mode.name = "PhotoMode"
	add_child(photo_mode)
	photo_mode.closed.connect(_on_photo_mode_closed)
	pause_menu.saving_enabled = level is StoryLevel and not practice_run
	get_tree().auto_accept_quit = false
	debug_overlay = DebugOverlay.new()
	debug_overlay.player = player
	add_child(debug_overlay)
	benchmark = Benchmark.new()
	add_child(benchmark)
	benchmark.finished.connect(_on_benchmark_finished)
	benchmark_results = BenchmarkResults.new()
	add_child(benchmark_results)
	benchmark_results.closed.connect(_on_results_closed)

	EventBus.player_died.connect(_on_player_died)
	EventBus.checkpoint_reached.connect(func(_id: StringName) -> void: autosave())
	EventBus.travel_requested.connect(travel_to)
	EventBus.credits_requested.connect(_on_credits_requested)
	var city: StoryLevel = level as StoryLevel
	if city != null:
		story_ui.cinematic_player = city.cinematic
	if mode == Mode.MENU:
		_enter_menu()
		MusicDirector.set_area("menu")
		return
	MusicDirector.set_area(level_name if level is StoryLevel else "")
	_capture_mouse(true)
	_run_startup_options()
	if loading:
		level.restore_state(player)
		player.read_state()
		var resume: Array = resume_transform() if mission_title.is_empty() else []
		if resume.is_empty():
			player.teleport(level.spawn_position, level.spawn_yaw)
		else:
			player.teleport(resume[0], resume[1])
		GameState.resume_point = []
		if mission_title.is_empty():
			EventBus.toast_requested.emit("Game loaded", 2.5)
		else:
			hud.show_title(mission_title, "MISSION")
			EventBus.toast_requested.emit("Mission select: progress here is not saved", 3.5)
		return
	if travelling:
		player.read_state()
		if city != null and not city.saved_state().is_empty():
			# Coming back to an area already visited.
			level.restore_state(player)
			player.teleport(level.spawn_position, level.spawn_yaw)
		else:
			level.start_story(player, _automated or headless)
		autosave()
		return
	var skip_intro: bool = (_automated or _options.has("skip-intro") or _options.has("benchmark")
			or (headless and not (str(request.get("mode", "")) in ["new", "new_plus"])))
	if city == null:
		hud.show_title(level.title, level.subtitle)
	level.start_story(player, skip_intro)
	if new_game_plus:
		# Kael starts the rooftop again with everything he carried out of the Chamber.
		player.read_state()
		EventBus.toast_requested.emit("New Game+ %d: your weapons carry over; the Hollows hit harder" % NewGamePlus.cycle(), 5.0)


func _finish_loading() -> void:
	if loading_screen == null:
		return
	await loading_screen.finish(world, camera_rig.camera if camera_rig != null else null)
	loading_screen = null


func _process(delta: float) -> void:
	if mode != Mode.MENU or _menu_camera == null or benchmark.is_running:
		return
	# A slow drift along the level's fly-through route behind the menu.
	var stops: Array[Array] = level.get_tour_stops()
	if stops.size() < 2:
		return
	_menu_time += delta
	var along: float = fmod(_menu_time / 14.0, float(stops.size()))
	var index: int = int(along)
	var t: float = smoothstep(0.0, 1.0, along - float(index))
	var from: Array = stops[index]
	var to: Array = stops[(index + 1) % stops.size()]
	var eye: Vector3 = (from[0] as Vector3).lerp(to[0], t) + Vector3(0.0, 1.5, 0.0)
	var target: Vector3 = (from[1] as Vector3).lerp(to[1], t)
	if eye.distance_squared_to(target) > 0.01:
		_menu_camera.look_at_from_position(eye, target, Vector3.UP)


# --- Main menu ----------------------------------------------------------------------

func _enter_menu() -> void:
	player.input_enabled = false
	player.god_mode = true
	hud.set_hud_visible(false)
	story_ui.visible = false
	debug_overlay.visible = false
	player.visible = false
	_menu_camera = Camera3D.new()
	_menu_camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_menu_camera.far = 300.0
	_menu_camera.fov = 60.0
	add_child(_menu_camera)
	_menu_camera.make_current()
	main_menu = MainMenu.new()
	add_child(main_menu)
	main_menu.new_game_requested.connect(start_new_game)
	main_menu.new_game_plus_requested.connect(start_new_game_plus)
	main_menu.chapter_requested.connect(start_chapter)
	main_menu.mission_requested.connect(start_mission)
	main_menu.continue_requested.connect(func() -> void: load_slot(SaveManager.get_most_recent_slot()))
	main_menu.load_requested.connect(load_slot)
	main_menu.quit_requested.connect(quit_game)
	_capture_mouse(false)
	main_menu.set_status(_menu_status)
	_menu_status = ""
	if _options.has("visual-tour"):
		_run_startup_options()
	elif not SettingsManager.get_bool("graphics", "auto_detected") and not force_menu and level.get_tour_stops().size() >= 2:
		_start_auto_detect()


## First launch: measure ten seconds on Medium and pick the preset that fits this Mac.
func _start_auto_detect() -> void:
	_auto_detecting = true
	main_menu.set_menu_visible(false)
	SettingsManager.apply_graphics_preset("medium", false)
	story_ui.visible = true
	story_ui.show_hint("Measuring performance to choose graphics settings…", AUTO_DETECT_SECONDS + 2.0)
	level.prepare_benchmark(player)
	benchmark.start(level.get_tour_stops(), AUTO_DETECT_SECONDS)


## Chooses a preset from a Medium-preset measurement (thresholds in graphics_presets.json).
static func pick_preset(average_fps: float, one_percent_low: float, rules: Dictionary) -> String:
	if average_fps < float(rules.get("low_below_average_fps", 70.0)) or one_percent_low < float(rules.get("low_below_one_percent_fps", 40.0)):
		return "low"
	if average_fps >= float(rules.get("high_above_average_fps", 170.0)):
		return "high"
	return "medium"


func _finish_auto_detect(summary: Dictionary) -> void:
	_auto_detecting = false
	var rules: Dictionary = SettingsManager.get_auto_detect_rules()
	var preset: String = pick_preset(float(summary.get("average_fps", 0.0)), float(summary.get("one_percent_low_fps", 0.0)), rules)
	SettingsManager.apply_graphics_preset(preset, false)
	SettingsManager.set_value("graphics", "auto_detected", true)
	print("Auto-detect: %.1f FPS average on Medium, chose %s" % [float(summary.get("average_fps", 0.0)), preset])
	# The measurement staged a fight; start the menu again from a clean level.
	boot_request = {}
	_reload("Graphics set to %s (measured %d FPS on Medium). Change it any time under Settings." % [preset.capitalize(), roundi(float(summary.get("average_fps", 0.0)))])


func start_mission(id: String) -> void:
	boot_request = {"mode": "mission", "id": id}
	_reload()


func start_chapter(area: String) -> void:
	boot_request = {"mode": "chapter", "area": area}
	_reload()


func start_new_game() -> void:
	boot_request = {"mode": "new"}
	_reload()


func start_new_game_plus() -> void:
	boot_request = {"mode": "new_plus"}
	_reload()


func load_slot(slot: String) -> void:
	if slot.is_empty() or not SaveManager.has_save(slot):
		return
	boot_request = {"mode": "load", "slot": slot}
	_reload()


## Leaves this area for another, carrying the whole run across.
func travel_to(area: String) -> void:
	if not LEVELS.has(area) or mode != Mode.PLAY:
		return
	player.write_state()
	level.capture_state()
	GameState.current_area = area
	GameState.checkpoint_id = ""
	boot_request = {"mode": "travel", "practice": practice_run}
	_reload()


func _on_credits_requested(epilogue: bool) -> void:
	story_ui.show_credits(epilogue)
	await story_ui.credits_finished
	quit_to_menu()


func quit_to_menu() -> void:
	boot_request = {}
	_reload()


static var _menu_status: String = ""


func _reload(status: String = "") -> void:
	_menu_status = status
	get_tree().paused = false
	AudioManager.stop_all()
	if get_tree().current_scene != self:
		# Embedded (tests): nothing to reload into.
		return
	# Put the black loading screen up and let it draw before the reload stalls the frame.
	var title: String = level_name
	match str(boot_request.get("mode", "")):
		"travel":
			title = GameState.current_area
		"new", "new_plus":
			title = DEFAULT_LEVEL
		"chapter":
			title = str(boot_request.get("area", DEFAULT_LEVEL))
		"mission":
			var found: Array = Missions.find(str(boot_request.get("id", "")))
			title = str(found[0]) if not found.is_empty() else DEFAULT_LEVEL
		"":
			title = "GHOSTLINE"
	add_child(LoadingScreen.for_area(title))
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().reload_current_scene()


# --- Saving -------------------------------------------------------------------------

## Writes the run to a slot. Kael resumes from the last checkpoint he reached.
func save_to_slot(slot: String) -> Error:
	if not (level is StoryLevel) or mode != Mode.PLAY or benchmark.is_running or practice_run:
		return ERR_UNAVAILABLE
	player.write_state()
	level.capture_state()
	GameState.resume_point = []
	if can_resume_here():
		var at: Vector3 = player.global_position
		GameState.resume_point = [level_name, at.x, at.y, at.z, player.facing_yaw]
	var error: Error = SaveManager.save_game(slot)
	EventBus.toast_requested.emit("Saved" if error == OK else "Could not save (error %d)" % error, 2.0)
	return error


## True when Kael may be saved exactly where he stands: on solid ground, alive,
## nothing hunting him and no cinematic running. Otherwise loading puts him at
## the last checkpoint.
func can_resume_here() -> bool:
	if player == null or player.is_dead() or not player.is_on_floor() or player.velocity.length() > 8.0:
		return false
	# Solid ground right under his feet (is_on_floor lags a teleport by a frame).
	var feet: Vector3 = player.global_position
	var query := PhysicsRayQueryParameters3D.create(feet + Vector3.UP * 0.3, feet + Vector3.DOWN * 0.35, Player.LAYER_WORLD)
	if player.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		return false
	if CombatDirector.engaged_count() > 0:
		return false
	var story_level: StoryLevel = level as StoryLevel
	if story_level == null or story_level.cinematic.is_playing:
		return false
	for enemy: Enemy in level.get_enemies():
		if is_instance_valid(enemy) and not enemy.is_dead() and enemy.state in [Enemy.AIState.COMBAT, Enemy.AIState.ATTACK, Enemy.AIState.SEARCH, Enemy.AIState.INVESTIGATE, Enemy.AIState.HIT, Enemy.AIState.STAGGER]:
			return false
	return true


## The saved spot for this area, if the loaded save has one.
func resume_transform() -> Array:
	var point: Array = GameState.resume_point
	if point.size() == 5 and str(point[0]) == level_name:
		return [Vector3(float(point[1]), float(point[2]), float(point[3])), float(point[4])]
	return []


func autosave() -> void:
	if autosave_enabled and not player.is_dead():
		save_to_slot(SaveManager.AUTOSAVE_SLOT)


## From the pause menu: the world stays frozen while the free camera is out.
func open_photo_mode() -> void:
	if mode != Mode.PLAY or not get_tree().paused:
		return
	pause_menu.close()
	hud.set_hud_visible(false)
	story_ui.visible = false
	photo_mode.open(world, camera_rig.camera, player, screen_fx)


func _on_photo_mode_closed() -> void:
	hud.set_hud_visible(true)
	story_ui.visible = true
	pause_menu.open()
	_capture_mouse(false)


func _unhandled_input(event: InputEvent) -> void:
	if photo_mode != null and photo_mode.active:
		return
	if not event.is_action_pressed(&"pause") or story_ui.is_modal_open():
		return
	if mode == Mode.MENU:
		if main_menu != null and not main_menu.is_capturing_input():
			main_menu.close_side_panel()
		return
	if pause_menu.is_capturing_input():
		return
	var story_level: StoryLevel = level as StoryLevel
	if story_level != null and story_level.cinematic.is_playing:
		return
	if benchmark.is_running:
		benchmark.cancel()
		_end_benchmark_mode()
	elif benchmark_results.visible:
		benchmark_results.visible = false
		_on_results_closed()
	else:
		set_paused(not get_tree().paused)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()
	# Pause when the player switches away from the game.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready():
		if (mode == Mode.PLAY and not _automated and not benchmark.is_running and not get_tree().paused
				and not story_ui.is_modal_open()):
			set_paused(true)


## Stops looping audio and lets the mixer release it before the game exits.
func quit_game() -> void:
	get_tree().paused = true
	AudioManager.stop_all()
	for child: Node in level.get_children():
		if child is AudioStreamPlayer3D:
			(child as AudioStreamPlayer3D).stop()
	for i: int in 4:
		await get_tree().process_frame
	get_tree().quit()


func set_paused(paused: bool) -> void:
	get_tree().paused = paused
	if paused:
		player.write_state()
		pause_menu.open()
	else:
		pause_menu.close()
	_capture_mouse(not paused)
	EventBus.pause_changed.emit(paused)


func start_benchmark(seconds: float = 60.0) -> void:
	var stops: Array[Array] = level.get_tour_stops()
	if stops.size() < 2:
		EventBus.toast_requested.emit("This level has no benchmark route", 3.0)
		return
	pause_menu.close()
	get_tree().paused = false
	player.input_enabled = false
	hud.set_hud_visible(false)
	story_ui.visible = false
	_capture_mouse(true)
	level.prepare_benchmark(player)
	benchmark.start(stops, seconds)


func _on_benchmark_finished(summary: Dictionary) -> void:
	if _auto_detecting:
		_finish_auto_detect(summary)
		return
	print(Benchmark.format_summary(summary))
	if _options.has("benchmark-quit"):
		quit_game()
		return
	_end_benchmark_mode()
	get_tree().paused = true
	_capture_mouse(false)
	benchmark_results.show_summary(summary)


func _end_benchmark_mode() -> void:
	player.input_enabled = true
	player.god_mode = false
	hud.set_hud_visible(true)
	story_ui.visible = true
	respawn_player()


func _on_results_closed() -> void:
	set_paused(false)


func _on_respawn_requested() -> void:
	set_paused(false)
	respawn_player()


## Death: a short pause on the fallen Kael, then back to the checkpoint with
## the area's enemies restored.
func _on_player_died() -> void:
	player.input_enabled = false
	get_tree().create_timer(RESPAWN_DELAY, false).timeout.connect(respawn_player)


func respawn_player() -> void:
	level.reset_encounters()
	camera_rig.set_lock_target(null)
	player.revive()
	player.teleport(level.spawn_position, level.spawn_yaw)


func _capture_mouse(captured: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE


func _run_startup_options() -> void:
	if _options.has("visual-tour") and ResourceLoader.exists(DEV_TOUR_PATH):
		var tour: Node = (load(DEV_TOUR_PATH) as GDScript).new()
		add_child(tour)
		tour.call(&"run", self, str(_options["visual-tour"]))
		return
	if _options.has("benchmark"):
		if _options.has("benchmark-preset"):
			SettingsManager.apply_graphics_preset(str(_options["benchmark-preset"]), false)
		hud.hide_intro()
		var seconds: float = float(_options.get("benchmark-seconds", 60.0))
		get_tree().create_timer(1.0).timeout.connect(start_benchmark.bind(seconds))


## Turns "--name=value" / "--flag" user arguments into a dictionary.
func _parse_options() -> Dictionary:
	var options: Dictionary = {}
	for argument: String in OS.get_cmdline_user_args():
		if not argument.begins_with("--"):
			continue
		var parts: PackedStringArray = argument.trim_prefix("--").split("=", true, 1)
		options[parts[0]] = parts[1] if parts.size() > 1 else true
	return options
