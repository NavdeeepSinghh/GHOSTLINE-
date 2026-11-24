extends PlayerTestBase
## Ground movement: speeds, sprint and stamina, crouch, stair stepping, slopes.


func test_spawns_on_the_ground() -> void:
	await spawn_player()
	assert_eq(state(), &"Ground")
	assert_true(player.is_on_floor())
	assert_almost_eq(player.global_position.y, 0.0, 0.03)


func test_jog_reaches_target_speed_and_moves_forward() -> void:
	await spawn_player()
	press(&"move_forward")
	await seconds(1.0)
	assert_almost_eq(player.get_horizontal_speed(), tuning.jog_speed, 0.05)
	assert_lt(player.global_position.z, -3.0, "forward is -Z when the camera yaw is 0")
	assert_almost_eq(player.global_position.x, 0.0, 0.05)
	assert_eq(player.move_mode, Player.MoveMode.JOG)


func test_walk_speed() -> void:
	await spawn_player()
	press(&"move_forward")
	press(&"walk")
	await seconds(1.0)
	assert_almost_eq(player.get_horizontal_speed(), tuning.walk_speed, 0.05)
	assert_eq(player.move_mode, Player.MoveMode.WALK)


func test_sprint_speed_and_stamina_drain() -> void:
	await spawn_player()
	press(&"move_forward")
	press(&"sprint")
	await seconds(1.5)
	assert_almost_eq(player.get_horizontal_speed(), tuning.sprint_speed, 0.05)
	assert_true(player.is_sprinting)
	var expected: float = tuning.max_stamina - tuning.sprint_stamina_per_second * 1.5
	assert_almost_eq(player.stamina, expected, 2.0)


func test_stamina_regenerates_after_delay() -> void:
	await spawn_player()
	press(&"move_forward")
	press(&"sprint")
	await seconds(1.0)
	release(&"sprint")
	var after_sprint: float = player.stamina
	await seconds(tuning.stamina_regen_delay * 0.5)
	assert_almost_eq(player.stamina, after_sprint, 0.01, "no regeneration during the delay")
	await seconds(tuning.stamina_regen_delay * 0.5 + 0.5)
	assert_gt(player.stamina, after_sprint + 5.0)


func test_sprint_stops_when_stamina_runs_out() -> void:
	await spawn_player()
	player.stamina = 4.0
	press(&"move_forward")
	await seconds(0.2)
	player.is_sprinting = true
	press(&"sprint")
	await seconds(1.0)
	assert_false(player.is_sprinting, "exhausted")
	assert_almost_eq(player.get_horizontal_speed(), tuning.jog_speed, 0.1)


func test_stops_quickly_when_input_released() -> void:
	await spawn_player()
	press(&"move_forward")
	await seconds(0.8)
	release(&"move_forward")
	await seconds(0.3)
	assert_almost_eq(player.get_horizontal_speed(), 0.0, 0.01)
	assert_eq(player.move_mode, Player.MoveMode.IDLE)


func test_body_turns_to_face_movement() -> void:
	await spawn_player()
	press(&"move_right")
	await seconds(0.6)
	assert_gt(player.get_facing_direction().x, 0.98)
	assert_gt(player.velocity.x, 4.0)


func test_crouch_shrinks_collider_and_slows_movement() -> void:
	await spawn_player()
	await tap(&"crouch")
	assert_true(player.is_crouching)
	assert_almost_eq(player.get_current_height(), tuning.crouch_height, 0.001)
	press(&"move_forward")
	await seconds(1.0)
	assert_almost_eq(player.get_horizontal_speed(), tuning.crouch_speed, 0.05)
	assert_eq(player.move_mode, Player.MoveMode.CROUCH)
	release(&"move_forward")
	await tap(&"crouch")
	assert_false(player.is_crouching)
	assert_almost_eq(player.get_current_height(), tuning.stand_height, 0.001)


