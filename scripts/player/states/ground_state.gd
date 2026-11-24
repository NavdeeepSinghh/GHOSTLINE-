extends PlayerState
## On the ground: idle, walk, jog, sprint and crouch are one continuous state
## because Kael blends freely between them.

var _hold_crouch_active: bool = false


func enter(previous: StringName, _message: Dictionary) -> void:
	player.velocity.y = 0.0
	player.visuals.set_pose_mode(PlayerVisuals.PoseMode.GROUND)
	if previous == &"Air" and player.consume_jump_buffer():
		_jump()


func exit(_next: StringName) -> void:
	player.is_sprinting = false


func physics_update(delta: float) -> void:
	var tuning: PlayerTuning = player.tuning
	if not player.is_on_floor():
		machine.transition_to(&"Air", {"coyote": true})
		return

	if player.try_combat_action():
		return
	_update_crouch()

	if player.consume_jump_buffer():
		if player.is_crouching and not player.set_crouching(false):
			pass  # low ceiling: cannot jump from here
		elif _try_ground_mantle():
			return
		else:
			_jump()
			return

	var direction: Vector3 = player.get_move_direction()
	var wants_to_move: bool = direction.length_squared() > 0.01
	var sprinting: bool = player.update_sprint(wants_to_move and not player.is_healing(), delta)

	var speed: float = tuning.jog_speed
	var mode: Player.MoveMode = Player.MoveMode.JOG
	if player.is_crouching:
		speed = tuning.crouch_speed
		mode = Player.MoveMode.CROUCH
	elif sprinting:
		speed = tuning.sprint_speed
		mode = Player.MoveMode.SPRINT
	elif player.is_action_held(&"walk") or player.is_healing() or direction.length() < tuning.analog_walk_threshold:
		speed = tuning.walk_speed
		mode = Player.MoveMode.WALK

	if wants_to_move:
		player.move_mode = mode
		player.accelerate_horizontal(direction.normalized(), speed, tuning.ground_acceleration, delta)
		player.face_direction(direction, tuning.sprint_turn_speed if sprinting else tuning.turn_speed, delta)
	else:
		player.move_mode = Player.MoveMode.CROUCH if player.is_crouching else Player.MoveMode.IDLE
		player.accelerate_horizontal(Vector3.ZERO, 0.0, tuning.ground_deceleration, delta)

	# A small downward push keeps the body glued to slopes and steps.
	player.velocity.y = -2.0
	player.move(delta)
	if player.is_on_floor():
		player.velocity.y = 0.0


func _update_crouch() -> void:
	if SettingsManager.get_bool("controls", "toggle_crouch"):
		if player.is_action_just_pressed(&"crouch"):
			player.set_crouching(not player.is_crouching)
	else:
		var held: bool = player.is_action_held(&"crouch")
		if held and not player.is_crouching:
			player.set_crouching(true)
			_hold_crouch_active = true
		elif not held and player.is_crouching and _hold_crouch_active:
			if player.set_crouching(false):
				_hold_crouch_active = false


func _jump() -> void:
	player.velocity.y = player.tuning.get_jump_velocity()
	machine.transition_to(&"Air", {"jumped": true})


## Vault straight onto a low climbable obstacle in front of the body.
func _try_ground_mantle() -> bool:
	var tuning: PlayerTuning = player.tuning
	var ledge: LedgeInfo = player.ledge_detector.find_ledge(
			player.global_position, player.get_facing_direction(),
			tuning.mantle_min_height, tuning.mantle_max_height)
	if ledge == null or not ledge.can_stand:
		return false
	machine.transition_to(&"Mantle", {"ledge": ledge})
	return true
