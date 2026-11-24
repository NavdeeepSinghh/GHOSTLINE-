extends PlayerTestBase
## Jumping and falling: apex height, coyote time, jump buffering, landing.


func test_jump_reaches_tuned_apex_height() -> void:
	await spawn_player()
	var ground_y: float = player.global_position.y
	await tap(&"jump")
	var apex: float = 0.0
	for i: int in 60:
		await step(1)
		apex = maxf(apex, player.global_position.y - ground_y)
	assert_almost_eq(apex, tuning.jump_apex_height, 0.03)
	assert_eq(state(), &"Ground", "landed again")


func test_jump_enters_air_state_and_lands() -> void:
	await spawn_player()
	watch_signals(EventBus)
	await tap(&"jump")
	await step(3)
	assert_eq(state(), &"Air")
	assert_true(await until_state(&"Ground", 1.5))
	assert_signal_emitted(EventBus, "player_landed")


func test_running_jump_clears_a_three_metre_gap() -> void:
	await spawn_player()
	press(&"move_forward")
	press(&"sprint")
	await seconds(0.8)
	var takeoff_z: float = player.global_position.z
	await tap(&"jump")
	await until_state(&"Air", 0.2)
	await until_state(&"Ground", 1.5)
	assert_gt(takeoff_z - player.global_position.z, 3.0)


func test_coyote_time_allows_late_jump() -> void:
	add_block(0.0, 0.0, 4.0, 4.0, 3.0)
	await spawn_player(Vector3(0.0, 3.02, 0.0))
	press(&"move_forward")
	assert_true(await until_state(&"Air", 2.0), "walked off the edge")
	await seconds(tuning.coyote_time * 0.5)
	assert_lt(player.velocity.y, 0.0, "falling")
	await tap(&"jump")
	await step(2)
	assert_gt(player.velocity.y, 3.0, "coyote jump fired")


func test_no_jump_after_coyote_time_expires() -> void:
	add_block(0.0, 0.0, 4.0, 4.0, 6.0)
	await spawn_player(Vector3(0.0, 6.02, 0.0))
	press(&"move_forward")
	assert_true(await until_state(&"Air", 2.0))
	await seconds(tuning.coyote_time + 0.1)
	await tap(&"jump")
	await step(2)
	assert_lt(player.velocity.y, 0.0, "too late: still falling")


func test_jump_is_buffered_just_before_landing() -> void:
	await spawn_player()
	await tap(&"jump")
	await until_state(&"Air", 0.2)
	# Wait until landing is under half the buffer window away, then press jump early.
	for i: int in 90:
		await step(1)
		if player.velocity.y < 0.0 and player.global_position.y < -player.velocity.y * tuning.jump_buffer_time * 0.5:
			break
	assert_eq(state(), &"Air", "still airborne when the button is pressed")
	await tap(&"jump")
	await step(6)
	assert_gt(player.velocity.y, 2.0, "buffered jump fired on landing")
	assert_eq(state(), &"Air")


func test_air_control_steers_the_jump() -> void:
	await spawn_player()
	await tap(&"jump")
	await until_state(&"Air", 0.2)
	press(&"move_right")
	await seconds(0.4)
	assert_gt(player.velocity.x, 2.0)


func test_long_fall_reports_hard_landing() -> void:
	await spawn_player(Vector3(0.0, 9.0, 0.0))
	watch_signals(EventBus)
	assert_true(await until_state(&"Ground", 3.0))
	var parameters: Array = get_signal_parameters(EventBus, "player_landed")
	assert_gt(float(parameters[0]), tuning.hard_landing_speed)
	assert_signal_emitted(EventBus, "camera_shake_requested")


func test_falling_out_of_the_world_is_survivable_by_teleport() -> void:
	await spawn_player()
	player.teleport(Vector3(5.0, 2.0, 5.0), PI)
	await step(2)
	assert_almost_eq(player.global_position.x, 5.0, 0.01)
	assert_almost_eq(player.facing_yaw, PI, 0.001)
	assert_true(await until_state(&"Ground", 2.0))
