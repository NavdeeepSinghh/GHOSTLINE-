extends PlayerState
## Reeling from a hit: a short flinch, or a longer stagger for heavy blows
## and guard breaks. Kael is pushed back and cannot act until it ends.

var _time: float = 0.0
var _duration: float = 0.3


func enter(_previous: StringName, message: Dictionary) -> void:
	var combat: CombatTuning = player.combat
	var stagger: bool = message.get("stagger", false)
	_time = 0.0
	_duration = float(message.get("duration", combat.stagger_time if stagger else combat.flinch_time))
	player.is_sprinting = false
	var from: Vector3 = message.get("from", player.get_facing_direction())
	var push: float = combat.knockback_stagger if stagger else combat.knockback_flinch
	player.velocity.x = -from.x * push
	player.velocity.z = -from.z * push
	player.visuals.play_action(&"Hit_B" if stagger else &"Hit_A", _duration)


func physics_update(delta: float) -> void:
	_time += delta
	player.accelerate_horizontal(Vector3.ZERO, 0.0, 14.0, delta)
	player.ground_move(delta)
	if _time >= _duration:
		machine.transition_to(&"Ground" if player.is_on_floor() else &"Air")
