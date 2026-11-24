extends GutTest
## Pure combat rules: health, attack slots, projectile arcs and data sanity.


func before_each() -> void:
	SettingsManager.reset_to_defaults(false)
	CombatDirector.clear()


func test_health_damage_heal_and_death() -> void:
	var health := HealthComponent.new()
	add_child_autofree(health)
	health.setup(80.0)
	watch_signals(health)
	assert_almost_eq(health.apply_damage(30.0), 30.0, 0.001)
	assert_almost_eq(health.health, 50.0, 0.001)
	health.heal(100.0)
	assert_almost_eq(health.health, 80.0, 0.001, "healing never exceeds the maximum")
	assert_almost_eq(health.apply_damage(500.0), 80.0, 0.001, "damage dealt is capped at remaining health")
	assert_true(health.is_dead())
	assert_signal_emit_count(health, "died", 1)
	assert_almost_eq(health.apply_damage(10.0), 0.0, 0.001, "the dead take no more damage")
	health.heal(10.0)
	assert_true(health.is_dead(), "healing does not resurrect")
	health.revive()
	assert_almost_eq(health.get_ratio(), 1.0, 0.001)


func test_only_two_enemies_may_attack_at_once() -> void:
	var enemies: Array[Node] = []
	for i: int in 4:
		var node := Node.new()
		add_child_autofree(node)
		enemies.append(node)
	assert_true(CombatDirector.request(enemies[0]))
	assert_true(CombatDirector.request(enemies[1]))
	assert_false(CombatDirector.request(enemies[2]), "third attacker must wait")
	assert_true(CombatDirector.request(enemies[0]), "asking again keeps the slot")
	CombatDirector.release(enemies[0])
	assert_true(CombatDirector.request(enemies[2]))
	assert_eq(CombatDirector.count(), 2)


func test_freed_attackers_give_up_their_slot() -> void:
	var first := Node.new()
	add_child(first)
	var second := Node.new()
	add_child_autofree(second)
	CombatDirector.request(first)
	first.free()
	assert_eq(CombatDirector.count(), 0)
	assert_true(CombatDirector.request(second))


func test_projectile_arc_lands_on_target() -> void:
	var start := Vector3(0.0, 1.5, 0.0)
	var target := Vector3(6.0, 0.2, -4.0)
	var gravity: float = 12.0
	var time: float = 0.9
	var velocity: Vector3 = Ballistic.solve_arc(start, target, time, gravity)
	var landed: Vector3 = start + velocity * time + Vector3.DOWN * 0.5 * gravity * time * time
	assert_almost_eq(landed.x, target.x, 0.001)
	assert_almost_eq(landed.y, target.y, 0.001)
	assert_almost_eq(landed.z, target.z, 0.001)


func test_parry_window_is_wider_on_story_difficulty() -> void:
	var combat: CombatTuning = load(Player.DEFAULT_COMBAT_PATH)
	assert_almost_eq(combat.get_parry_window(), combat.parry_window, 0.0001)
	SettingsManager.set_value("gameplay", "difficulty", "story", false)
	assert_gt(combat.get_parry_window(), combat.parry_window)
	assert_lt(combat.get_damage_taken_multiplier(), 1.0)
	SettingsManager.set_value("gameplay", "difficulty", "hard", false)
	assert_gt(combat.get_damage_taken_multiplier(), 1.0)


func test_weapons_load_and_are_distinct() -> void:
	var ids: Array[String] = []
	for path: String in Player.WEAPON_PATHS:
		var weapon: WeaponData = load(path)
		assert_not_null(weapon, path)
		assert_eq(weapon.light_clips.size(), 3, "three-hit combo")
		assert_gt(weapon.heavy_damage, weapon.light_damage)
		assert_gt(weapon.heavy_windup, weapon.light_windup)
		ids.append(weapon.id)
	assert_eq(ids, ["rebar_pipe", "fire_axe", "resonance_blade"])
	assert_gt((load(Player.WEAPON_PATHS[1]) as WeaponData).armor_multiplier, 1.0, "the axe breaks armour")
	assert_gt((load(Player.WEAPON_PATHS[2]) as WeaponData).echo_multiplier, 1.0, "the blade hurts Echo-infused enemies")


func test_enemy_types_load_with_their_roles() -> void:
	var kinds: Dictionary = {
		"hollow": EnemyData.AttackKind.MELEE, "skitter": EnemyData.AttackKind.DASH,
		"bulwark": EnemyData.AttackKind.SLAM, "spitter": EnemyData.AttackKind.RANGED}
	for type: String in kinds:
		var data: EnemyData = load(Level.ENEMY_DATA_DIR + type + ".tres")
		assert_not_null(data, type)
		assert_not_null(data.model, type + " has a model")
		assert_eq(data.attack_kind, kinds[type], type)
		var model: Node = data.model.instantiate()
		var animations: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
		for clip: StringName in [data.idle_clip, data.walk_clip, data.run_clip, data.attack_clip, data.hit_clip, data.stagger_clip, data.death_clip]:
			assert_true(animations.has_animation(clip), "%s is missing clip %s" % [type, clip])
		model.free()
	var skitter: EnemyData = load(Level.ENEMY_DATA_DIR + "skitter.tres")
	var hollow: EnemyData = load(Level.ENEMY_DATA_DIR + "hollow.tres")
	var bulwark: EnemyData = load(Level.ENEMY_DATA_DIR + "bulwark.tres")
	assert_gt(skitter.chase_speed, hollow.chase_speed * 1.5, "the Skitter is the fast one")
	assert_lt(skitter.max_health, hollow.max_health, "and fragile")
	assert_gt(bulwark.armor, 0.0)
	assert_false(bulwark.takedown_allowed, "armoured enemies cannot be taken down")


func test_hit_info_copies_are_independent() -> void:
	var hit := HitInfo.new()
	hit.damage = 12.0
	hit.breaks_guard = true
	var copy: HitInfo = hit.duplicate_hit()
	copy.damage = 99.0
	assert_almost_eq(hit.damage, 12.0, 0.001)
	assert_true(copy.breaks_guard)
	assert_true(HitInfo.landed(HitInfo.Result.KILLED))
	assert_false(HitInfo.landed(HitInfo.Result.PARRIED))
