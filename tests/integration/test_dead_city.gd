extends GutTest
## The Dead City: the level builds, enemies can path through it, the critical
## route is physically walkable, and the Act 1 story flow works end to end.

const SCENE: String = "res://scenes/levels/dead_city/dead_city.tscn"
const PLAYER_SCENE: String = "res://scenes/player/player.tscn"
const ACTIONS: PackedStringArray = ["move_forward", "move_back", "move_left", "move_right", "sprint", "jump", "interact", "crouch"]

var city: DeadCity
var player: Player


func before_each() -> void:
	SettingsManager.reset_to_defaults(false)
	CombatFX.hitstop_enabled = false
	CombatDirector.clear()
	GameState.reset()
	PerceptionComponent.hearing_scale = 1.0
	Player.starting_weapons = PackedStringArray()
	city = (load(SCENE) as PackedScene).instantiate() as DeadCity
	add_child_autofree(city)
	# The navigation map takes a few physics frames to pick up the baked region.
	for i: int in 240:
		await wait_physics_frames(1)
		if i > 2 and _path_length(Vector3(-29.0, 0.0, 52.0), Vector3(0.0, 0.0, 50.0)) < 100.0:
			break


func after_each() -> void:
	for action: String in ACTIONS:
		Input.action_release(action)
	Player.starting_weapons = PackedStringArray()


func _spawn_player(at: Vector3, yaw: float = 0.0) -> void:
	# Enemies are parked first so nothing wanders over during movement tests.
	for enemy: Enemy in city.get_enemies():
		enemy.set_physics_process(false)
	Player.starting_weapons = city.starting_weapons
	player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	player.position = at
	player.rotation.y = yaw
	city.add_child(player)
	await wait_physics_frames(20)


func _walk(action: StringName, time: float) -> void:
	Input.action_press(action)
	await wait_physics_frames(int(time * 60.0))
	Input.action_release(action)
	await wait_physics_frames(6)


func _path_end_distance(from: Vector3, to: Vector3) -> float:
	var map: RID = city.get_world_3d().navigation_map
	var path: PackedVector3Array = NavigationServer3D.map_get_path(map, from, to, true)
	if path.is_empty():
		return INF
	var end: Vector3 = path[path.size() - 1]
	return Vector2(end.x - to.x, end.z - to.z).length()


func _path_length(from: Vector3, to: Vector3) -> float:
	var path: PackedVector3Array = NavigationServer3D.map_get_path(city.get_world_3d().navigation_map, from, to, true)
	var total: float = 0.0
	for i: int in range(1, path.size()):
		total += path[i - 1].distance_to(path[i])
	return total if path.size() > 1 else INF


# --- Build ------------------------------------------------------------------------

func test_level_builds_with_navigation_and_content() -> void:
	assert_gt(city.navigation_region.navigation_mesh.get_polygon_count(), 150, "navigation mesh was baked")
	assert_eq(city.documents.size(), 8, "eight documents in the area")
	for document: Dictionary in city.documents:
		var words: int = str(document["body"]).split(" ", false).size()
		assert_between(words, 55, 160, "%s is a short read" % document["id"])
		assert_true(city.objects.has(document["id"]), "%s is placed in the world" % document["id"])
	assert_gt(city.get_enemies().size(), 15)
	assert_lt(city.get_enemies().size(), 26)
	assert_gt(city.get_tour_stops().size(), 6)
	assert_eq(city.starting_weapons, PackedStringArray(["rebar_pipe"]))


func test_rain_dulls_hearing_while_the_level_exists() -> void:
	assert_almost_eq(PerceptionComponent.hearing_scale, 0.7, 0.001)
	city.free()
	assert_almost_eq(PerceptionComponent.hearing_scale, 1.0, 0.001, "restored when the level goes away")


