extends GutTest
## Milestone 4: a Dead City run survives save, quit and continue; workbenches,
## upgrades and cores; menus; rebinding; first-launch preset choice.

const SCENE: String = "res://scenes/levels/dead_city/dead_city.tscn"
const PLAYER_SCENE: String = "res://scenes/player/player.tscn"
const MAIN_SCENE: String = "res://scenes/main/main.tscn"
const GAME_SCRIPT: String = "res://scripts/core/game.gd"
const SCRATCH: String = "user://test_saves_m4"

var city: DeadCity
var player: Player


func before_each() -> void:
	SettingsManager.reset_to_defaults(false)
	CombatFX.hitstop_enabled = false
	CombatDirector.clear()
	GameState.reset()
	MissionManager.reset()
	InputSetup.reset_bindings()
	SaveManager.save_dir = SCRATCH
	for slot: String in ["autosave", "slot1", "slot2", "slot3"]:
		SaveManager.delete_slot(slot)
	(load(GAME_SCRIPT) as GDScript).set("boot_request", {})
	Player.starting_weapons = PackedStringArray()


func after_each() -> void:
	get_tree().paused = false
	for slot: String in ["autosave", "slot1", "slot2", "slot3"]:
		SaveManager.delete_slot(slot)
	SaveManager.save_dir = SaveManager.SAVE_DIR
	InputSetup.reset_bindings()
	SettingsManager.reset_to_defaults(false)
	Player.starting_weapons = PackedStringArray()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _build_city(at: Vector3) -> void:
	city = (load(SCENE) as PackedScene).instantiate() as DeadCity
	add_child_autofree(city)
	for enemy: Enemy in city.get_enemies():
		enemy.set_physics_process(false)
	Player.starting_weapons = city.starting_weapons
	player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	player.position = at
	city.add_child(player)
	await wait_physics_frames(12)


func _use(key: String) -> void:
	(city.objects[key] as Usable).interact(player)
	get_tree().paused = false


# --- Save, quit, continue ---------------------------------------------------------------

func test_a_dead_city_run_survives_save_and_load() -> void:
	await _build_city(Vector3(0.0, 0.1, -90.0))
	_use("fuse_metro")
	_use("axe")
	_use("salvage_0")
	_use("salvage_1")
	_use("dc_mara_1")
	_use("gate_lever")
	_use("generator")
	_use("vital_core")
	_use("lung_core")
	_use("ladder_kick")
	GameState.salvage = 200
	assert_true(Upgrades.purchase("fire_axe"))
	# Walk-in triggers that already fired must not fire again after loading.
	player.teleport(Vector3(0.0, 0.1, -1.0), 0.0)
	await wait_physics_frames(6)
	assert_eq(GameState.checkpoint_id, "dc_main_street")
	city.set_checkpoint("dc_plaza", Vector3(-20.0, 0.1, -72.5), 0.0)
	player.health.apply_damage(40.0)
	player.throwables = 1
	player.write_state()
	city.capture_state()
	assert_eq(SaveManager.save_game("slot1"), OK)
	var health_saved: float = player.health.health

	# Quit: everything in memory goes away.
	city.free()
	GameState.reset()
	MissionManager.reset()
	assert_eq(GameState.salvage, 0)
	assert_eq(SaveManager.load_game("slot1"), OK)
	await _build_city(Vector3(0.0, 0.1, -90.0))
	city.restore_state(player)
	player.read_state()
	player.teleport(Vector3(0.0, 0.1, -1.0), 0.0)
	await wait_physics_frames(6)

	assert_eq(city.stage, DeadCity.Stage.RESTORE_POWER, "story stage")
	assert_eq(city.fuses_found, 1)
	assert_eq(city.spawn_position, Vector3(-20.0, 0.1, -72.5), "resumes at the last checkpoint")
	assert_false((city.objects["fuse_metro"] as Usable).can_interact(player), "taken things stay taken")
	assert_true((city.objects["fuse_school"] as Usable).can_interact(player), "untaken things are still there")
	assert_false((city.objects["salvage_0"] as Usable).can_interact(player))
	assert_true((city.objects["salvage_2"] as Usable).can_interact(player))
	assert_false((city.objects["lung_core"] as Usable).can_interact(player))
	assert_false(city.objects.has("gate"), "the gate stays open")
	assert_false(city.objects.has("shutter"), "the pharmacy shutter stays open")
	assert_true((city.objects["ladder_shortcut"] as Ladder).enabled, "the ladder stays down")
	assert_true(player.has_weapon("fire_axe"))
	assert_eq(player.weapon.id, "fire_axe", "equipped weapon")
	assert_eq(Upgrades.tier("fire_axe"), 1)
	assert_eq(GameState.salvage, 200 - 80)
	assert_almost_eq(player.health.max_health, 125.0, 0.01, "Vital Core")
	assert_almost_eq(player.max_stamina, 120.0, 0.01, "Lung Core")
	assert_almost_eq(player.health.health, health_saved, 0.01)
	assert_eq(player.throwables, 1)
	assert_true(GameState.collected_documents.has("dc_mara_1"))
	assert_string_contains(MissionManager.current_objective, "1 / 2")
	assert_true(MissionManager.side_objectives.has("journal"))
	assert_true(MissionManager.is_side_done("pharmacy"))


