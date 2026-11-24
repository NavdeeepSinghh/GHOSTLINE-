extends GutTest
## Milestone 6: double-tap dodge, toggle block, HUD idle fade, the loading
## screen and shader warm-up, adaptive music and the mix, accessibility
## options, controller rebinding and the gameplay effects.

const MAIN_SCENE: String = "res://scenes/main/main.tscn"
const PLAYER_SCENE: String = "res://scenes/player/player.tscn"
const GAME_SCRIPT: String = "res://scripts/core/game.gd"

var player: Player
var floor_body: StaticBody3D


func before_each() -> void:
	SettingsManager.reset_to_defaults(false)
	CombatFX.hitstop_enabled = false
	CombatDirector.clear()
	GameState.reset()
	MissionManager.reset()
	InputSetup.reset_bindings()
	(load(GAME_SCRIPT) as GDScript).set("boot_request", {})
	Player.starting_weapons = PackedStringArray()
	MusicDirector.stop()


func after_each() -> void:
	for action: StringName in [&"move_forward", &"block", &"move_left"]:
		Input.action_release(action)
	MusicDirector.stop()
	SettingsManager.reset_to_defaults(false)
	InputSetup.reset_bindings()
	get_tree().paused = false


func _spawn_player_on_floor() -> void:
	floor_body = StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 1, 40)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position.y = -0.5
	add_child_autofree(floor_body)
	player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	player.position = Vector3(0, 0.1, 0)
	add_child_autofree(player)
	await wait_physics_frames(10)


func _tap(action: StringName) -> void:
	Input.action_press(action)
	await wait_physics_frames(1)
	Input.action_release(action)
	await wait_physics_frames(1)


# --- Movement and combat input ----------------------------------------------------

func test_double_tap_window_logic() -> void:
	await _spawn_player_on_floor()
	player.clock = 10.0
	assert_false(player.register_direction_tap(&"move_left"), "one tap is just a step")
	player.clock = 10.15
	assert_true(player.register_direction_tap(&"move_left"), "a second tap inside the window dodges")
	player.clock = 11.0
	assert_false(player.register_direction_tap(&"move_left"))
	player.clock = 11.5
	assert_false(player.register_direction_tap(&"move_left"), "too slow")
	player.clock = 11.6
	assert_false(player.register_direction_tap(&"move_right"), "another direction starts over")
	player.clock = 11.7
	assert_false(player.register_direction_tap(&"move_left"))


func test_double_tap_dodges_only_when_enabled() -> void:
	await _spawn_player_on_floor()
	SettingsManager.set_value("controls", "double_tap_dodge", false, false)
	await _tap(&"move_forward")
	await _tap(&"move_forward")
	assert_false(player.state_machine.is_in(&"Dodge"), "off: double taps do nothing")
	await wait_physics_frames(30)
	SettingsManager.set_value("controls", "double_tap_dodge", true, false)
	await _tap(&"move_forward")
	Input.action_press(&"move_forward")
	await wait_physics_frames(2)
	assert_true(player.state_machine.is_in(&"Dodge"), "on: the second tap dodges")


func test_toggle_block() -> void:
	await _spawn_player_on_floor()
	SettingsManager.set_value("controls", "toggle_block", true, false)
	await _tap(&"block")
	await wait_physics_frames(6)
	assert_true(player.state_machine.is_in(&"Block"), "one press raises the guard and it stays up")
	await _tap(&"block")
	await wait_physics_frames(3)
	assert_false(player.state_machine.is_in(&"Block"), "the next press lowers it")


# --- HUD and loading -------------------------------------------------------------

