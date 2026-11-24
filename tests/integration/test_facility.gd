extends GutTest
## The Underground Facility: builds, all four levels connect, power and the two
## locks gate the route, security can be switched off, the Choir runs three
## phases, the ending rolls the credits, and progress survives a save.

const SCENE: String = "res://scenes/levels/facility/facility.tscn"
const PLAYER_SCENE: String = "res://scenes/player/player.tscn"

var facility: Facility
var player: Player


func before_each() -> void:
	SettingsManager.reset_to_defaults(false)
	CombatFX.hitstop_enabled = false
	CombatDirector.clear()
	GameState.reset()
	MissionManager.reset()
	Player.starting_weapons = PackedStringArray()
	facility = (load(SCENE) as PackedScene).instantiate() as Facility
	add_child_autofree(facility)
	for i: int in 240:
		await wait_physics_frames(1)
		if i > 2 and _path_length(Vector3(3.0, 0.0, 0.0), Vector3(20.0, 0.0, 0.0)) < 100.0:
			break
	for enemy: Enemy in facility.get_enemies():
		enemy.set_physics_process(false)


func after_each() -> void:
	get_tree().paused = false
	Player.starting_weapons = PackedStringArray()


func _spawn_player(at: Vector3) -> void:
	player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	player.position = at
	facility.add_child(player)
	await wait_physics_frames(12)


func _path_length(from: Vector3, to: Vector3) -> float:
	var path: PackedVector3Array = NavigationServer3D.map_get_path(facility.get_world_3d().navigation_map, from, to, true)
	if path.size() < 2:
		return INF
	var end: Vector3 = path[path.size() - 1]
	if Vector2(end.x - to.x, end.z - to.z).length() > 1.5 or absf(end.y - to.y) > 1.5:
		return INF
	var total: float = 0.0
	for i: int in range(1, path.size()):
		total += path[i - 1].distance_to(path[i])
	return total


func _hit(damage: float) -> HitInfo:
	var hit := HitInfo.new()
	hit.damage = damage
	return hit


func test_facility_builds_with_content() -> void:
	assert_eq(facility.documents.size(), 8)
	for document: Dictionary in facility.documents:
		assert_true(facility.objects.has(document["id"]), "%s is placed" % document["id"])
	assert_eq(Documents.total(), 24, "eight documents in each of the three areas")
	assert_gt(facility.get_enemies().size(), 12)
	assert_eq(facility.sentinels.size(), 5)
	assert_not_null(facility.choir)
	assert_false(facility.choir.is_active)
	assert_eq(GameState.current_area, "facility")
	assert_gt(facility.get_tour_stops().size(), 6)
	assert_true(facility.is_sheltered(Vector3.ZERO))


func test_four_levels_connect() -> void:
	var start := Vector3(3.0, 0.0, 0.0)
	for place: Array in [["security office", Vector3(32.0, 0.0, 11.0)], ["generator room", Vector3(33.0, 0.0, -10.5)],
			["quarters corridor", Vector3(72.0, -6.0, 0.0)], ["school room", Vector3(63.0, -6.0, 12.0)], ["bunks", Vector3(65.0, -6.0, -11.0)],
			["lab corridor", Vector3(110.0, -12.0, 0.0)], ["lab B by way of lab A", Vector3(131.0, -12.0, 11.0)],
			["Dr. Vance's office", Vector3(113.0, -12.0, -11.0)], ["lock door", Vector3(141.0, -12.0, 0.0)],
			["chamber platform", Vector3(170.0, -18.0, 0.0)], ["the heart", Vector3(176.0, -18.0, -11.0)]]:
		assert_lt(_path_length(start, place[1]), 400.0, "a path reaches the %s" % place[0])
	for key: String in ["stair_1", "stair_2", "office", "lock"]:
		assert_true(facility.objects.has(key), "door %s starts shut" % key)