func test_loading_mid_defence_brings_the_wave_back_and_console_state() -> void:
	await _build_city(Vector3(0.0, 0.1, -90.0))
	_use("fuse_metro")
	_use("fuse_school")
	city.restore_power()
	player.write_state()
	city.capture_state()
	SaveManager.save_game("slot2")
	var enemies_before: int = city.get_enemies().size()
	city.free()
	GameState.reset()
	SaveManager.load_game("slot2")
	await _build_city(Vector3(0.0, 0.1, -86.0))
	city.restore_state(player)
	await wait_physics_frames(4)
	assert_eq(city.stage, DeadCity.Stage.DEFEND)
	assert_eq(city.get_enemies().size(), enemies_before, "the wave is back")
	assert_false((city.objects["panel"] as Usable).can_interact(player), "the panel stays solved")
	assert_false((city.objects["console"] as Usable).can_interact(player))


func test_old_saves_are_migrated() -> void:
	var old: Dictionary = {"version": 1, "current_area": "dead_city", "salvage": 40, "saved_at_unix": 5}
	SaveManager.write_slot("slot3", old)
	assert_eq(SaveManager.load_game("slot3"), OK)
	assert_eq(GameState.salvage, 40)
	assert_eq(GameState.throwables, 3)
	assert_eq(GameState.level_states, {})
	assert_string_contains(SaveManager.describe_slot("slot3"), "Dead_city".capitalize())
	SaveManager.write_slot("slot3", {"version": 2, "level_state": {"stage": 4}, "saved_at_unix": 6})
	SaveManager.load_game("slot3")
	assert_eq(int(GameState.get_level_state("dc")["stage"]), 4, "version 2 state becomes the Dead City's")


# --- Workbench, upgrades, cores -----------------------------------------------------------

func test_upgrades_cost_salvage_and_change_the_numbers() -> void:
	GameState.weapons = {"rebar_pipe": 0}
	GameState.salvage = 50
	assert_false(Upgrades.can_purchase("rebar_pipe"), "60 needed")
	assert_false(Upgrades.purchase("rebar_pipe"))
	GameState.salvage = 400
	assert_almost_eq(Upgrades.damage_multiplier("rebar_pipe"), 1.0, 0.001)
	assert_true(Upgrades.purchase("rebar_pipe"))
	assert_eq(GameState.salvage, 340)
	assert_almost_eq(Upgrades.damage_multiplier("rebar_pipe"), 1.12, 0.001)
	assert_almost_eq(Upgrades.stamina_multiplier("rebar_pipe"), 1.0, 0.001)
	assert_true(Upgrades.purchase("rebar_pipe"))
	assert_almost_eq(Upgrades.stamina_multiplier("rebar_pipe"), 0.85, 0.001)
	assert_almost_eq(Upgrades.special("rebar_pipe", "finisher_bonus"), 0.0, 0.001, "special arrives at tier 3")
	assert_true(Upgrades.purchase("rebar_pipe"))
	assert_eq(GameState.salvage, 20)
	assert_almost_eq(Upgrades.special("rebar_pipe", "finisher_bonus"), 0.3, 0.001)
	assert_eq(Upgrades.next_cost("rebar_pipe"), -1, "fully upgraded")
	assert_false(Upgrades.purchase("rebar_pipe"))
	assert_false(Upgrades.can_purchase("fire_axe"), "cannot upgrade a weapon Kael does not own")


