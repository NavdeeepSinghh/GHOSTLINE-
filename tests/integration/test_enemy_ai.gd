extends PlayerTestBase
## Enemy senses, AI state transitions, the four enemy types and stealth takedowns.

const S := Enemy.AIState


func _zone(kind: StealthZone.Kind, at: Vector3, size: Vector3) -> void:
	var zone := StealthZone.new()
	zone.kind = kind
	zone.size = size
	zone.position = at
	world.add_child(zone)


func test_does_not_notice_player_behind_it() -> void:
	var enemy: Enemy = spawn_enemy("hollow", Vector3(0.0, 0.02, -6.0), 0.0)  # facing -Z, away from the player
	await spawn_player()
	await seconds(2.5)
	assert_eq(enemy.state, S.PATROL)
	assert_almost_eq(enemy.perception.detection, 0.0, 0.001)


func test_notices_player_in_view_and_enters_combat() -> void:
	var enemy: Enemy = spawn_enemy("hollow", Vector3(0.0, 0.02, -9.0), 180.0)  # facing the player
	await spawn_player()
	var states: Array = []
	enemy.state_changed.connect(func(_previous: int, current: int) -> void: states.append(current))
	assert_true(await until(func() -> bool: return enemy.state == S.COMBAT, 4.0), "spotted the player")
	assert_true(states.has(S.SUSPICIOUS), "grew suspicious before committing")
	assert_true(enemy.is_aware())


func test_detection_is_faster_up_close() -> void:
	var near: Enemy = spawn_enemy("hollow", Vector3(-3.0, 0.02, -4.0), 180.0, false)
	var far: Enemy = spawn_enemy("hollow", Vector3(3.0, 0.02, -15.0), 180.0, false)
	near.data.vision_fov_degrees = 160.0
	far.data.vision_fov_degrees = 160.0
	await spawn_player()
	await seconds(0.3)
	assert_gt(near.perception.detection, far.perception.detection)
	assert_gt(far.perception.detection, 0.0)


func test_wall_blocks_line_of_sight() -> void:
	add_block(0.0, -4.0, 6.0, 0.5, 3.0)
	var enemy: Enemy = spawn_enemy("hollow", Vector3(0.0, 0.02, -8.0), 180.0)
	await spawn_player()
	await seconds(2.0)
	assert_eq(enemy.state, S.PATROL)
	assert_false(enemy.perception.sees_target)


func test_shadow_shortens_sight() -> void:
	_zone(StealthZone.Kind.SHADOW, Vector3(0, 0, 0), Vector3(4, 3, 4))
	var enemy: Enemy = spawn_enemy("hollow", Vector3(0.0, 0.02, -12.0), 180.0)
	await spawn_player()
	await seconds(2.0)
	assert_true(player.is_in_shadow())
	assert_eq(enemy.state, S.PATROL, "12 m is beyond dark sight range")


func test_crouching_in_tall_grass_hides_the_player() -> void:
	_zone(StealthZone.Kind.HIDING, Vector3(0, 0, 0), Vector3(4, 2, 4))
	var enemy: Enemy = spawn_enemy("hollow", Vector3(0.0, 0.02, -5.0), 180.0)
	await spawn_player()
	await tap(&"crouch")
	await seconds(2.5)
	assert_true(player.is_hidden())
	assert_eq(enemy.state, S.PATROL, "looking straight at the grass, sees nothing")
	await tap(&"crouch")
	assert_true(await until(func() -> bool: return enemy.state != S.PATROL, 3.0), "standing up gives him away")