func test_power_puzzle_opens_the_stairs() -> void:
	await _spawn_player(Vector3(33.0, 0.1, -10.0))
	var puzzle := Puzzles.LoadBalance.new(facility.tuning["generator_loads"], int(facility.tuning["generator_capacity"]))
	assert_false(puzzle.is_solved(), "everything starts on one generator")
	# 40+10, 30+20, 30+20.
	for entry: Array in [[1, 1], [3, 1], [2, 2], [4, 2]]:
		for i: int in entry[1]:
			puzzle.cycle(entry[0])
	assert_true(puzzle.is_solved())
	assert_eq(facility.stage, Facility.Stage.POWER)
	(facility.objects["generators"] as Usable).interact(player)
	await wait_physics_frames(3)
	assert_true(GameState.has_flag("uf_power"))
	assert_false(facility.objects.has("stair_1"), "the stairwell door opens")
	assert_eq(facility.stage, Facility.Stage.DESCEND)


func test_keycard_and_resonance_lock() -> void:
	await _spawn_player(Vector3(89.5, -5.9, 1.2))
	watch_signals(EventBus)
	(facility.objects["reader_stair_2"] as Usable).interact(player)
	assert_true(facility.objects.has("stair_2"), "no card, no door")
	assert_signal_emitted(EventBus, "toast_requested")
	(facility.objects["keycard"] as Usable).interact(player)
	assert_eq(facility.stage, Facility.Stage.LABS)
	(facility.objects["reader_stair_2"] as Usable).interact(player)
	assert_false(facility.objects.has("stair_2"))
	(facility.objects["reader_office"] as Usable).interact(player)
	assert_false(facility.objects.has("office"), "the same card opens Dr. Vance's office")
	var lock := Puzzles.ToneLock.new(facility.tuning["tone_sequence"])
	assert_false(lock.press(1), "a wrong tone clears the entry")
	assert_eq(lock.failures, 1)
	for tone: int in [2, 0, 3, 1]:
		lock.press(tone)
	assert_true(lock.is_solved())
	var wall: Dictionary = facility.get_document("uf_lyra_wall")
	assert_string_contains(str(wall.get("body", "")), lock.as_symbols(), "Lyra's wall shows the sequence")
	(facility.objects["lock_panel"] as Usable).interact(player)
	await wait_physics_frames(3)
	assert_true(GameState.has_flag("uf_lock_open"))
	assert_false(facility.objects.has("lock"))
	assert_eq(facility.stage, Facility.Stage.CHAMBER)


func test_security_panels_and_lasers() -> void:
	await _spawn_player(Vector3(112.0, -11.9, 0.0))
	var before: float = player.health.health
	player.teleport(Vector3(122.0, -11.9, 0.0), 0.0)
	await wait_physics_frames(30)
	assert_lt(player.health.health, before, "the laser grid burns")
	(facility.objects["security_labs"] as Usable).interact(player)
	assert_true(GameState.has_flag("uf_lasers_off"))
	await wait_physics_frames(30)
	var after: float = player.health.health
	await wait_physics_frames(40)
	assert_eq(player.health.health, after, "and stops once powered down")
	var upper: int = 0
	for sentinel: Sentinel in facility.sentinels:
		if str(sentinel.get_meta(&"group")) == "labs":
			assert_false(sentinel.enabled)
		else:
			assert_true(sentinel.enabled)
			upper += 1
	assert_eq(upper, 3)
	(facility.objects["security_upper"] as Usable).interact(player)
	for sentinel: Sentinel in facility.sentinels:
		assert_false(sentinel.enabled)


func test_sentinel_raises_the_alarm() -> void:
	await _spawn_player(Vector3(72.0, -5.9, -1.0))
	var sentinel: Sentinel = facility.sentinels[2]
	watch_signals(sentinel)
	sentinel.raise_alarm()
	assert_signal_emitted(sentinel, "alarm_raised")
	var alerted: int = 0
	for enemy: Enemy in facility.get_enemies():
		if enemy.global_position.distance_to(sentinel.global_position) < sentinel.alarm_radius and enemy.state != Enemy.AIState.PATROL:
			alerted += 1
	assert_gt(alerted, 0, "nearby enemies come looking")