func test_upgraded_weapon_hits_harder() -> void:
	await _build_city(Vector3(0.0, 0.1, -90.0))
	var attack: Node = player.state_machine.get_node("Attack")
	attack.set("_weapon", player.weapon)
	attack.set("is_heavy", false)
	var base: float = (attack.call("build_hit") as HitInfo).damage
	GameState.weapons["rebar_pipe"] = 1
	var upgraded: float = (attack.call("build_hit") as HitInfo).damage
	assert_almost_eq(upgraded, base * 1.12, 0.01)


func test_workbench_rests_saves_and_opens_upgrades() -> void:
	await _build_city(Vector3(-27.5, 0.1, 7.6))
	var ui := StoryUI.new()
	add_child_autofree(ui)
	watch_signals(EventBus)
	player.health.apply_damage(60.0)
	player.injectors = 0
	var enemies: int = city.get_enemies().size()
	(city.get_enemies()[0] as Enemy).finish_takedown()
	GameState.salvage = 100
	(city.objects["workbench_main"] as Usable).interact(player)
	await wait_process_frames(3)
	assert_almost_eq(player.health.health, player.health.max_health, 0.01, "rested")
	assert_eq(player.injectors, player.combat.max_injectors)
	assert_eq(GameState.checkpoint_id, "dc_workbench_main")
	assert_signal_emitted(EventBus, "checkpoint_reached")
	assert_true(ui.is_modal_open(), "upgrade panel is open")
	assert_true(get_tree().paused)
	ui._buy_upgrade("rebar_pipe")
	assert_eq(Upgrades.tier("rebar_pipe"), 1)
	assert_eq(GameState.salvage, 40)
	ui._close_modal()
	await wait_physics_frames(3)
	assert_eq(city.get_enemies().size(), enemies, "ordinary enemies return after resting")
	# Resting again at the same bench still saves.
	(city.objects["workbench_main"] as Usable).interact(player)
	assert_signal_emit_count(EventBus, "checkpoint_reached", 2)
	ui._close_modal()


func test_mission_tracker_follows_the_story() -> void:
	await _build_city(Vector3(0.0, 0.1, -90.0))
	assert_eq(MissionManager.mission_title, "Act 1: Static")
	assert_string_contains(MissionManager.current_objective, "rooftop")
	assert_true(MissionManager.waypoint is Vector3, "the first objective has a marker")
	assert_eq(MissionManager.completed.size(), 0)
	_use("fuse_metro")
	assert_eq(MissionManager.completed.size(), 4, "earlier objectives are logged as done")
	assert_eq(MissionManager.waypoint, DeadCity.FUSE_SPOTS["fuse_school"], "the marker shows the fuse still missing (owner feedback, M6)")
	_use("fuse_school")
	assert_true(MissionManager.waypoint is Vector3, "the junction panel is marked")


# --- Menus ----------------------------------------------------------------------------------

func test_main_menu_shows_first_and_continue_needs_a_save() -> void:
	SettingsManager.set_value("graphics", "auto_detected", true, false)
	var game: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	game.set("force_menu", true)
	add_child_autofree(game)
	await wait_physics_frames(10)
	var menu: MainMenu = game.get("main_menu")
	assert_not_null(menu, "the game opens on the main menu")
	assert_false((game.get("player") as Player).input_enabled, "Kael cannot be controlled behind the menu")
	assert_true((menu.find_child("Continue", true, false) as Button).disabled, "nothing to continue yet")
	assert_false((menu.find_child("NewGame", true, false) as Button).disabled)
	GameState.current_area = "dead_city"
	SaveManager.save_game("slot1")
	menu.refresh()
	assert_false((menu.find_child("Continue", true, false) as Button).disabled, "Continue lights up once a save exists")
	(menu.find_child("Settings", true, false) as Button).pressed.emit()
	(menu.find_child("Credits", true, false) as Button).pressed.emit()
	(menu.find_child("Load", true, false) as Button).pressed.emit()
	await wait_process_frames(2)
	assert_true(true, "side panels open without errors")