func test_noise_draws_an_enemy_to_investigate_then_it_returns() -> void:
	var enemy: Enemy = spawn_enemy("hollow", Vector3(0.0, 0.02, -20.0), 0.0)
	await spawn_player(Vector3(0.0, 0.02, 14.0))  # out of sight range of the noise spot
	var noise_at := Vector3(6.0, 0.0, -14.0)
	EventBus.noise_emitted.emit(noise_at, 15.0, world)
	await step(2)
	assert_eq(enemy.state, S.SUSPICIOUS)
	assert_true(await until(func() -> bool: return enemy.state == S.INVESTIGATE, 2.5))
	assert_true(await until(func() -> bool: return enemy.global_position.distance_to(noise_at) < 1.6, 8.0), "walked to the noise")
	assert_true(await until(func() -> bool: return enemy.state == S.PATROL, 5.0), "found nothing, gave up")
	assert_true(await until(func() -> bool: return enemy.global_position.distance_to(Vector3(0, 0, -20)) < 1.0, 10.0), "went back to its post")


func test_noise_out_of_earshot_is_ignored_and_rain_muffles() -> void:
	var enemy: Enemy = spawn_enemy("hollow", Vector3(0.0, 0.02, -20.0), 0.0)
	await spawn_player()
	EventBus.noise_emitted.emit(Vector3(0, 0, -8.0), 6.0, world)
	await step(2)
	assert_eq(enemy.state, S.PATROL, "12 m away from a 6 m noise")
	PerceptionComponent.hearing_scale = 0.7
	EventBus.noise_emitted.emit(Vector3(0, 0, -8.0), 15.0, world)
	await step(2)
	assert_eq(enemy.state, S.PATROL, "rain cuts a 15 m noise to 10.5 m")
	PerceptionComponent.hearing_scale = 1.0
	EventBus.noise_emitted.emit(Vector3(0, 0, -8.0), 15.0, world)
	await step(2)
	assert_eq(enemy.state, S.SUSPICIOUS)


func test_sprinting_footsteps_are_heard_but_crouching_is_not() -> void:
	var enemy: Enemy = spawn_enemy("hollow", Vector3(0.0, 0.02, -8.0), 0.0)
	await spawn_player()
	await tap(&"crouch")
	press(&"move_forward")
	await seconds(1.5)
	assert_eq(enemy.state, S.PATROL, "crept up unheard")
	await tap(&"crouch")
	player.teleport(Vector3(0.0, 0.05, 2.0))
	await step(10)
	press(&"sprint")
	assert_true(await until(func() -> bool: return enemy.state != S.PATROL, 2.0), "heard the sprint")


func test_patrol_walks_between_its_points() -> void:
	var enemy: Enemy = spawn_enemy("hollow", Vector3(20.0, 0.02, -20.0), 0.0)
	enemy.patrol_points = [Vector3(20.0, 0.0, -20.0), Vector3(20.0, 0.0, -26.0)]
	await spawn_player()
	assert_true(await until(func() -> bool: return enemy.global_position.z < -25.0, 12.0), "reached the second point")
	assert_true(await until(func() -> bool: return enemy.global_position.z > -21.0, 14.0), "and came back")
	assert_eq(enemy.state, S.PATROL)


func test_hollow_chases_and_hurts_the_player() -> void:
	var enemy: Enemy = spawn_enemy("hollow", Vector3(0.0, 0.02, -7.0), 180.0)
	await spawn_player()
	assert_true(await until(func() -> bool: return player.health.health < player.health.max_health, 9.0), "landed a hit")
	assert_almost_eq(player.health.max_health - player.health.health, enemy.data.attack_damage, 0.01)


func test_attack_has_a_windup_before_it_can_hit() -> void:
	var enemy: Enemy = spawn_enemy("hollow", Vector3(0.0, 0.02, -1.4), 180.0)
	await spawn_player()
	enemy.alert(player.global_position)
	enemy.attack_cooldown = 0.0
	assert_true(await until(func() -> bool: return enemy.state == S.ATTACK, 2.0))
	assert_eq(enemy.attack_phase, Enemy.AttackPhase.WINDUP)
	await seconds(enemy.data.attack_windup - 0.1)
	assert_almost_eq(player.health.health, player.health.max_health, 0.001, "no damage during the telegraph")
	await seconds(0.4)
	assert_lt(player.health.health, player.health.max_health)


