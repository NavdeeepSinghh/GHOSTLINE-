extends GutTest
## The Forgotten Forest: builds, is walkable along the critical route, the
## radio puzzle opens the inner gate, the Warden fights through three phases,
## and progress survives a save.

const SCENE: String = "res://scenes/levels/forest/forest.tscn"
const PLAYER_SCENE: String = "res://scenes/player/player.tscn"

var forest: Forest
var player: Player


func before_each() -> void:
	SettingsManager.reset_to_defaults(false)
	CombatFX.hitstop_enabled = false
	CombatDirector.clear()
	GameState.reset()
	MissionManager.reset()
	Player.starting_weapons = PackedStringArray()
	forest = (load(SCENE) as PackedScene).instantiate() as Forest
	add_child_autofree(forest)
	for i: int in 240:
		await wait_physics_frames(1)
		if i > 2 and _path_length(Vector3(-120.0, 0.0, 2.0), Vector3(-100.0, 0.0, 0.0)) < 100.0:
			break
	for enemy: Enemy in forest.get_enemies():
		enemy.set_physics_process(false)


func after_each() -> void:
	get_tree().paused = false
	Player.starting_weapons = PackedStringArray()


func _spawn_player(at: Vector3) -> void:
	player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	player.position = at
	forest.add_child(player)
	await wait_physics_frames(12)


func _path_length(from: Vector3, to: Vector3) -> float:
	var path: PackedVector3Array = NavigationServer3D.map_get_path(forest.get_world_3d().navigation_map, from, to, true)
	if path.size() < 2:
		return INF
	var end: Vector3 = path[path.size() - 1]
	if Vector2(end.x - to.x, end.z - to.z).length() > 1.5:
		return INF
	var total: float = 0.0
	for i: int in range(1, path.size()):
		total += path[i - 1].distance_to(path[i])
	return total


func test_forest_builds_with_content() -> void:
	assert_eq(forest.documents.size(), 8)
	for document: Dictionary in forest.documents:
		assert_true(forest.objects.has(document["id"]), "%s is placed" % document["id"])
	assert_gt(forest.get_enemies().size(), 14)
	assert_not_null(forest.warden, "the Warden waits in the arena")
	assert_true(forest.warden.is_asleep())
	assert_eq(GameState.current_area, "forest")
	assert_gt(forest.get_tour_stops().size(), 6)
	var wolves: int = 0
	for enemy: Enemy in forest.get_enemies():
		if enemy.data.id == "wolf":
			wolves += 1
	assert_gt(wolves, 4, "corrupted wolves live here")


func test_route_is_connected_and_gated() -> void:
	var start := Vector3(-120.0, 0.0, 2.0)
	assert_lt(_path_length(start, Vector3(-84.0, 0.0, -40.0)), 120.0, "through the breach in the outer wall")
	assert_gt(_path_length(start, Vector3(-84.0, 0.0, 0.0)), 60.0, "the outer gate is shut: the only way is round by the breach")
	for place: Array in [["outpost", Vector3(-70.0, 0.0, -28.0)], ["watchtower foot", Vector3(-45.0, 0.0, 29.0)], ["radio hut", Vector3(12.0, 0.0, 32.0)],
			["hunter's cave", Vector3(-4.0, 0.0, -54.0)], ["lower cave", Vector3(40.0, 0.0, -50.0)], ["inner gate", Vector3(56.0, 0.0, 0.0)]]:
		assert_lt(_path_length(start, place[1]), 400.0, "a path reaches the %s" % place[0])
	# The navmesh is baked before the gate door exists, so check the door itself blocks Kael.
	assert_true(forest.objects.has("inner_gate"))
	assert_lt(_path_length(Vector3(56.0, 0.0, 0.0), Vector3(108.0, 0.0, 0.0)), 80.0, "the arena and tunnel mouth are reachable once it opens")