func test_health_panel_fades_when_idle() -> void:
	var hud := HUD.new()
	add_child_autofree(hud)
	await wait_frames(2)
	SettingsManager.set_value("gameplay", "hud_fade_seconds", 1.0, false)
	for i: int in 6:
		hud._process(0.5)
	assert_almost_eq(hud.vitals_alpha(), 0.0, 0.01, "faded out after a quiet spell")
	EventBus.health_changed.emit(80.0, 100.0)
	hud._process(0.3)
	assert_gt(hud.vitals_alpha(), 0.9, "back at once when something changes")
	EventBus.health_changed.emit(20.0, 100.0)
	for i: int in 8:
		hud._process(0.5)
	assert_gt(hud.vitals_alpha(), 0.9, "stays up while health is low")
	EventBus.health_changed.emit(100.0, 100.0)
	SettingsManager.set_value("gameplay", "hud_fade_seconds", 0.0, false)
	for i: int in 8:
		hud._process(0.5)
	assert_gt(hud.vitals_alpha(), 0.9, "\"Never\" keeps it on screen")


func test_loading_screen_covers_a_boot_and_then_goes() -> void:
	(load(GAME_SCRIPT) as GDScript).set("boot_request", {"mode": "new"})
	var game: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	game.set("skip_intro", true)
	add_child_autofree(game)
	var screen: LoadingScreen = game.get("loading_screen")
	assert_not_null(screen, "a black loading screen is up while the area builds")
	assert_eq(screen.area_title, "THE DEAD CITY")
	await wait_frames(2)
	assert_not_null(game.find_child("ShaderWarmUp", true, false), "enemies and effects are drawn once behind it")
	await wait_seconds(1.2)
	assert_null(game.get("loading_screen"))
	assert_null(game.find_child("ShaderWarmUp", true, false), "and cleaned up")
	assert_eq(game.find_children("*", "LoadingScreen", true, false).size(), 0)
	assert_eq(MusicDirector.area, "dead_city", "the area's music starts")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_menu_boot_has_no_loading_screen_and_plays_menu_music() -> void:
	var game: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	game.set("force_menu", true)
	add_child_autofree(game)
	await wait_frames(3)
	assert_null(game.get("loading_screen"))
	assert_eq(MusicDirector.area, "menu")
	assert_eq(MusicDirector.layer_count(), 1)


# --- Music and mix ---------------------------------------------------------------

func test_music_state_choice() -> void:
	assert_eq(MusicDirector.choose_state(false, false, 0, false), "explore")
	assert_eq(MusicDirector.choose_state(false, false, 0, true), "tension")
	assert_eq(MusicDirector.choose_state(false, false, 2, true), "combat")
	assert_eq(MusicDirector.choose_state(false, true, 2, true), "boss")
	assert_eq(MusicDirector.choose_state(true, false, 2, true), "silent", "cinematics quiet the music")
	assert_eq(MusicDirector.choose_state(true, true, 2, true), "boss", "except the camera moments inside a boss fight")


func test_music_layers_crossfade_and_stop() -> void:
	MusicDirector.set_area("forest")
	assert_eq(MusicDirector.layer_count(), 4)
	assert_true(MusicDirector.is_playing())
	assert_almost_eq(MusicDirector.layer_volume("explore"), MusicDirector.target_db("explore", "explore"), 0.01)
	assert_lt(MusicDirector.layer_volume("combat"), -50.0, "combat drums start silent")
	EventBus.boss_started.emit("The Warden")
	for i: int in 12:
		MusicDirector._process(0.25)
	assert_eq(MusicDirector.state, "boss")
	assert_almost_eq(MusicDirector.layer_volume("boss"), MusicDirector.target_db("boss", "boss"), 0.5, "boss layer faded in")
	EventBus.boss_ended.emit()
	EventBus.cinematic_changed.emit(true)
	for i: int in 12:
		MusicDirector._process(0.25)
	assert_eq(MusicDirector.state, "silent")
	assert_lt(MusicDirector.layer_volume("explore"), -50.0)
	assert_lt(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Ambience")),
			linear_to_db(SettingsManager.get_float("audio", "ambience")) - 3.0, "ambience ducks under a cinematic")
	EventBus.cinematic_changed.emit(false)
	AudioManager.stop_all()
	assert_eq(MusicDirector.layer_count(), 0, "stop_all silences the music too")