func test_enemies_can_path_along_the_critical_route() -> void:
	var street := Vector3(-29.0, 0.0, 52.0)
	var targets: Dictionary = {
		"store": Vector3(-26.0, 0.0, 38.0),
		"courtyard": Vector3(-22.0, 0.0, 22.0),
		"apartment": Vector3(-12.0, 0.0, 62.0),
		"main street": Vector3(0.0, 0.0, -10.0),
		"pharmacy": Vector3(19.0, 0.0, 1.0),
		"generator room": Vector3(14.0, 0.0, 8.0),
		"metro concourse": Vector3(-20.0, -5.0, -30.0),
		"metro fuse room": Vector3(-3.5, -5.0, -35.0),
		"tower plaza": Vector3(-20.0, 0.0, -76.0),
		"classroom": Vector3(20.0, 0.0, -54.0),
		"tower base": Vector3(0.0, 0.0, -92.0),
	}
	for place: String in targets:
		assert_lt(_path_end_distance(street, targets[place]), 1.0, "a path reaches the %s" % place)
	# The metro really connects both sides (not just a long way round through the gate).
	assert_lt(_path_length(Vector3(-20.0, -5.0, -30.0), Vector3(-20.0, 0.0, -76.0)), 60.0)
	assert_lt(_path_length(Vector3(-20.0, 0.0, 9.0), Vector3(-20.0, -5.0, -30.0)), 50.0)


func test_footstep_surfaces() -> void:
	assert_eq(city.get_surface(Vector3(0.0, 0.0, 50.0)), "wet", "open street in the rain")
	assert_eq(city.get_surface(Vector3(-12.0, 0.0, 63.0)), "concrete", "inside the apartment")
	assert_eq(city.get_surface(Vector3(-24.0, 0.0, 22.0)), "grass", "the overgrown courtyard")
	assert_eq(city.get_surface(Vector3(-10.0, 9.0, 70.0)), "gravel", "the camp roof")
	assert_true(city.is_sheltered(Vector3(-20.0, -4.5, -30.0)), "the metro is out of the rain")
	assert_false(city.is_sheltered(Vector3(0.0, 0.5, -10.0)))


# --- Walking the route --------------------------------------------------------------

func test_kael_starts_on_the_camp_roof_and_can_jump_to_the_next_one() -> void:
	await _spawn_player(DeadCityLayout.SPAWN)
	assert_eq(player.state_machine.current_name, &"Ground")
	assert_almost_eq(player.global_position.y, DeadCityLayout.ROOF_A_Y, 0.1)
	assert_eq(player.weapons.size(), 1, "only the rebar pipe at the start")
	# Run west off roof A; the gap is 2 m and roof B is lower.
	player.teleport(Vector3(-17.0, DeadCityLayout.ROOF_A_Y + 0.05, 70.0), 0.0)
	await wait_physics_frames(10)
	Input.action_press(&"sprint")
	Input.action_press(&"move_left")
	await wait_physics_frames(22)
	Input.action_press(&"jump")
	await wait_physics_frames(4)
	Input.action_release(&"jump")
	await wait_physics_frames(70)
	Input.action_release(&"move_left")
	Input.action_release(&"sprint")
	await wait_physics_frames(20)
	assert_lt(player.global_position.x, -22.0, "landed on roof B")
	assert_almost_eq(player.global_position.y, DeadCityLayout.ROOF_B_Y, 0.15)


func test_fire_escape_ladder_reaches_the_street() -> void:
	await _spawn_player(Vector3(-29.0, DeadCityLayout.ROOF_B_Y + 0.05, 58.9))
	var ladder: Ladder = city.objects["ladder_escape"]
	assert_true(ladder.can_interact(player))
	ladder.interact(player)
	await wait_physics_frames(30)
	assert_eq(player.state_machine.current_name, &"Ladder")
	Input.action_press(&"move_back")
	for i: int in 600:
		if player.state_machine.current_name != &"Ladder":
			break
		await wait_physics_frames(1)
	Input.action_release(&"move_back")
	await wait_physics_frames(40)
	assert_almost_eq(player.global_position.y, 0.0, 0.15, "down on South Street")
	assert_lt(player.global_position.z, 58.0, "on the street side of the wall")


func test_metro_ramps_connect_street_and_concourse() -> void:
	await _spawn_player(Vector3(-20.0, 0.1, 9.0))
	await _walk(&"move_forward", 4.5)
	assert_almost_eq(player.global_position.y, DeadCityLayout.METRO_Y, 0.2, "walked down into the metro")
	assert_lt(player.global_position.z, -2.0)
	player.teleport(Vector3(-20.0, DeadCityLayout.METRO_Y + 0.1, -57.0), 0.0)
	await wait_physics_frames(20)
	await _walk(&"move_forward", 5.0)
	assert_almost_eq(player.global_position.y, 0.0, 0.2, "walked up into the plaza")
	assert_lt(player.global_position.z, -70.0)