func test_game_autosaves_at_checkpoints_and_boots_from_a_load_request() -> void:
	var game: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	add_child_autofree(game)
	game.set("autosave_enabled", true)
	await wait_physics_frames(10)
	var first_city: DeadCity = game.get("level")
	first_city.objects["fuse_metro"].interact(game.get("player"))
	first_city.set_checkpoint("dc_main_street", Vector3(0.0, 0.1, 2.0), 0.0)
	assert_true(SaveManager.has_save("autosave"), "checkpoint wrote the autosave")
	assert_eq(SaveManager.get_most_recent_slot(), "autosave")
	# Saved in mid-air: not a safe spot, so the load falls back to the checkpoint.
	(game.get("player") as Player).global_position = Vector3(6.0, 9.0, 10.0)
	var safe: bool = game.call("can_resume_here")
	assert_false(safe, "not in mid-air")
	assert_eq(game.call("save_to_slot", "slot2"), OK)
	game.free()
	GameState.reset()

	(load(GAME_SCRIPT) as GDScript).set("boot_request", {"mode": "load", "slot": "slot2"})
	var second: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	add_child_autofree(second)
	await wait_physics_frames(30)
	var loaded_city: DeadCity = second.get("level")
	var kael: Player = second.get("player")
	assert_eq(loaded_city.fuses_found, 1)
	assert_almost_eq(kael.global_position.x, 0.0, 0.5, "Kael stands at the checkpoint")
	assert_almost_eq(kael.global_position.z, 2.0, 0.8)
	assert_almost_eq(kael.global_position.y, 0.0, 0.2)
	assert_true(kael.input_enabled)


func test_pause_menu_pages_and_slots() -> void:
	GameState.collected_documents = ["dc_mara_1"] as Array[String]
	GameState.weapons = {"rebar_pipe": 2, "fire_axe": 0}
	MissionManager.set_objective("Reach the tower", Vector3.ZERO)
	MissionManager.set_side("journal", "Optional: follow Mara's journal (1 / 3)", false)
	var menu := PauseMenu.new()
	add_child_autofree(menu)
	menu.open()
	watch_signals(menu)
	for page: String in PauseMenu.PAGES:
		menu.show_page(page)
		await wait_process_frames(2)
		assert_eq(menu.current_page, page)
	menu.show_page("Documents")
	await wait_process_frames(2)
	var entry: Button = null
	for node: Node in menu.find_children("*", "Button", true, false):
		if (node as Button).text == "Mara's journal, page one":
			entry = node
	assert_not_null(entry, "found documents are listed by title")
	entry.pressed.emit()
	await wait_process_frames(2)
	var body_shown: bool = false
	for node: Node in menu.find_children("*", "Label", true, false):
		if (node as Label).text.begins_with("Day 6,212"):
			body_shown = true
	assert_true(body_shown, "documents can be read again")
	menu.show_page("Save game")
	await wait_process_frames(2)
	(menu.find_child("Slot_slot2", true, false) as Button).pressed.emit()
	assert_signal_emitted_with_parameters(menu, "save_requested", ["slot2"])
	menu.show_page("Load game")
	await wait_process_frames(2)
	assert_true((menu.find_child("Slot_slot1", true, false) as Button).disabled, "empty slots cannot be loaded")


func test_settings_panel_tabs_and_values() -> void:
	var panel := SettingsPanel.new()
	add_child_autofree(panel)
	for tab: String in SettingsPanel.TABS:
		panel.show_tab(tab)
		await wait_process_frames(2)
		assert_eq(panel.current_tab, tab)
	SettingsManager.set_value("graphics", "ssr", 0, false)
	assert_eq(str(SettingsManager.get_value("graphics", "preset")), "custom", "changing one option leaves the preset")
	SettingsManager.apply_graphics_preset("low", false)
	assert_eq(int(SettingsManager.get_value("graphics", "ssr")), 0)
	SettingsManager.set_value("audio", "subtitle_size", 1.4, false)
	assert_almost_eq(SettingsManager.get_float("audio", "subtitle_size"), 1.4, 0.001)


