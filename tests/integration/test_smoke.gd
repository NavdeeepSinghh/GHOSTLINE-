extends GutTest
## Smoke test: every scene loads and instantiates, and the game boots and runs
## without script errors.

const SCENE_ROOT: String = "res://scenes"


func _collect_scenes(directory: String, found: PackedStringArray) -> void:
	var dir := DirAccess.open(directory)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		_collect_scenes(directory.path_join(sub), found)
	for file: String in dir.get_files():
		if file.ends_with(".tscn"):
			found.append(directory.path_join(file))


func test_every_scene_loads_and_instantiates() -> void:
	var scenes: PackedStringArray = []
	_collect_scenes(SCENE_ROOT, scenes)
	assert_gt(scenes.size(), 2)
	for path: String in scenes:
		var packed: PackedScene = load(path)
		assert_not_null(packed, "failed to load %s" % path)
		if packed != null and path != "res://scenes/main/main.tscn":
			var instance: Node = packed.instantiate()
			assert_not_null(instance, "failed to instantiate %s" % path)
			instance.free()


func test_game_boots_and_runs() -> void:
	var game: Node = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	add_child_autofree(game)
	await wait_physics_frames(90)
	var player: Player = game.get("player")
	assert_not_null(player)
	assert_not_null(game.get("level"))
	assert_true(game.get("level") is DeadCity, "the game starts in the Dead City")
	assert_eq(player.state_machine.current_name, &"Ground", "Kael is standing on the camp roof")
	assert_almost_eq(player.global_position.y, DeadCityLayout.ROOF_A_Y, 0.1)
	assert_eq(player.weapons.size(), 1, "weapons are found in the world")
	assert_string_contains(MissionManager.current_objective, "rooftop")
	game.call(&"set_paused", true)
	assert_true(get_tree().paused)
	game.call(&"set_paused", false)
	assert_false(get_tree().paused)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Player.starting_weapons = PackedStringArray()


func test_proving_ground_still_boots_from_the_game() -> void:
	var game: Node = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	game.set("level_name", "proving_ground")
	add_child_autofree(game)
	await wait_physics_frames(60)
	var player: Player = game.get("player")
	assert_false(game.get("level") is DeadCity)
	assert_eq(player.weapons.size(), 3, "the test level unlocks every weapon")
	assert_almost_eq(player.global_position.y, 0.0, 0.05)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Player.starting_weapons = PackedStringArray()


func test_proving_ground_has_a_benchmark_route() -> void:
	var level: Level = (load("res://scenes/levels/proving_ground/proving_ground.tscn") as PackedScene).instantiate()
	add_child_autofree(level)
	assert_gt(level.get_tour_stops().size(), 3)
	assert_gt(get_tree().get_nodes_in_group(CameraRig.LOCK_ON_GROUP).size(), 2)


func test_facility_boots_and_the_credits_roll() -> void:
	GameState.reset()
	var game: Node = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	game.set("level_name", "facility")
	game.set("skip_intro", true)
	add_child_autofree(game)
	await wait_physics_frames(60)
	var player: Player = game.get("player")
	assert_true(game.get("level") is Facility)
	assert_almost_eq(player.global_position.y, 0.0, 0.1, "Kael stands in reception")
	assert_string_contains(MissionManager.current_objective.to_lower(), "power")
	var ui: StoryUI = game.get("story_ui")
	EventBus.credits_requested.emit(true)
	await wait_physics_frames(3)
	assert_not_null(ui.get("_credits"), "the credits are on screen")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Player.starting_weapons = PackedStringArray()
