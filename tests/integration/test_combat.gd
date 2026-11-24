extends PlayerTestBase
## Kael's combat: attacks, combo, heavy charge, dodge, block, parry, damage,
## healing, weapon switching and death.

const BAG_Z: float = -1.35  # a punching-bag enemy just in front of the spawn


func _bag(max_health: float = 1000.0) -> Enemy:
	# Faces away from the player, so the first hit is an unaware (x1.5) hit.
	return spawn_enemy("hollow", Vector3(0.0, 0.02, BAG_Z), 0.0, true, max_health)


func _lost(enemy: Enemy) -> float:
	return enemy.health.max_health - enemy.health.health


func test_light_attack_hits_enemy_in_front() -> void:
	var bag: Enemy = _bag()
	await spawn_player()
	var stamina_before: float = player.stamina
	await tap(&"light_attack")
	assert_eq(state(), &"Attack")
	await seconds(0.6)
	assert_almost_eq(_lost(bag), player.weapon.light_damage * 1.5, 0.01, "one unaware hit")
	assert_almost_eq(stamina_before - player.stamina, player.weapon.light_stamina, 0.01)
	assert_eq(state(), &"Ground")


func test_light_attack_misses_enemy_behind() -> void:
	var bag: Enemy = spawn_enemy("hollow", Vector3(0.0, 0.02, 2.0), 0.0, true, 1000.0)
	await spawn_player()
	await tap(&"light_attack")
	await seconds(0.6)
	assert_almost_eq(_lost(bag), 0.0, 0.001)


func test_each_swing_hits_a_target_only_once() -> void:
	var bag: Enemy = _bag()
	await spawn_player()
	player.hitbox.begin(make_hit(10.0, Vector3.ZERO), 1.2, 1.0, Player.LAYER_ENEMY)
	await step(6)
	player.hitbox.end()
	assert_almost_eq(_lost(bag), 15.0, 0.01, "six active frames, one hit")


func test_three_hit_combo_chains_and_finisher_hits_harder() -> void:
	var bag: Enemy = _bag()
	await spawn_player()
	var weapon: WeaponData = player.weapon
	var highest_combo: int = 0
	# Press again while each swing is live; the buffered press chains into the next one.
	await tap(&"light_attack")
	var presses: int = 0
	for i: int in 90:
		await step(1)
		if state() != &"Attack":
			continue
		var attack: Node = player.state_machine.current
		var combo: int = int(attack.get("combo_index"))
		highest_combo = maxi(highest_combo, combo)
		if presses < 2 and combo == presses and int(attack.get("phase")) >= 2:
			presses += 1
			await tap(&"light_attack")
	await seconds(0.6)
	assert_eq(highest_combo, 2, "reached the third swing")
	var expected: float = weapon.light_damage * 1.5 + weapon.light_damage + weapon.light_damage * weapon.combo_finisher_multiplier
	assert_almost_eq(_lost(bag), expected, 0.01)
	assert_eq(state(), &"Ground")


func test_heavy_attack_lands_after_its_windup() -> void:
	var bag: Enemy = _bag()
	await spawn_player()
	await tap(&"heavy_attack")
	await seconds(player.weapon.heavy_windup - 0.15)
	assert_almost_eq(_lost(bag), 0.0, 0.001, "still winding up")
	await seconds(0.5)
	assert_almost_eq(_lost(bag), player.weapon.heavy_damage * 1.5, 0.01)


func test_held_heavy_attack_charges_for_more_damage() -> void:
	var bag: Enemy = _bag()
	await spawn_player()
	press(&"heavy_attack")
	await seconds(player.weapon.heavy_windup + player.combat.heavy_charge_time + 0.6)
	release(&"heavy_attack")
	var expected: float = player.weapon.heavy_damage * (1.0 + player.combat.heavy_charge_bonus) * 1.5
	assert_almost_eq(_lost(bag), expected, 0.01, "full charge releases on its own")


func test_cannot_attack_without_stamina() -> void:
	_bag()
	await spawn_player()
	player.stamina = 0.0
	await tap(&"light_attack")
	await step(2)
	assert_eq(state(), &"Ground")


func test_dodge_covers_its_distance_and_costs_stamina() -> void:
	await spawn_player()
	press(&"move_forward")
	await seconds(0.1)
	var start: Vector3 = player.global_position
	var stamina_before: float = player.stamina
	await tap(&"dodge")
	assert_eq(state(), &"Dodge")
	release(&"move_forward")
	assert_true(await until_state(&"Ground", 1.0))
	assert_almost_eq(start.z - player.global_position.z, player.combat.dodge_distance, 0.5)
	assert_almost_eq(stamina_before - player.stamina, player.combat.dodge_stamina, 0.01)