func test_doorways_are_wide_enough() -> void:
	await _spawn_player(Vector3(-12.0, 0.1, 56.0))
	await _walk(&"move_back", 1.6)
	assert_gt(player.global_position.z, 59.0, "into the apartment")
	player.teleport(Vector3(0.0, 0.1, -81.0), 0.0)
	await wait_physics_frames(20)
	await _walk(&"move_forward", 2.0)
	assert_lt(player.global_position.z, -85.0, "into the tower base")
	player.teleport(Vector3(19.0, 0.1, -6.0), 0.0)
	await wait_physics_frames(20)
	await _walk(&"move_back", 2.0)
	assert_gt(player.global_position.z, -2.0, "into the pharmacy")


func test_overpass_rubble_blocks_central_avenue() -> void:
	await _spawn_player(Vector3(0.0, 0.1, -20.0))
	Input.action_press(&"sprint")
	Input.action_press(&"move_forward")
	for i: int in 8:
		await wait_physics_frames(30)
		Input.action_press(&"jump")
		await wait_physics_frames(4)
		Input.action_release(&"jump")
	Input.action_release(&"move_forward")
	Input.action_release(&"sprint")
	assert_gt(player.global_position.z, -47.0, "no way over the rubble")


func test_enemy_walks_round_a_wall_using_the_navmesh() -> void:
	for enemy: Enemy in city.get_enemies():
		enemy.set_physics_process(false)
	var hollow: Enemy = city.spawn_enemy("hollow", Vector3(-31.0, 0.05, 50.0))
	await wait_physics_frames(10)
	# A noise inside the store: the straight line is blocked by the shop front.
	var inside := Vector3(-30.0, 0.0, 37.0)
	EventBus.noise_emitted.emit(inside, 40.0, city)
	for i: int in 1100:
		if hollow.global_position.distance_to(inside) < 1.6:
			break
		await wait_physics_frames(1)
	assert_lt(hollow.global_position.distance_to(inside), 1.6, "went in through the door")


# --- Story flow ---------------------------------------------------------------------

func test_checkpoints_move_the_respawn_point() -> void:
	city.set_checkpoint("dc_test", Vector3(1.0, 0.1, 2.0), 0.5)
	assert_eq(city.spawn_position, Vector3(1.0, 0.1, 2.0))
	assert_eq(GameState.checkpoint_id, "dc_test")


func test_fuses_then_junction_then_wave_then_console() -> void:
	await _spawn_player(Vector3(0.0, 0.1, -90.0))
	watch_signals(EventBus)
	var panel: Usable = city.objects["panel"]
	panel.interact(player)
	assert_false(GameState.has_flag("dc_power_on"), "a dead panel does nothing without fuses")
	city.stage = DeadCity.Stage.RESTORE_POWER
	city._update_objective()
	var nearest: Vector3 = DeadCity.FUSE_SPOTS["fuse_metro"]
	if player.global_position.distance_to(DeadCity.FUSE_SPOTS["fuse_school"]) < player.global_position.distance_to(nearest):
		nearest = DeadCity.FUSE_SPOTS["fuse_school"]
	assert_eq(MissionManager.waypoint, nearest, "the marker shows the nearer fuse")
	(city.objects["fuse_metro"] as Usable).interact(player)
	assert_eq(city.fuses_found, 1)
	assert_eq(city.stage, DeadCity.Stage.RESTORE_POWER)
	assert_eq(MissionManager.waypoint, DeadCity.FUSE_SPOTS["fuse_school"], "then the one still missing")
	(city.objects["fuse_school"] as Usable).interact(player)
	assert_eq(city.stage, DeadCity.Stage.JUNCTION)
	assert_false((city.objects["fuse_school"] as Usable).can_interact(player), "a fuse can only be taken once")
	var before: int = city.get_enemies().size()
	city.restore_power()
	assert_eq(city.stage, DeadCity.Stage.DEFEND)
	assert_eq(city.get_enemies().size(), before + 6, "the noise brings a wave")
	assert_false((city.objects["console"] as Usable).can_interact(player))
	assert_eq(city.spawn_position, Vector3(0.0, 0.1, -86.5), "checkpoint at the tower")
	# Dying mid-fight brings the wave back.
	city.reset_encounters()
	await wait_physics_frames(4)
	assert_eq(city.get_enemies().size(), before + 6)
	for enemy: Enemy in city.get_enemies():
		if enemy.global_position.z < -60.0:
			enemy.finish_takedown()
	await wait_physics_frames(45)
	assert_eq(city.stage, DeadCity.Stage.TRANSMIT)
	assert_true((city.objects["console"] as Usable).can_interact(player))
	assert_signal_emitted(EventBus, "objective_changed")


