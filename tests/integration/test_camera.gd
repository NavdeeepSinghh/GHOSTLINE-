extends PlayerTestBase
## Camera rig: framing, wall collision, lock-on targeting.

var rig: CameraRig


func _spawn_with_camera(at: Vector3 = Vector3(0.0, 0.02, 0.0)) -> void:
	await spawn_player(at)
	rig = CameraRig.new()
	world.add_child(rig)
	rig.follow(player)
	await wait_process_frames(4)


func test_camera_sits_behind_and_above_the_player() -> void:
	await _spawn_with_camera()
	var offset: Vector3 = rig.camera.global_position - player.global_position
	assert_gt(offset.z, 2.5, "behind (player faces -Z)")
	assert_gt(offset.y, 1.4, "above")
	assert_almost_eq(offset.x, rig.tuning.shoulder_offset, 0.1, "over the right shoulder")
	assert_almost_eq(rig.camera.global_position.distance_to(
			player.global_position + Vector3.UP * rig.tuning.focus_height + Vector3.RIGHT * rig.tuning.shoulder_offset),
			rig.tuning.distance, 0.1)


func test_movement_is_relative_to_camera_yaw() -> void:
	await _spawn_with_camera()
	rig.yaw = PI * 0.5
	press(&"move_forward")
	await seconds(0.8)
	assert_lt(player.velocity.x, -4.0, "camera turned left, so forward is -X")
	assert_almost_eq(player.velocity.z, 0.0, 0.2)


func test_camera_pulls_in_front_of_a_wall_behind_the_player() -> void:
	add_block(0.0, 2.0, 12.0, 1.0, 6.0)  # wall face at z = 1.5
	await _spawn_with_camera()
	await wait_process_frames(6)
	assert_lt(rig.camera.global_position.z, 1.5 - rig.tuning.collision_radius + 0.03, "camera stays out of the wall")
	assert_gt(rig.camera.global_position.z, 0.5)


func test_camera_eases_back_out_when_clear() -> void:
	add_block(0.0, 2.0, 12.0, 1.0, 6.0)
	await _spawn_with_camera()
	await wait_process_frames(6)
	var close: float = rig.camera.global_position.distance_to(player.global_position)
	player.teleport(Vector3(0.0, 0.02, -20.0))
	rig._back_fraction = 0.3
	await wait_process_frames(3)
	var recovering: float = rig._back_fraction
	assert_lt(recovering, 0.9, "recovers gradually, not in one frame")
	await wait_seconds(1.2)
	assert_almost_eq(rig._back_fraction, 1.0, 0.01)
	assert_gt(rig.camera.global_position.distance_to(player.global_position), close)


func test_camera_stays_low_under_a_ceiling_instead_of_collapsing() -> void:
	add_box(Vector3(0.0, 2.1, 0.0), Vector3(8.0, 0.4, 16.0))  # underside at 1.9
	await _spawn_with_camera()
	await wait_process_frames(6)
	assert_lt(rig.camera.global_position.y, 1.9 - rig.tuning.collision_radius + 0.03)
	assert_gt(rig.camera.global_position.z - player.global_position.z, 2.5, "still well behind the player")


func test_pitch_is_clamped() -> void:
	await _spawn_with_camera()
	rig.pitch = 5.0
	rig._update_look(0.016)
	assert_almost_eq(rig.pitch, deg_to_rad(rig.tuning.max_pitch_degrees), 0.001)


func test_lock_on_picks_visible_target_and_releases() -> void:
	await _spawn_with_camera()
	var dummy := TargetDummy.new()
	dummy.position = Vector3(0.0, 0.0, -8.0)
	world.add_child(dummy)
	await wait_process_frames(3)
	watch_signals(EventBus)
	rig.toggle_lock_on()
	assert_eq(rig.lock_target, dummy)
	assert_signal_emitted_with_parameters(EventBus, "lock_on_changed", [dummy])
	rig.toggle_lock_on()
	assert_null(rig.lock_target)


func test_lock_on_ignores_targets_behind_walls_or_out_of_range() -> void:
	await _spawn_with_camera()
	add_block(0.0, -4.0, 10.0, 0.5, 5.0)
	var hidden := TargetDummy.new()
	hidden.position = Vector3(0.0, 0.0, -8.0)
	world.add_child(hidden)
	var far := TargetDummy.new()
	far.position = Vector3(6.0, 0.0, -60.0)
	world.add_child(far)
	await wait_process_frames(3)
	rig.toggle_lock_on()
	assert_null(rig.lock_target)


func test_lock_on_switches_to_target_on_the_right() -> void:
	await _spawn_with_camera()
	var left := TargetDummy.new()
	left.position = Vector3(-2.0, 0.0, -9.0)
	world.add_child(left)
	var right := TargetDummy.new()
	right.position = Vector3(3.0, 0.0, -9.0)
	world.add_child(right)
	await wait_process_frames(3)
	rig.set_lock_target(left)
	assert_eq(rig._find_lock_target(1.0), right)
	assert_null(rig._find_lock_target(-1.0), "nothing further left")


func test_lock_on_turns_camera_toward_target() -> void:
	await _spawn_with_camera()
	var dummy := TargetDummy.new()
	dummy.position = Vector3(8.0, 0.0, -4.0)
	world.add_child(dummy)
	await wait_process_frames(3)
	rig.set_lock_target(dummy)
	await wait_seconds(1.0)
	var to_target: Vector3 = (dummy.global_position - player.global_position).normalized()
	var camera_forward: Vector3 = -rig.camera.global_basis.z
	assert_gt(Vector2(camera_forward.x, camera_forward.z).normalized().dot(Vector2(to_target.x, to_target.z).normalized()), 0.97)


func test_shake_respects_setting() -> void:
	await _spawn_with_camera()
	SettingsManager.set_value("gameplay", "camera_shake", false, false)
	rig.add_trauma(0.8)
	assert_almost_eq(rig._trauma, 0.0, 0.001)
	SettingsManager.set_value("gameplay", "camera_shake", true, false)
	rig.add_trauma(0.8)
	assert_almost_eq(rig._trauma, 0.8, 0.001)