func test_parrying_a_real_attack_staggers_the_enemy() -> void:
	var enemy: Enemy = spawn_enemy("hollow", Vector3(0.0, 0.02, -1.4), 180.0)
	await spawn_player()
	enemy.alert(player.global_position)
	enemy.attack_cooldown = 0.0
	assert_true(await until(func() -> bool: return enemy.state == S.ATTACK, 2.0))
	await seconds(enemy.data.attack_windup - 0.08)
	press(&"block")
	assert_true(await until(func() -> bool: return enemy.state == S.STAGGER, 0.6), "parried")
	assert_almost_eq(player.health.health, player.health.max_health, 0.001)


func test_loses_the_player_then_searches_then_gives_up() -> void:
	var enemy: Enemy = spawn_enemy("hollow", Vector3(0.0, 0.02, -8.0), 180.0)
	enemy.data.lose_target_time = 1.5
	await spawn_player()
	assert_true(await until(func() -> bool: return enemy.state == S.COMBAT, 4.0))
	player.teleport(Vector3(90.0, 0.05, 90.0))
	assert_true(await until(func() -> bool: return enemy.state == S.SEARCH, 4.0), "lost sight")
	assert_true(await until(func() -> bool: return enemy.state == S.PATROL, 40.0), "search ended")
	assert_almost_eq(enemy.perception.detection, 0.0, 0.05)


func test_spotting_the_player_alerts_nearby_allies() -> void:
	var spotter: Enemy = spawn_enemy("hollow", Vector3(0.0, 0.02, -8.0), 180.0)
	var ally: Enemy = spawn_enemy("hollow", Vector3(5.0, 0.02, -10.0), 0.0)  # looking away
	var distant: Enemy = spawn_enemy("hollow", Vector3(40.0, 0.02, -40.0), 0.0)
	await spawn_player()
	assert_true(await until(func() -> bool: return spotter.state == S.COMBAT, 4.0))
	await step(2)
	assert_true(ally.is_aware(), "ally within earshot joined in")
	assert_eq(distant.state, S.PATROL)


func test_at_most_two_enemies_attack_at_the_same_time() -> void:
	var enemies: Array[Enemy] = []
	for i: int in 4:
		enemies.append(spawn_enemy("hollow", Vector3(-3.0 + i * 2.0, 0.02, -4.0), 180.0))
	await spawn_player()
	player.health.setup(100000.0)
	var most: int = 0
	var attacks_seen: int = 0
	for frame: int in 60 * 9:
		await step(1)
		var attacking: int = 0
		for enemy: Enemy in enemies:
			if enemy.state == S.ATTACK:
				attacking += 1
		most = maxi(most, attacking)
		attacks_seen += attacking
	assert_gt(attacks_seen, 0, "they did attack")
	assert_lte(most, CombatDirector.MAX_ATTACKERS)


func test_hits_flinch_and_enough_poise_damage_staggers() -> void:
	var enemy: Enemy = spawn_enemy("hollow", Vector3(0.0, 0.02, -6.0), 180.0, false, 1000.0)
	await spawn_player()
	enemy.alert(player.global_position)
	assert_eq(enemy.receive_hit(make_hit(5.0, player.global_position, 10.0)), HitInfo.Result.HIT)
	assert_eq(enemy.state, S.HIT)
	await seconds(enemy.data.flinch_time + 0.1)
	assert_eq(enemy.state, S.COMBAT)
	enemy.receive_hit(make_hit(5.0, player.global_position, 40.0))
	assert_eq(enemy.state, S.STAGGER)


func test_killing_an_enemy() -> void:
	var enemy: Enemy = spawn_enemy("hollow", Vector3(0.0, 0.02, -6.0), 180.0)
	await spawn_player()
	watch_signals(EventBus)
	assert_eq(enemy.receive_hit(make_hit(999.0, player.global_position)), HitInfo.Result.KILLED)
	assert_true(enemy.is_dead())
	assert_false(enemy.is_in_group(&"enemies"))
	assert_signal_emitted(EventBus, "enemy_died")
	assert_eq(enemy.receive_hit(make_hit(10.0, player.global_position)), HitInfo.Result.IGNORED)


