extends PlayerState
## Airborne: jumping or falling, with air control, coyote time and ledge grabs.

var _coyote_timer: float = 0.0
var _peak_fall_speed: float = 0.0


func enter(_previous: StringName, message: Dictionary) -> void:
	_coyote_timer = player.tuning.coyote_time if message.get("coyote", false) else 0.0
	_peak_fall_speed = 0.0
	player.is_sprinting = false
	if player.is_crouching:
		player.set_crouching(false, true)
	player.visuals.set_pose_mode(PlayerVisuals.PoseMode.AIR)
	if message.get("jumped", false):
		player.visuals.play_jump()


func physics_update(delta: float) -> void:
	var tuning: PlayerTuning = player.tuning

	# Coyote time: a jump pressed just after walking off an edge still counts.
	if _coyote_timer > 0.0:
		_coyote_timer -= delta
		if player.consume_jump_buffer():
			_coyote_timer = 0.0
			player.velocity.y = tuning.get_jump_velocity()
			player.visuals.play_jump()

	var direction: Vector3 = player.get_move_direction()
	if direction.length_squared() > 0.01:
		var air_speed: float = maxf(player.get_horizontal_speed(), tuning.jog_speed)
		player.accelerate_horizontal(direction.normalized(), air_speed, tuning.air_acceleration, delta)
		player.face_direction(direction, tuning.turn_speed * 0.6, delta)

	player.apply_gravity_half(delta)
	player.move_and_slide()
	player.apply_gravity_half(delta)
	_peak_fall_speed = maxf(_peak_fall_speed, -player.velocity.y)

	if player.is_on_floor():
		_land()
		return

	if player.velocity.y < 5.0 and player.ledge_cooldown <= 0.0 and _try_grab_ledge():
		return


func _land() -> void:
	var impact: float = _peak_fall_speed
	player.visuals.play_land(impact)
	player.emit_noise(player.tuning.noise_landing * clampf(impact / 8.0, 0.4, 1.5))
	if impact >= player.tuning.hard_landing_speed:
		EventBus.camera_shake_requested.emit(0.35)
	EventBus.player_landed.emit(impact)
	machine.transition_to(&"Ground")


func _try_grab_ledge() -> bool:
	var tuning: PlayerTuning = player.tuning
	var ledge: LedgeInfo = player.ledge_detector.find_ledge(
			player.global_position, player.get_facing_direction(),
			tuning.air_mantle_min_height, tuning.ledge_grab_max_height)
	if ledge == null:
		return false
	var height_above_feet: float = ledge.top_y - player.global_position.y
	# Only grab when moving or steering toward the wall.
	var toward_wall: Vector3 = -ledge.normal
	var steering: bool = player.get_move_direction().dot(toward_wall) > 0.2
	var drifting: bool = player.get_horizontal_velocity().dot(toward_wall) > 0.5
	if not steering and not drifting:
		return false
	# High enough to hang from; lower ledges are pulled onto directly.
	if ledge.can_hang and height_above_feet >= tuning.ledge_grab_min_height:
		machine.transition_to(&"LedgeHang", {"ledge": ledge})
		return true
	if ledge.can_stand:
		machine.transition_to(&"Mantle", {"ledge": ledge})
		return true
	return false