func test_choir_three_phases_then_ending_and_credits() -> void:
	watch_signals(EventBus)
	GameState.set_flag("uf_choir_seen")
	await _spawn_player(Vector3(160.0, -17.9, 0.0))
	player.god_mode = true
	facility._on_chamber_entered(player)
	await wait_physics_frames(4)
	var choir: Choir = facility.choir
	assert_eq(facility.stage, Facility.Stage.CHOIR)
	assert_true(choir.is_active)
	assert_signal_emitted(EventBus, "boss_started")
	assert_eq(choir.on_target_hit(-1, _hit(50.0)), HitInfo.Result.ARMORED, "the heart is shut between attack sets")
	choir._set_heart(true)
	choir.on_target_hit(-1, _hit(choir.max_health * 0.4))
	assert_eq(choir.phase, 2)
	assert_false(choir.heart_exposed)
	assert_lt(choir.get_safe_radius(), choir.arena_radius, "the platform shrinks")
	await wait_physics_frames(3)
	var adds: int = 0
	for enemy: Enemy in facility.get_enemies():
		if enemy.global_position.x > 160.0:
			adds += 1
			enemy.set_physics_process(false)
	assert_eq(adds, 4, "it calls Hollows up onto the platform")
	for i: int in 3:
		assert_eq(choir.on_target_hit(i, _hit(10.0)), HitInfo.Result.HIT)
	assert_true(choir.heart_exposed, "three pillars open the heart")
	choir.on_target_hit(-1, _hit(choir.max_health * 0.3))
	assert_eq(choir.phase, 3)
	choir._set_heart(true)
	assert_false((facility.objects["anchor"] as Usable).can_interact(player))
	assert_eq(choir.on_target_hit(-1, _hit(choir.max_health)), HitInfo.Result.KILLED)
	await wait_physics_frames(3)
	assert_signal_emitted(EventBus, "boss_ended")
	assert_true(GameState.has_flag("uf_choir_dead"))
	assert_eq(facility.stage, Facility.Stage.SEVER)
	player.teleport(Vector3(176.0, -17.9, -11.0), PI)
	await wait_physics_frames(3)
	var anchor: Usable = facility.objects["anchor"]
	assert_true(anchor.can_interact(player), "the final blow is Kael's to make")
	anchor.interact(player)
	await wait_physics_frames(3)
	assert_true(facility.cinematic.is_playing, "the ending plays")
	facility.cinematic.skip()
	await wait_physics_frames(3)
	assert_true(GameState.has_flag("game_complete"))
	assert_signal_emitted(EventBus, "act_completed")
	assert_signal_emitted_with_parameters(EventBus, "credits_requested", [false])
	assert_false(facility.all_documents_found())
	for area: Dictionary in Documents.areas():
		for document: Dictionary in area.get("documents", []):
			if not GameState.collected_documents.has(document["id"]):
				GameState.collected_documents.append(document["id"])
	assert_true(facility.all_documents_found(), "all 24 unlock the epilogue")


func test_dying_to_the_choir_resets_the_fight() -> void:
	GameState.set_flag("uf_choir_seen")
	await _spawn_player(Vector3(160.0, -17.9, 0.0))
	facility._on_chamber_entered(player)
	await wait_physics_frames(4)
	facility.choir._set_heart(true)
	facility.choir.on_target_hit(-1, _hit(250.0))
	facility.reset_encounters()
	await wait_physics_frames(4)
	assert_eq(facility.stage, Facility.Stage.CHAMBER)
	assert_false(facility.choir.is_active)
	assert_almost_eq(facility.choir.get_ratio(), 1.0, 0.001)
	assert_eq(facility.choir.phase, 1)
	assert_eq(facility.spawn_position, Vector3(159.0, -17.9, 0.0), "Kael comes back at the chamber door")