func test_bulwark_armour_shrugs_off_light_hits_until_broken() -> void:
	var bulwark: Enemy = spawn_enemy("bulwark", Vector3(0.0, 0.02, -6.0), 180.0, true)
	await spawn_player()
	bulwark.alert(player.global_position)
	var light: HitInfo = make_hit(20.0, player.global_position)
	assert_eq(bulwark.receive_hit(light), HitInfo.Result.ARMORED)
	assert_almost_eq(bulwark.data.max_health - bulwark.health.health, 20.0 * bulwark.data.armor_light_multiplier, 0.01)
	assert_ne(bulwark.state, S.HIT, "does not flinch")
	var heavy: HitInfo = make_hit(40.0, player.global_position, 45.0)
	heavy.is_heavy = true
	assert_eq(bulwark.receive_hit(heavy), HitInfo.Result.HIT)
	assert_true(bulwark.has_armor(), "one heavy hit is not enough")
	assert_eq(bulwark.receive_hit(heavy.duplicate_hit()), HitInfo.Result.HIT)
	assert_false(bulwark.has_armor(), "armour broken")
	assert_eq(bulwark.state, S.STAGGER)
	var before: float = bulwark.health.health
	assert_eq(bulwark.receive_hit(make_hit(20.0, player.global_position)), HitInfo.Result.HIT)
	assert_almost_eq(before - bulwark.health.health, 20.0, 0.01, "light hits now do full damage")


func test_axe_breaks_armour_faster_than_the_pipe() -> void:
	var bulwark: Enemy = spawn_enemy("bulwark", Vector3(0.0, 0.02, -6.0), 180.0, true)
	await spawn_player()
	bulwark.alert(player.global_position)
	var axe: WeaponData = load(Player.WEAPON_PATHS[1])
	var hit: HitInfo = make_hit(axe.light_damage, player.global_position)
	hit.armor_multiplier = axe.armor_multiplier
	bulwark.receive_hit(hit)
	assert_almost_eq(bulwark.data.armor - bulwark.armor_points, axe.light_damage * axe.armor_multiplier, 0.01,
			"even light axe swings chew through plating")


func test_bulwark_slam_hits_nearby_but_not_a_jumping_player() -> void:
	var bulwark: Enemy = spawn_enemy("bulwark", Vector3(0.0, 0.02, -2.5), 180.0, true)
	await spawn_player()
	bulwark.target = player
	bulwark._slam()
	assert_almost_eq(player.health.max_health - player.health.health, bulwark.data.attack_damage, 0.01)
	player.revive()
	player.teleport(Vector3(0.0, 1.0, 0.0))
	bulwark._slam()
	assert_almost_eq(player.health.health, player.health.max_health, 0.001, "jumped over the shockwave")
	player.teleport(Vector3(0.0, 0.05, 6.0))
	await step(20)
	bulwark._slam()
	assert_almost_eq(player.health.health, player.health.max_health, 0.001, "out of range")


func test_spitter_keeps_its_distance_and_shoots() -> void:
	var spitter: Enemy = spawn_enemy("spitter", Vector3(0.0, 0.02, -3.0), 180.0)
	await spawn_player()
	spitter.alert(player.global_position)
	var fired: Array = [false]
	var check := func() -> bool:
		for node: Node in get_tree().get_nodes_in_group(&"transient"):
			if node is EchoGlob:
				fired[0] = true
		return fired[0]
	assert_true(await until(check, 6.0), "fired a glob")
	await seconds(2.0)
	assert_gt(spitter.global_position.distance_to(player.global_position), 4.0, "backed away from melee range")