func test_side_objectives_and_shortcuts() -> void:
	await _spawn_player(Vector3(0.0, 0.1, -90.0))
	# Pharmacy: the generator opens the shutter and wakes the street.
	assert_true(city.objects.has("shutter"))
	var before: int = city.get_enemies().size()
	(city.objects["generator"] as Usable).interact(player)
	assert_true(GameState.has_flag("dc_pharmacy_power"))
	assert_eq(city.get_enemies().size(), before + 2)
	await wait_physics_frames(2)
	assert_false(city.objects.has("shutter"), "shutter is gone")
	var health_before: float = player.health.max_health
	(city.objects["vital_core"] as Usable).interact(player)
	assert_almost_eq(player.health.max_health, health_before + 25.0, 0.01)
	# Journal trail: three pages unlock Mara's locker.
	var locker: Usable = city.objects["locker"]
	assert_false(locker.can_interact(player))
	for page: String in DeadCity.JOURNAL_IDS:
		(city.objects[page] as Usable).interact(player)
		get_tree().paused = false
	assert_eq(city.journal_pages_found(), 3)
	assert_true(locker.can_interact(player))
	locker.interact(player)
	assert_eq(GameState.salvage, 150)
	assert_eq(GameState.collected_documents.size(), 3)
	# Shortcuts. The shut gate is a wall to the navmesh; opening it rebuilds paths.
	var north := Vector3(40.0, 0.0, -44.0)
	var south := Vector3(40.0, 0.0, -32.0)
	assert_gt(_path_length(south, north), 30.0, "enemies cannot path through the shut gate")
	(city.objects["gate_lever"] as Usable).interact(player)
	assert_true(GameState.has_flag("dc_gate_open"))
	var rebuilt: bool = false
	for i: int in 300:
		await wait_physics_frames(1)
		if _path_length(south, north) < 16.0:
			rebuilt = true
			break
	assert_true(rebuilt, "after it opens the short way exists")
	var ladder: Ladder = city.objects["ladder_shortcut"]
	assert_false(ladder.can_interact(player), "folded up until kicked down")
	(city.objects["ladder_kick"] as Usable).interact(player)
	assert_true(ladder.can_interact(player))
	# Weapons are found, not given.
	assert_false(player.has_weapon("fire_axe"))
	(city.objects["axe"] as Usable).interact(player)
	assert_true(player.has_weapon("fire_axe"))
	assert_eq(player.weapon.id, "fire_axe")
	assert_eq(city.get_summary_rows().size(), 5)


func test_ending_cinematic_completes_the_act() -> void:
	await _spawn_player(Vector3(-5.0, 0.1, -96.0))
	watch_signals(EventBus)
	city.play_ending()
	await wait_physics_frames(5)
	assert_true(city.cinematic.is_playing)
	assert_false(player.input_enabled, "no control during the cinematic")
	city.cinematic.skip()
	await wait_physics_frames(5)
	assert_true(player.input_enabled)
	assert_true(GameState.has_flag("act1_complete"))
	assert_signal_emitted(EventBus, "act_completed")
	assert_eq(city.stage, DeadCity.Stage.DONE)


func test_set_dressing_fills_the_streets_without_blocking_them() -> void:
	assert_not_null(city.dressing)
	var atmosphere: Node = city.get_node_or_null("Atmosphere")
	assert_not_null(atmosphere, "steam, fires, lights and searchlights are built")
	assert_eq(atmosphere.find_children("*", "HologramScreen", true, false).size(), 3, "three glitching ads")
	assert_eq(atmosphere.find_children("*", "RainSplashes", true, false).size(), 1)
	var veins: Array[Node] = atmosphere.find_children("*", "GlowVeins", true, false)
	assert_eq(veins.size(), 1, "the Echo creeps across Tower Plaza")
	assert_gt((veins[0] as GlowVeins).multimesh.instance_count, 100)
	assert_gt(atmosphere.find_children("*", "Crows", true, false).size(), 8, "crows on roofs and in the street")
	assert_eq(atmosphere.find_children("*", "BlowingPaper", true, false).size(), 1)
	var fires: int = 0
	var steam: int = 0
	var strobes: int = 0
	var searchlights: int = 0
	for node: Node in atmosphere.find_children("*", "", true, false):
		if node is FireLight:
			fires += 1
		elif node is StrobeLight:
			strobes += 1
		elif node is Searchlight:
			searchlights += 1
		elif node is GPUParticles3D and node.get_parent() == atmosphere:
			steam += 1
	assert_eq(fires, 5)
	assert_eq(strobes, 2)
	assert_eq(searchlights, 2)
	assert_gt(steam, 6)
	# The places Kael has to reach are still reachable around the new props.
	var plaza := Vector3(-20.0, 0.0, -76.0)
	for place: Vector3 in [Vector3(0.0, 0.0, -86.0), Vector3(20.0, 0.0, -62.0), Vector3(32.0, 0.0, -61.5), Vector3(-28.5, 0.0, -62.4),
			Vector3(-29.0, 0.0, -98.0), Vector3(38.0, 0.0, -66.0)]:
		assert_lt(_path_end_distance(plaza, place), 1.0, "a path still reaches %s" % place)