func test_every_music_file_in_the_mix_exists() -> void:
	var mix: Dictionary = MusicDirector.load_mix()
	assert_false(mix.is_empty())
	for area: String in mix["areas"]:
		var layers: PackedStringArray = ["explore"] if area == "menu" else MusicDirector.LAYERS
		for layer: String in layers:
			var path: String = "%s%s_%s.wav" % [MusicDirector.MUSIC_DIR, area, layer]
			assert_true(ResourceLoader.exists(path), path)
	for state: String in ["explore", "tension", "combat", "boss", "silent"]:
		assert_true((mix["states"] as Dictionary).has(state))


# --- Accessibility ---------------------------------------------------------------

func test_high_contrast_cues_change_danger_colours() -> void:
	var standard: Color = Accessibility.cue("telegraph")
	SettingsManager.set_value("accessibility", "high_contrast_cues", true, false)
	var contrast: Color = Accessibility.cue("telegraph")
	assert_ne(standard, contrast)
	assert_gt(contrast.g, 0.8, "warnings turn yellow, away from red")
	for cue: String in ["sentinel_alert", "choir_telegraph", "choir_edge"]:
		assert_ne(Accessibility.cue(cue), Color(1, 0, 1, 1), "%s is in the palette" % cue)


func test_reduce_flashing() -> void:
	SettingsManager.set_value("accessibility", "reduce_flashing", true, false)
	var weather := Weather.new()
	add_child_autofree(weather)
	await wait_frames(1)
	weather.strike()
	assert_eq(weather._flash, 0.0, "no lightning flash")
	var flicker: OmniLight3D = OmniLight3D.new()
	flicker.set_script(load("res://scripts/levels/flicker_light.gd"))
	flicker.light_energy = 2.0
	add_child_autofree(flicker)
	for i: int in 60:
		flicker._process(0.05)
		assert_almost_eq(flicker.light_energy, 1.8, 0.001)
	var strobe := StrobeLight.new()
	strobe.light_energy = 3.0
	add_child_autofree(strobe)
	for i: int in 30:
		strobe._process(0.037)
		assert_almost_eq(strobe.light_energy, 3.0, 0.001, "emergency lights hold steady")
	var visuals := EnemyVisuals.new()
	add_child_autofree(visuals)
	visuals.setup(load("res://data/enemies/hollow.tres") as EnemyData)
	visuals.flash()
	assert_eq(visuals._flash_time, 0.0, "no white hit flash")


func test_subtitle_background_option() -> void:
	var ui := StoryUI.new()
	add_child_autofree(ui)
	await wait_frames(2)
	ui.apply_subtitle_background()
	assert_true(ui.has_subtitle_background())
	SettingsManager.set_value("accessibility", "subtitle_background", false, false)
	ui.apply_subtitle_background()
	assert_false(ui.has_subtitle_background(), "text with an outline instead")


func test_access_tab_builds() -> void:
	var panel := SettingsPanel.new()
	add_child_autofree(panel)
	await wait_frames(1)
	panel.show_tab("Access")
	await wait_frames(1)
	assert_gt(panel.find_children("*", "CheckButton", true, false).size(), 4)


# --- Controller rebinding --------------------------------------------------------