func test_spitter_glob_hurts_and_leaves_a_puddle() -> void:
	await spawn_player()
	var glob := EchoGlob.new()
	world.add_child(glob)
	var start := Vector3(0.0, 1.6, -8.0)
	glob.launch(world, start, Ballistic.solve_arc(start, Vector3(0.0, 1.0, 0.0), 0.8, glob.gravity))
	var damage: float = glob.damage
	await seconds(1.0)
	assert_almost_eq(player.health.max_health - player.health.health, damage, 0.01, "direct hit")
	var puddles: int = 0
	for node: Node in get_tree().get_nodes_in_group(&"transient"):
		if node is HazardPuddle:
			puddles += 1
	assert_eq(puddles, 1)
	await seconds(1.6)
	assert_lt(player.health.health, player.health.max_health - damage - 4.0, "standing in the puddle keeps hurting")


func test_skitter_dash_closes_distance_fast() -> void:
	var skitter: Enemy = spawn_enemy("skitter", Vector3(0.0, 0.02, -10.0), 180.0)
	await spawn_player()
	skitter.alert(player.global_position)
	assert_true(await until(func() -> bool: return player.health.health < player.health.max_health, 6.0), "dashed in and hit")
	assert_true(skitter.data.chase_speed > 5.0)


func test_takedown_from_behind_an_unaware_enemy() -> void:
	await spawn_player()
	await tap(&"crouch")
	# Placed after Kael has settled: the thud of landing would have turned its head.
	var enemy: Enemy = spawn_enemy("hollow", Vector3(0.0, 0.02, -1.5), 0.0)  # back turned
	watch_signals(EventBus)
	await step(3)
	assert_eq(player.takedown_target, enemy)
	await tap(&"interact")
	assert_eq(state(), &"Takedown")
	assert_eq(enemy.state, S.TAKEDOWN)
	assert_true(await until_state(&"Ground", 2.0))
	assert_true(enemy.is_dead())
	assert_null(player.takedown_target)


func test_no_takedown_from_the_front_or_on_alert_or_armoured_enemies() -> void:
	var facing: Enemy = spawn_enemy("hollow", Vector3(0.0, 0.02, -1.5), 180.0, true)
	await spawn_player()
	await step(3)
	assert_false(facing.can_be_taken_down(player), "it is looking at him")
	facing.facing_yaw = 0.0
	assert_true(facing.can_be_taken_down(player))
	facing.alert(player.global_position)
	assert_false(facing.can_be_taken_down(player), "alerted")
	var bulwark: Enemy = spawn_enemy("bulwark", Vector3(4.0, 0.02, 1.5), 180.0, true)
	assert_false(bulwark.can_be_taken_down(player), "armoured")


func test_bottle_hit_stuns_and_opens_a_takedown() -> void:
	var enemy: Enemy = spawn_enemy("hollow", Vector3(0.0, 0.02, -4.0), 180.0, false, 100.0)
	await spawn_player()
	enemy.alert(player.global_position)
	var bottle := Throwable.new()
	world.add_child(bottle)
	bottle.launch(player, Vector3(0.0, 1.2, -1.0), Vector3(0.0, 1.0, -14.0))
	assert_true(await until(func() -> bool: return enemy.state == S.STUNNED, 1.0))
	assert_true(enemy.can_be_taken_down(player), "stunned enemies can be finished from any side")


func test_level_reset_restores_enemies() -> void:
	var level := Level.new()
	world.add_child(level)
	level.add_enemy_spawn("hollow", Vector3(10.0, 0.02, -10.0))
	level.add_enemy_spawn("skitter", Vector3(14.0, 0.02, -10.0))
	level.spawn_enemies()
	await spawn_player()
	assert_eq(level.get_enemies().size(), 2)
	level.get_enemies()[0].receive_hit(make_hit(999.0, Vector3.ZERO))
	level.reset_encounters()
	await step(3)
	var alive: int = 0
	for enemy: Enemy in level.get_enemies():
		if not enemy.is_dead():
			alive += 1
	assert_eq(alive, 2)