func test_dodge_is_invulnerable_only_during_its_window() -> void:
	await spawn_player()
	await tap(&"dodge")
	await seconds(0.08)
	assert_eq(player.receive_hit(make_hit(30.0, Vector3(0, 0, -1))), HitInfo.Result.IGNORED, "inside the i-frames")
	assert_almost_eq(player.health.health, player.health.max_health, 0.001)
	await seconds(player.combat.dodge_iframe_duration + 0.1)
	assert_eq(state(), &"Dodge", "still recovering")
	assert_eq(player.receive_hit(make_hit(30.0, Vector3(0, 0, -1))), HitInfo.Result.HIT, "after the i-frames")


func test_backstep_when_no_direction_is_held() -> void:
	await spawn_player()
	await tap(&"dodge")
	assert_true(await until_state(&"Ground", 1.0))
	assert_gt(player.global_position.z, 2.0, "moved backwards (+Z) while still facing -Z")
	assert_lt(player.get_facing_direction().z, -0.9)


func test_block_reduces_damage_and_drains_stamina() -> void:
	await spawn_player()
	press(&"block")
	await seconds(0.5)
	assert_eq(state(), &"Block")
	var stamina_before: float = player.stamina
	assert_eq(player.receive_hit(make_hit(20.0, Vector3(0, 0, -2))), HitInfo.Result.BLOCKED)
	assert_almost_eq(player.health.max_health - player.health.health, 20.0 * player.combat.block_damage_multiplier, 0.01)
	assert_almost_eq(stamina_before - player.stamina, 20.0 * player.combat.block_stamina_per_damage, 0.01)
	assert_eq(state(), &"Block", "guard holds")


func test_block_does_not_stop_hits_from_behind() -> void:
	await spawn_player()
	press(&"block")
	await seconds(0.5)
	assert_eq(player.receive_hit(make_hit(20.0, Vector3(0, 0, 2))), HitInfo.Result.HIT)
	assert_almost_eq(player.health.max_health - player.health.health, 20.0, 0.01)


func test_guard_breaks_when_stamina_runs_out() -> void:
	await spawn_player()
	press(&"block")
	await seconds(0.5)
	player.stamina = 5.0
	assert_eq(player.receive_hit(make_hit(20.0, Vector3(0, 0, -2))), HitInfo.Result.BLOCKED)
	await step(1)
	assert_eq(state(), &"Hurt", "staggered by the guard break")


func test_parry_just_after_raising_guard() -> void:
	var attacker: Enemy = spawn_enemy("hollow", Vector3(0.0, 0.02, -1.5), 180.0, true)
	await spawn_player()
	press(&"block")
	await step(4)
	var hit: HitInfo = make_hit(25.0, attacker.global_position)
	hit.attacker = attacker
	assert_eq(player.receive_hit(hit), HitInfo.Result.PARRIED)
	assert_almost_eq(player.health.health, player.health.max_health, 0.001, "a parry takes no damage")
	assert_eq(attacker.state, Enemy.AIState.STAGGER, "the attacker is staggered")


func test_late_block_is_not_a_parry_but_is_on_story_difficulty() -> void:
	await spawn_player()
	press(&"block")
	await seconds(0.22)
	assert_eq(player.receive_hit(make_hit(10.0, Vector3(0, 0, -2))), HitInfo.Result.BLOCKED, "outside the 0.15 s window")
	release(&"block")
	await seconds(1.0)
	SettingsManager.set_value("gameplay", "difficulty", "story", false)
	press(&"block")
	await seconds(0.22)
	assert_eq(player.receive_hit(make_hit(10.0, Vector3(0, 0, -2))), HitInfo.Result.PARRIED, "story mode widens the window")


func test_mashing_block_cannot_parry() -> void:
	await spawn_player()
	await tap(&"block")
	await step(3)
	press(&"block")
	await step(4)
	assert_eq(player.receive_hit(make_hit(10.0, Vector3(0, 0, -2))), HitInfo.Result.BLOCKED, "guard was re-raised too soon")