# --- Rebinding and auto-detect --------------------------------------------------------------------

func test_rebinding_replaces_the_key_and_swaps_conflicts() -> void:
	assert_eq(InputSetup.get_action_label("jump"), "Space")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_J
	key.pressed = true
	assert_true(InputSetup.rebind("jump", key))
	assert_eq(InputSetup.get_action_label("jump"), "J")
	assert_true(InputMap.action_has_event(&"jump", key))
	var space := InputEventKey.new()
	space.physical_keycode = KEY_SPACE
	assert_false(InputMap.action_has_event(&"jump", space), "the old key no longer jumps")
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_A
	assert_true(InputMap.action_has_event(&"jump", pad), "controller bindings are untouched")
	# Binding Interact to J as well: Jump takes Interact's old key so nothing is unbound.
	assert_true(InputSetup.rebind("interact", key))
	assert_eq(InputSetup.get_action_label("interact"), "J")
	assert_eq(InputSetup.get_action_label("jump"), "E")
	assert_eq(SettingsManager.get_section("bindings")["jump"], [InputSetup.Kind.KEY, KEY_E])
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_XBUTTON1
	assert_true(InputSetup.rebind("dodge", mouse))
	assert_eq(InputSetup.get_action_label("dodge"), "Mouse %d" % MOUSE_BUTTON_XBUTTON1)
	InputSetup.reset_bindings()
	assert_eq(InputSetup.get_action_label("jump"), "Space")
	assert_true(InputMap.action_has_event(&"jump", space))


func test_first_launch_preset_choice() -> void:
	var rules: Dictionary = SettingsManager.get_auto_detect_rules()
	var game_script: GDScript = load(GAME_SCRIPT)
	assert_eq(game_script.call("pick_preset", 112.2, 57.8, rules), "medium", "the owner's MacBook Air M4")
	assert_eq(game_script.call("pick_preset", 55.0, 44.0, rules), "low")
	assert_eq(game_script.call("pick_preset", 95.0, 30.0, rules), "low", "bad dips count too")
	assert_eq(game_script.call("pick_preset", 190.0, 120.0, rules), "high")


func test_loading_puts_kael_back_where_he_saved() -> void:
	var game: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	add_child_autofree(game)
	await wait_physics_frames(10)
	var kael: Player = game.get("player")
	kael.teleport(Vector3(-4.0, 0.1, 14.0), 1.2)
	await wait_physics_frames(20)
	var safe: bool = game.call("can_resume_here")
	assert_true(safe, "standing on the street with nothing hunting him")
	assert_eq(game.call("save_to_slot", "slot3"), OK)
	game.free()
	GameState.reset()
	(load(GAME_SCRIPT) as GDScript).set("boot_request", {"mode": "load", "slot": "slot3"})
	var second: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	add_child_autofree(second)
	await wait_physics_frames(30)
	var loaded: Player = second.get("player")
	assert_almost_eq(loaded.global_position.x, -4.0, 0.3)
	assert_almost_eq(loaded.global_position.z, 14.0, 0.3)
	assert_almost_eq(loaded.facing_yaw, 1.2, 0.05, "facing the same way")
	assert_true(GameState.resume_point.is_empty(), "used once, so a death goes back to the checkpoint")


func test_photo_mode_opens_from_the_pause_menu_and_returns_to_it() -> void:
	var game: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	add_child_autofree(game)
	await wait_physics_frames(10)
	game.call("set_paused", true)
	var pause: PauseMenu = game.get("pause_menu")
	(pause.find_child("PhotoMode", true, false) as Button).pressed.emit()
	var photo: PhotoMode = game.get("photo_mode")
	assert_true(photo.active)
	assert_false(pause.visible, "the pause menu steps aside")
	assert_true(get_tree().paused, "the world stays frozen")
	photo.close()
	assert_true(pause.visible, "and comes back after")
	game.call("set_paused", false)
