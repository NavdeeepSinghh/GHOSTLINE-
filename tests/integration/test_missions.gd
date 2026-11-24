extends GutTest
## Mission select: every mission boots straight into its area at the right
## objective, with Kael standing on solid ground at its checkpoint, and a
## mission run never writes to the player's saves.

const MAIN_SCENE: String = "res://scenes/main/main.tscn"
const GAME_SCRIPT: String = "res://scripts/core/game.gd"
const LEVEL_TYPES: Dictionary = {"dead_city": "DeadCity", "forest": "Forest", "facility": "Facility"}


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


func _boot(id: String) -> Node:
	(load(GAME_SCRIPT) as GDScript).set("boot_request", {"mode": "mission", "id": id})
	var game: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	add_child(game)
	await wait_seconds(1.0)
	return game


func test_mission_data_is_complete() -> void:
	var all: Dictionary = Missions.data()
	var ids: Array[String] = []
	for area: String in Chapters.ORDER:
		assert_gt((all.get(area, []) as Array).size(), 3, "%s has missions" % area)
		for mission: Dictionary in all[area]:
			assert_false(ids.has(str(mission["id"])), "ids are unique")
			ids.append(str(mission["id"]))
			assert_eq((mission["spawn"] as Array).size(), 4)
	assert_eq(Missions.find("nope"), [])
	assert_false(Missions.apply("nope"))


func test_every_mission_starts_at_its_objective() -> void:
	var all: Dictionary = Missions.data()
	for area: String in Chapters.ORDER:
		for mission: Dictionary in all[area]:
			var id: String = str(mission["id"])
			var game: Node = await _boot(id)
			var level: StoryLevel = game.get("level") as StoryLevel
			assert_not_null(level, id)
			if level == null:
				game.queue_free()
				continue
			assert_eq(str(level.get_script().get_global_name()), str(LEVEL_TYPES[area]), "%s loads %s" % [id, area])
			assert_eq(int(level.get("stage")), int(mission["stage"]), "%s starts at its objective" % id)
			var player: Player = game.get("player")
			var spawn: Array = mission["spawn"]
			var expected := Vector3(float(spawn[0]), float(spawn[1]), float(spawn[2]))
			assert_lt(Vector2(player.global_position.x - expected.x, player.global_position.z - expected.z).length(), 1.5, "%s: Kael at the checkpoint" % id)
			assert_lt(absf(player.global_position.y - expected.y), 1.5, "%s: on the ground, not falling" % id)
			assert_false(MissionManager.current_objective.is_empty(), "%s shows an objective" % id)
			assert_true(game.get("practice_run"), "%s is a practice run" % id)
			game.queue_free()
			await wait_frames(3)


func test_mission_states_match_the_story_so_far() -> void:
	var game: Node = await _boot("dc_junction")
	var city: DeadCity = game.get("level")
	assert_eq(city.fuses_found, 2, "both fuses already in hand")
	assert_true((city.objects["panel"] as Usable).enabled)
	game.queue_free()
	await wait_frames(3)
	game = await _boot("uf_labs")
	var facility: Facility = game.get("level")
	assert_false(facility.objects.has("stair_1"), "the doors behind are open")
	assert_false(facility.objects.has("stair_2"))
	assert_true(facility.objects.has("lock"), "the lock ahead is still shut")
	assert_true((game.get("player") as Player).has_weapon("fire_axe"))
	game.queue_free()
	await wait_frames(3)


func test_a_mission_never_touches_the_saves() -> void:
	SaveManager.delete_slot(SaveManager.AUTOSAVE_SLOT)
	var game: Node = await _boot("ff_tune")
	game.set("autosave_enabled", true)
	game.call(&"autosave")
	assert_eq(game.call(&"save_to_slot", "slot1"), ERR_UNAVAILABLE)
	assert_true(SaveManager.describe_slot(SaveManager.AUTOSAVE_SLOT).is_empty(), "no autosave written")
	assert_true(SaveManager.describe_slot("slot1").is_empty())
	assert_false((game.get("pause_menu") as PauseMenu).saving_enabled)
	game.queue_free()
	await wait_frames(3)


func test_missions_page_lists_everything_and_starts_one() -> void:
	var menu := MainMenu.new()
	add_child_autofree(menu)
	await wait_frames(1)
	assert_true((menu.find_child("Missions", true, false) as Button).visible, "available from the start")
	menu._show_missions()
	await wait_frames(1)
	var count: int = 0
	for area: String in Chapters.ORDER:
		count += (Missions.data()[area] as Array).size()
	assert_eq(menu.find_children("Mission_*", "Button", true, false).size(), count)
	watch_signals(menu)
	(menu.find_child("Mission_ff_warden", true, false) as Button).pressed.emit()
	assert_signal_emitted_with_parameters(menu, "mission_requested", ["ff_warden"])