func test_unparryable_hit_is_only_blocked() -> void:
	await spawn_player()
	press(&"block")
	await step(4)
	var hit: HitInfo = make_hit(10.0, Vector3(0, 0, -2))
	hit.can_be_parried = false
	assert_eq(player.receive_hit(hit), HitInfo.Result.BLOCKED)


func test_taking_a_hit_flinches_then_recovers() -> void:
	await spawn_player()
	assert_eq(player.receive_hit(make_hit(20.0, Vector3(0, 0, -2))), HitInfo.Result.HIT)
	await step(1)
	assert_eq(state(), &"Hurt")
	assert_gt(player.velocity.z, 0.5, "knocked away from the attacker")
	assert_eq(player.receive_hit(make_hit(20.0, Vector3(0, 0, -2))), HitInfo.Result.IGNORED, "brief mercy window")
	assert_true(await until_state(&"Ground", 1.5))
	assert_almost_eq(player.health.health, 80.0, 0.01)


func test_difficulty_scales_damage_taken() -> void:
	await spawn_player()
	SettingsManager.set_value("gameplay", "difficulty", "story", false)
	player.receive_hit(make_hit(20.0, Vector3(0, 0, -2)))
	assert_almost_eq(player.health.health, 100.0 - 20.0 * player.combat.damage_taken_story, 0.01)


func test_death_and_revive() -> void:
	await spawn_player()
	watch_signals(EventBus)
	assert_eq(player.receive_hit(make_hit(500.0, Vector3(0, 0, -2))), HitInfo.Result.KILLED)
	await step(2)
	assert_eq(state(), &"Dead")
	assert_signal_emit_count(EventBus, "player_died", 1)
	press(&"move_forward")
	await tap(&"light_attack")
	await seconds(0.4)
	assert_eq(state(), &"Dead", "the dead do not act")
	assert_almost_eq(player.global_position.z, 0.0, 0.05)
	release_all()
	player.revive()
	player.teleport(Vector3(3.0, 0.5, 3.0))
	assert_true(await until_state(&"Ground", 2.0))
	assert_almost_eq(player.health.health, player.health.max_health, 0.001)
	assert_eq(player.injectors, player.combat.max_injectors)


func test_injector_heals_after_a_moment() -> void:
	await spawn_player()
	player.health.apply_damage(60.0)
	await tap(&"heal")
	assert_eq(player.injectors, player.combat.max_injectors - 1)
	assert_almost_eq(player.health.health, 40.0, 0.01, "not instant")
	await seconds(player.combat.injector_time + 0.1)
	assert_almost_eq(player.health.health, 40.0 + player.combat.injector_heal, 0.01)


func test_injector_is_not_wasted_at_full_health() -> void:
	await spawn_player()
	await tap(&"heal")
	assert_eq(player.injectors, player.combat.max_injectors)


func test_being_hit_interrupts_healing() -> void:
	await spawn_player()
	player.health.apply_damage(60.0)
	await tap(&"heal")
	await seconds(0.2)
	player.receive_hit(make_hit(10.0, Vector3(0, 0, -2)))
	await seconds(1.2)
	assert_almost_eq(player.health.health, 30.0, 0.01, "the injector was lost")


func test_weapon_switching() -> void:
	await spawn_player()
	watch_signals(EventBus)
	assert_eq(player.weapon.id, "rebar_pipe")
	await tap(&"weapon_2")
	assert_eq(player.weapon.id, "fire_axe")
	await tap(&"weapon_next")
	assert_eq(player.weapon.id, "resonance_blade")
	await tap(&"weapon_next")
	assert_eq(player.weapon.id, "rebar_pipe", "wraps around")
	assert_signal_emitted(EventBus, "weapon_changed")


func test_thrown_bottle_makes_noise_where_it_lands() -> void:
	await spawn_player()
	watch_signals(EventBus)
	var before: int = player.throwables
	await tap(&"throw")
	assert_eq(player.throwables, before - 1)
	await seconds(2.0)
	assert_signal_emitted(EventBus, "noise_emitted")
	var noises: Array = []
	for i: int in get_signal_emit_count(EventBus, "noise_emitted"):
		noises.append(get_signal_parameters(EventBus, "noise_emitted", i))
	var loudest: Array = noises[0]
	for noise: Array in noises:
		if float(noise[1]) > float(loudest[1]):
			loudest = noise
	assert_almost_eq(float(loudest[1]), player.combat.throw_noise_radius, 0.01)
	assert_lt((loudest[0] as Vector3).z, -5.0, "it flew forward before breaking")
