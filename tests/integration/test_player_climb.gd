extends PlayerTestBase
## Climbing: vaults, ledge grabs, shimmying, pulling up, dropping, and ladders.

const WALL_Z: float = -2.0  # near face of the test blocks


func _add_wall(height: float, climbable: bool = true, width: float = 8.0, depth: float = 3.0) -> void:
	add_block(0.0, WALL_Z - depth * 0.5, width, depth, height, climbable)


func _grab_wall() -> bool:
	press(&"move_forward")
	await tap(&"jump")
	var grabbed: bool = await until_state(&"LedgeHang", 1.5)
	release(&"move_forward")
	return grabbed


func test_vaults_onto_a_low_climbable_block() -> void:
	_add_wall(1.0)
	await spawn_player(Vector3(0.0, 0.02, -1.2))
	await tap(&"jump")
	assert_true(await until_state(&"Mantle", 0.2), "jump next to a low ledge vaults instead of jumping")
	assert_true(await until_state(&"Ground", 1.5))
	assert_almost_eq(player.global_position.y, 1.0, 0.04)
	assert_lt(player.global_position.z, WALL_Z, "standing on top")


func test_plain_jump_when_block_is_not_climbable() -> void:
	_add_wall(1.0, false)
	await spawn_player(Vector3(0.0, 0.02, -1.2))
	await tap(&"jump")
	await step(3)
	assert_eq(state(), &"Air")
	assert_gt(player.velocity.y, 3.0)


func test_grabs_a_high_ledge_and_hangs() -> void:
	_add_wall(2.3)
	await spawn_player(Vector3(0.0, 0.02, -1.0))
	assert_true(await _grab_wall(), "grabbed the ledge")
	await seconds(0.3)
	assert_eq(state(), &"LedgeHang")
	assert_almost_eq(player.global_position.y, 2.3 - tuning.hang_feet_offset, 0.02)
	assert_almost_eq(player.velocity.length(), 0.0, 0.001, "hanging still")
	assert_lt(player.get_facing_direction().z, -0.98, "facing the wall")


func test_pulls_up_from_hang_with_jump() -> void:
	_add_wall(2.3)
	await spawn_player(Vector3(0.0, 0.02, -1.0))
	assert_true(await _grab_wall())
	await seconds(0.2)
	await tap(&"jump")
	assert_true(await until_state(&"Mantle", 0.3))
	assert_true(await until_state(&"Ground", 1.5))
	assert_almost_eq(player.global_position.y, 2.3, 0.04)


func test_holding_forward_pulls_up_automatically() -> void:
	_add_wall(2.3)
	await spawn_player(Vector3(0.0, 0.02, -1.0))
	press(&"move_forward")
	await tap(&"jump")
	assert_true(await until_state(&"LedgeHang", 1.5))
	assert_true(await until_state(&"Ground", 2.0), "kept holding forward")
	assert_almost_eq(player.global_position.y, 2.3, 0.04)


func test_drops_from_hang_with_crouch_and_does_not_regrab() -> void:
	_add_wall(2.3)
	await spawn_player(Vector3(0.0, 0.02, -1.0))
	assert_true(await _grab_wall())
	await seconds(0.2)
	await tap(&"crouch")
	assert_true(await until_state(&"Ground", 1.5))
	assert_almost_eq(player.global_position.y, 0.0, 0.04)


func test_hops_off_backwards() -> void:
	_add_wall(2.3)
	await spawn_player(Vector3(0.0, 0.02, -1.0))
	assert_true(await _grab_wall())
	await seconds(0.2)
	var hang_z: float = player.global_position.z
	press(&"move_back")
	await tap(&"jump")
	await step(4)
	assert_eq(state(), &"Air")
	assert_gt(player.velocity.z, 2.0, "pushed away from the wall")
	release(&"move_back")
	assert_true(await until_state(&"Ground", 2.0))
	assert_gt(player.global_position.z, hang_z + 0.8)


func test_shimmies_sideways_and_stops_at_the_end_of_the_ledge() -> void:
	_add_wall(2.3, true, 6.0)
	await spawn_player(Vector3(0.0, 0.02, -1.0))
	assert_true(await _grab_wall())
	await seconds(0.2)
	press(&"move_right")
	await seconds(1.0)
	assert_almost_eq(player.global_position.x, tuning.shimmy_speed, 0.1, "about one second of shimmy")
	assert_eq(state(), &"LedgeHang")
	await seconds(4.0)
	assert_eq(state(), &"LedgeHang")
	assert_lt(player.global_position.x, 3.0, "never past the end of the wall")
	assert_gt(player.global_position.x, 2.3, "reached the end")