func test_cannot_stand_up_under_low_ceiling() -> void:
	var clearance: float = (load(Player.DEFAULT_TUNING_PATH) as PlayerTuning).crouch_height + 0.15
	add_box(Vector3(0.0, clearance + 0.25, -4.0), Vector3(3.0, 0.5, 6.0))
	await spawn_player()
	await tap(&"crouch")
	press(&"move_forward")
	await seconds(1.6)
	release(&"move_forward")
	await seconds(0.3)
	assert_lt(player.global_position.z, -1.5, "walked under the ceiling")
	await tap(&"crouch")
	assert_true(player.is_crouching, "ceiling blocks standing up")
	assert_false(player.can_stand_up())


func test_standing_player_is_blocked_by_low_ceiling() -> void:
	add_box(Vector3(0.0, 1.55 + 0.25, -4.0), Vector3(3.0, 0.5, 6.0))
	await spawn_player()
	press(&"move_forward")
	await seconds(1.5)
	assert_gt(player.global_position.z, -1.4, "standing height does not fit")


func test_steps_up_a_curb() -> void:
	add_block(0.0, -3.0, 4.0, 2.0, 0.25)
	await spawn_player()
	press(&"move_forward")
	await seconds(0.9)
	assert_almost_eq(player.global_position.y, 0.25, 0.03, "on top of the curb")
	assert_eq(state(), &"Ground", "stepping never leaves the ground state")


func test_does_not_step_up_a_tall_block() -> void:
	add_block(0.0, -3.0, 4.0, 2.0, 0.6)
	await spawn_player()
	press(&"move_forward")
	await seconds(1.2)
	assert_almost_eq(player.global_position.y, 0.0, 0.03)
	assert_gt(player.global_position.z, -2.0 - tuning.body_radius - 0.05, "stopped at the block")


func test_climbs_a_staircase() -> void:
	for i: int in 8:
		add_block(0.0, -2.0 - i * 0.32, 3.0, 0.32, 0.18 * (i + 1))
	add_block(0.0, -2.0 - 8 * 0.32 - 1.84, 3.0, 4.0, 0.18 * 8)
	await spawn_player()
	press(&"move_forward")
	await seconds(1.0)
	assert_almost_eq(player.global_position.y, 0.18 * 8, 0.04, "reached the landing")
	assert_eq(state(), &"Ground")


func test_walks_up_a_gentle_slope_but_not_a_steep_one() -> void:
	var gentle: StaticBody3D = add_box(Vector3(0.0, 0.0, -5.0), Vector3(3.0, 0.4, 8.0))
	gentle.rotation.x = deg_to_rad(25.0)
	var steep: StaticBody3D = add_box(Vector3(20.0, 0.0, -4.0), Vector3(3.0, 0.4, 10.0))
	steep.rotation.x = deg_to_rad(58.0)
	await spawn_player()
	press(&"move_forward")
	for i: int in 60:
		await step(1)
	assert_gt(player.global_position.y, 0.8, "climbed the 25 degree slope")
	release_all()
	player.teleport(Vector3(20.0, 0.05, 0.0))
	await step(20)
	press(&"move_forward")
	await seconds(1.5)
	assert_lt(player.global_position.y, 1.0, "58 degrees is too steep to walk up")


func test_movement_emits_noise_by_mode() -> void:
	await spawn_player()
	watch_signals(EventBus)
	press(&"move_forward")
	await seconds(0.6)
	assert_almost_eq(player.noise_radius, tuning.noise_jog, 0.01)
	assert_signal_emitted(EventBus, "noise_emitted")
	await tap(&"crouch")
	await seconds(0.6)
	assert_almost_eq(player.noise_radius, tuning.noise_crouch, 0.01)
	press(&"sprint")
	await tap(&"crouch")
	await seconds(0.6)
	assert_almost_eq(player.noise_radius, tuning.noise_sprint, 0.01)


func test_input_can_be_disabled() -> void:
	await spawn_player()
	player.input_enabled = false
	press(&"move_forward")
	await seconds(0.5)
	assert_almost_eq(player.get_horizontal_speed(), 0.0, 0.01)
	assert_almost_eq(player.global_position.z, 0.0, 0.01)
