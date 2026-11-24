extends PlayerState
## Climbing a ladder: up/down along it, step off at the bottom, pull up at the
## top, or jump away.

var _ladder: Ladder
## Height of the feet above the ladder's base.
var _height: float = 0.0


func enter(_previous: StringName, message: Dictionary) -> void:
	_ladder = message["ladder"]
	player.velocity = Vector3.ZERO
	player.is_sprinting = false
	if player.is_crouching:
		player.set_crouching(false, true)
	_height = clampf(player.global_position.y - _ladder.get_base().y, 0.05, _ladder.get_max_feet_height())
	if message.get("from_top", false):
		_height = _ladder.get_max_feet_height()
	var before: Vector3 = player.global_position
	player.global_position = _ladder.get_climb_position(_height, player.tuning.body_radius)
	player.visuals.absorb_step(before - player.global_position)
	player.snap_facing(-_ladder.get_normal())
	player.visuals.set_pose_mode(PlayerVisuals.PoseMode.LADDER)
	_update_limbs()


func physics_update(delta: float) -> void:
	var tuning: PlayerTuning = player.tuning

	if player.consume_jump_buffer():
		player.velocity = _ladder.get_normal() * 3.6 + Vector3.UP * tuning.get_jump_velocity() * 0.6
		player.snap_facing(_ladder.get_normal())
		machine.transition_to(&"Air", {"jumped": true})
		return
	if player.is_action_just_pressed(&"crouch"):
		machine.transition_to(&"Air")
		return

	var climb_input: float = -player.get_move_input().y
	_height += climb_input * tuning.ladder_speed * delta

	if _height >= _ladder.get_max_feet_height() and climb_input > 0.0:
		_exit_top()
		return
	if _height <= 0.0 and climb_input < 0.0:
		player.global_position = _ladder.get_climb_position(0.0, tuning.body_radius)
		machine.transition_to(&"Air")
		return

	_height = clampf(_height, 0.0, _ladder.get_max_feet_height())
	player.global_position = _ladder.get_climb_position(_height, tuning.body_radius)
	_update_limbs()


func exit(_next: StringName) -> void:
	player.ledge_cooldown = player.tuning.ledge_regrab_cooldown


func _exit_top() -> void:
	var ledge := LedgeInfo.new()
	ledge.normal = _ladder.get_normal()
	ledge.edge_point = _ladder.get_top()
	ledge.top_y = ledge.edge_point.y
	ledge.stand_position = _ladder.get_top_exit_position(player.tuning.body_radius)
	ledge.can_stand = true
	machine.transition_to(&"Mantle", {"ledge": ledge})


## Hands and feet step from rung to rung, alternating sides.
func _update_limbs() -> void:
	var pose: CharacterAnimationSet = player.visuals.animation_set
	var spacing: float = pose.ladder_rung_spacing
	var base: Vector3 = _ladder.get_base()
	var face: Vector3 = base + _ladder.get_normal() * 0.04
	var side: Vector3 = Vector3.UP.cross(_ladder.get_normal()).normalized() * 0.16
	var top_limit: float = _ladder.height - 0.02

	var left_hand: float = minf(snappedf(_height + pose.ladder_hand_height, spacing), top_limit)
	var right_hand: float = minf(snappedf(_height + pose.ladder_hand_height + spacing * 0.5, spacing), top_limit)
	var left_foot: float = maxf(snappedf(_height + pose.ladder_foot_height + spacing * 0.5, spacing), 0.0)
	var right_foot: float = maxf(snappedf(_height + pose.ladder_foot_height, spacing), 0.0)

	player.visuals.set_hand_targets(
			face - side + Vector3.UP * left_hand,
			face + side + Vector3.UP * right_hand)
	player.visuals.set_foot_targets(
			face - side * 0.8 + Vector3.UP * left_foot,
			face + side * 0.8 + Vector3.UP * right_foot)