func test_cannot_pull_up_where_the_top_is_blocked() -> void:
	_add_wall(2.3)
	# A crate set back from the edge: room for hands, no room to stand.
	add_box(Vector3(0.0, 2.3 + 0.7, WALL_Z - 0.45 - 0.5), Vector3(8.0, 1.4, 1.0))
	await spawn_player(Vector3(0.0, 0.02, -1.0))
	assert_true(await _grab_wall(), "can still hang below the crate")
	await seconds(0.2)
	await tap(&"jump")
	await seconds(0.5)
	assert_eq(state(), &"LedgeHang", "no room on top")


func test_does_not_grab_non_climbable_wall() -> void:
	_add_wall(2.3, false)
	await spawn_player(Vector3(0.0, 0.02, -1.0))
	press(&"move_forward")
	await tap(&"jump")
	assert_false(await until_state(&"LedgeHang", 1.0))
	assert_true(await until_state(&"Ground", 1.0))
	assert_almost_eq(player.global_position.y, 0.0, 0.04)


func test_wall_too_high_cannot_be_reached() -> void:
	_add_wall(3.2)
	await spawn_player(Vector3(0.0, 0.02, -1.0))
	press(&"move_forward")
	await tap(&"jump")
	assert_false(await until_state(&"LedgeHang", 1.2))
	assert_almost_eq(player.global_position.y, 0.0, 0.04)


func test_medium_block_is_pulled_onto_from_a_jump() -> void:
	_add_wall(1.7)
	await spawn_player(Vector3(0.0, 0.02, -1.0))
	press(&"move_forward")
	await tap(&"jump")
	assert_true(await until_state(&"Mantle", 1.0), "pulled up without a second button press")
	release(&"move_forward")
	assert_true(await until_state(&"Ground", 1.5))
	assert_almost_eq(player.global_position.y, 1.7, 0.04)


func test_missed_jump_onto_platform_edge_is_saved_by_mantle() -> void:
	add_block(0.0, -6.0, 4.0, 4.0, 1.0, true)
	# Start level with the platform top, slightly too far to land on it.
	add_block(0.0, 2.0, 4.0, 4.0, 1.0)
	await spawn_player(Vector3(0.0, 1.02, 0.5))
	press(&"move_forward")
	await seconds(0.25)
	await tap(&"jump")
	await seconds(1.6)
	assert_eq(state(), &"Ground")
	assert_almost_eq(player.global_position.y, 1.0, 0.04, "ended on the far platform, not on the floor")
	assert_lt(player.global_position.z, -4.0)


func _add_ladder(height: float) -> Ladder:
	add_block(0.0, -5.0, 4.0, 4.0, height)
	var ladder := Ladder.new()
	ladder.height = height
	ladder.position = Vector3(0.0, 0.0, -3.0)
	world.add_child(ladder)
	return ladder


func test_ladder_prompt_and_interact() -> void:
	_add_ladder(4.0)
	await spawn_player(Vector3(0.0, 0.02, -2.2))
	await step(4)
	assert_not_null(player.interaction.current, "ladder is in reach")
	await tap(&"interact")
	assert_eq(state(), &"Ladder")
	assert_lt(player.get_facing_direction().z, -0.98)


func test_climbs_ladder_to_the_top() -> void:
	_add_ladder(4.0)
	await spawn_player(Vector3(0.0, 0.02, -2.2))
	await step(4)
	await tap(&"interact")
	press(&"move_forward")
	await seconds(1.0)
	assert_almost_eq(player.global_position.y, tuning.ladder_speed * 1.0, 0.15)
	assert_eq(state(), &"Ladder")
	assert_true(await until_state(&"Ground", 3.0), "pulled up onto the roof")
	assert_almost_eq(player.global_position.y, 4.0, 0.05)
	assert_lt(player.global_position.z, -3.0)


func test_climbs_down_and_steps_off() -> void:
	_add_ladder(4.0)
	await spawn_player(Vector3(0.0, 0.02, -2.2))
	await step(4)
	await tap(&"interact")
	press(&"move_forward")
	await seconds(0.8)
	release(&"move_forward")
	press(&"move_back")
	assert_true(await until_state(&"Ground", 2.5))
	assert_almost_eq(player.global_position.y, 0.0, 0.05)


func test_jump_off_ladder() -> void:
	_add_ladder(4.0)
	await spawn_player(Vector3(0.0, 0.02, -2.2))
	await step(4)
	await tap(&"interact")
	press(&"move_forward")
	await seconds(0.6)
	release(&"move_forward")
	await tap(&"jump")
	await step(3)
	assert_eq(state(), &"Air")
	assert_gt(player.velocity.z, 1.5, "pushed away from the ladder")


func test_ladder_can_be_entered_from_the_top() -> void:
	var ladder: Ladder = _add_ladder(4.0)
	await spawn_player(Vector3(0.0, 4.02, -3.8))
	await step(4)
	assert_eq(ladder.get_prompt(player), "Climb down")
	await tap(&"interact")
	assert_eq(state(), &"Ladder")
	assert_almost_eq(player.global_position.y, ladder.get_max_feet_height(), 0.05)