func test_controller_buttons_can_be_rebound_and_swap() -> void:
	assert_eq(InputSetup.get_pad_button("jump"), JOY_BUTTON_A)
	assert_eq(InputSetup.get_pad_button("crouch"), JOY_BUTTON_B)
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_B
	assert_true(InputSetup.rebind_pad("jump", event))
	assert_eq(InputSetup.get_pad_button("jump"), JOY_BUTTON_B)
	assert_eq(InputSetup.get_pad_button("crouch"), JOY_BUTTON_A, "the two actions swap")
	var press := InputEventJoypadButton.new()
	press.button_index = JOY_BUTTON_B
	press.pressed = true
	assert_true(InputMap.event_is_action(press, &"jump"))
	assert_false(InputMap.event_is_action(press, &"crouch"))
	assert_eq(InputSetup.get_pad_label("jump"), "B / Circle")
	assert_false(InputSetup.rebind_pad("move_forward", event), "sticks are fixed")
	InputSetup.reset_bindings()
	assert_eq(InputSetup.get_pad_button("jump"), JOY_BUTTON_A)


# --- Effects ---------------------------------------------------------------------

func test_effects_spawn_and_clean_up() -> void:
	var dust: GPUParticles3D = VFX.ground_burst(Vector3.ZERO, false, 8)
	assert_true(dust.one_shot)
	add_child(dust)
	var splash: GPUParticles3D = VFX.ground_burst(Vector3.ZERO, true, 8)
	add_child(splash)
	var effects := VFX.new()
	add_child_autofree(effects)
	effects.world = self
	var dummy := Node3D.new()
	add_child_autofree(dummy)
	dummy.position = Vector3(2, 0, 0)
	EventBus.enemy_died.emit(dummy)
	await wait_frames(2)
	assert_eq(get_children().filter(func(n: Node) -> bool: return n is Node3D and n.get_child_count() == 2 and n.get_child(0) is GPUParticles3D and not n is GPUParticles3D).size(), 1,
			"an Echo burst rises from the body")
	await wait_seconds(2.6)
	assert_false(is_instance_valid(dust), "one-shot effects free themselves")
	assert_false(is_instance_valid(splash))
	assert_eq(get_children().filter(func(n: Node) -> bool: return n is Node3D and n.get_child_count() == 2 and n.get_child(0) is GPUParticles3D and not n is GPUParticles3D).size(), 0)
	assert_gt(VFX.count("death_sparks"), 0)
	var embers: GPUParticles3D = VFX.flame_embers(10.0)
	assert_gt(embers.amount, 1)
	embers.free()


func test_choir_collapses_at_the_end() -> void:
	var choir := Choir.new()
	choir.tuning = {}
	add_child_autofree(choir)
	await wait_frames(2)
	var heights: Array[float] = []
	for child: Node in choir.get_children():
		if child is Node3D:
			heights.append((child as Node3D).position.y)
	choir.collapse(0.5)
	await wait_seconds(0.8)
	var sunk: int = 0
	var i: int = 0
	for child: Node in choir.get_children():
		if child is Node3D:
			if (child as Node3D).position.y < heights[i] - 4.0:
				sunk += 1
			i += 1
	assert_eq(sunk, heights.size(), "every part sinks")


# --- Wildlife --------------------------------------------------------------------

func test_deer_bolts_when_kael_comes_close() -> void:
	var deer := Deer.new()
	add_child(deer)
	await wait_frames(2)
	assert_false(deer.fleeing)
	watch_signals(deer)
	deer.startle(deer.global_position + Vector3(0, 0, 5))
	assert_true(deer.fleeing)
	var start: Vector3 = deer.global_position
	await wait_seconds(1.0)
	if is_instance_valid(deer):
		assert_lt(deer.global_position.z, start.z - 4.0, "it runs away from him")
	await wait_seconds(3.5)
	assert_false(is_instance_valid(deer), "and is gone into the trees")


func test_birds_circle() -> void:
	var flock := BirdFlock.new()
	flock.count = 5
	add_child_autofree(flock)
	await wait_frames(2)
	assert_eq(flock.get_child_count(), 5)
	var bird: Node3D = flock.get_child(0)
	var before: Vector3 = bird.position
	await wait_seconds(0.5)
	assert_gt(bird.position.distance_to(before), 0.5, "they move")
	assert_gt(bird.position.y, 20.0, "above the canopy")