func test_radio_puzzle_opens_the_inner_gate() -> void:
	await _spawn_player(Vector3(12.0, 0.1, 32.0))
	var puzzle := Puzzles.Waveform.new(4, 2)
	assert_false(puzzle.is_solved())
	for i: int in 3:
		puzzle.turn_frequency(1)
	for i: int in 3:
		puzzle.turn_amplitude(-1)
	assert_true(puzzle.is_solved(), "frequency 4, strength 2, as the operator's log says")
	puzzle.turn_frequency(9)
	assert_eq(puzzle.frequency, Puzzles.Waveform.STEPS, "dials stop at their ends")
	(forest.objects["radio"] as Usable).interact(player)
	await wait_physics_frames(3)
	assert_true(GameState.has_flag("ff_gate_open"))
	assert_false(forest.objects.has("inner_gate"), "the gate is gone")
	assert_eq(forest.stage, Forest.Stage.TUNNEL)


func test_warden_runs_three_phases_and_opens_the_tunnel() -> void:
	watch_signals(EventBus)
	# Stepping into the yard wakes the Warden (the arena's trigger zone does the same in play).
	await _spawn_player(Vector3(70.0, 0.1, 0.0))
	forest._on_arena_entered(player)
	await wait_physics_frames(4)
	assert_true(forest.cinematic.is_playing, "the first time, the Warden makes an entrance")
	assert_eq(forest.warden.process_mode, Node.PROCESS_MODE_DISABLED, "and holds still for it")
	assert_signal_not_emitted(EventBus, "boss_started")
	forest.cinematic.skip()
	await wait_physics_frames(4)
	assert_true(GameState.has_flag("ff_warden_seen"))
	assert_eq(forest.stage, Forest.Stage.WARDEN)
	assert_signal_emitted(EventBus, "boss_started")
	assert_signal_emitted_with_parameters(EventBus, "area_title_requested", ["THE WARDEN", "Meridian's last guard"])
	var warden: Enemy = forest.warden
	var controller: WardenController = forest.warden_controller
	assert_false(warden.is_asleep())
	assert_gt(warden.armor_points, 0.0)
	assert_false(warden.data.takedown_allowed)
	assert_eq(controller.phase, 1)
	warden.set_physics_process(false)
	warden.health.apply_damage(warden.health.max_health * 0.45)
	await wait_physics_frames(3)
	assert_eq(controller.phase, 2, "below 60%")
	assert_eq(warden.armor_points, 0.0, "the armour falls away")
	await wait_frames(2)
	assert_true(forest.cinematic.is_playing, "the camera swings in on the change")
	assert_eq(MusicDirector.choose_state(true, true, 0, false), "boss", "boss music carries on through it")
	forest.cinematic.skip()
	await wait_frames(2)
	assert_eq(warden.process_mode, Node.PROCESS_MODE_INHERIT, "and the Warden moves again")
	warden.health.apply_damage(warden.health.max_health * 0.35)
	await wait_physics_frames(3)
	assert_eq(controller.phase, 3, "below 25%")
	await wait_frames(2)
	forest.cinematic.skip()
	await wait_frames(2)
	assert_eq(warden.data.attack_kind, EnemyData.AttackKind.DASH, "erratic lunges")
	assert_gt(warden.data.attack_recovery, 1.5, "with long recoveries")
	assert_false((forest.objects["tunnel"] as Usable).can_interact(player))
	warden.finish_takedown()
	await wait_physics_frames(3)
	assert_true(GameState.has_flag("ff_warden_dead"))
	assert_signal_emitted(EventBus, "boss_ended")
	await wait_seconds(2.0)
	assert_true(forest.cinematic.is_playing, "Oren's confession plays")
	forest.cinematic.skip()
	await wait_physics_frames(3)
	assert_eq(forest.stage, Forest.Stage.ENTER)
	assert_true((forest.objects["tunnel"] as Usable).can_interact(player))
	(forest.objects["tunnel"] as Usable).interact(player)
	assert_signal_emitted_with_parameters(EventBus, "travel_requested", ["facility"])


