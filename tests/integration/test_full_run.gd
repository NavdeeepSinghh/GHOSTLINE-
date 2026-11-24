extends GutTest
## The whole game in one chain, through the real Game node: a new game in the
## Dead City, its act ending and the road out, arriving in the Forest with
## everything carried over, the Warden's fall and the tunnel, the Facility,
## the Choir, the final blow, the ending, the credits, and the chapter select
## it unlocks. Each area's own puzzles and fights are covered by its own tests;
## this checks that the areas hand over to each other.

const MAIN_SCENE: String = "res://scenes/main/main.tscn"
const GAME_SCRIPT: String = "res://scripts/core/game.gd"

var game: Node


func before_each() -> void:
	SettingsManager.reset_to_defaults(false)
	CombatFX.hitstop_enabled = false
	CombatDirector.clear()
	GameState.reset()
	MissionManager.reset()
	Player.starting_weapons = PackedStringArray()


func after_each() -> void:
	(load(GAME_SCRIPT) as GDScript).set("boot_request", {})
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	MusicDirector.stop()
	SettingsManager.reset_to_defaults(false)


func _boot(request: Dictionary) -> Node:
	if request.size() > 0:
		(load(GAME_SCRIPT) as GDScript).set("boot_request", request)
	var node: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	node.set("skip_intro", true)
	add_child(node)
	# Let the loading screen and warm-up finish.
	await wait_seconds(1.2)
	return node


func _leave(node: Node) -> void:
	node.queue_free()
	await wait_frames(3)


func _close_summary() -> void:
	(game.get("story_ui") as StoryUI).close_modal()
	get_tree().paused = false
	await wait_frames(2)


func _skip_cinematic(level: StoryLevel) -> void:
	for i: int in 400:
		if level.cinematic.is_playing:
			level.cinematic.skip()
			return
		await wait_physics_frames(1)


func test_the_whole_game_hands_over_from_area_to_area() -> void:
	# Act 1.
	game = await _boot({"mode": "new"})
	var city: DeadCity = game.get("level") as DeadCity
	assert_not_null(city, "a new game starts in the Dead City")
	var player: Player = game.get("player")
	GameState.salvage = 0
	player.grant_weapon("fire_axe")
	GameState.salvage = 77
	city.stage = DeadCity.Stage.TRANSMIT
	city.play_ending()
	await _skip_cinematic(city)
	await wait_frames(3)
	assert_true(GameState.has_flag("act1_complete"))
	await _close_summary()
	var road: Usable = city.objects["exit_road"]
	assert_true(road.can_interact(player) or road.enabled, "the road out opens")
	watch_signals(EventBus)
	road.interact(player)
	assert_signal_emitted_with_parameters(EventBus, "travel_requested", ["forest"])
	assert_eq(GameState.current_area, "forest", "Game takes the request")
	assert_eq((load(GAME_SCRIPT) as GDScript).get("boot_request"), {"mode": "travel", "practice": false}, "a real playthrough keeps saving")
	await _leave(game)

	# Act 2.
	game = await _boot({})
	var forest: Forest = game.get("level") as Forest
	assert_not_null(forest, "travel arrives in the Forest")
	player = game.get("player")
	assert_true(player.has_weapon("fire_axe"), "weapons carry over")
	assert_eq(GameState.salvage, 77, "so does salvage")
	assert_true(GameState.has_flag("act1_complete"), "and the story so far")
	forest._on_warden_defeated()
	await _skip_cinematic(forest)
	await wait_frames(3)
	await _close_summary()
	var tunnel: Usable = forest.objects["tunnel"]
	assert_true(tunnel.enabled, "the tunnel opens after the Warden")
	tunnel.interact(player)
	assert_eq(GameState.current_area, "facility")
	await _leave(game)

	# Act 3.
	game = await _boot({})
	var facility: Facility = game.get("level") as Facility
	assert_not_null(facility, "the tunnel leads to the Facility")
	player = game.get("player")
	assert_true(player.has_weapon("fire_axe"))
	player.god_mode = true
	player.teleport(Vector3(160.0, -17.9, 0.0), -PI * 0.5)
	GameState.set_flag("uf_choir_seen")
	facility._on_chamber_entered(player)
	await wait_frames(3)
	var choir: Choir = facility.choir
	choir._set_heart(true)
	choir.on_target_hit(-1, _hit(choir.max_health * 0.45))
	for i: int in 3:
		choir.on_target_hit(i, _hit(10.0))
	choir.on_target_hit(-1, _hit(choir.max_health * 0.3))
	choir._set_heart(true)
	choir.on_target_hit(-1, _hit(choir.max_health))
	await wait_frames(3)
	assert_eq(facility.stage, Facility.Stage.SEVER)
	player.teleport(Vector3(176.0, -17.9, -11.0), PI)
	await wait_physics_frames(3)
	var ui: StoryUI = game.get("story_ui")
	ui.credits_page_seconds = 0.1
	assert_false(Chapters.is_unlocked())
	(facility.objects["anchor"] as Usable).interact(player)
	await _skip_cinematic(facility)
	await wait_frames(3)
	assert_true(GameState.has_flag("game_complete"))
	await _close_summary()
	await wait_frames(3)
	assert_not_null(ui.get("_credits"), "the credits roll")
	await wait_seconds(1.5)
	assert_null(ui.get("_credits"), "and finish")
	assert_true(Chapters.is_unlocked(), "finishing unlocks chapter select")
	await _leave(game)


func test_chapter_select_starts_an_act_with_a_prepared_kael() -> void:
	SettingsManager.set_value("progress", "game_complete", true, false)
	game = await _boot({"mode": "chapter", "area": "facility"})
	assert_true(game.get("level") is Facility)
	var player: Player = game.get("player")
	assert_true(player.has_weapon("fire_axe"))
	assert_almost_eq(player.health.max_health, 150.0, 0.01)
	assert_eq(GameState.salvage, 300)
	await _leave(game)


func test_chapters_appear_in_the_menu_only_after_finishing() -> void:
	var menu := MainMenu.new()
	add_child_autofree(menu)
	await wait_frames(1)
	assert_false((menu.find_child("Chapters", true, false) as Button).visible)
	SettingsManager.set_value("progress", "game_complete", true, false)
	var second := MainMenu.new()
	add_child_autofree(second)
	await wait_frames(1)
	assert_true((second.find_child("Chapters", true, false) as Button).visible)
	watch_signals(second)
	second._show_chapters()
	await wait_frames(1)
	(second.find_child("Chapter_forest", true, false) as Button).pressed.emit()
	assert_signal_emitted_with_parameters(second, "chapter_requested", ["forest"])


func _hit(damage: float) -> HitInfo:
	var hit := HitInfo.new()
	hit.damage = damage
	return hit
