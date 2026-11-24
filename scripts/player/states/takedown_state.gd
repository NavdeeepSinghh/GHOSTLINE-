extends PlayerState
## A silent takedown from behind an unaware enemy.

const STRIKE_FRACTION: float = 0.55

var _target: Node3D
var _time: float = 0.0
var _struck: bool = false


func enter(_previous: StringName, message: Dictionary) -> void:
	_target = message["target"]
	_time = 0.0
	_struck = false
	player.velocity = Vector3.ZERO
	player.is_sprinting = false
	player.dodge_invulnerable = true
	if player.is_crouching:
		player.set_crouching(false, true)
	var to_target: Vector3 = _target.global_position - player.global_position
	to_target.y = 0.0
	player.snap_facing(to_target)
	_target.call(&"begin_takedown", player)
	player.visuals.play_action(&"1H_Melee_Attack_Stab", player.combat.takedown_duration)


func exit(_next: StringName) -> void:
	player.dodge_invulnerable = false
	if not _struck and is_instance_valid(_target):
		_target.call(&"finish_takedown")


func physics_update(delta: float) -> void:
	_time += delta
	player.ground_move(delta)
	var duration: float = player.combat.takedown_duration
	if not _struck and _time >= duration * STRIKE_FRACTION:
		_struck = true
		if is_instance_valid(_target):
			_target.call(&"finish_takedown")
			EventBus.takedown_performed.emit()
			CombatFX.sfx(&"takedown", _target.global_position + Vector3.UP, -8.0)
	if _time >= duration:
		machine.transition_to(&"Ground" if player.is_on_floor() else &"Air")