func test_flame_is_blocked_by_pillars() -> void:
	await _spawn_player(Vector3(80.0, 0.1, 0.0))
	GameState.set_flag("ff_warden_seen")
	forest._on_arena_entered(player)
	await wait_physics_frames(4)
	var warden: Enemy = forest.warden
	warden.set_physics_process(false)
	var controller: WardenController = forest.warden_controller
	warden.global_position = Vector3(90.0, 0.05, 0.0)
	player.teleport(Vector3(84.0, 0.1, 0.0), 0.0)
	await wait_physics_frames(3)
	var yaw: float = atan2(player.global_position.x - warden.global_position.x, player.global_position.z - warden.global_position.z)
	assert_true(controller.flame_reaches(player, yaw), "in the open, the flame reaches Kael")
	assert_false(controller.flame_reaches(player, yaw + 1.0), "outside the cone it does not")
	# Behind the pillar at (86, -13), seen from the Warden at (90, -13).
	warden.global_position = Vector3(90.0, 0.05, -13.0)
	player.teleport(Vector3(83.5, 0.1, -13.0), 0.0)
	await wait_physics_frames(3)
	yaw = atan2(player.global_position.x - warden.global_position.x, player.global_position.z - warden.global_position.z)
	assert_false(controller.flame_reaches(player, yaw), "a pillar breaks line of sight")


func test_dying_to_the_warden_resets_the_fight() -> void:
	await _spawn_player(Vector3(70.0, 0.1, 0.0))
	GameState.set_flag("ff_warden_seen")
	forest._on_arena_entered(player)
	await wait_physics_frames(4)
	forest.warden.health.apply_damage(200.0)
	forest.reset_encounters()
	await wait_physics_frames(4)
	assert_eq(forest.stage, Forest.Stage.TUNNEL, "back to before the arena")
	assert_almost_eq(forest.warden.health.get_ratio(), 1.0, 0.001, "the Warden is whole again")
	assert_true(forest.warden.is_asleep())
	assert_eq(forest.spawn_position, Vector3(63.0, 0.1, 0.0), "Kael respawns at the gate")


func test_side_objectives_and_save() -> void:
	await _spawn_player(Vector3(-4.0, 0.1, -54.0))
	GameState.weapons = {"rebar_pipe": 1}
	(forest.objects["ff_hunter_note"] as Usable).interact(player)
	get_tree().paused = false
	assert_true(MissionManager.side_objectives.has("cache"))
	(forest.objects["cache"] as Usable).interact(player)
	assert_eq(Upgrades.tier("rebar_pipe"), 2, "the cache hones the weapon in hand")
	assert_true(MissionManager.is_side_done("cache"))
	(forest.objects["lung_core"] as Usable).interact(player)
	assert_almost_eq(player.max_stamina, 120.0, 0.01)
	(forest.objects["ff_patrol_log"] as Usable).interact(player)
	get_tree().paused = false
	(forest.objects["ff_patrol_final"] as Usable).interact(player)
	get_tree().paused = false
	assert_true(MissionManager.is_side_done("patrol"))
	forest.open_inner_gate()
	player.write_state()
	forest.capture_state()
	var saved: Dictionary = GameState.to_dict()
	forest.free()
	GameState.reset()
	GameState.from_dict(saved)
	forest = (load(SCENE) as PackedScene).instantiate() as Forest
	add_child_autofree(forest)
	await _spawn_player(Vector3(12.0, 0.1, 28.0))
	forest.restore_state(player)
	assert_eq(forest.stage, Forest.Stage.TUNNEL)
	assert_false(forest.objects.has("inner_gate"), "the gate stays open")
	assert_false((forest.objects["cache"] as Usable).can_interact(player))
	assert_false((forest.objects["ff_hunter_note"] as Usable).can_interact(player))
	assert_eq(forest.spawn_position, Vector3(12.0, 0.1, 28.0))


func test_set_dressing_and_wildlife() -> void:
	var wildlife: Node = forest.get_node_or_null("Wildlife")
	assert_not_null(wildlife)
	assert_eq(wildlife.find_children("*", "BirdFlock", true, false).size(), 3)
	assert_eq(wildlife.find_children("*", "Deer", true, false).size(), 3)
	assert_gt(wildlife.find_children("*", "FogVolume", true, false).size(), 4, "mist on the river and in the hollows")
	assert_eq(wildlife.find_children("*", "FollowPlayer", true, false).size(), 1, "leaves fall around Kael")
	assert_eq(wildlife.find_children("*", "Crows", true, false).size(), 5, "ravens in the clearings")
	assert_gt((forest.get_node("Canopies") as MultiMeshInstance3D).multimesh.instance_count,
			(forest.get_node("Trunks") as MultiMeshInstance3D).multimesh.instance_count * 2, "firs have stacked tiers")
