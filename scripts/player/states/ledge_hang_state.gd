extends PlayerState
## Hanging from a ledge: shimmy left/right, climb up, drop, or hop off backwards.

const CLIMB_HOLD_SECONDS: float = 0.22

var _ledge: LedgeInfo
var _push_up_time: float = 0.0


func enter(_previous: StringName, message: Dictionary) -> void:
	_ledge = message["ledge"]
	_push_up_time = 0.0
	player.velocity = Vector3.ZERO
	player.is_sprinting = false
	var before: Vector3 = player.global_position
	player.global_position = _ledge.hang_position
	player.visuals.absorb_step(before - _ledge.hang_position)
	player.snap_facing(-_ledge.normal)
	player.visuals.set_pose_mode(PlayerVisuals.PoseMode.HANG)
	_update_hands()


func physics_update(delta: float) -> void:
	var tuning: PlayerTuning = player.tuning
	var direction: Vector3 = player.get_move_direction()
	var toward_wall: float = direction.dot(-_ledge.normal)

	if player.consume_jump_buffer():
		if toward_wall < -0.4:
			_hop_off()
			return
		if _try_climb():
			return

	if player.is_action_just_pressed(&"crouch"):
		_drop()
		return

	# Holding toward the wall climbs up without needing a second button.
	_push_up_time = _push_up_time + delta if toward_wall > 0.7 else 0.0
	if _push_up_time >= CLIMB_HOLD_SECONDS and _try_climb():
		return

	var sideways: float = direction.dot(_ledge.get_tangent())
	if absf(sideways) > 0.3:
		_shimmy(signf(sideways) * tuning.shimmy_speed * delta)


func exit(_next: StringName) -> void:
	player.ledge_cooldown = player.tuning.ledge_regrab_cooldown


func _shimmy(step: float) -> void:
	var hand_lead: float = signf(step) * (player.visuals.animation_set.hand_spread + 0.08)
	# The leading hand must still have ledge under it.
	if player.ledge_detector.find_ledge_along(_ledge, step + hand_lead) == null:
		return
	var next: LedgeInfo = player.ledge_detector.find_ledge_along(_ledge, step)
	if next == null or not next.can_hang:
		return
	_ledge = next
	player.global_position = _ledge.hang_position
	_update_hands()


func _try_climb() -> bool:
	# Re-check: something may have moved onto the ledge since the grab.
	var fresh: LedgeInfo = player.ledge_detector.find_ledge_along(_ledge, 0.0)
	if fresh == null or not fresh.can_stand:
		return false
	machine.transition_to(&"Mantle", {"ledge": fresh})
	return true


func _drop() -> void:
	player.velocity = Vector3.ZERO
	machine.transition_to(&"Air")


func _hop_off() -> void:
	player.velocity = _ledge.normal * 4.2 + Vector3.UP * player.tuning.get_jump_velocity() * 0.8
	player.snap_facing(_ledge.normal)
	machine.transition_to(&"Air", {"jumped": true})


func _update_hands() -> void:
	var spread: Vector3 = _ledge.get_tangent() * player.visuals.animation_set.hand_spread
	var grip: Vector3 = _ledge.edge_point - _ledge.normal * 0.05 + Vector3.UP * 0.03
	# Tangent points to the player's right when facing the wall.
	player.visuals.set_hand_targets(grip - spread, grip + spread)
