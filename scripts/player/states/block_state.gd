extends PlayerState
## Guard up. A hit that lands just after the guard is raised is a parry.

var _can_parry: bool = true
var _time: float = 0.0


func enter(_previous: StringName, _message: Dictionary) -> void:
	_time = 0.0
	_can_parry = player.clock - player.block_ended_at >= player.combat.parry_rearm_time
	player.is_sprinting = false
	player.visuals.play_action(&"Blocking")


func exit(_next: StringName) -> void:
	player.block_ended_at = player.clock


## True while a hit would count as a parry rather than a block.
func can_parry_now() -> bool:
	return _can_parry and _time <= player.combat.get_parry_window()


func physics_update(delta: float) -> void:
	_time += delta
	if not player.is_block_wanted():
		machine.transition_to(&"Ground" if player.is_on_floor() else &"Air")
		return
	if player.try_combat_action(false):
		return
	var direction: Vector3 = player.get_move_direction()
	player.accelerate_horizontal(direction, player.combat.block_move_speed, 30.0, delta)
	player.face_direction(player.get_attack_direction(), 9.0, delta)
	player.ground_move(delta)