func test_fuses_are_easy_to_spot() -> void:
	for key: String in ["fuse_metro", "fuse_school"]:
		var fuse: Usable = city.objects[key]
		assert_eq(fuse.find_children("*", "KeyItemBeacon", true, false).size(), 1, "%s has a column of light" % key)
	assert_gt((city.objects["fuse_school"] as Usable).global_position.y, 0.5, "the school fuse sits on a crate, not the floor")
	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as Player
	player.position = Vector3(-3.2, -4.9, -38.5)
	city.add_child(player)
	await wait_physics_frames(6)
	(city.objects["fuse_metro"] as Usable).interact(player)
	await wait_frames(2)
	assert_eq((city.objects["fuse_metro"] as Usable).find_children("*", "KeyItemBeacon", true, false).size(), 0, "the light goes once taken")


func test_help_when_stuck_and_the_hint_key() -> void:
	city.stage = DeadCity.Stage.RESTORE_POWER
	assert_eq(city.current_stage_key(), "restore_power")
	assert_eq(city.stuck_hints().size(), 2)
	watch_signals(EventBus)
	city.tick_stuck(1.0)
	for i: int in 45:
		city.tick_stuck(1.0)
	assert_signal_not_emitted(EventBus, "hint_requested", "no nagging before the first threshold")
	for i: int in 10:
		city.tick_stuck(1.0)
	assert_signal_emitted(EventBus, "hint_requested")
	var first: Array = get_signal_parameters(EventBus, "hint_requested")
	assert_string_contains(str(first[0]), "orange", "a gentle hint first")
	assert_string_contains(str(first[0]), "Press T", "and a reminder of the Hint key")
	for i: int in 70:
		city.tick_stuck(1.0)
	assert_string_contains(str(get_signal_parameters(EventBus, "hint_requested")[0]), "Learning Centre", "then step by step")
	city.stage = DeadCity.Stage.JUNCTION
	city.tick_stuck(1.0)
	assert_eq(city.stuck_seconds, 0.0, "a new objective starts the clock again")
	city.request_hint()
	assert_string_contains(str(get_signal_parameters(EventBus, "hint_requested")[0]), "breaker", "T gives the full hint at once")
	var event := InputEventKey.new()
	event.physical_keycode = KEY_T
	event.pressed = true
	assert_true(InputMap.event_is_action(event, &"hint"))


func test_every_objective_has_stuck_hints() -> void:
	for path: String in ["res://data/story/dead_city.json", "res://data/story/forest.json", "res://data/story/facility.json"]:
		var story: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		for key: String in story["objectives"]:
			if key == "done" and str(story["objectives"][key]).is_empty():
				continue
			assert_true((story["stuck"] as Dictionary).has(key), "%s: %s has hints" % [path.get_file(), key])
			assert_eq((story["stuck"].get(key, []) as Array).size(), 2)


func test_lucky_diner_is_open() -> void:
	var door := Vector3(44.0, 0.0, 26.0)
	for place: Array in [["the booths", Vector3(48.0, 0.0, 26.0)], ["behind the counter", Vector3(52.0, 0.0, 26.0)], ["the kitchen", Vector3(54.4, 0.0, 21.4)],
			["the jukebox corner", Vector3(54.8, 0.0, 30.8)]]:
		assert_lt(_path_length(door, place[1]), 40.0, "a path reaches %s" % place[0])
	assert_true(city.objects.has("salvage_8") and city.objects.has("salvage_9"), "salvage in the kitchen")
	var inside: bool = false
	for box: AABB in city.interiors:
		if box.has_point(Vector3(50.0, 1.0, 26.0)):
			inside = true
	assert_true(inside, "counts as indoors (no rain, indoor footsteps)")