func test_progress_survives_a_save() -> void:
	await _spawn_player(Vector3(33.0, 0.1, -10.0))
	facility.restore_power()
	(facility.objects["keycard"] as Usable).interact(player)
	(facility.objects["reader_stair_2"] as Usable).interact(player)
	(facility.objects["security_labs"] as Usable).interact(player)
	(facility.objects["blade"] as Usable).interact(player)
	(facility.objects["uf_ilse_office"] as Usable).interact(player)
	get_tree().paused = false
	assert_true(MissionManager.is_side_done("office"))
	facility.open_lock()
	player.write_state()
	facility.capture_state()
	var saved: Dictionary = GameState.to_dict()
	facility.free()
	GameState.reset()
	GameState.from_dict(saved)
	facility = (load(SCENE) as PackedScene).instantiate() as Facility
	add_child_autofree(facility)
	await _spawn_player(Vector3(141.0, -11.9, 0.0))
	facility.restore_state(player)
	assert_eq(facility.stage, Facility.Stage.CHAMBER)
	for key: String in ["stair_1", "stair_2", "lock"]:
		assert_false(facility.objects.has(key), "%s stays open" % key)
	assert_true(facility.objects.has("office"), "a door never opened stays shut")
	assert_false((facility.objects["keycard"] as Usable).can_interact(player))
	assert_false((facility.objects["blade"] as Usable).can_interact(player))
	assert_true(GameState.weapons.has("resonance_blade"))
	assert_false(facility.sentinels[3].enabled)
	assert_true(facility.sentinels[0].enabled)
	assert_eq(facility.spawn_position, Vector3(141.0, -11.9, 0.0))


func test_set_dressing_and_atmosphere() -> void:
	assert_not_null(facility.dressing)
	var atmosphere: Node = facility.get_node_or_null("Atmosphere")
	assert_not_null(atmosphere)
	assert_gt(atmosphere.find_children("*", "Blinker", true, false).size(), 10, "server lights blink")
	assert_gt(atmosphere.find_children("*", "SparkEmitter", true, false).size(), 1, "cables spark")
	assert_eq(atmosphere.find_children("*", "Spinner", true, false).size(), 3, "a beacon at every stairwell")
	var statics: int = 0
	for node: Node in atmosphere.find_children("*", "MeshInstance3D", true, false):
		var quad := (node as MeshInstance3D).mesh as QuadMesh
		if quad != null and quad.material is ShaderMaterial and (quad.material as ShaderMaterial).shader.resource_path.ends_with("static_screen.gdshader"):
			statics += 1
	assert_between(statics, 3, 14, "some dead monitors show static")
	assert_eq(atmosphere.find_children("*", "HologramScreen", true, false).size(), 2)
	assert_eq(atmosphere.find_children("*", "FogVolume", true, false).size(), 1, "mist in the Chamber")
	assert_gt(atmosphere.find_children("*", "Drip", true, false).size(), 3, "leaks in the corridors")


func test_cameras_face_their_rooms_and_their_cables_can_be_cut() -> void:
	# Every camera looks into open space, not at the wall behind it.
	for sentinel: Sentinel in facility.sentinels:
		# The centre of its sweep.
		var forward: Vector3 = Basis(Vector3.UP, sentinel._base_yaw) * Vector3.FORWARD
		var query := PhysicsRayQueryParameters3D.create(sentinel.global_position, sentinel.global_position + forward.normalized() * 4.0, Player.LAYER_WORLD)
		var hit: Dictionary = facility.get_world_3d().direct_space_state.intersect_ray(query)
		assert_true(hit.is_empty(), "camera at %s has room to look (hit %s)" % [sentinel.position, hit.get("position")])
	var box: Usable = facility.objects["cable_3"]
	await _spawn_player(box.global_position + Vector3(0.0, 0.1, 0.0))
	var sentinel: Sentinel = facility.sentinels[3]
	sentinel.suspicion = 0.9
	assert_false(facility.cut_cable(3), "not while it is watching")
	assert_true(sentinel.enabled)
	sentinel.suspicion = 0.0
	box.interact(player)
	assert_false(sentinel.enabled, "cut from underneath")
	assert_false(box.enabled)
	assert_true(facility.sentinels[4].enabled, "only that one camera")
	facility.capture_state()
	var saved: Dictionary = GameState.to_dict()
	facility.free()
	GameState.reset()
	GameState.from_dict(saved)
	facility = (load(SCENE) as PackedScene).instantiate() as Facility
	add_child_autofree(facility)
	await _spawn_player(Vector3(3.0, 0.1, 0.0))
	facility.restore_state(player)
	assert_false(facility.sentinels[3].enabled, "stays cut after a load")
	assert_true(facility.sentinels[4].enabled)
