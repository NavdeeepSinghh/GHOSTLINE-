extends PlayerState
## A quick dodge with a short invulnerable window. Toward the stick, or a
## backstep when no direction is held.

var _time: float = 0.0
var _direction: Vector3


func enter(_previous: StringName, _message: Dictionary) -> void:
	var combat: CombatTuning = player.combat
	_time = 0.0
	player.is_sprinting = false
	player.spend_stamina(combat.dodge_stamina)
	var input: Vector3 = player.get_move_direction()
	if input.length_squared() > 0.04:
		_direction = input.normalized()
		player.snap_facing(_direction)
		player.visuals.play_action(&"Dodge_Forward", combat.dodge_duration)
	else:
		_direction = -player.get_facing_direction()
		player.visuals.play_action(&"Dodge_Backward", combat.dodge_duration)
	CombatFX.sfx(&"dodge", player.global_position + Vector3.UP, -6.0)
	player.emit_noise(player.tuning.noise_jog)


func exit(_next: StringName) -> void:
	player.dodge_invulnerable = false


func physics_update(delta: float) -> void:
	var combat: CombatTuning = player.combat
	_time += delta
	player.dodge_invulnerable = (_time >= combat.dodge_iframe_start
			and _time <= combat.dodge_iframe_start + combat.dodge_iframe_duration)
	# Speed falls linearly to zero so the dodge covers exactly dodge_distance.
	var progress: float = clampf(_time / combat.dodge_duration, 0.0, 1.0)
	var speed: float = 2.0 * combat.dodge_distance / combat.dodge_duration * (1.0 - progress)
	player.velocity.x = _direction.x * speed
	player.velocity.z = _direction.z * speed
	player.ground_move(delta)
	if _time >= combat.dodge_duration:
		machine.transition_to(&"Ground" if player.is_on_floor() else &"Air")
